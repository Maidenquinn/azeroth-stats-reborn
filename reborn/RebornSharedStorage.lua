-- Opt-in shared backup format. Legacy profiles are never converted on load.
-- Both catalogues and their immutable pool live in the manual root in one file.
local A = AzerothStatsReborn
local M = A.SharedCodec
local owner = "AzerothStatsRebornBackup"
local function plain(t)
    return type(t) == "table" and getmetatable(t) == nil
end
local function integer(n)
    return type(n) == "number" and n >= 1 and n < 1000000000 and n == math.floor(n)
end
local function shallow(t)
    local out = {}
    for k, v in pairs(t) do
        out[k] = v
    end
    return out
end
local function marker()
    return { schema = 3, format = 1, game = A.game, owner = owner }
end
local function envelope(store)
    local digest = M.fingerprint(store)
    if not digest then
        return nil, "Shared backup size or integrity limit exceeded"
    end
    return { schema = 3, format = 1, game = A.game, store = store, digest = digest }
end
function A.SharedBackupsEnabled()
    local m, a = AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup
    return (
        type(m) == "table"
        and (rawget(m, "schema") == 3 or rawget(m, "store") ~= nil or rawget(m, "digest") ~= nil)
    ) or (type(a) == "table" and (rawget(a, "schema") == 3 or rawget(a, "owner") ~= nil))
end
function A.ValidateSharedBackups(root, automatic)
    if
        not plain(root)
        or root.schema ~= 3
        or root.format ~= 1
        or root.game ~= A.game
        or not plain(automatic)
        or automatic.schema ~= 3
        or automatic.format ~= 1
        or automatic.game ~= A.game
        or automatic.owner ~= owner
    then
        return nil, "Shared backup roots are incomplete; no data changed"
    end
    for key in pairs(root) do
        if
            key ~= "schema"
            and key ~= "format"
            and key ~= "game"
            and key ~= "store"
            and key ~= "digest"
        then
            return nil, "Unknown shared backup metadata"
        end
    end
    for key in pairs(automatic) do
        if key ~= "schema" and key ~= "format" and key ~= "game" and key ~= "owner" then
            return nil, "Unknown shared backup metadata"
        end
    end
    local store = root.store
    if
        not plain(store)
        or store.schema ~= 1
        or not plain(store.entries)
        or not plain(store.pool)
        or not plain(store.digests)
        or not plain(store.sourceNextIds)
        or not integer(store.nextBackup)
        or not integer(store.nextRun)
        or not integer(store.sourceNextIds.manual)
        or not integer(store.sourceNextIds.auto)
    then
        return nil, "Invalid shared backup catalogue"
    end
    if type(root.digest) ~= "string" or M.fingerprint(store) ~= root.digest then
        return nil, "Shared backup integrity check failed"
    end
    local fields = {
        schema = true,
        nextRun = true,
        nextBackup = true,
        pool = true,
        digests = true,
        entries = true,
        sourceNextIds = true,
    }
    for key in pairs(store) do
        if not fields[key] then
            return nil, "Unknown shared store metadata"
        end
    end
    for key in pairs(store.sourceNextIds) do
        if key ~= "manual" and key ~= "auto" then
            return nil, "Unknown shared sequence"
        end
    end
    local seen, reachable = { manual = {}, auto = {} }, {}
    local count = 0
    for id, entry in pairs(store.entries) do
        count = count + 1
        local meta = plain(entry) and entry.origin
        if
            count > 10000
            or not integer(id)
            or id >= store.nextBackup
            or not plain(entry)
            or entry.id ~= id
            or not plain(meta)
            or not seen[meta.kind]
            or not integer(meta.id)
            or meta.id >= store.sourceNextIds[meta.kind]
            or seen[meta.kind][meta.id]
            or entry.automatic ~= (meta.kind == "auto")
            or not plain(entry.runRefs)
            or (meta.at ~= nil and (type(meta.at) ~= "number" or meta.at ~= meta.at or math.abs(
                meta.at
            ) > 1e100))
            or type(meta.runs) ~= "number"
            or meta.runs ~= table.getn(entry.runRefs)
        then
            return nil, "Invalid shared checkpoint metadata"
        end
        seen[meta.kind][meta.id] = true
        local entryFields = {
            id = true,
            automatic = true,
            runRefs = true,
            state = true,
            stateDigest = true,
            manifestDigest = true,
            origin = true,
        }
        for key in pairs(entry) do
            if not entryFields[key] then
                return nil, "Unknown checkpoint field"
            end
        end
        local metaFields =
            { kind = true, id = true, at = true, runs = true, legacy = true, sourceFields = true }
        for key in pairs(meta) do
            if not metaFields[key] then
                return nil, "Unknown checkpoint origin"
            end
        end
        if meta.sourceFields then
            if not plain(meta.sourceFields) then
                return nil, "Invalid original checkpoint fields"
            end
            for _, key in ipairs({ "at", "runs", "legacy" }) do
                if type(meta.sourceFields[key]) ~= "boolean" then
                    return nil, "Invalid original checkpoint field flag"
                end
            end
            for key in pairs(meta.sourceFields) do
                if key ~= "at" and key ~= "runs" and key ~= "legacy" then
                    return nil, "Unknown original checkpoint field"
                end
            end
        end
        local n = table.getn(entry.runRefs)
        for index, ref in pairs(entry.runRefs) do
            if
                not integer(index)
                or index > n
                or not integer(ref)
                or not plain(store.pool[ref])
            then
                return nil, "Dangling shared backup reference"
            end
            reachable[ref] = true
        end
        for index = 1, n do
            if entry.runRefs[index] == nil then
                return nil, "Sparse shared backup references"
            end
        end
    end
    for ref, payload in pairs(store.pool) do
        if
            not integer(ref)
            or ref >= store.nextRun
            or not plain(payload)
            or type(payload.id) ~= "string"
            or payload.id == ""
            or not reachable[ref]
            or type(store.digests[ref]) ~= "string"
        then
            return nil, "Invalid shared version pool"
        end
    end
    for ref in pairs(store.digests) do
        if not store.pool[ref] then
            return nil, "Invalid shared version digest"
        end
    end
    return store
