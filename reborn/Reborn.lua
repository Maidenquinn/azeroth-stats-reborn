-- Reborn-only adapters. No writes to AZS_* tables, CVars, player inventory or other addons.
local A = AzerothStatsReborn
A.game = "azeroth-survivors-reborn"
A.knownClasses.monk = true
A.knownClasses.deathknight = true
A.knownClasses.demonhunter = true
-- Versioned Reborn readers distinguish zero arguments from a supplied nil.
function A.Call(fn, value)
    if type(fn) ~= "function" then
        return nil
    end
    local ok, x, y, z
    if value == nil then
        ok, x, y, z = pcall(fn)
    else
        ok, x, y, z = pcall(fn, value)
    end
    if ok then
        return x, y, z
    end
    A.apiError = tostring(x)
end
local function native(fn, value)
    if type(fn) ~= "function" then
        return nil, { code = "API_MISSING" }
    end
    local ok, result, err
    if value == nil then
        ok, result, err = pcall(fn)
    else
        ok, result, err = pcall(fn, value)
    end
    if not ok then
        return nil, { code = "API_ERROR" }
    end
    return result, err
end
local function text(s)
    return A.Text(s, 500)
end
local fr = {
    ["Reborn"] = "Reborn",
    ["Recent damage"] = "Dégâts récents",
    ["Recent healing"] = "Soins récents",
    ["Campaign"] = "Campagne",
    ["Endless"] = "Sans fin",
    ["Run mode"] = "Mode de partie",
    ["Native run identity"] = "Identité native de partie",
    ["Observed build"] = "Build observé",
    ["No future endless boss is exposed by the game."] = "Le jeu ne fournit pas le prochain boss en mode sans fin.",
    ["Partial native history"] = "Historique natif partiel",
    ["Not measured by the game"] = "Non mesuré par le jeu",
    ["Segment"] = "Segment",
    ["Start segment"] = "Commencer un segment",
    ["End segment"] = "Terminer le segment",
    ["No segment"] = "Aucun segment",
    ["Native API unavailable"] = "API native indisponible",
    ["Next bosses"] = "Prochains boss",
    ["Guardians"] = "Gardiens",
    ["Unsupported"] = "Non pris en charge",
    ["Observed only"] = "Observations uniquement",
    ["Recent DPS"] = "DPS récent",
    ["Recent HPS"] = "HPS récent",
    ["Sampled"] = "Échantillonné",
    ["Timers observed"] = "Minuteries observées",
    ["Totems observed"] = "Totems observés",
    ["Fatal hit observed"] = "Coup fatal observé",
    ["Surge of Strength"] = "Afflux de force",
}
for k, v in pairs(fr) do
    A.uiText.fr[k] = v
end
local oldG, oldSource, oldSpell, oldDetect = A.G, A.SourceName, A.SpellName, A.DetectLocale
local english, sourceKeys, classIcons = {}, {}, {}
local function catalog()
    if not AZS_GEN then
        return
    end
    for _, c in ipairs(AZS_GEN.classes or {}) do
        english["class." .. c.key .. ".name"] = c.name
        classIcons[c.key] = c.icon
    end
    for _, z in ipairs(AZS_GEN.zones or {}) do
        english["zone." .. z.key .. ".name"] = z.name
        local locale = type(GetLocale) == "function" and string.sub(GetLocale(), 1, 2) or "en"
        if A.gameText[locale] then
            A.gameText[locale]["zone." .. z.key .. ".name"] = AZS_L and AZS_L[z.name] or z.name
        end
    end
    local lists = AZS_GEN.spells or {}
    if lists[1] then
        lists = { lists }
    end
    for _, list in pairs(lists) do
        for _, s in ipairs(list) do
            if s.key and s.name then
                local k = "ability." .. s.key .. ".name"
                english[k], sourceKeys[s.name] = s.name, k
                A.gameSpellIcons[k] = s.icon
            end
        end
    end
end
catalog()
for _, dictionary in pairs(A.rebornNames or {}) do
    for key, label in pairs(dictionary) do
        if string.find(key, "^ability%.") or string.find(key, "^boss%.") then
            sourceKeys[label] = key
        end
    end
end
function A.RebornClassIcon(key)
    return classIcons[key]
end
local oldIcon = A.SpellIcon
function A.SpellIcon(name)
    local key = sourceKeys[name]
    return key and A.gameSpellIcons[key] or oldIcon(name)
