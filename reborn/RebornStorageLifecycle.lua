-- Player-facing storage transitions. The recovery journal is a fourth local
-- SavedVariables root in the same addon file, not an external-file guarantee.
local A = AzerothStatsReborn
local M = A.SharedCodec
-- Legacy addon hosts load SavedVariables after Lua chunks but before the
-- lifecycle's first InitDB. Capture the witness there, never at chunk scope.
local loaded, loadedPhase, loadedProof
local initializedSession = false
local verifiedReload = false
local cachedSnapshot, cachedData, cachedCount
local function tr(en, fr)
    return A.Locale() == "fr" and fr or en
end
local function plain(t)
    return type(t) == "table" and getmetatable(t) == nil
end
local function rootDigest()
    local wire, err = M.encodeStore({
        manual = AzerothStatsRebornBackup,
        automatic = AzerothStatsRebornAutoBackup,
    })
    return wire and M.fingerprint(wire), err
end
-- The classic format follows the client's 16-significant-digit numeric writer.
-- Keep the lossless safety payload, and verify that exact native projection.
local function nativeLegacyDigest(manual, automatic)
    local encoded, err = M.encodeStore({ manual = manual, automatic = automatic })
    if not encoded then
        return nil, err
    end
    local copy, reason = M.decodeStore(encoded)
    if not copy then
        return nil, reason
    end
    local function project(value)
        local result = {}
        for key, v in pairs(value) do
            local target = type(key) == "number" and tonumber(string.format("%.16g", key)) or key
            assert(target ~= nil and result[target] == nil, "Classic numeric key collision")
            if type(v) == "table" then
                result[target] = project(v)
            elseif type(v) == "number" then
                result[target] = tonumber(string.format("%.16g", v))
                assert(result[target], "Invalid native number")
            else
                result[target] = v
            end
        end
        return result
    end
    local ok, projected = pcall(project, copy)
    if not ok then
        return nil, projected
    end
    local wire, failure = M.encodeStore(projected)
    return wire and M.fingerprint(wire), failure