end
local function current()
    return A.ValidateSharedBackups(AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup)
end
local function candidate(store)
    return {
        schema = 1,
        nextRun = store.nextRun,
        nextBackup = store.nextBackup,
        sourceNextIds = shallow(store.sourceNextIds),
        entries = shallow(store.entries),
        pool = shallow(store.pool),
        digests = shallow(store.digests),
    }
end
local function commit(store)
    local root, reason = envelope(store)
    if not root then
        return false, reason
    end
    local auto = marker()
    local valid, err = A.ValidateSharedBackups(root, auto)
    if not valid then
        return false, err
    end
    AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup = root, auto
    return true
end
function A.BuildSharedBackupRoots(live, manual, automatic)
    local store, reason = M.importLegacy(live, manual, automatic)
    if not store then
        return nil, reason
    end
    local ok, err = M.verifyMigration(store, live, manual, automatic)
    if not ok then
        return nil, err
    end
    for _, source in ipairs({
        { root = manual, kind = "manual" },
        { root = automatic, kind = "auto" },
    }) do
        if source.root and source.root.schema == 2 then
            for _, entry in ipairs(source.root.entries) do
                local internal = M.findOrigin(store, source.kind, entry.id)
                store.entries[internal].origin.sourceFields =
                    { at = entry.at ~= nil, runs = entry.runs ~= nil, legacy = entry.legacy ~= nil }
                assert(M.sealEntry(store, internal))
            end
        end
    end
    local root, failure = envelope(store)
    if not root then
        return nil, failure
    end
    local auto = marker()
    local valid, validation = A.ValidateSharedBackups(root, auto)
    if not valid then
        return nil, validation
    end
    return root, auto