end
-- Original-game static drop locations are not authoritative for Reborn.
A.collectionSources = {}
function A.G(key)
    local dictionary = A.rebornNames and A.rebornNames[A.Locale()]
    if dictionary and dictionary[key] then
        return dictionary[key]
    end
    local en = english[key]
    if en then
        local translated = AZS_L and text(AZS_L[en])
        if translated and translated ~= en then
            return translated
        end
        return oldG(key) or en
    end
    return oldG(key)
end
function A.SourceName(name)
    local key = sourceKeys[name]
    if key then
        return A.G(key)
    end
    if AZS_L and type(name) == "string" and AZS_L[name] ~= name then
        local translated = text(AZS_L[name])
        if translated then
            return translated
        end
    end
    if A.uiText[A.Locale()] and A.uiText[A.Locale()][name] then
        return A.T(name)
    end
    return oldSource(name)
end
function A.SpellName(sp)
    return A.G("ability." .. tostring(sp.key) .. ".name") or A.SourceName(sp.name or sp.spell)
end
function A.DetectLocale()
    local setting = A.db and A.db.settings.language
    if setting and setting ~= "auto" then
        return oldDetect()
    end
    local code = type(GetLocale) == "function" and string.sub(GetLocale(), 1, 2)
    if code and A.uiText[code] then
        A.locale, A.localeSource = code, "Reborn locale"
        return code
    end
    return oldDetect()
end
function A.ReadHeroic()
    return A.HeroicLevel(type(AZS_ZONE) == "table" and AZS_ZONE.dt)
end
function A.NativeRunId()
    local id = type(AZS_ZONE) == "table" and AZS_ZONE.run
    if type(id) == "string" and string.find(id, "^azs:r%x%x%x%x%x%x%x%x$") then
        return id
    end
    if type(id) == "string" and string.find(id, "^r%x%x%x%x%x%x%x%x$") then
        return "azs:" .. id
    end
end
local oldIdentity = A.Identity
function A.Identity()
    local key, class, hero, zone, label, source = oldIdentity()
    local id = A.NativeRunId()
    if id then
        key = hero .. ":" .. class .. ":" .. id
        local old = A.run
        if old and old.nativeRunId == id then
            zone, label = old.zone or zone, old.zoneName or label
        end
    end
    return key, class, hero, zone, label, source
end
local oldSummaryMatches = A.SummaryMatches
function A.SummaryMatches(run, summary)
    local id = summary and (summary.runId or summary.run)
    if
        id
        and run.nativeRunId
        and id ~= run.nativeRunId
        and "azs:" .. tostring(id) ~= run.nativeRunId
    then
        return false
    end
    return oldSummaryMatches(run, summary)
end
function A.V2NativeCapabilities()
    return {
        combat = {
            available = type(AZS_GetCombatTextEvents) == "function",
            state = type(AZS_GetCombatTextEvents) == "function" and "ready" or "missing",
        },
        encounter = {
            available = type(AZS_GetWorldAnchors) == "function",
            state = type(AZS_GetWorldAnchors) == "function" and "ready" or "missing",
        },
        coop = { available = type(AZS_GetDownedPartyMembers) == "function" },
        playerPosition = { available = type(AZS_GetPlayerPosition) == "function" },
    }
end
function A.NormalizeCombatBatch(batch)
    local out = {
        apiVersion = batch.apiVersion,
        cursor = batch.cursor,
        hasMore = batch.hasMore,
        gap = batch.gap,
        events = {},
    }
    local caps = native(AZS_GetMeterCapabilities)
    out.streamId = (A.NativeRunId() or "unknown")
        .. ":"
        .. tostring(caps and caps.uiSessionId or "session")
    if type(batch.events) ~= "table" or getmetatable(batch.events) then
        out.events = false
        return out
    end
    for i = 1, math.min(256, table.getn(batch.events or {})) do
        local e = A.Copy(batch.events[i])
        if type(e) == "table" then
            e.schoolMask = e.school
        end
        table.insert(out.events, e)
    end
    return out
end
local elapsed = 0
function A.RebornFrameTick(dt)
    elapsed = elapsed + dt
    if elapsed < 0.2 then
        return
    end
    elapsed = 0
    if A.db and A.run and A.V2FeaturePreferences().combatIntelligence then
        A.V2CombatTick(A.run)
    end
