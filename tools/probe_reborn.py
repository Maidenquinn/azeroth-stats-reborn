"""Read-only probes against installed Reborn Lua. Synthetic packets; no player saves."""

from pathlib import Path
import argparse, json
from lupa.lua51 import LuaRuntime

p = argparse.ArgumentParser()
p.add_argument("--game", type=Path, required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
addon = root / "AzerothStats"
native = args.game / "Interface/AddOns"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((addon / "tests/mock.lua").read_text(encoding="utf8"))
lua.execute(
    """
time=function() return 1000 end
IsLoggedIn=function() return true end
UnitExists=function(u) return u=='player' end
UnitName=function() return 'Tester' end
UnitClass=function() return 'Monk','MONK' end
AZS={handlers={}}
function AZS.On(prefix,fn) AZS.handlers[prefix]=AZS.handlers[prefix] or {};table.insert(AZS.handlers[prefix],fn) end
function AZS.ParseKV(msg) local t={};for k,v in string.gmatch(msg or '', '(%w+)=([^;]*)') do t[k]=tonumber(v) or v end;return t end
function AZS.ParseList(msg,names) local out={};for row in string.gmatch(msg or '', '[^;]+') do local v={};local i=1;for s in string.gmatch(row..',','(.-),') do v[names[i] or i]=tonumber(s) or s;i=i+1 end;table.insert(out,v) end;return out end
AZS_List=AZS.ParseList;AZS_Fields=AZS.ParseKV
function ROUTE(prefix,msg) for _,fn in ipairs(AZS.handlers[prefix] or {}) do fn(msg,prefix) end end
AZS_ZONE={zone='hellfire',class='monk',dt=3,run='r12345678'}
AZS_RUN={ph='playing',t=100};AZS_SCHEDULE={};AZS_REVIVE={};AZS_END={};AZS_SPELLS={};AZS_GEAR={}
"""
)
for name in ["Generated/Content.lua"]:
    lua.execute((native / "AzerothSurvivors" / name).read_text(encoding="utf8"))
for name in ["Api.lua", "Meter.lua", "CombatText.lua"]:
    lua.execute((native / "AzerothSurvivorsAPI" / name).read_text(encoding="utf8"))
for name in ["Util.lua", "Safety.lua", "API.lua", "V2CombatObserve.lua"]:
    lua.execute((addon / name).read_text(encoding="utf8"))
lua.execute(
    "AzerothStats.gameText={}; AzerothStats.T=function(s) return s end; AzerothStats.V2FeaturePreferences=function() return {combatIntelligence=true} end"
)
checks = []


def check(name, expr, expected, meaning):
    actual = lua.eval(expr)
    assert actual == expected, (name, actual, expected)
    checks.append(dict(name=name, observed=actual, meaning=meaning))


check("native difficulty", "AZS_ZONE.dt", 3, "Reborn exports dt")
check(
    "native class catalogue",
    "table.getn(AZS_GEN.classes)",
    12,
    "Reborn has twelve class records",
)
check(
    "native zone catalogue",
    "table.getn(AZS_GEN.zones)",
    48,
    "Reborn has forty-eight zone records",
)
check(
    "old difficulty adapter",
    "AzerothStats.ReadHeroic()",
    None,
    "Missing heroic field remains unknown",
)
check(
    "old monk identity",
    "(select(2,AzerothStats.Identity()))",
    "unknown",
    "Monk rejected by nine-class allowlist",
)
lua.execute(
    "ROUTE('AZSZONE',''); ROUTE('AZSMETER','Jab,200,2,1,0,0'); ROUTE('AZSHEAL','Heal,50,0.5,1,0,0')"
)
check(
    "legacy damage",
    'AzerothStats.ReadMeter("damage").total',
    200,
    "Existing reader accepts native meter rows",
)
check(
    "legacy healing",
    'AzerothStats.ReadMeter("healing").total',
    50,
    "Existing reader accepts performed healing rows",
)
check(
    "native stable ID",
    "AZS_API_RunId()",
    "azs:r12345678",
    "Native stable run identity available",
)
check(
    "combat batch version",
    "AZS_GetCombatTextEvents(nil,256).apiVersion",
    1,
    "Native exported batch is valid",
)
check(
    "combat streamId",
    "AZS_GetCombatTextEvents(nil,256).streamId",
    None,
    "Native contract lacks required original streamId",
)
lua.execute("AzerothStats.V2CombatTick({id='probe',status='active'})")
check(
    "old observer rejection",
    "AzerothStats.V2CombatSnapshot().invalid",
    1,
    "Existing observer rejects native batch before collecting events",
)
check(
    "missing combat capability endpoint",
    "type(AZS_GetCombatTextCapabilities)",
    "nil",
    "Capability endpoint absent although feed exists",
)
check(
    "native snapshots",
    "type(AZS_GetMeterSnapshot)",
    "function",
    "Structured meter extension exists",
)
check(
    "native checkpoints",
    "type(AZS_CreateMeterCheckpoint)",
    "function",
    "Atomic checkpoints available",
)
check(
    "computed meter freshness stamp",
    "type(AZS_METER_UPDATED)",
    "number",
    "Computed export is present despite static not-found",
)
lua.execute("AZS_END={result='victory',t=100,dmg=200,zone='hellfire'}")
check(
    "terminal reader",
    "AzerothStats.ReadSummary().result",
    "victory",
    "Reader accepts compatible terminal payload; server scenarios still require live recipe",
)
report = {
    "scope": "Actual installed Lua in Lua 5.1 with mocked host/UI and synthetic packets. Not a live client or server validation. No saves read. PASS confirms audit observations, not port readiness.",
    "checks": checks,
}
(root / "docs/reborn/PROBES.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
)
print(
    f"PASS: {len(checks)} Reborn contract probes (including expected incompatibilities)"
)