end
function A.ExportSharedBackupRoots(root, automatic)
    local store, err = A.ValidateSharedBackups(root, automatic)
    if not store then
        return nil, err
    end
    local result = {
        manual = { schema = 2, nextId = store.sourceNextIds.manual, entries = {} },
        auto = { schema = 2, nextId = store.sourceNextIds.auto, entries = {} },
    }
    for id, entry in pairs(store.entries) do
        local data, reason = M.restore(store, id)
        if not data then
            return nil, reason
        end
        local meta = entry.origin
        local saved = { id = meta.id, data = data }
        if meta.sourceFields then
            if meta.sourceFields.at then
                saved.at = meta.at
            end
            if meta.sourceFields.runs then
                saved.runs = meta.runs
            end
            if meta.sourceFields.legacy then
                saved.legacy = meta.legacy
            end
        else
            saved.at = meta.at
            saved.runs = meta.runs
            saved.legacy = meta.legacy and true or nil
        end
        table.insert(result[meta.kind].entries, saved)
    end
    for _, catalogue in pairs(result) do
        table.sort(catalogue.entries, function(a, b)
            return a.id < b.id
        end)
    end
    return result.manual, result.auto
end
local function ordered(store, automatic)
    local result = {}
    local kind = automatic and "auto" or "manual"
    for id, entry in pairs(store.entries) do
        if entry.origin.kind == kind then
            table.insert(result, { internal = id, meta = entry.origin })
        end
    end
    table.sort(result, function(a, b)
        return a.meta.id > b.meta.id
    end)
    return result
end
function A.SharedListBackups(automatic)
    local store, reason = current()
    if not store then
        A.Say(reason)
        return {}, reason
    end
    local result = {}
    for _, item in ipairs(ordered(store, automatic)) do
        local m = item.meta
        table.insert(result, {
            id = m.id,
            at = m.at,
            runs = m.runs,
            legacy = m.legacy,
            automatic = automatic and true or false,
        })
    end
    return result
end
function A.SharedReadBackup(id, automatic)
    local store, reason = current()
    if not store then
        return nil, reason
    end
    local items = ordered(store, automatic)
    local internal = id == nil and items[1] and items[1].internal
        or M.findOrigin(store, automatic and "auto" or "manual", id)
    if not internal then
        return nil, "Selected backup not found"
    end
    local data, err = M.restore(store, internal)
    if not data then
        return nil, err
    end
    return { id = store.entries[internal].origin.id, data = data }
end
function A.SharedCreateBackup(automatic, live)
    local store, reason = current()
    if not store then
        return false, reason
    end
    local next = candidate(store)
    local internal, err = M.save(next, A.db, automatic, nil, function(data)
        if live then
            for _, run in ipairs(data.runs) do
                if run.status == "active" then
                    run.status, run.partial = "interrupted", true
                end
            end
        end
    end)
    if not internal then
        return false, err
    end
    local entry = next.entries[internal]
    if automatic then
        local previous = ordered(store, true)[1]
        if previous then
            local old = store.entries[previous.internal]
            if M.sameData(old.state, entry.state) and M.sameData(old.runRefs, entry.runRefs) then
                return true, "Automatic backup already up to date (No." .. old.origin.id .. ")"
            end
        end
    end
    local kind = automatic and "auto" or "manual"
    local id = next.sourceNextIds[kind]
    entry.origin = {
        kind = kind,
        id = id,
        at = A.Wall() or 0,
        runs = table.getn(entry.runRefs),
        legacy = false,
    }
    if not M.sealEntry(next, internal) then
        return false, "Cannot seal shared checkpoint"
    end
    next.sourceNextIds[kind] = id + 1
    if automatic then
        local keep =
            math.max(1, math.min(15, math.floor(A.Number(A.db.settings.autoBackupRetention) or 15)))
        local list = ordered(next, true)
        for index = keep + 1, table.getn(list) do
            if not M.delete(next, list[index].internal) then
                return false, "Cannot prune shared checkpoint"
            end
        end
    end
    local removed, failure = M.collect(next)
    if not removed then
        return false, failure
    end
    local ok, message = commit(next)
    if not ok then
        return false, message
    end
    return true,
        (automatic and "Automatic safety backup No." or "Manual backup No.") .. id .. " saved"