end
function A.RebornSnapshot(metric, seconds, scope, checkpoint)
    if metric ~= "damage" and metric ~= "healing" then
        return nil, { code = "UNSUPPORTED_QUERY" }
    end
    if
        type(seconds) ~= "number"
        or seconds ~= math.floor(seconds)
        or (seconds ~= 0 and (seconds < 5 or seconds > 120))
    then
        return nil, { code = "INVALID_WINDOW" }
    end
    local context, err = native(AZS_GetMeterContext)
    if not context then
        return nil, err
    end
    local q = {
        apiVersion = 1,
        runId = context.runId,
        metric = metric,
        scope = scope or "self",
        period = "run",
        groupBy = "source",
        windowSeconds = seconds,
    }
    if checkpoint then
        q.checkpointId = checkpoint
    end
    return native(AZS_GetMeterSnapshot, q)
end
local segment
function A.RebornStartSegment()
    if not A.run or A.run.status ~= "active" then
        return nil, { code = "NO_LIVE_RUN" }
    end
    if segment then
        return nil, { code = "SEGMENT_ACTIVE" }
    end
    local context, err = native(AZS_GetMeterContext)
    if not context then
        return nil, err
    end
    local cp, failure = native(AZS_CreateMeterCheckpoint, context.runId)
    if not cp then
        return nil, failure
    end
    segment = {
        id = cp.checkpointId,
        runId = context.runId,
        start = context.asOfRunSeconds,
        uiSessionId = context.uiSessionId,
    }
    return segment
end
function A.RebornEndSegment()
    if not segment then
        return nil, { code = "NO_SEGMENT" }
    end
    local active = segment
    local damage, failure = A.RebornSnapshot("damage", 0, "self", active.id)
    local healing = A.RebornSnapshot("healing", 0, "self", active.id)
    native(AZS_ReleaseMeterCheckpoint, active.id)
    segment = nil
    if not damage then
        return nil, failure
    end
    local result = {
        start = active.start,
        damage = damage.totals,
        healing = healing and healing.totals,
        partial = not healing,
        runId = active.runId,
    }
    if A.run and A.run.nativeRunId == active.runId then
        local r = A.run.reborn
        r.segments = r.segments or {}
        if table.getn(r.segments) < 32 then
            table.insert(r.segments, result)
        else
            r.truncated = true
        end
    end
    return result
end
local oldBuild = A.ObserveBuild
function A.ObserveBuild(run)
    if run.trendsReset then
        return
    end
    oldBuild(run)
    local context = native(AZS_GetMeterContext)
    if not context then
        return
    end
    local loadout = native(AZS_GetMeterLoadout, { apiVersion = 1, runId = context.runId })
    if not loadout then
        return
    end
    run.reborn = run.reborn or { game = A.game, contract = 1 }
    local r = run.reborn
    local captured = {
        abilities = {},
        jewelry = {},
        complete = loadout.complete,
        language = context.languageCode,
    }
    for _, item in ipairs(loadout.abilities or {}) do
        if table.getn(captured.abilities) >= 32 then
            break
        end
        local s = loadout.sources and loadout.sources[item.sourceKey]
        if s then
            table.insert(captured.abilities, {
                key = s.abilityKey,
                name = text(s.name),
                rank = A.Number(item.rank),
                spell = s.spellIds and s.spellIds[1],
                icon = A.TexturePath(s.icon),
                description = AZS_SPELLTIPS and text(AZS_SPELLTIPS[s.abilityKey]),
            })
        end
    end
    run.usage = run.usage or { spells = {}, jewelry = {}, slots = {} }
    for index, item in ipairs(loadout.runJewelry or {}) do
        if table.getn(captured.jewelry) >= 5 then
            break
        end
        local s = loadout.sources and loadout.sources[item.sourceKey]
        if s then
            local row = {
                key = text(s.itemKey),
                name = text(s.name),
                rank = A.Number(s.rank),
                slot = item.slotId,
                icon = A.TexturePath(s.icon),
            }
            local gear = AZS_GEAR and AZS_GEAR[index]
            if gear and gear.name == s.name then
                row.description = text(gear.text)
                row.rarity = A.Number(gear.rarity)
            end
            table.insert(captured.jewelry, row)
            if row.key and not A.TrendKeyReset(run, "jewelry", row.key) then
                local prior = run.usage.jewelry[row.key] or { name = row.name, changes = 0 }
                prior.rank, prior.slot, prior.icon = row.rank, row.slot, row.icon
                prior.maxRank = math.max(prior.maxRank or 0, row.rank or 0)
                run.usage.jewelry[row.key] = prior
                A.AccountUsage(run, "jewelry", row.key, prior)
            end
        end
    end
    r.loadout = captured
    local signature = A.Sign(captured)
    if signature ~= r.loadoutSignature then
        r.loadoutChanges = r.loadoutChanges or {}
        if table.getn(r.loadoutChanges) < 16 then
            local compact = { abilities = {}, jewelry = {} }
            for _, item in ipairs(captured.abilities) do
                table.insert(compact.abilities, { key = item.key, rank = item.rank })
            end
            for _, item in ipairs(captured.jewelry) do
                table.insert(compact.jewelry, { key = item.key, rank = item.rank })
            end
            table.insert(r.loadoutChanges, { t = run.values.duration, loadout = compact })
        else
            r.truncated = true
        end
        r.loadoutSignature = signature
    end
