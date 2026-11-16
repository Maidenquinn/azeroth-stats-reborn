"""Production shared-engine contracts on synthetic data only."""

import json
from pathlib import Path
import runpy
import sys
import hashlib
from reborn_storage_io import dump, load, transform

ROOT = Path(__file__).resolve().parents[1]


def main():
    args = sys.argv
    sys.argv = [str(ROOT / "tools/verify_reborn.py")]
    try:
        context = runpy.run_path(
            str(ROOT / "tools/verify_reborn.py"), run_name="__main__"
        )
    finally:
        sys.argv = args
    lua = context["lua"]
    lua.globals().SHARED_TESTS = 0
    lua.execute(
        """
local A=AzerothStatsReborn;local M=A.SharedCodec
local function check(ok,msg) SHARED_TESTS=SHARED_TESTS+1;assert(ok,msg) end
local function clone(value) return assert(loadstring('return '..SNAPSHOT(value)))() end
AzerothStatsRebornDB=nil;AzerothStatsRebornBackup=nil;AzerothStatsRebornAutoBackup=nil
A.db=nil;A.run=nil;assert(A.InitDB())
local db=A.db
db.runs={{id='shared-fixture-1',class='monk',status='ended',values={damage=10},accounted={},meters={},events={},note='old'},
 {id='shared-fixture-2',class='mage',status='ended',values={damage=20},accounted={},meters={},events={}}}
db.sequence=2;A.Account(db.runs[1]);A.Account(db.runs[2])
check(A.CreateDataBackup(false),'legacy manual fixture')
check(A.CreateDataBackup(true),'legacy auto fixture')
db.runs[1].note='edited'
check(A.CreateDataBackup(false),'edited legacy fixture')
check(A.CreateDataBackup(true),'edited auto fixture')
local manual,auto=AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup
local original=SNAPSHOT({db,manual,auto})
local root,marker=A.BuildSharedBackupRoots(db,manual,auto)
check(root and marker,'all catalogues migrate')
local optional={schema=2,nextId=2,entries={{id=1,data=clone(db),legacy=false}}}
local optionalRoot,optionalMarker=A.BuildSharedBackupRoots(db,optional,nil)
check(optionalRoot and optionalMarker,'older optional checkpoint metadata accepted')
local optionalExport=A.ExportSharedBackupRoots(optionalRoot,optionalMarker)
check(M.sameData(optionalExport,optional),'rollback preserves absent fields and explicit false flags')
check(SNAPSHOT({db,manual,auto})==original,'migration never mutates source data')
local exportedManual,exportedAuto=A.ExportSharedBackupRoots(root,marker)
check(M.sameData(exportedManual,manual) and M.sameData(exportedAuto,auto),'initial rollback recovers complete legacy catalogues')
AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup=root,marker
check(A.SharedBackupsEnabled(),'shared marker selects backend')
check(table.getn(A.ListDataBackups(false))==2 and table.getn(A.ListDataBackups(true))==2,'both catalogue IDs retained')
local versions=0;for _ in pairs(root.store.pool) do versions=versions+1 end
check(versions==3,'eight run copies share three distinct immutable versions')
for _,kind in ipairs({'manual','auto'}) do
 local source=kind=='manual' and manual or auto
 for _,entry in ipairs(source.entries) do
  local restored=assert(A.SharedReadBackup(entry.id,kind=='auto'))
  check(M.sameData(restored.data,entry.data),'full state restored exactly')
  restored.data.runs[1].note='mutated returned copy'
  check(M.sameData(A.SharedReadBackup(entry.id,kind=='auto').data,entry.data),'restore objects never alias pool')
 end
end
local before=SNAPSHOT(root)
check(A.CreateDataBackup(true),'identical shared automatic request succeeds')
check(SNAPSHOT(AzerothStatsRebornBackup)==before,'identical automatic request changes no shared bytes')
db.settings.autoBackupRetention=1;db.runs[1].note='third'
check(A.CreateDataBackup(true),'new automatic version created')
check(table.getn(A.ListDataBackups(true))==1,'automatic retention applied')
check(M.sameData(A.SharedReadBackup(1,false).data,manual.entries[1].data),'auto pruning preserves manual referenced versions')
A.run=db.runs[2];A.run.status='active'
local current=A.run;local currentData=SNAPSHOT(current)
check(A.CreateDataBackup(false),'manual shared snapshot while playing')
check(A.run==current and SNAPSHOT(current)==currentData,'snapshot freeze never mutates live run')
check(A.SharedReadBackup(3,false).data.runs[2].status=='interrupted','shared active observation frozen in copy')
check(A.DeleteDataBackup(2,false),'shared manual checkpoint deletion')
check(M.sameData(A.SharedReadBackup(1,false).data,manual.entries[1].data),'garbage collection preserves other old checkpoints')
local plan=A.PreviewManualBackupCleanup(1)
check(plan and plan.remove==1,'shared cleanup preview')
check(A.CreateDataBackup(false),'new checkpoint after preview')
check(not A.CleanupManualBackups(1,plan.token),'stale shared cleanup fails')
plan=A.PreviewManualBackupCleanup(1)
check(A.CleanupManualBackups(1,plan.token) and table.getn(A.ListDataBackups(false))==1,'confirmed shared cleanup')
-- Restore through the existing production controller, including its safety snapshot.
db.settings.sharedTest='current'
local selected=A.ListDataBackups(false)[1]
local expected=A.SharedReadBackup(selected.id,false).data
check(A.RestoreDataBackup(selected.id,false),'production shared restore during play')
check(not A.run and A.db.settings.sharedTest==expected.settings.sharedTest,'restore detaches tracker and restores preferences')
local count=table.getn(A.db.runs);local totals=M.fingerprint(A.db.totals)
A.Sample();check(table.getn(A.db.runs)==count and M.fingerprint(A.db.totals)==totals,'current native sample does not overwrite restoration')
local state=clone({AzerothStatsRebornDB=A.db,AzerothStatsRebornBackup=AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup=AzerothStatsRebornAutoBackup})
SHARED_FIXTURE=state
check(A.ValidateSharedBackups(state.AzerothStatsRebornBackup,state.AzerothStatsRebornAutoBackup),'shared root survives serializer roundtrip')
local store=AzerothStatsRebornBackup.store
local ref=next(store.pool);local value=store.pool[ref].values.damage
store.pool[ref].values.damage=value+1
local dbPointer=A.db;local broken=AzerothStatsRebornBackup
check(not A.CreateDataBackup(false) and AzerothStatsRebornBackup==broken,'corrupt root refuses writes without normalization')
check(not A.RestoreDataBackup(selected.id,false) and A.db==dbPointer,'corrupt restore leaves DB unchanged')
check(not A.DeleteDataBackup(selected.id,false),'corrupt root cannot be pruned')
check(not A.ExportSharedBackupRoots(AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup),'corrupt export fails closed')
store.pool[ref].values.damage=value
local marker=AzerothStatsRebornAutoBackup;AzerothStatsRebornAutoBackup=nil
check(A.SharedBackupsEnabled() and not A.CreateDataBackup(false),'partial root pair refuses legacy fallback')
check(AzerothStatsRebornBackup==broken and AzerothStatsRebornAutoBackup==nil,'partial roots preserved')
AzerothStatsRebornAutoBackup=marker
local legacyM,legacyA=A.ExportSharedBackupRoots(AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup)
check(legacyM and legacyA,'rollback exports newly created shared checkpoints too')
local remigrated,ma=A.BuildSharedBackupRoots(A.db,legacyM,legacyA)
check(remigrated and ma,'rollback export remains migration-compatible')
for _,isAuto in ipairs({false,true}) do
 for _,entry in ipairs(A.ListDataBackups(isAuto)) do
  local internal=M.findOrigin(remigrated.store,isAuto and 'auto' or 'manual',entry.id)
  check(M.sameData(A.SharedReadBackup(entry.id,isAuto).data,M.restore(remigrated.store,internal)),'post-migration checkpoints preserve rollback parity')
 end
end
check(AzerothStatsDB==ORIGINAL,'original addon namespace untouched')
local clock=time;time=nil
check(A.CreateDataBackup(false),'missing native clock uses safe checkpoint timestamp')
check(A.ListDataBackups(false)[1].at==0,'missing clock timestamp remains readable')
time=clock
"""
    )
    # Exercise the actual bounded serializer/tool transformation on synthetic roots.
    env = lua.globals().SHARED_FIXTURE
    # Add the data-only loader/serializer to this already isolated VM.
    from reborn_storage_io import runtime

    disk = runtime()
    # Existing serializer in the runtime harness returns valid data assignments.
    raw = lua.eval(
        "function(e) return 'AzerothStatsRebornDB='..SNAPSHOT(e.AzerothStatsRebornDB)..'\\nAzerothStatsRebornBackup='..SNAPSHOT(e.AzerothStatsRebornBackup)..'\\nAzerothStatsRebornAutoBackup='..SNAPSHOT(e.AzerothStatsRebornAutoBackup) end"
    )(env).encode()
    loaded = load(disk, raw)
    legacy, old = transform(disk, loaded, rollback=True)
    migrated, reconstructed = transform(disk, old)
    exported, exported_env = transform(disk, reconstructed, rollback=True)
    assert disk.globals().AzerothStatsReborn.SharedCodec.sameData(old, exported_env)
    compatibility = ROOT / "research/shared-snapshots/compatibility"
    decoder = (compatibility / "DataManagement-0.1.0-reborn.8-dev.lua").read_bytes()
    assert (
        hashlib.sha256(decoder).hexdigest()
        == json.loads((compatibility / "provenance.json").read_text())["sha256"]
    )
    prior_vm = runtime()
    prior_vm.execute(
        decoder.decode("utf8").replace("AzerothStats", "AzerothStatsReborn")
    )
    from reborn_storage_io import bind

    prior_env = load(prior_vm, legacy)
    bind(prior_vm, prior_env)
    assert prior_vm.globals().AzerothStatsReborn.InitDB()
    for name, automatic in (
        ("AzerothStatsRebornBackup", False),
        ("AzerothStatsRebornAutoBackup", True),
    ):
        for _, entry in prior_env[name].entries.items():
            ok = prior_vm.globals().AzerothStatsReborn.RestoreDataBackup(
                entry.id, automatic
            )
            assert ok is True or (isinstance(ok, tuple) and ok[0] is True)
    # Old .8-dev package can restore every exported checkpoint.
    import zipfile, tempfile

    archive = ROOT / "build/AzerothStatsReborn-0.1.0-reborn.8-dev.zip"
    older_checked = False
    if archive.exists():
        with tempfile.TemporaryDirectory(prefix="reborn-old-") as folder:
            with zipfile.ZipFile(archive) as z:
                z.extractall(folder)
            older = runtime(Path(folder) / "AzerothStatsReborn")
            prior = load(older, legacy)
            from reborn_storage_io import bind

            bind(older, prior)
            older.execute("assert(AzerothStatsReborn.InitDB())")
            for name, automatic in (
                ("AzerothStatsRebornBackup", False),
                ("AzerothStatsRebornAutoBackup", True),
            ):
                for _, entry in prior[name].entries.items():
                    ok = older.globals().AzerothStatsReborn.RestoreDataBackup(
                        entry.id, automatic
                    )
                    assert ok is True or (isinstance(ok, tuple) and ok[0] is True)
            older_checked = True
    report = {
        "checks": lua.globals().SHARED_TESTS,
        "syntheticOnly": True,
        "migrationRestoreRollback": True,
        "olderAddonRestore": older_checked,
        "olderDecoderRestore": True,
        "serializedSharedBytes": len(migrated),
        "serializedLegacyBytes": len(legacy),
    }
    (ROOT / "build/reborn-shared-storage-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf8"
    )
    print("PASS: production shared-backup contracts", report)


if __name__ == "__main__":
    main()
