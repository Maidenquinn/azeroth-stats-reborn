local A = AzerothStatsReborn
-- Reborn launches runs immediately: local cleanup cannot require a ready screen.
A.liveDataManagement = true
function A.BeforeFullDataReset()
    if A.run then
        A.db.settings.rebornResetRunId = A.NativeRunId() or A.run.nativeRunId
    end
    A.RebornDiscardSegment()
    if A.V2CombatReset then
        A.V2CombatReset()
    end
end
local sampleBeforeResetGate = A.Sample
function A.Sample()
    local settings = A.db and A.db.settings
    local ignored = settings and settings.rebornResetRunId
    if ignored then
        local current = A.NativeRunId()
        if not current or current == ignored then
            return
        end
        settings.rebornResetRunId = nil
        A.packetSummary, A.packetReady, A.v2Packets = nil, nil, nil
        A.meterPackets = {}
    end
    return sampleBeforeResetGate()
end
-- All history, analysis and comparison views share the theme's illustration path.
local classicZoneIllustration = A.ZoneIllustration
function A.ZoneIllustration(texture, zone)
    local entry = A.rebornZoneImages and A.rebornZoneImages[zone]
    if not entry then
        return classicZoneIllustration(texture, zone)
    end
    texture.themeGlyph = nil
    texture:SetVertexColor(1, 1, 1)
    texture:SetTexture(A.theme.media .. entry.texture)
    texture:SetTexCoord(entry.left, entry.right, entry.top, entry.bottom)
end
-- Reborn does not consistently inherit strata/levels when a parent is raised.
-- Repair only Stats-owned descendants; preserve explicit modal ordering.
local modalOffsets = {
    AzerothStatsRebornThemePicker = 80,
    AzerothStatsRebornBackupManager = 35,
    AzerothStatsRebornDataManagement = 60,
    AzerothStatsRebornEntryReview = 80,
    AzerothStatsRebornRetentionConfirmation = 50,
    AzerothStatsRebornV2Note = 90,
    AzerothStatsRebornV2Goal = 90,
}
function A.RebornRepairLayers()
    local ui = A.ui or {}
    local roles = {}
    for _, v in ipairs({
        { ui.themeBlocker, 79 },
        { ui.dataBlocker, 59 },
        { ui.entryBlocker, 79 },
        { ui.retentionBlocker, 49 },
        { ui.advancedPanel, 20 },
    }) do
        if v[1] then
            roles[v[1]] = v[2]
        end
    end
    local function walk(parent, depth)
        if depth > 24 or not parent.GetChildren then
            return
        end
        local level = parent.GetFrameLevel and parent:GetFrameLevel() or 0
        local strata = parent.GetFrameStrata and parent:GetFrameStrata() or "FULLSCREEN_DIALOG"
        for _, child in ipairs({ parent:GetChildren() }) do
            if child.SetFrameLevel and child.GetFrameLevel then
                local offset = roles[child]
                    or modalOffsets[child:GetName() or ""]
                    or child.rebornLayerOffset
                if not offset then
                    offset = math.max(1, math.min(100, child:GetFrameLevel() - level))
                    child.rebornLayerOffset = offset
                end
                if child:GetFrameLevel() ~= level + offset then
                    child:SetFrameLevel(level + offset)
                end
                if child.SetFrameStrata then
                    local current = child.GetFrameStrata and child:GetFrameStrata()
                    if current ~= "TOOLTIP" and current ~= strata then
                        child:SetFrameStrata(strata)
                    end
                end
                walk(child, depth + 1)
            end
        end
    end
    for _, root in pairs({ A.window, A.bar, A.barEditor }) do
        if root then
            walk(root, 1)
        end
    end
end
local syncLayers = A.SyncScreenOverlays
function A.SyncScreenOverlays()
    syncLayers()
    A.RebornRepairLayers()
end
local frameTick = A.RebornFrameTick
local layerElapsed = 0
function A.RebornFrameTick(dt)
    frameTick(dt)
    layerElapsed = layerElapsed + dt
    if layerElapsed >= 0.2 then
        layerElapsed = 0
        if A.window and A.window:IsShown() then
            A.RebornRepairLayers()
        end
    end
end

local function tr(key)
    return A.T(key)
end
local function plain(v)
    return A.Text(v, 500)