end
local oldSample = A.Sample
function A.Sample()
    if A.Call(AZS_GetPhase) == nil then
        return
    end
    oldSample()
    local run = A.run
    if not run then
        return
    end
    run.game = A.game
    run.heroicSource = run.heroic ~= nil and "AZS_ZONE.dt" or nil
    run.reborn = run.reborn or { game = A.game, contract = 1 }
    local r = run.reborn
    r.endless = type(AZS_RUN) == "table" and AZS_RUN.endless == 1
    if r.endless then
        r.endlessAt = r.endlessAt or run.values.duration
    end
    r.locale = A.Locale()
    r.guardians = {}
    local guards = native(AZS_GetGuardians)
    for i = 1, math.min(8, table.getn(guards or {})) do
        local g = guards[i]
        if g.hp and g.hpm and g.hpm > 0 then
            table.insert(r.guardians, {
                id = text(tostring(g.id)),
                name = text(g.name),
                hp = A.Number(g.hp),
                hpm = A.Number(g.hpm),
                awake = g.awake == true,
            })
        end
    end
    r.nextBosses = {}
    if not r.endless then
        local bosses = native(AZS_GetUpcomingBosses)
        for i = 1, math.min(9, table.getn(bosses or {})) do
            local b = bosses[i]
            table.insert(
                r.nextBosses,
                { name = text(b.name), left = A.Number(b.left), index = A.Number(b.index) }
            )
        end
    end
    if segment and segment.runId ~= A.NativeRunId() then
        segment = nil
    end
end
if AZS and type(AZS.On) == "function" then
    for _, prefix in ipairs({
        "AZSRUN",
        "AZSEND",
        "AZSMETER",
        "AZSHEAL",
        "AZSBOSSDMG",
        "AZSTAKEN",
        "AZSSPELLS",
        "AZSPARTY",
        "AZSZONE",
        "AZSSTATS",
        "AZSBUFFS",
        "AZSDEBUFFS",
        "AZSPETS",
        "AZSUNITS",
        "AZSREVIVE",
    }) do
        local channel = prefix
        AZS.On(channel, function(message)
            A.Packet(channel, message)
        end)
    end
end
-- Read-only, explicitly versioned interop. No references to the live database escape.
function A.ExportRebornRun(id)
    local run = A.FindRun(id)
    if not run then
        return nil, "UNKNOWN_RUN"
    end
    return {
        apiVersion = 1,
        game = A.game,
        version = A.version,
        id = run.id,
        nativeRunId = run.nativeRunId,
        values = A.Copy(run.values),
        reborn = A.Copy(run.reborn),
    }
