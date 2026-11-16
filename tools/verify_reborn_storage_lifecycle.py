"""Synthetic native-reload recipes for default shared storage and in-addon transitions."""

import json
from build_reborn import build, ROOT
from reborn_storage_io import runtime, dump, ROOTS


def state(vm):
    return vm.table_from({name: vm.globals()[name] for name in ROOTS})


def native_save(vm):
    vm.execute(
        "STORAGE_REAL_FORMAT=string.format;string.format=function(fmt,...) if fmt=='%.17g' then fmt='%.16g' end;return STORAGE_REAL_FORMAT(fmt,...) end"
    )
    try:
        return dump(vm, state(vm))
    finally:
        vm.execute("string.format=STORAGE_REAL_FORMAT")


def reload(vm):
    out = runtime(saved=native_save(vm))
    assert out.globals().AzerothStatsReborn.InitDB()
    return out


def main():
    build()
    checks = 0

    def test(vm, code):
        nonlocal checks
        vm.execute("local A=AzerothStatsReborn;local M=A.SharedCodec;" + code)
        checks += 1

    fresh = runtime()
    test(
        fresh,
        "assert(A.InitDB());assert(A.SharedBackupsEnabled());assert(not AzerothStatsRebornStorageSafety)",
    )
    fresh = reload(fresh)
    test(
        fresh,
        "assert(A.SharedBackupsEnabled());assert(A.CreateDataBackup(false));assert(table.getn(A.ListDataBackups(false))==1)",
    )
    empty = runtime()
    test(
        empty,
        "assert(A.InitDB());AzerothStatsRebornBackup=nil;AzerothStatsRebornAutoBackup=nil;assert(A.PrepareStorageChange('shared'))",
    )
    empty = reload(empty)
    test(empty, "assert(A.ApplyStorageChange(A.StorageReview().token))")
    empty = reload(empty)
    test(
        empty,
        "assert(A.StorageReview().phase=='complete');assert(A.RecoverStorageSafety(A.StorageReview().token))",
    )
    empty = reload(empty)
    test(
        empty,
        "assert(A.StorageReview().phase=='complete');assert(AzerothStatsRebornBackup==nil and AzerothStatsRebornAutoBackup==nil);assert(A.DeleteStorageSafety(A.StorageReview().token))",
    )
    empty = reload(empty)
    test(empty, "assert(not A.SharedBackupsEnabled());assert(A.db)")
    # Manufacture a prior-version profile without performing any real-player write.
    test(
        fresh,
        "AzerothStatsRebornBackup=nil;AzerothStatsRebornAutoBackup=nil;A.db.settings.storageProbe='live';A.db.runs={{id='migration-run',class='mage',status='ended',values={damage=10},accounted={},meters={},events={}}};A.db.sequence=1;A.Account(A.db.runs[1]);assert(A.CreateDataBackup(false));assert(A.CreateDataBackup(true));A.db.runs[1].note='second';assert(A.CreateDataBackup(false))",
    )
    legacy_bytes = native_save(fresh)
    precision = runtime(saved=legacy_bytes)
    test(
        precision,
        "assert(A.InitDB());A.db.settings.autoPrecision=1/7;assert(A.CreateDataBackup(true));assert(A.PrepareStorageChange('shared'))",
    )
    precision = reload(precision)
    test(precision, "assert(A.ApplyStorageChange(A.StorageReview().token))")
    precision = reload(precision)
    test(
        precision,
        "assert(A.StorageReview().phase=='complete' and A.StorageReview().persisted);assert(A.SharedReadBackup(2,true).data.settings.autoPrecision==1/7)",
    )
    vm = runtime(saved=legacy_bytes)
    test(
        vm,
        "assert(A.InitDB());assert(not A.SharedBackupsEnabled());assert(table.getn(A.ListDataBackups(false))==2)",
    )
    test(
        vm,
        "ROOTS_BEFORE=M.encodeStore({manual=AzerothStatsRebornBackup,automatic=AzerothStatsRebornAutoBackup});DB_BEFORE=A.db;assert(A.PrepareStorageChange('shared'));assert(not A.SharedBackupsEnabled());assert(ROOTS_BEFORE==M.encodeStore({manual=AzerothStatsRebornBackup,automatic=AzerothStatsRebornAutoBackup}));assert(A.db==DB_BEFORE)",
    )
    test(
        vm,
        "assert(not A.ApplyStorageChange(A.StorageReview().token));assert(A.InitDB());assert(not A.ApplyStorageChange(A.StorageReview().token));assert(not A.CreateDataBackup(false));assert(not A.DeleteDataBackup(1,false));assert(not A.RestoreDataBackup(1,false))",
    )
    test(
        vm,
        "A.db.settings.storageProbe='progress-during-review';assert(A.StorageReview().phase=='prepared');assert(not A.StorageReview().persisted)",
    )
    staged_bytes = native_save(vm)
    vm = reload(vm)
    test(
        vm,
        "assert(A.StorageReview().persisted);assert(not A.ApplyStorageChange('stale-token'));DB_BEFORE=A.db;assert(A.ApplyStorageChange(A.StorageReview().token));assert(A.db==DB_BEFORE and A.db.settings.storageProbe=='progress-during-review');assert(A.SharedBackupsEnabled());assert(A.StorageReview().phase=='applied')",
    )
    test(
        vm,
        "assert(A.InitDB());assert(A.StorageReview().phase=='applied');assert(not A.CreateDataBackup(false))",
    )
    applied_bytes = native_save(vm)
    vm = reload(vm)
    test(
        vm,
        "assert(A.StorageReview().phase=='complete' and A.StorageReview().persisted);assert(not A.StorageTransitionLocked());assert(table.getn(A.ListDataBackups(false))==2 and table.getn(A.ListDataBackups(true))==1)",
    )
    test(
        vm,
        "A.db.settings.precisionProbe=1/7;A.db.runs[1].precisionProbe=1/3;assert(A.CreateDataBackup(false));assert(A.SharedReadBackup(3,false).data.settings.precisionProbe==1/7)",
    )
    vm = reload(vm)
    test(
        vm,
        "assert(A.SharedReadBackup(3,false).data.settings.precisionProbe==1/7);assert(not A.PrepareStorageChange('legacy'));assert(A.PrepareStorageChange('legacy',A.StorageReview().token));assert(A.SharedBackupsEnabled())",
    )
    vm = reload(vm)
    test(
        vm,
        "assert(A.ApplyStorageChange(A.StorageReview().token));assert(not A.SharedBackupsEnabled());assert(A.StorageReview().phase=='applied')",
    )
    vm = reload(vm)
    test(
        vm,
        "assert(A.StorageReview().phase=='complete');assert(not A.SharedBackupsEnabled());assert(table.getn(A.ListDataBackups(false))==3 and table.getn(A.ListDataBackups(true))==1);assert(AzerothStatsRebornBackup.entries[3].data.settings.precisionProbe==tonumber(string.format('%.16g',1/7)))",
    )
    test(
        vm,
        "DB_BEFORE=A.db;assert(A.RecoverStorageSafety(A.StorageReview().token));assert(A.db==DB_BEFORE);assert(A.SharedBackupsEnabled())",
    )
    vm = reload(vm)
    test(
        vm,
        "assert(A.StorageReview().phase=='complete');assert(A.SharedReadBackup(3,false).data.settings.precisionProbe==1/7);assert(not A.DeleteStorageSafety('wrong-token'));ROOTS_BEFORE=AzerothStatsRebornBackup;assert(A.DeleteStorageSafety(A.StorageReview().token));assert(not AzerothStatsRebornStorageSafety and AzerothStatsRebornBackup==ROOTS_BEFORE)",
    )
    vm = reload(vm)
    test(
        vm,
        "assert(not AzerothStatsRebornStorageSafety and A.SharedBackupsEnabled());assert(A.CreateDataBackup(false))",
    )
    stale = runtime(saved=staged_bytes)
    test(
        stale,
        "assert(A.InitDB());AzerothStatsRebornBackup.entries[1].data.settings.externalEdit=true;assert(not A.ApplyStorageChange(A.StorageReview().token));assert(not A.SharedBackupsEnabled())",
    )
    cancelled = runtime(saved=staged_bytes)
    test(
        cancelled,
        "assert(A.InitDB());local roots=AzerothStatsRebornBackup;assert(A.CancelStorageChange(A.StorageReview().token));assert(AzerothStatsRebornBackup==roots and not AzerothStatsRebornStorageSafety);assert(A.CreateDataBackup(false))",
    )
    test(
        stale,
        "assert(A.CancelStorageChange(A.StorageReview().token));assert(AzerothStatsRebornBackup.entries[1].data.settings.externalEdit and not AzerothStatsRebornStorageSafety)",
    )
    damaged = runtime(saved=applied_bytes)
    test(
        damaged,
        "AzerothStatsRebornBackup.payload=AzerothStatsRebornBackup.payload..'x';assert(A.InitDB());assert(A.StorageReview().phase=='applied' and A.StorageReview().message);assert(not A.CreateDataBackup(false));assert(A.RecoverStorageSafety(A.StorageReview().token))",
    )
    damaged = reload(damaged)
    test(
        damaged,
        "assert(A.StorageReview().phase=='complete');assert(not A.SharedBackupsEnabled());assert(table.getn(A.ListDataBackups(false))==2)",
    )
    corrupt = runtime(saved=staged_bytes)
    test(
        corrupt,
        "assert(A.InitDB());local roots=AzerothStatsRebornBackup;AzerothStatsRebornStorageSafety.snapshot=AzerothStatsRebornStorageSafety.snapshot..'x';assert(not A.ApplyStorageChange(AzerothStatsRebornStorageSafety.proof));assert(AzerothStatsRebornBackup==roots and A.StorageTransitionLocked())",
    )
    test(
        corrupt,
        "local s=A.StorageReview();assert(s.invalidSafety and s.token);local roots=AzerothStatsRebornBackup;assert(A.DeleteStorageSafety(s.token));assert(AzerothStatsRebornBackup==roots and not A.StorageTransitionLocked());assert(A.CreateDataBackup(false))",
    )
    malformed = runtime(saved=legacy_bytes)
    test(
        malformed,
        "assert(A.InitDB());AzerothStatsRebornBackup.entries[1].data.invalid=function()end;local roots=AzerothStatsRebornBackup;assert(not A.PrepareStorageChange('shared'));assert(not AzerothStatsRebornStorageSafety and AzerothStatsRebornBackup==roots)",
    )
    # Exercise actual button callbacks, translations, theme repaint and the reload barrier.
    ui = runtime(saved=legacy_bytes)
    ui.execute(
        "local mt=getmetatable(UIParent).__index;function mt:Enable() self.disabled=false end;function mt:Disable() self.disabled=true end;RELOADS=0;function ReloadUI() RELOADS=RELOADS+1 end"
    )
    test(
        ui,
        "assert(A.InitDB());A.BuildUI();assert(A.OpenStorageSettings());local d=A.storageDialog;d.primary.callback();assert(d.intent=='shared' and not AzerothStatsRebornStorageSafety);d.cancel.callback();assert(not d.intent and not AzerothStatsRebornStorageSafety)",
    )
    test(
        ui,
        "for _,language in ipairs({'fr','en'}) do A.locale=language; for _,theme in ipairs(A.themeOrder) do A.UseTheme(theme);A.ApplyUI();assert(A.OpenStorageSettings());local d=A.storageDialog;assert(d.primary.label:GetText():find(language=='fr' and 'Passer' or 'Migrate',1,true));assert(d.primary:GetWidth()+44<=d:GetWidth()) end end",
    )
    test(
        ui,
        "local d=A.storageDialog;d.primary.callback();d.primary.callback();assert(RELOADS==1 and A.StorageReview().phase=='prepared' and not A.SharedBackupsEnabled())",
    )
    test(
        ui,
        "local d=A.storageDialog;d.primary.callback();assert(RELOADS==2 and not A.SharedBackupsEnabled());d.cancel.callback();assert(RELOADS==3 and not AzerothStatsRebornStorageSafety)",
    )
    test(
        ui,
        "assert(A.PrepareStorageChange('shared'));AzerothStatsRebornStorageSafety.phase='complete';assert(A.StorageReview().invalidSafety);assert(not A.ApplyStorageChange(AzerothStatsRebornStorageSafety.proof))",
    )
    report = {
        "checks": checks,
        "syntheticOnly": True,
        "nativeSixteenDigitReloads": True,
        "freshSharedDefault": True,
        "legacyMigrationRollbackRecovery": True,
        "actualDialogCallbacks": True,
        "fourthRootLocalSafety": True,
    }
    (ROOT / "build/reborn-storage-lifecycle-validation.json").write_text(
        json.dumps(report, indent=2) + "\n"
    )
    print("PASS: in-addon storage lifecycle", report)


if __name__ == "__main__":
    main()