end
local labels = {
    ["Current run excluded after reset; recording resumes next run"] = "Après la remise à zéro, l’enregistrement reprendra à la prochaine partie",
    ["Deleted run contributions are removed from totals"] = "Les statistiques de cette partie sont retirées des totaux",
    ["Damage / healing"] = "Dégâts / soins",
    ["Segments"] = "Segments",
    ["Window not recorded for this run"] = "Cette fenêtre n’a pas été enregistrée pour cette partie",
    ["Select the current run to measure a segment"] = "Sélectionnez la partie en cours pour mesurer un segment",
    ["No recorded segments"] = "Aucun segment enregistré",
    ["Segment started"] = "Segment démarré",
    ["Segment completed"] = "Segment terminé",
    ["Segment in progress"] = "Segment en cours",
    ["Captured at"] = "Relevé à",
    ["Historical sample"] = "Échantillon historique",
}
for k, v in pairs(labels) do
    A.uiText.fr[k] = v
end
function A.RebornTexture(value)
    if type(value) == "table" then
        value = value.path
    end
    return A.TexturePath(value)
end
local npcByName = {}
for name, row in pairs(A.rebornCreatureIcons or {}) do
    npcByName[name] = row
    if AZS_L and AZS_L[name] then
        npcByName[AZS_L[name]] = row
    end
end
for _, dict in pairs(A.rebornNames or {}) do
    for key, label in pairs(dict) do
        local en = A.rebornNames.en[key]
        if npcByName[en] then
            npcByName[label] = npcByName[en]
        end
    end
end
function A.RebornNpcIcon(name, entry)
    if A.creaturePortraits[name] then
        return A.NemesisPortrait(name)
    end
    local row = npcByName[name]
    entry = tonumber(entry) or (row and row.entry)
    local icon = entry and AZS_GEN and AZS_GEN.creatureIcons and AZS_GEN.creatureIcons[entry]
    return A.RebornTexture(icon) or "Interface\\Icons\\INV_Misc_QuestionMark"
end
local enhance = A.V2EnhanceModel
function A.V2EnhanceModel(model, run)
    enhance(model, run)
    local section = (model.report and A.view.reportSection)
        or (A.view.tab == 5 and A.view.characterTab)
    if section == "Encounters" then
        for _, r in ipairs(model.rows or {}) do
            if
                (r.entryAction and r.entryAction.section == "encounters")
                or string.find(r.detail or "", tr("Guardians"), 1, true)
            then
                r.icon = A.RebornNpcIcon(r.label)
            end
        end
    end
end
local page = A.PageModel
function A.PageModel()
    local model = page()
    for _, r in ipairs(model.rows or {}) do
        if r.rebornTooltip and not r.icon then
            r.icon = A.SpellIcon(r.label)
        end
    end
    return model
end
local function capture(snapshot)
    if not snapshot or not snapshot.totals then
        return { status = "unavailable" }
    end
    local rate = snapshot.totals.recentRate or {}
    local out = {
        status = rate.status,
        value = rate.status == "ready" and A.Number(rate.value) or nil,
        amount = A.Number(snapshot.totals.windowAmount),
        elapsed = A.Number(rate.elapsedSeconds),
        partial = rate.approximate or rate.status ~= "ready",
        sources = {},
    }
    for i = 1, math.min(8, table.getn(snapshot.rows or {})) do
        local r = snapshot.rows[i]
        local s = snapshot.sources and snapshot.sources[r.sourceKey] or {}
        local sr = r.recentRate or {}
        table.insert(out.sources, {
            name = plain(s.name),
            amount = A.Number(r.windowAmount),
            rate = sr.status == "ready" and A.Number(sr.value) or nil,
            icon = A.RebornTexture(s.icon),
        })
    end
    return out
end
local function windowData(seconds)
    return {
        seconds = seconds,
        at = A.run and A.run.values.duration,
        damage = capture(A.RebornSnapshot("damage", seconds)),
        healing = capture(A.RebornSnapshot("healing", seconds)),
    }
end
local sample = A.Sample
function A.Sample()
    if not A.Call(AZS_GetPhase) then
        return
    end
    sample()
    local run = A.run
    if not run or not run.reborn or run.nativeRunId ~= A.NativeRunId() then
        return
    end
    local r, t = run.reborn, run.values.duration
    if not t then
        return
    end
    local final = run.status == "ended" and not r.recentFinalCaptured
    if run.status == "active" then
        r.recentFinalCaptured = nil
    end
    if final or not r.lastRecentAt or t >= r.lastRecentAt + 15 then
        r.recentWindows = r.recentWindows or {}
        for _, s in ipairs({ 5, 15, 30, 60, 120 }) do
            r.recentWindows[tostring(s)] = windowData(s)
        end
        r.lastRecentAt = t
        if final then
            r.recentFinalCaptured = true
        end
    end