end
local oldReport = A.ReportModel
function A.ReportModel(model, run)
    oldReport(model, run)
    if A.view.reportSection == "Combat Intelligence" and run and run.game == A.game then
        for _, row in ipairs(model.rows or {}) do
            if row.label == "Missed attacks" then
                row.value = A.T("Not measured by the game")
                row.detail = ""
            end
        end
    end
    if A.view.reportSection ~= "Reborn" or not run then
        return
    end
    model.title = A.T("Reborn")
    model.rows = {}
    model.columnLabel = A.T("Details")
    model.columnValue = A.T("Value")
    local function row(k, v, d)
        table.insert(
            model.rows,
            { label = A.T(k), value = tostring(v or A.T("Not available")), detail = d or "" }
        )
    end
    local r = run.reborn or {}
    row(
        "Run mode",
        A.T(r.endless and "Endless" or "Campaign"),
        r.endless and A.T("No future endless boss is exposed by the game.") or ""
    )
    row("Difficulty", A.HeroicLabel(run))
    if A.run == run and run.status == "active" then
        for _, metric in ipairs({ "damage", "healing" }) do
            local snap, err = A.RebornSnapshot(metric, A.rebornWindow or 15)
            local rate = snap and snap.totals and snap.totals.recentRate
            row(
                metric == "damage" and "Recent damage" or "Recent healing",
                rate and rate.status == "ready" and A.Short(rate.value) .. " /s"
                    or A.T("Not available"),
                (A.rebornWindow or 15)
                    .. " s · "
                    .. (
                        rate
                            and (rate.reason and A.T("Partial native history") or (rate.status == "warming_up" and A.T(
                                "Waiting"
                            )) or (rate.approximate and A.T("Sampled")) or A.T(
                                "Observed only"
                            ))
                        or (err and A.T("Native API unavailable"))
                        or ""
                    )
            )
        end
    else
        row("Recent damage", A.T("Not available"), A.T("Partial native history"))
    end
    local loadout = r.loadout
    row(
        "Observed build",
        loadout and table.getn(loadout.abilities) .. " / " .. table.getn(loadout.jewelry),
        A.T("Spells") .. " / " .. A.T("Equipment")
    )
    row("Segment", r.segments and table.getn(r.segments) or 0)
    row(
        "Next bosses",
        r.nextBosses and r.nextBosses[1] and A.SourceName(r.nextBosses[1].name)
            or A.T("Not available")
    )
end

-- Native observations use bounded plain data; they never replace official totals.
local function rateValue(snapshot)
    local rate = snapshot and snapshot.totals and snapshot.totals.recentRate
    if rate and rate.status == "ready" then
        return A.Number(rate.value), rate.reason, rate.approximate
    end
    return nil, rate and (rate.reason or rate.status) or "unavailable"
end
local sampled = A.Sample
function A.Sample()
    sampled()
    local run = A.run
    if not run or run.status ~= "active" or not run.reborn then
        return
    end
    local r = run.reborn
    local t = run.values.duration
    if not t or (r.lastWindowAt and t < r.lastWindowAt + 15) then
        return
    end
    r.lastWindowAt = t
    local damage, derr = rateValue(A.RebornSnapshot("damage", 15))
    local healing, herr = rateValue(A.RebornSnapshot("healing", 15))
    r.windowSamples = r.windowSamples or {}
    if table.getn(r.windowSamples) < 120 then
        table.insert(r.windowSamples, {
            t = t,
            seconds = 15,
            damage = damage,
            healing = healing,
            damageState = derr,
            healingState = herr,
            partial = true,
        })
    else
        r.truncated = true
    end
    if damage then
        r.peakRecentDps = math.max(r.peakRecentDps or 0, damage)
    end
    local party = native(AZS_GetMeterContext)
    if party and party.partyState == "party" then
        local snap = A.RebornSnapshot("damage", 0, "party")
        if snap then
            r.party = { rows = {}, asOf = t, partial = not snap.complete }
            for i = 1, math.min(32, table.getn(snap.rows or {})) do
                local item = snap.rows[i]
                table.insert(r.party.rows, {
                    ownerId = text(item.ownerId),
                    sourceKey = text(item.sourceKey),
                    amount = A.Number(item.displayAmount),
                })
            end
        end
    end
    r.dotStats = {}
    for _, key in ipairs({ "doth", "dotd", "dots" }) do
        r.dotStats[key] = A.Number(AZS_STATS and AZS_STATS[key])
    end
end
local oldMatches = A.MatchesHistory
function A.MatchesHistory(run, filters, protected)
    local mode = A.view.rebornMode or (A.db and A.db.settings.rebornMode)
    if mode == "endless" and not (run.reborn and run.reborn.endless) then
        return false
    end
    if mode == "campaign" and run.reborn and run.reborn.endless then
        return false
    end
    return oldMatches(run, filters, protected)
end
local oldContext = A.RunContext
function A.RunContext(run)
    local value = oldContext(run)
    if run and run.reborn and run.reborn.endless then
        return value .. " · " .. A.T("Endless")
    end
    return value