end
local function sourceMatches(j)
    if rootDigest() == j.sourceDigest then
        return true
    end
    return not j.sourceShared
        and nativeLegacyDigest(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
            == j.sourceDigest
end
local function proof(j)
    return M.fingerprint({
        schema = j.schema,
        snapshot = j.snapshot,
        sourceDigest = j.sourceDigest,
        target = j.target,
        sourceShared = j.sourceShared,
        at = j.at,
        phase = j.phase,
        recovering = j.recovering,
    })
end
local function persisted(j)
    return loaded == AzerothStatsRebornStorageSafety
        and (
            (loadedPhase == j.phase and loadedProof == j.proof)
            or (verifiedReload and j.phase == "complete")
        )
end
local function journal()
    local j = AzerothStatsRebornStorageSafety
    if
        not plain(j)
        or j.schema ~= 1
        or type(j.snapshot) ~= "string"
        or type(j.sourceDigest) ~= "string"
        or (j.target ~= "shared" and j.target ~= "legacy")
        or type(j.sourceShared) ~= "boolean"
        or type(j.recovering) ~= "boolean"
        or type(j.at) ~= "number"
        or (j.phase ~= "prepared" and j.phase ~= "applied" and j.phase ~= "complete")
        or type(j.proof) ~= "string"
        or proof(j) ~= j.proof
    then
        return nil,
            tr(
                "Storage safety copy is invalid; nothing changed",
                "La copie de sécurité du stockage est invalide ; aucune modification"
            )
    end
    for k in pairs(j) do
        if
            k ~= "schema"
            and k ~= "snapshot"
            and k ~= "sourceDigest"
            and k ~= "target"
            and k ~= "sourceShared"
            and k ~= "at"
            and k ~= "phase"
            and k ~= "proof"
            and k ~= "recovering"
        then
            return nil, "Unknown storage safety field"
        end
    end
    if cachedSnapshot == j.snapshot then
        return j, cachedData
    end
    local data, err = M.decodeStore(j.snapshot)
    if not data then
        return nil, err
    end
    if
        not plain(data)
        or type(data.hadManual) ~= "boolean"
        or type(data.hadAutomatic) ~= "boolean"
    then
        return nil, "Invalid storage safety catalogue"
    end
    local store, reason = A.ValidateSharedBackups(data.manual, data.automatic)
    if not store then
        return nil, reason
    end
    -- Reconstruct all checkpoints, not only the outer integrity envelope.
    local count = 0
    for id in pairs(store.entries) do
        count = count + 1
        local restored, failure = M.restore(store, id)
        if not restored then
            return nil, failure
        end
    end
    cachedSnapshot, cachedData, cachedCount = j.snapshot, data, count
    return j, data
end
local function targetRoots(j, data, source)
    local shared = source and j.sourceShared or (not source and j.target == "shared")
    if shared then
        -- Never alias a cached safety envelope into the writable current roots.
        local manual, automatic = {}, {}
        for k, v in pairs(data.manual) do
            manual[k] = v
        end
        for k, v in pairs(data.automatic) do
            automatic[k] = v
        end
        return manual, automatic
    end
    local manual, automatic = A.ExportSharedBackupRoots(data.manual, data.automatic)
    if not manual then
        return nil, nil, automatic
    end
    if source then
        if not data.hadManual then
            manual = nil
        end
        if not data.hadAutomatic then
            automatic = nil
        end
    end
    return manual, automatic
end
local function activeHealthy()
    return A.db and A.ValidateDatabase(A.db)
end
function A.StorageTransitionLocked()
    local value = AzerothStatsRebornStorageSafety
    if value == nil then
        return false
    end
    -- A damaged retained safety copy must not disable healthy current backups.
    -- Every transition/recovery still validates its complete proof independently.
    return not plain(value) or value.phase ~= "complete"
end
function A.StorageReview()
    local result = {
        shared = A.SharedBackupsEnabled(),
        hasSafety = AzerothStatsRebornStorageSafety ~= nil,
    }
    if result.shared then
        local store, err =
            A.ValidateSharedBackups(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
        if not store then
            result.error = err
        end
    end
    if result.hasSafety then
        local j, data = journal()
        if not j then
            result.error = data
            result.invalidSafety = true
            result.token = M.fingerprint(AzerothStatsRebornStorageSafety)
        else
            result.phase = j.phase
            result.target = j.target
            result.token = j.proof
            result.persisted = persisted(j)
            result.checkpoints = cachedCount
        end
    end
    result.message = A.storageTransitionError or result.error
    return result
end
function A.PrepareStorageChange(target, replaceToken)
    if not activeHealthy() then
        return false,
            tr("Database is invalid; nothing changed", "Base invalide ; aucune modification")
    end
    if target ~= "shared" and target ~= "legacy" then
        return false, "Invalid storage target"
    end
    if A.StorageTransitionLocked() then
        return false,
            tr(
                "Finish or cancel the pending storage change",
                "Termine ou annule le changement de stockage en attente"
            )
    end
    if AzerothStatsRebornStorageSafety ~= nil then
        local existing = journal()
        if not existing or replaceToken ~= existing.proof then
            return false,
                tr(
                    "Review replacement of the previous safety copy",
                    "Confirme le remplacement de la copie de sécurité précédente"
                )
        end
    end
    local wasShared = A.SharedBackupsEnabled() and true or false
    if wasShared == (target == "shared") then
        return false, tr("This storage format is already active", "Ce format est déjà actif")
    end
    local digest, err
    if wasShared then
        digest, err = rootDigest()
    else
        digest, err = nativeLegacyDigest(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
    end
    if not digest then
        return false, err
    end
    local manual, automatic
    if wasShared then
        manual, automatic = AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup
        local valid, reason = A.ValidateSharedBackups(manual, automatic)
        if not valid then
            return false, reason
        end
        -- Prove a complete legacy export before offering a rollback.
        local legacy, failure = A.ExportSharedBackupRoots(manual, automatic)
        if not legacy then
            return false, failure
        end
    else
        manual, automatic =
            A.BuildSharedBackupRoots(A.db, AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
        if not manual then
            return false, automatic
        end
    end
    local snapshot, failure = M.encodeStore({
        manual = manual,
        automatic = automatic,
        hadManual = AzerothStatsRebornBackup ~= nil,
        hadAutomatic = AzerothStatsRebornAutoBackup ~= nil,
    })
    if not snapshot then
        return false, failure
    end
    local staged = {
        schema = 1,
        snapshot = snapshot,
        sourceDigest = digest,
        target = target,
        sourceShared = wasShared and true or false,
        at = A.Wall() or 0,
        phase = "prepared",
        recovering = false,
    }
    staged.proof = proof(staged)
    if not staged.proof then
        return false, "Storage safety size limit exceeded"
    end
    -- Staging changes only the safety root. Existing catalogues stay intact.
    local previous = AzerothStatsRebornStorageSafety
    AzerothStatsRebornStorageSafety = staged
    local valid, reason = journal()
    if not valid then
        AzerothStatsRebornStorageSafety = previous
        return false, reason
    end
    A.storageTransitionError = nil
    return true,
        tr(
            "Safety copy prepared. Reload before applying the change.",
            "Copie de sécurité préparée. Recharge avant d’appliquer le changement."
        )
end
function A.ApplyStorageChange(token)
    local j, data = journal()
    if not j then
        return false, data
    end
    if
        j.phase ~= "prepared"
        or j.proof ~= token
        or loaded ~= AzerothStatsRebornStorageSafety
        or loadedPhase ~= "prepared"
        or loadedProof ~= j.proof
    then
        return false,
            tr(
                "Save and reload the safety copy before applying",
                "Enregistre et recharge la copie de sécurité avant d’appliquer"
            )
    end
    if not activeHealthy() or not sourceMatches(j) then
        return false,
            tr(
                "Backup catalogues changed; cancel and review again",
                "Les sauvegardes ont changé ; annule puis recommence la vérification"
            )
    end
    local manual, automatic, err = targetRoots(j, data, false)
    if err then
        return false, err
    end
    if j.target == "shared" then
        local store = A.ValidateSharedBackups(manual, automatic)
        local originalManual, originalAuto = A.ExportSharedBackupRoots(data.manual, data.automatic)
        if not originalManual then
            return false, originalAuto
        end
        local valid, reason = M.verifyMigration(store, A.db, originalManual, originalAuto)
        if not valid then
            return false, reason
        end
    else
        local root, marker = A.BuildSharedBackupRoots(A.db, manual, automatic)
        if not root then
            return false, marker
        end
        local old = assert(A.ValidateSharedBackups(data.manual, data.automatic))
        local next = assert(A.ValidateSharedBackups(root, marker))
        for id, entry in pairs(old.entries) do
            local other = M.findOrigin(next, entry.origin.kind, entry.origin.id)
            if not other or not M.sameData(M.restore(old, id), M.restore(next, other)) then
                return false, "Storage rollback mismatch"
            end
        end
    end
    AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup = manual, automatic
    j.phase = "applied"
    j.proof = proof(j)
    return true,
        tr(
            "Storage changed. Reload to verify the saved format.",
            "Stockage modifié. Recharge pour vérifier le format enregistré."
        )
end
function A.CancelStorageChange(token)
    local j, err = journal()
    if not j then
        return false, err
    end
    if j.proof ~= token or j.phase ~= "prepared" then
        return false, "Storage review changed"
    end
    local healthy, reason
    if A.SharedBackupsEnabled() then
        healthy, reason =
            A.ExportSharedBackupRoots(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
    else
        healthy, reason =
            A.BuildSharedBackupRoots(A.db, AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
    end
    if not healthy then
        return false, reason
    end
    AzerothStatsRebornStorageSafety = nil
    A.storageTransitionError = nil
    return true,
        tr(
            "Storage change cancelled; original backups kept",
            "Changement annulé ; sauvegardes d’origine conservées"
        )
end
function A.RecoverStorageSafety(token)
    local j, data = journal()
    if not j then
        return false, data
    end
    if token ~= j.proof or not persisted(j) then
        return false, "Reload and review the safety copy first"
    end
    local manual, automatic, err = targetRoots(j, data, true)
    if err then
        return false, err
    end
    -- Recovery restores catalogue roots only; current statistics are untouched.
    AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup = manual, automatic
    j.target = j.sourceShared and "shared" or "legacy"
    j.recovering = true
    j.phase = "applied"
    j.proof = proof(j)
    A.storageTransitionError = nil
    return true,
        tr(
            "Safety catalogues recovered. Reload to verify.",
            "Sauvegardes de sécurité récupérées. Recharge pour vérifier."
        )
end
function A.DeleteStorageSafety(token)
    local j, err = journal()
    local invalidToken = not j and M.fingerprint(AzerothStatsRebornStorageSafety)
    if not j and (not invalidToken or token ~= invalidToken) then
        return false, err
    end
    if j and (j.phase ~= "complete" or j.proof ~= token) then
        return false, "Finish the storage change first"
    end
    if not activeHealthy() then
        return false, "Database validation failed"
    end
    if A.SharedBackupsEnabled() then
        local valid, reason =
            A.ExportSharedBackupRoots(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
        if not valid then
            return false, reason
        end
    else
        local valid, reason =
            A.BuildSharedBackupRoots(A.db, AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
        if not valid then
            return false, reason
        end
    end
    AzerothStatsRebornStorageSafety = nil
    A.storageTransitionError = nil
    return true,
        tr(
            "Local safety copy removed; backups kept",
            "Copie de sécurité locale supprimée ; sauvegardes conservées"
        )
end
local init = A.InitDB
function A.InitDB()
    if not initializedSession then
        initializedSession = true
        loaded = AzerothStatsRebornStorageSafety
        loadedPhase = type(loaded) == "table" and loaded.phase
        loadedProof = type(loaded) == "table" and loaded.proof
    end
    local fresh = AzerothStatsRebornDB == nil
        and AzerothStatsRebornBackup == nil
        and AzerothStatsRebornAutoBackup == nil
        and AzerothStatsRebornStorageSafety == nil
    if not init() then
        return false
    end
    if fresh then
        local manual, automatic = A.BuildSharedBackupRoots(A.db, nil, nil)
        if not manual then
            A.storageTransitionError = automatic
            return false
        end
        AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup = manual, automatic
    end
    local j, data = journal()
    if
        loaded
        and j
        and loaded == AzerothStatsRebornStorageSafety
        and loadedPhase == "applied"
        and loadedProof == j.proof
        and j.phase == "applied"
    then
        local manual, automatic, err = targetRoots(j, data, j.recovering)
        local expected = M.encodeStore({ manual = manual, automatic = automatic })
        local actual = rootDigest()
        local native = j.target == "legacy" and nativeLegacyDigest(manual, automatic)
        if not err and expected and (actual == M.fingerprint(expected) or actual == native) then
            j.phase = "complete"
            j.proof = proof(j)
            verifiedReload = true
        else
            A.storageTransitionError = tr(
                "Saved storage verification failed; safety copy retained",
                "La vérification du stockage enregistré a échoué ; copie de sécurité conservée"
            )
        end
    end
    return true
end
for _, name in ipairs({
    "CreateDataBackup",
    "DeleteDataBackup",
    "PreviewManualBackupCleanup",
    "CleanupManualBackups",
}) do
    local previous = A[name]
    A[name] = function(...)
        if A.StorageTransitionLocked() then
            return false,
                tr(
                    "Storage change pending: open Backup storage",
                    "Changement de stockage en attente : ouvre Stockage des sauvegardes"
                )
        end
        return previous(...)
    end
end