end
function A.RebornSection(key)
    local n = tonumber(string.match(key or "", "^Reborn:(%d+)$"))
    if n and n >= 5 and n <= 120 then
        A.rebornWindow = n
        if A.db then
            A.db.settings.rebornWindow = n
        end
        return "RebornWindow"
    end
    if key == "Reborn:segments" then
        A.rebornSegmentNotice = nil
        return "RebornSegments"
    end
    if key == "Reborn:start" or key == "Reborn:end" then
        if not A.run or A.Selected() ~= A.run or A.run.status ~= "active" then
            A.rebornSegmentNotice = tr("Select the current run to measure a segment")
        else
            local result, err
            if key == "Reborn:start" then
                result, err = A.RebornStartSegment()
            else
                result, err = A.RebornEndSegment()
            end
            A.rebornSegmentNotice = result
                    and tr(key == "Reborn:start" and "Segment started" or "Segment completed")
                or tr("Not available")
        end
        return "RebornSegments"
    end
    return key
end
local report = A.ReportModel
function A.ReportModel(model, run)
    report(model, run)
    if not run then
        return
    end
    local section = A.view.reportSection
    if section ~= "RebornWindow" and section ~= "RebornSegments" then
        return
    end
    model.rows = {}
    model.empty = false
    model.emptyText = nil
    model.columnValue = tr("Value")
    local function row(k, v, d, icon)
        table.insert(
            model.rows,
            { label = k, value = v or tr("Not available"), detail = d or "", icon = icon }
        )
    end
    if section == "RebornWindow" then
        local seconds = A.rebornWindow or 15
        local data
        local live = A.run == run and run.status == "active"
        if live then
            data = windowData(seconds)
        else
            data = run.reborn
                and run.reborn.recentWindows
                and run.reborn.recentWindows[tostring(seconds)]
        end
        -- Older candidates retained only actual 15-second rate observations.
        if not data and seconds == 15 then
            local list = run.reborn and run.reborn.windowSamples or {}
            local s = list[table.getn(list)]
            if s then
                data = { at = s.t, damage = { value = s.damage }, healing = { value = s.healing } }
            end
        end
        model.title = tr("Damage / healing") .. " · " .. seconds .. " s"
        model.columnLabel = model.title
        model.note = data
                and ((live and tr("Live") or tr("Historical sample")) .. " · " .. tr("Captured at") .. " " .. A.Duration(
                    data.at
                ))
            or tr("Window not recorded for this run")
        for _, metric in ipairs({ "damage", "healing" }) do
            local r = data and data[metric]
            local value = r and r.value
            row(
                tr(metric == "damage" and "Recent damage" or "Recent healing")
                    .. " · "
                    .. seconds
                    .. " s",
                value and A.Short(value) .. " /s" or nil,
                r and r.partial and tr("Partial native history") or ""
            )
        end
        for _, metric in ipairs({ "damage", "healing" }) do
            for _, s in ipairs(data and data[metric] and data[metric].sources or {}) do
                row(
                    A.SourceName(s.name),
                    s.rate and A.Short(s.rate) .. " /s" or nil,
                    tr(metric == "damage" and "Damage" or "Healing") .. " · " .. A.Short(s.amount),
                    s.icon or A.SpellIcon(s.name)
                )
            end
        end
    else
        model.title = tr("Segments")
        model.columnLabel = model.title
        model.note = A.rebornSegmentNotice or ""
        local active = A.RebornSegmentState()
        if active and A.run == run then
            row(
                tr("Segment in progress"),
                A.Duration(math.max(0, (run.values.duration or active.start) - active.start)),
                tr("Start segment") .. " " .. A.Duration(active.start)
            )
        end
        for i, s in ipairs(run.reborn and run.reborn.segments or {}) do
            local duration = s.stop and s.start and math.max(0, s.stop - s.start)
            local d = s.damage or {}
            local h = s.healing or {}
            row(
                tr("Segment") .. " " .. i,
                A.Short(d.sinceCheckpointAmount or d.displayAmount)
                    .. " / "
                    .. A.Short(h.sinceCheckpointAmount or h.displayAmount),
                A.Duration(s.start)
                    .. " → "
                    .. A.Duration(s.stop)
                    .. (duration and " · " .. A.Duration(duration) or "")
            )
        end
        if table.getn(model.rows) == 0 then
            model.empty = true
            model.emptyText = tr("No recorded segments")
        end
    end
end