end
function A.RebornCommand(message)
    local _, _, command, value = string.find(string.lower(message or ""), "^(%S+)%s*(.-)$")
    if command == "window" then
        local n = tonumber(value)
        if n and n == math.floor(n) and n >= 5 and n <= 120 then
            A.rebornWindow = n
            if A.db then
                A.db.settings.rebornWindow = n
            end
        end
        if A.db then
            A.OpenReport(A.Selected() and A.Selected().id)
            A.view.reportSection = "Reborn"
            A.RefreshUI()
        end
        return true
    elseif command == "segment" then
        local result, err
        if value == "start" then
            result, err = A.RebornStartSegment()
        elseif value == "end" then
            result, err = A.RebornEndSegment()
        end
        A.Say(
            result and A.T("Segment")
                or A.T("Not available")
                    .. " · "
                    .. tostring(err and err.code or "/azstatsr segment start | end")
        )
        return true
    elseif command == "mode" and (value == "campaign" or value == "endless" or value == "all") then
        A.view.rebornMode = value
        if A.db then
            A.db.settings.rebornMode = value
            A.view.page = 1
            A.RefreshUI()
        end
        return true
    end
    return false
end
local oldInit = A.InitDB
function A.InitDB()
    local fresh = AzerothStatsRebornDB == nil
    if fresh then
        AzerothStatsRebornDB = {
            game = A.game,
            schema = A.schema,
            sequence = 0,
            runs = {},
            totals = {},
            classes = {},
            settings = {},
            migrations = {},
        }
    end
    if not oldInit() then
        return false
    end
    if fresh then
        -- Stats is an analysis companion: no second HUD by default beside FieldKit.
        A.db.settings.bar = false
    end
    local n = A.Number(A.db.settings.rebornWindow)
    A.rebornWindow = n and n >= 5 and n <= 120 and math.floor(n) == n and n or 15
    return true
end
local validateDatabase = A.ValidateDatabase
function A.ValidateDatabase(database)
    return type(database) == "table" and database.game == A.game and validateDatabase(database)
end
local function buildRows(run, kind)
    local data = run and run.reborn and run.reborn.loadout
    if not data then
        return nil
    end
    local result = {}
    for _, item in ipairs(kind == "Spells" and data.abilities or data.jewelry) do
        table.insert(result, {
            label = kind == "Spells" and A.SpellName(item) or item.name,
            value = A.T("Rank") .. " " .. tostring(item.rank or "?"),
            detail = item.description or A.T("Not available"),
            exact = item.description,
            icon = item.icon,
            rebornTooltip = true,
        })
    end
    return result
end
local pageModel = A.PageModel
function A.PageModel()
    local model = pageModel()
    if A.view.tab == 5 then
        local rows = buildRows(A.Selected(), A.view.characterTab or "Spells")
        if rows and table.getn(rows) > 0 then
            if A.view.characterTab == "Equipment" then
                for _, r in ipairs(model.rows) do
                    if r.collection then
                        table.insert(rows, r)
                    end
                end
            end
            model.rows = rows
            model.empty = false
        end
    end
    return model
end
local itemTooltip = A.ItemTooltip
function A.ItemTooltip(frame, item)
    if item.rebornTooltip then
        GameTooltip:SetOwner(frame, "ANCHOR_RIGHT")
        GameTooltip:ClearLines()
        GameTooltip:AddLine(text(item.label) or "", 1, 0.82, 0)
        GameTooltip:AddLine(text(item.value) or "", 0.75, 0.75, 0.75)
        GameTooltip:AddLine(text(item.exact or item.detail) or "", 1, 1, 1, true)
        GameTooltip:Show()
        return true
    end
    return itemTooltip(frame, item)
end
local reportModel = A.ReportModel
function A.ReportModel(model, run)
    reportModel(model, run)
    if run and (A.view.reportSection == "Equipment" or A.view.reportSection == "Spells") then
        local rows = buildRows(run, A.view.reportSection)
        if rows and table.getn(rows) > 0 then
            model.rows = rows
            model.empty = false
        end
    end
end

