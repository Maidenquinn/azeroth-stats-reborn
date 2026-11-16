-- Experimental read-only inspection for a future shared backup format.
-- This module NEVER writes SavedVariables or creates a backup.
local A = AzerothStatsReborn

local function plain(value)
    return type(value) == "table" and getmetatable(value) == nil
end

local function denseCount(value, limit)
    if not plain(value) then
        return nil
    end
    local count = 0
    for key in pairs(value) do
        if type(key) ~= "number" or key < 1 or key > limit or key ~= math.floor(key) then
            return nil
        end
        count = count + 1
        if count > limit then
            return nil
        end
    end
    for index = 1, count do
        if rawget(value, index) == nil then
            return nil
        end
    end
    return count
end

local function scan(root, label)
    local report = {
        name = label,
        snapshots = 0,
        storedRuns = 0,
        distinctRunIDs = 0,
        repeatedRunIDs = 0,
        incompleteRunIDs = 0,
        invalid = nil,
    }
    if root == nil then
        return report
    end
    if not plain(root) then
        report.invalid = "root is not a table"
        return report
    end
    local entries
    if root.schema == 1 and plain(root.data) then
        entries = { { id = 1, data = root.data } }
    elseif root.schema == 2 and plain(root.entries) then
        entries = root.entries
    else
        report.invalid = "unsupported backup root"
        return report
    end
    local seen = {}
    local maxEntries = 100
    local maxCopies = 100000
    local count = denseCount(entries, maxEntries)
    if not count then
        report.invalid = "invalid or over-budget checkpoint list"
        return report
    end
    for index = 1, count do
        local entry = entries[index]
        if not plain(entry) or not plain(entry.data) or not plain(entry.data.runs) then
            report.invalid = "missing backup data or run list"
            return report
        end
        report.snapshots = report.snapshots + 1
        local runs = entry.data.runs
        local n = denseCount(runs, maxCopies - report.storedRuns)
        if not n then
            report.invalid = "invalid or over-budget run list"
            return report
        end
        for i = 1, n do
            local run = runs[i]
            if not plain(run) then
                report.invalid = "malformed run"
                return report
            end
            local id = run.id
            if type(id) == "string" and id ~= "" then
                if seen[id] then
                    report.repeatedRunIDs = report.repeatedRunIDs + 1
                else
                    seen[id] = true
                    report.distinctRunIDs = report.distinctRunIDs + 1
                end
            else
                report.incompleteRunIDs = report.incompleteRunIDs + 1
            end
        end
        report.storedRuns = report.storedRuns + n
    end
    return report
end

function A.SharedStorageReadOnlyAudit()
    -- Reading globals directly avoids backupStore(), which can initialize or
    -- normalize old roots and would violate the no-mutation guarantee.
    local manual = scan(AzerothStatsRebornBackup, "Manual")
    local automatic = scan(AzerothStatsRebornAutoBackup, "Automatic")
    local live = A.db or AzerothStatsRebornDB
    local active = plain(live) and denseCount(live.runs, 100000) or nil
    return {
        manual = manual,
        automatic = automatic,
        activeRuns = active or 0,
        activeInvalid = live ~= nil and not active and "invalid or over-budget live run list"
            or nil,
        nonDestructive = true,
        -- Same run ID is NOT proof of identical content. A run can be edited.
        exactDeduplicatedBytesKnown = false,
    }
end

local function tr(en, fr)
    return A.Locale() == "fr" and fr or en
end

local frenchErrors = {
    ["root is not a table"] = "racine non standard",
    ["unsupported backup root"] = "format de sauvegarde non pris en charge",
    ["invalid or over-budget checkpoint list"] = "liste de sauvegardes invalide ou trop volumineuse",
    ["missing backup data or run list"] = "données ou liste de parties manquantes",
    ["invalid or over-budget run list"] = "liste de parties invalide ou trop volumineuse",
    ["malformed run"] = "partie mal formée",
}

function A.PrintSharedStorageAudit()
    local result = A.SharedStorageReadOnlyAudit()
    A.Say(
        tr(
            "Read-only storage audit: no migration or compression.",
            "Audit du stockage en lecture seule : aucune migration ni compression."
        )
    )
    if result.activeInvalid then
        A.Say(tr("Live history: audit incomplete", "Historique actuel : audit incomplet"))
    else
        A.Say(tr("Retained runs: ", "Parties conservées : ") .. result.activeRuns)
    end
    for _, source in ipairs({ result.manual, result.automatic }) do
        local label = source.name == "Manual" and tr("Manual", "Manuelles")
            or tr("Automatic", "Automatiques")
        if source.invalid then
            A.Say(
                label
                    .. tr(": audit incomplete (", " : audit incomplet (")
                    .. (A.Locale() == "fr" and frenchErrors[source.invalid] or source.invalid)
                    .. ")"
            )
        else
            A.Say(
                label
                    .. ": "
                    .. source.snapshots
                    .. tr(" backups; ", " sauvegardes ; ")
                    .. source.storedRuns
                    .. tr(" stored run copies; ", " copies de parties ; ")
                    .. source.distinctRunIDs
                    .. tr(" distinct IDs; ", " identifiants distincts ; ")
                    .. source.repeatedRunIDs
                    .. tr(" repeated IDs; ", " identifiants répétés ; ")
                    .. source.incompleteRunIDs
                    .. tr(" missing IDs.", " identifiants manquants.")
            )
        end
    end
    A.Say(
        tr(
            "Repeated IDs do not prove identical content. Disk savings are not measured.",
            "Des identifiants répétés ne prouvent pas des contenus identiques. Aucun gain disque n’est mesuré."
        )
    )
    return result
end

local rebornCommand = A.RebornCommand
function A.RebornCommand(message)
    local command, value =
        string.match(string.lower(string.gsub(message or "", "^%s+", "")), "^(%S+)%s*(.-)%s*$")
    if command == "shared" then
        if value == "audit" then
            A.PrintSharedStorageAudit()
        else
            A.Say(
                tr(
                    "Read-only diagnostic: /azstatsr shared audit",
                    "Diagnostic en lecture seule : /azstatsr shared audit"
                )
            )
        end
        return true
    end
    return rebornCommand(message)
end