end
function A.SharedDeleteBackup(id, automatic)
    local store, reason = current()
    if not store then
        return false, reason
    end
    local internal = M.findOrigin(store, automatic and "auto" or "manual", id)
    if not internal then
        return false, "Backup not found"
    end
    local next = candidate(store)
    local ok, err = M.delete(next, internal)
    if not ok then
        return false, err
    end
    local removed, failure = M.collect(next)
    if not removed then
        return false, failure
    end
    local committed, message = commit(next)
    return committed, committed and "Backup deleted" or message
end
function A.SharedPreviewCleanup(keep)
    keep = A.Number(keep)
    if not keep or keep < 1 or keep > 50 or keep ~= math.floor(keep) then
        return nil, "Keep count must be between 1 and 50"
    end
    local store, reason = current()
    if not store then
        return nil, reason
    end
    local items, ids = ordered(store, false), {}
    for index = keep + 1, table.getn(items) do
        table.insert(ids, items[index].meta.id)
    end
    return {
        keep = keep,
        remove = table.getn(ids),
        ids = ids,
        token = M.fingerprint({ ids = ids, nextId = store.sourceNextIds.manual }),
    }
end
function A.SharedCleanup(keep, token)
    local plan, reason = A.SharedPreviewCleanup(keep)
    if not plan then
        return false, reason
    end
    if type(token) ~= "string" or token ~= plan.token then
        return false, "Backup list changed; review cleanup again"
    end
    local store = assert(current())
    local next = candidate(store)
    for _, id in ipairs(plan.ids) do
        local internal = M.findOrigin(next, "manual", id)
        if not M.delete(next, internal) then
            return false, "Cannot delete shared checkpoint"
        end
    end
    local removed, err = M.collect(next)
    if not removed then
        return false, err
    end
    local ok, message = commit(next)
    return ok,
        ok and (plan.remove .. " older manual backups deleted; reload to save changes") or message
end
local audit = A.SharedStorageReadOnlyAudit
function A.SharedStorageReadOnlyAudit()
    if not A.SharedBackupsEnabled() then
        return audit()
    end
    local store, err = current()
    local result = {
        activeRuns = A.db and table.getn(A.db.runs) or 0,
        nonDestructive = true,
        exactDeduplicatedBytesKnown = false,
        shared = true,
    }
    for _, kind in ipairs({ "manual", "auto" }) do
        local report = {
            name = kind == "manual" and "Manual" or "Automatic",
            snapshots = 0,
            storedRuns = 0,
            distinctRunIDs = 0,
            repeatedRunIDs = 0,
            incompleteRunIDs = 0,
            invalid = err,
        }
        if store then
            local seen = {}
            for _, item in ipairs(ordered(store, kind == "auto")) do
                report.snapshots = report.snapshots + 1
                for _, ref in ipairs(store.entries[item.internal].runRefs) do
                    local id = store.pool[ref].id
                    report.storedRuns = report.storedRuns + 1
                    if seen[id] then
                        report.repeatedRunIDs = report.repeatedRunIDs + 1
                    else
                        seen[id] = true
                        report.distinctRunIDs = report.distinctRunIDs + 1
                    end
                end
            end
        end
        result[kind == "auto" and "automatic" or "manual"] = report
    end
    if store then
        result.pooledVersions = 0
        for _ in pairs(store.pool) do
            result.pooledVersions = result.pooledVersions + 1
        end
    end
    return result
end
local command = A.RebornCommand
function A.RebornCommand(message)
    local value = string.lower(string.gsub(message or "", "^%s+", ""))
    if A.SharedBackupsEnabled() and (value == "storage" or value == "shared status") then
        local result = A.SharedStorageReadOnlyAudit()
        A.Say(
            A.Locale() == "fr" and "Sauvegardes partagées : format actif"
                or "Shared backups: format active"
        )
        if result.manual.invalid then
            A.Say(result.manual.invalid)
        else
            A.Say(
                (
                    A.Locale() == "fr" and "Versions de parties stockées : "
                    or "Stored run versions: "
                ) .. result.pooledVersions
            )
        end
        return true
    end
    return command(message)
end