-- Structured incoming damage is stronger death evidence than parsing translated chat.
-- An observed fatal overkill value is required before promoting an attribution.
local log = CreateFrame("Frame", "AzerothStatsRebornDeathLog", UIParent)
log:RegisterEvent("COMBAT_LOG_EVENT_UNFILTERED")
log:SetScript("OnEvent", function(_, event, ...)
    if event ~= "COMBAT_LOG_EVENT_UNFILTERED" or not A.run or not UnitGUID then
        return
    end
    local values = { ... }
    local sub, source, target = values[2], values[4], values[6]
    if target ~= UnitGUID("player") then
        return
    end
    local amount, over, spell
    if sub == "SWING_DAMAGE" then
        amount, over = values[9], values[10]
    elseif sub == "SPELL_DAMAGE" or sub == "SPELL_PERIODIC_DAMAGE" or sub == "RANGE_DAMAGE" then
        spell, amount, over = values[10], values[12], values[13]
    else
        return
    end
    amount = A.Number(amount)
    local watch = A.deathWatch
    if not amount or not watch or watch.run ~= A.run or not watch.armed or not text(source) then
        return
    end
    local hit = {
        at = GetTime(),
        source = text(source),
        amount = amount,
        spell = text(spell),
        overkill = A.Number(over),
    }
    table.insert(watch.hits, hit)
    while table.getn(watch.hits) > 16 do
        table.remove(watch.hits, 1)
    end
    if type(over) == "number" and over >= 0 then
        watch.explicit = {
            source = text(source),
            at = GetTime(),
            raw = "Reborn COMBAT_LOG_EVENT_UNFILTERED: fatal overkill " .. tostring(over),
        }
        A.run.reborn = A.run.reborn or { game = A.game, contract = 1 }
        A.run.reborn.fatal = {
            source = text(source),
            spell = text(spell),
            amount = amount,
            overkill = over,
            t = A.run.values.duration,
            confirmed = true,
        }
        if watch.closed then
            A.UpgradeDeath(watch)
        end
    end
end)
function A.RebornSection(key)
    local _, _, n = string.find(key or "", "^Reborn:(%d+)$")
    if n then
        n = tonumber(n)
        if n >= 5 and n <= 120 then
            A.rebornWindow = n
            if A.db then
                A.db.settings.rebornWindow = n
            end
        end
        return "Reborn"
    end
    if key == "Reborn:start" or key == "Reborn:end" then
        local result, err
        if key == "Reborn:start" then
            result, err = A.RebornStartSegment()
        else
            result, err = A.RebornEndSegment()
        end
        if not result then
            A.Say(A.T("Not available"))
        end
        return "Reborn"
    end
    return key
end
function A.NewRunData()
    return { game = A.game, contract = 1, endless = AZS_RUN and AZS_RUN.endless == 1 }
end
local matching = A.MatchingContext
function A.MatchingContext(left, right)
    if not matching(left, right) then
        return false
    end
    if left.game ~= right.game then
        return false
    end
    local a = left.reborn and left.reborn.endless == true
    local b = right.reborn and right.reborn.endless == true
    return a == b
end
local originalDeathEvidence = A.DeathEvidence
function A.DeathEvidence(ev, message)
    if ev == "UI_ERROR_MESSAGE" or ev == "CHAT_MSG_COMBAT_FRIENDLY_DEATH" or not UnitGUID then
        originalDeathEvidence(ev, message)
    end
end
local nemesis = A.NemesisModel
function A.NemesisModel(model, group)
    nemesis(model, group)
    for _, r in ipairs(model.rows) do
        if r.entryAction and r.entryAction.kind == "nemesis" then
            r.label = A.SourceName(r.label)
            r.detail = A.T("Fatal hit observed") .. " / " .. A.T("Probable")
        end
    end
end
local enhance = A.V2EnhanceModel
function A.V2EnhanceModel(model, run)
    enhance(model, run)
    local section = (model.report and A.view.reportSection)
        or (A.view.tab == 5 and A.view.characterTab)
    local r = run and run.reborn
    if not r then
        return
    end
    if section == "Encounters" then
        for _, g in pairs(r.guardianHistory or {}) do
            table.insert(model.rows, {
                label = A.SourceName(g.name),
                value = g.hpm and A.Format(g.hp) .. " / " .. A.Format(g.hpm),
                detail = A.T("Guardians") .. " · " .. A.Duration(g.lastAt),
            })
        end
    elseif section == "Summons" or section == "Effects" then
        local kinds = section == "Summons" and { "totems" } or { "timers" }
        for _, kind in ipairs(kinds) do
            for _, v in pairs((r.presence or {})[kind] or {}) do
                table.insert(model.rows, {
                    label = A.SourceName(v.name),
                    value = A.Duration(v.lastAt - v.firstAt),
                    detail = A.T(kind == "totems" and "Totems observed" or "Timers observed")
                        .. " · "
                        .. A.T("Observed presence"),
                    icon = v.icon,
                })
            end
        end
    end
    if r.truncated then
        model.note = (model.note or "") .. " · " .. A.T("Partial")
    end
