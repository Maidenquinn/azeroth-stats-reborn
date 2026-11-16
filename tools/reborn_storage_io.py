"""Local closed-client migration helpers. No network; no player input in CI."""

from pathlib import Path
from lupa.lua51 import LuaRuntime

ROOT = Path(__file__).resolve().parents[1]
ROOTS = (
    "AzerothStatsRebornDB",
    "AzerothStatsRebornBackup",
    "AzerothStatsRebornAutoBackup",
)


def runtime(target=None):
    target = target or ROOT / "build/AzerothStatsReborn"
    lua = LuaRuntime(
        unpack_returned_tuples=True,
        register_eval=False,
        register_builtins=False,
        max_memory=768 * 1024 * 1024,
    )
    lua.execute((ROOT / "AzerothStats/tests/mock.lua").read_text(encoding="utf8"))
    for name in (
        (target / "AzerothStatsReborn.toc").read_text(encoding="utf8").splitlines()
    ):
        if name.endswith(".lua"):
            lua.execute((target / name).read_text(encoding="utf8"))
    lua.execute(
        """
function LOAD_STORAGE_DATA(text)
 local f=assert(loadstring(text));local env={};setfenv(f,env)
 local count=0
 debug.sethook(function() count=count+10000;if count>100000000 then error('save parse instruction budget') end end,'',10000)
 local ok,reason=pcall(f);debug.sethook()
 assert(ok,reason)
 for key in pairs(env) do
  assert(key=='AzerothStatsRebornDB' or key=='AzerothStatsRebornBackup' or key=='AzerothStatsRebornAutoBackup','unexpected save root')
 end
 return env
end
function DUMP_STORAGE_DATA(env)
 local output={};local visiting={};local nodes=0
 local function emit(value,depth)
  nodes=nodes+1;assert(nodes<=12000000 and depth<=40,'serialization budget')
  local kind=type(value)
  if kind=='nil' then table.insert(output,'nil')
  elseif kind=='boolean' then table.insert(output,value and 'true' or 'false')
  elseif kind=='string' then table.insert(output,string.format('%q',value))
  elseif kind=='number' then assert(value==value and math.abs(value)<1e100,'invalid number');table.insert(output,string.format('%.17g',value))
  else
   assert(kind=='table' and not getmetatable(value) and not visiting[value],'unsafe serialized table')
   visiting[value]=true;local keys={}
   for key in pairs(value) do assert(type(key)=='string' or type(key)=='number','unsafe key');table.insert(keys,key) end
   table.sort(keys,function(a,b) if type(a)~=type(b) then return type(a)=='number' end return a<b end)
   table.insert(output,'{')
   for _,key in ipairs(keys) do table.insert(output,'[');emit(key,depth+1);table.insert(output,']=');emit(value[key],depth+1);table.insert(output,',') end
   table.insert(output,'}');visiting[value]=nil
  end
 end
 for _,name in ipairs({'AzerothStatsRebornDB','AzerothStatsRebornBackup','AzerothStatsRebornAutoBackup'}) do
  table.insert(output,name..' = ');emit(env[name],0);table.insert(output,'\\n')
 end
 return table.concat(output)
end
"""
    )
    return lua


def load(lua, data):
    assert len(data) <= 128 * 1024 * 1024, "save input exceeds 128 MiB"
    return lua.globals().LOAD_STORAGE_DATA(data.decode("utf-8-sig"))


def dump(lua, env):
    return lua.globals().DUMP_STORAGE_DATA(env).encode("utf8")


def bind(lua, env):
    for name in ROOTS:
        lua.globals()[name] = env[name]
    lua.globals().AzerothStatsReborn.db = env[ROOTS[0]]


def transform(lua, env, rollback=False):
    bind(lua, env)
    lua.globals().STORAGE_ENV = env
    lua.globals().STORAGE_ROLLBACK = rollback
    lua.execute(
        """
local A=AzerothStatsReborn;local M=A.SharedCodec;local env=STORAGE_ENV
assert(A.ValidateDatabase(env.AzerothStatsRebornDB),'live database validation failed')
local manual,automatic
if STORAGE_ROLLBACK then
 manual,automatic=A.ExportSharedBackupRoots(env.AzerothStatsRebornBackup,env.AzerothStatsRebornAutoBackup)
 assert(manual,automatic)
 local candidate,marker=A.BuildSharedBackupRoots(env.AzerothStatsRebornDB,manual,automatic)
 assert(candidate,marker)
 local old=assert(A.ValidateSharedBackups(env.AzerothStatsRebornBackup,env.AzerothStatsRebornAutoBackup))
 for id,entry in pairs(old.entries) do
  local other=M.findOrigin(candidate.store,entry.origin.kind,entry.origin.id)
  assert(other and M.sameData(M.restore(old,id),M.restore(candidate.store,other)),'rollback checkpoint mismatch')
 end
else
 manual,automatic=A.BuildSharedBackupRoots(env.AzerothStatsRebornDB,env.AzerothStatsRebornBackup,env.AzerothStatsRebornAutoBackup)
 assert(manual,automatic)
end
STORAGE_RESULT={AzerothStatsRebornDB=env.AzerothStatsRebornDB,AzerothStatsRebornBackup=manual,AzerothStatsRebornAutoBackup=automatic}
"""
    )
    result = lua.globals().STORAGE_RESULT
    encoded = dump(lua, result)
    reloaded = load(lua, encoded)
    assert lua.globals().AzerothStatsReborn.SharedCodec.sameData(
        result, reloaded
    ), "serialized roundtrip mismatch"
    if not rollback:
        codec = lua.globals().AzerothStatsReborn.SharedCodec
        valid = codec.verifyMigration(
            reloaded[ROOTS[1]].store, env[ROOTS[0]], env[ROOTS[1]], env[ROOTS[2]]
        )
        assert valid is True or (
            isinstance(valid, tuple) and valid[0] is True
        ), "all-checkpoint migration parity failed"
    return encoded, reloaded
