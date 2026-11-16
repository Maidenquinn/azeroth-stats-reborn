"""Run upstream storage research against isolated Reborn Lua 5.1 fixtures only.

No player files are read. No research module is copied to the player ZIP/TOC.
The upstream inputs are immutable and namespaced only in this isolated VM.
"""

import hashlib
import json
from pathlib import Path
import runpy
import sys
import unittest
import zipfile
from build_reborn import VERSION

ROOT = Path(__file__).resolve().parents[1]
RESEARCH = ROOT / "research/shared-snapshots"


def main():
    provenance = json.loads((RESEARCH / "provenance.json").read_text(encoding="utf8"))
    for name, digest in provenance["sha256"].items():
        assert (
            hashlib.sha256((RESEARCH / "upstream" / name).read_bytes()).hexdigest()
            == digest
        ), name

    # Reuse the generated-runtime contract harness, never a player's SavedVariables.
    arguments = sys.argv
    sys.argv = [str(ROOT / "tools/verify_reborn.py")]
    try:
        context = runpy.run_path(
            str(ROOT / "tools/verify_reborn.py"), run_name="__main__"
        )
    finally:
        sys.argv = arguments
    lua = context["lua"]
    target = context["target"]
    toc = (target / "AzerothStatsReborn.toc").read_text(encoding="utf8")
    assert "RebornStorageAudit.lua" in toc
    roots = next(
        line for line in toc.splitlines() if line.startswith("## SavedVariables:")
    )
    assert {name.strip() for name in roots.split(":", 1)[1].split(",")} == {
        "AzerothStatsRebornDB",
        "AzerothStatsRebornBackup",
        "AzerothStatsRebornAutoBackup",
        "AzerothStatsRebornStorageSafety",
    }
    assert not any("research" in path.name.lower() for path in target.rglob("*"))
    lua.execute(
        "assert(SharedBackupResearch==nil and SharedBackupMigrationJournalResearch==nil)"
    )
    with zipfile.ZipFile(
        target.parent / f"AzerothStatsReborn-{VERSION}.zip"
    ) as archive:
        assert all(
            "/tests/" not in name and "/research/" not in name
            for name in archive.namelist()
        )

    def research(name):
        text = (RESEARCH / "upstream/AzerothStats/tests" / (name + ".lua")).read_text(
            encoding="utf8"
        )
        lua.execute(text.replace("AzerothStats", "AzerothStatsReborn"))

    lua.globals().TEST_COUNT = 0
    research("shared_storage_audit")
    lua.execute(
        """
local A=AzerothStatsReborn
local function check(value,label) TEST_COUNT=TEST_COUNT+1;assert(value,label) end
local manual,auto,db,saved=AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup,A.db,AzerothStatsRebornDB
local create,restore=A.CreateDataBackup,A.RestoreDataBackup
A.CreateDataBackup=function() error('audit attempted a backup write') end
A.RestoreDataBackup=function() error('audit attempted restoration') end
local before=SNAPSHOT({db,manual,auto,saved})
local say=A.Say;local output={};A.Say=function(line) table.insert(output,line) end
for _,language in ipairs({'fr','en'}) do
 A.locale=language
 check(A.RebornCommand('  shared audit  '),'audit command routes in each language')
 check(string.find(table.concat(output,' '),language=='fr' and 'lecture seule' or 'Read-only',1,true),'localized audit output')
 output={}
end
check(A.RebornCommand('shared migrate'),'unsupported shared subcommand is help only')
check(SNAPSHOT({A.db,AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup,AzerothStatsRebornDB})==before,'audit and help preserve all saved roots byte-for-byte')
AzerothStatsRebornBackup={schema=2,entries={{data={runs={{id='private-run-id',note='private-note-a'}}}},{data={runs={{id='private-run-id',note='private-note-b'}}}}}}
local candidates=A.SharedStorageReadOnlyAudit()
check(candidates.manual.repeatedRunIDs==1 and not candidates.exactDeduplicatedBytesKnown,'same ID with changed content remains only a sharing candidate')
output={};A.RebornCommand('shared audit')
check(not string.find(table.concat(output,' '),'private-',1,true),'audit output contains no run identifiers or content')
AzerothStatsRebornBackup={schema=2,entries={[2]={data={runs={}}}}}
check(A.SharedStorageReadOnlyAudit().manual.invalid,'sparse checkpoint list is incomplete')
AzerothStatsRebornBackup={schema=2,entries={{data={runs={[2]={id='gap'}}}}}}
check(A.SharedStorageReadOnlyAudit().manual.invalid,'sparse run list is incomplete')
AzerothStatsRebornBackup=setmetatable({},{__index=function() error('unsafe lookup') end})
check(A.SharedStorageReadOnlyAudit().manual.invalid,'metatable root rejected without invoking it')
AzerothStatsRebornBackup={schema=2,entries={}}
for i=1,101 do AzerothStatsRebornBackup.entries[i]={data={runs={}}} end
check(A.SharedStorageReadOnlyAudit().manual.invalid,'checkpoint scan is bounded')
AzerothStatsRebornBackup=nil;AzerothStatsRebornAutoBackup=nil;A.db=nil;AzerothStatsRebornDB=nil
check(A.SharedStorageReadOnlyAudit().activeRuns==0,'audit works before DB initialization')
A.RebornCommand('shared audit')
check(AzerothStatsRebornBackup==nil and AzerothStatsRebornAutoBackup==nil and AzerothStatsRebornDB==nil,'audit never initializes absent roots')
AzerothStatsRebornBackup,AzerothStatsRebornAutoBackup,A.db,AzerothStatsRebornDB=manual,auto,db,saved
A.CreateDataBackup,A.RestoreDataBackup,A.Say=create,restore,say
local originalPrint=print
STORAGE_BENCHMARKS={}
function print(...)
 local values={...}
 if values[1]=='SHARED SNAPSHOT LUA SERIALIZATION PROXY' then
  table.insert(STORAGE_BENCHMARKS,{runs=values[2],legacyBytes=values[4],sharedBytes=values[6]})
 end
 originalPrint(...)
end
"""
    )
    for name in (
        "shared_backup_research",
        "shared_backup_research_contract",
        "shared_backup_migration_contract",
        "shared_backup_scale_contract",
        "shared_backup_size_benchmark",
        "shared_backup_journal_research",
        "shared_backup_journal_contract",
    ):
        research(name)
    lua.execute((RESEARCH / "reborn-contract.lua").read_text(encoding="utf8"))

    sys.path.insert(0, str(RESEARCH / "upstream/tools"))
    suite = unittest.defaultTestLoader.discover(
        str(RESEARCH / "upstream/tools"), pattern="test_research_shared_snapshots.py"
    )
    result = unittest.TextTestRunner(verbosity=1).run(suite)
    assert result.wasSuccessful()
    report = {
        "upstreamCommit": provenance["commit"],
        "luaChecks": lua.globals().TEST_COUNT,
        "pythonTests": result.testsRun,
        "runtime": "legacy by default; shared engine requires explicit migration",
        "researchShipped": False,
        "realDiskSavingsMeasured": False,
        "syntheticLuaSerializationProxy": [
            dict(row.items()) for _, row in lua.globals().STORAGE_BENCHMARKS.items()
        ],
    }
    (ROOT / "build/reborn-storage-research-validation.json").write_text(
        json.dumps(report, indent=2) + "\n", encoding="utf8"
    )
    print(
        f"PASS: {report['luaChecks']} isolated Reborn storage research checks; {report['pythonTests']} Python model tests; no live migration"
    )


if __name__ == "__main__":
    main()