end
local observe = A.Sample
function A.Sample()
    observe()
    local run = A.run
    if not run or run.status ~= "active" or not run.reborn then
        return
    end
    local r, t = run.reborn, run.values.duration
    if not t then
        return
    end
    r.guardianHistory = r.guardianHistory or {}
    for _, g in ipairs(r.guardians or {}) do
        if A.Admit(r.guardianHistory, g.id, 32, r, "truncated") then
            local h = r.guardianHistory[g.id] or { name = g.name, firstAt = t }
            h.lastAt, h.hp, h.hpm = t, g.hp, g.hpm
            r.guardianHistory[g.id] = h
        end
    end
    r.presence = r.presence or {}
    for _, def in ipairs({ { "totems", AZS_GetTotems }, { "timers", AZS_GetTimers } }) do
        local kind, fn = def[1], def[2]
        r.presence[kind] = r.presence[kind] or {}
        local list = native(fn)
        for i = 1, math.min(32, table.getn(list or {})) do
            local item = list[i]
            local key = text(item.key or item.name)
            if
                key
                and (item.permanent or (A.Number(item.remaining) or 0) > 0)
                and A.Admit(r.presence[kind], key, 32, r, "truncated")
            then
                local prev = r.presence[kind][key]
                    or {
                        name = text(item.name) or key,
                        firstAt = t,
                        icon = A.TexturePath(item.icon),
                    }
                prev.lastAt = t
                r.presence[kind][key] = prev
            end
        end
    end
end
local curve = A.V2Curve
function A.V2Curve(run, metric)
    if metric == "recentDps" or metric == "recentHps" then
        local rows = {}
        local gap = true
        for _, s in ipairs(run and run.reborn and run.reborn.windowSamples or {}) do
            local value = s.healing
            if metric == "recentDps" then
                value = s.damage
            end
            if type(value) == "number" then
                table.insert(rows, { t = s.t, value = value, gap = gap })
                gap = false
            else
                gap = true
            end
        end
        return rows
    end
    return curve(run, metric)
end
local metricLabel = A.Metric
function A.Metric(key)
    if key == "recentDps" then
        return A.T("Recent DPS") .. " · 15 s"
    end
    if key == "recentHps" then
        return A.T("Recent HPS") .. " · 15 s"
    end
    return metricLabel(key)
end
function A.NormalizeRunSummary(source)
    if type(source) ~= "table" or getmetatable(source) then
        return source
    end
    for _, key in ipairs({ "hero", "zone", "class", "race" }) do
        if source[key] ~= nil and type(source[key]) ~= "string" then
            return source
        end
    end
    local copy = A.ReadFields(source)
    if copy.result == "dead" then
        copy.nativeResult = copy.result
        copy.result = copy.quit == 1 and "left" or "defeat"
    end
    return copy
end
-- Explicit native cumulative counters. A cache price is never a chest count.
local tallySample = A.Sample
function A.Sample()
    if A.Call(AZS_GetPhase) == nil then
        return
    end
    tallySample()
    local run = A.run
    if not run or not run.reborn or not AZS_RUN then
        return
    end
    run.reborn.nativeTally = {}
    for _, key in ipairs({ "ge", "bk", "gk", "ek", "ck", "gold", "rrc" }) do
        run.reborn.nativeTally[key] = A.Number(AZS_RUN[key])
    end
    if run.status == "active" or run.status == "terminal" then
        local changed = false
        for metric, key in pairs({ bosses = "bk", guardians = "gk", elites = "ek", chests = "ck" }) do
            local n = A.Number(AZS_RUN[key])
            if n ~= nil and run.values[metric] and n < run.values[metric] then
                run.reborn.counterReset = true
            elseif n ~= nil and run.values[metric] ~= n then
                run.values[metric] = n
                run.provenance = run.provenance or {}
                run.provenance[metric] = "AZS_RUN." .. key
                changed = true
            end
        end
        if changed then
            A.Account(run)
        end
    end
end
