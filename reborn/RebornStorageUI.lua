local A = AzerothStatsReborn
local widgets = A.widgets
local function tr(en, fr)
    return A.Locale() == "fr" and fr or en
end
function A.OpenStorageSettings()
    if not A.window or not widgets then
        return false
    end
    A.ToggleUI(true)
    local w = widgets
    local dialog = A.storageDialog
    if not dialog then
        local blocker = CreateFrame("Button", nil, A.window)
        blocker:SetAllPoints(A.window)
        blocker:EnableMouse(true)
        blocker:SetFrameStrata("FULLSCREEN_DIALOG")
        blocker:SetFrameLevel(A.window:GetFrameLevel() + 99)
        blocker.rebornLayerOffset = 99
        w.solid(blocker, 0, 0, 0, 0.55)
        dialog = CreateFrame("Frame", "AzerothStatsRebornStorageSettings", A.window)
        A.storageDialog = dialog
        dialog:SetWidth(650)
        dialog:SetHeight(520)
        dialog:SetPoint("CENTER", A.window, "CENTER", 0, 0)
        dialog:SetFrameStrata("FULLSCREEN_DIALOG")
        dialog:SetFrameLevel(A.window:GetFrameLevel() + 100)
        dialog.rebornLayerOffset = 100
        dialog:EnableMouse(true)
        dialog.blocker = blocker
        dialog:SetScript("OnHide", function()
            blocker:Hide()
        end)
        w.surface(dialog, "main")
        local title = w.font(dialog, 22, 16, 600, 32, 20, A.theme.gold, true)
        local status = w.font(dialog, 22, 58, 600, 30, 14, A.theme.gold)
        local detail = w.font(dialog, 22, 96, 600, 160, 12, A.theme.text)
        local message = w.font(dialog, 22, 266, 600, 48, 12, A.theme.muted)
        local function reload()
            if type(ReloadUI) == "function" then
                ReloadUI()
            else
                dialog.message = tr(
                    "Restart the game to save and verify.",
                    "Relance le jeu pour enregistrer et vérifier."
                )
            end
        end
        local refresh
        local primary = w.button(dialog, 22, 328, 606, 34, "", function()
            local s = A.StorageReview()
            local ok, result
            if dialog.intent == "recover" then
                ok, result = A.RecoverStorageSafety(dialog.token)
            elseif dialog.intent == "delete" then
                ok, result = A.DeleteStorageSafety(dialog.token)
            elseif dialog.intent == "shared" or dialog.intent == "legacy" then
                ok, result = A.PrepareStorageChange(dialog.intent, dialog.token)
            elseif s.phase == "prepared" and s.persisted then
                ok, result = A.ApplyStorageChange(s.token)
            elseif s.phase == "prepared" or s.phase == "applied" then
                reload()
                refresh()
                return
            else
                dialog.intent = s.shared and "legacy" or "shared"
                dialog.token = s.token
                refresh()
                return
            end
            dialog.message = result
            dialog.intent = nil
            dialog.token = nil
            if ok then
                reload()
            else
                A.Say(result)
            end
            refresh()
        end)
        primary.key = nil
        local recovery = w.button(dialog, 22, 374, 294, 30, "", function()
            local s = A.StorageReview()
            dialog.intent = "recover"
            dialog.token = s.token
            dialog.message = nil
            refresh()
        end)
        recovery.key = nil
        local remove = w.button(dialog, 334, 374, 294, 30, "", function()
            local s = A.StorageReview()
            dialog.intent = "delete"
            dialog.token = s.token
            dialog.message = nil
            refresh()
        end)
        remove.key = nil
        local cancel = w.button(dialog, 22, 464, 294, 30, "", function()
            if dialog.intent then
                dialog.intent = nil
                dialog.token = nil
                dialog.message = nil
                refresh()
                return
            end
            local s = A.StorageReview()
            if s.phase == "prepared" then
                local ok, result = A.CancelStorageChange(s.token)
                dialog.message = result
                if ok then
                    reload()
                else
                    A.Say(result)
                end
                refresh()
            else
                dialog:Hide()
            end
        end)
        cancel.key = nil
        local close = w.button(dialog, 334, 464, 294, 30, "", function()
            dialog:Hide()
        end)
        close.key = nil
        refresh = function()
            local s = A.StorageReview()
            w.put(title, tr("Backup storage", "Stockage des sauvegardes"))
            w.put(
                status,
                s.shared and tr("Current format: shared", "Format actif : partagé")
                    or tr("Current format: classic", "Format actif : classique")
            )
            local text = tr(
                "Only backup storage changes. Current statistics and the running game are kept.\nThe local safety copy is stored in this addon's saved data.",
                "Seul le stockage des sauvegardes change. Les statistiques actuelles et la partie sont conservées.\nLa copie de sécurité locale reste dans les données de l’addon."
            )
            local label = s.shared
                    and tr("Return to classic format…", "Revenir au format classique…")
                or tr("Migrate to shared storage…", "Passer au stockage partagé…")
            if dialog.intent == "recover" then
                text = tr(
                    "Recover the backup catalogues from the safety copy? Newer backups will be replaced. Current statistics remain unchanged.",
                    "Récupérer les sauvegardes de la copie de sécurité ? Les sauvegardes plus récentes seront remplacées. Les statistiques actuelles restent inchangées."
                )
                label = tr(
                    "Confirm safety recovery and reload",
                    "Confirmer la récupération et recharger"
                )
            elseif dialog.intent == "delete" then
                text = tr(
                    "Remove the local safety copy to free its space? Current backups and statistics will be kept. Return to classic format remains available.",
                    "Supprimer la copie de sécurité locale pour libérer son espace ? Les sauvegardes actuelles et les statistiques sont conservées. Le retour au format classique reste disponible."
                )
                label = tr("Confirm removal and reload", "Confirmer la suppression et recharger")
            elseif dialog.intent then
                text = tr(
                    "First, save a verified safety copy and reload. Then reopen this screen and apply the change. All checkpoints, including newer backups during rollback, are retained.",
                    "Enregistre d’abord une copie de sécurité vérifiée et recharge. Rouvre ensuite cet écran pour appliquer le changement. Toutes les sauvegardes sont conservées, y compris les nouvelles lors du retour au format classique."
                )
                if s.hasSafety then
                    text = text
                        .. "\n"
                        .. tr(
                            "The previous local safety copy will be replaced.",
                            "La copie de sécurité locale précédente sera remplacée."
                        )
                end
                if dialog.intent == "legacy" then
                    text = text
                        .. "\n"
                        .. tr(
                            "Classic storage uses native numeric precision; the safety copy keeps exact values.",
                            "Le format classique utilise la précision native ; la copie de sécurité garde les valeurs exactes."
                        )
                end
                label = tr(
                    "Save safety copy and reload",
                    "Enregistrer la copie de sécurité et recharger"
                )
            elseif s.phase == "prepared" then
                text = tr(
                    "Safety copy prepared. Backup writes are temporarily paused. After reloading, apply the verified change or cancel it; current statistics continue recording.",
                    "Copie de sécurité préparée. L’écriture des sauvegardes est temporairement suspendue. Après rechargement, applique le changement vérifié ou annule-le ; les statistiques continuent d’être enregistrées."
                )
                label = s.persisted
                        and tr(
                            "Apply verified change and reload",
                            "Appliquer le changement vérifié et recharger"
                        )
                    or tr(
                        "Save safety copy and reload",
                        "Enregistrer la copie de sécurité et recharger"
                    )
            elseif s.phase == "applied" then
                text = tr(
                    "The format change awaits saved-file verification. Reload to finish. The safety copy is retained.",
                    "Le changement de format attend la vérification après enregistrement. Recharge pour terminer. La copie de sécurité est conservée."
                )
                label = tr("Reload and verify", "Recharger et vérifier")
            elseif s.phase == "complete" then
                text = text
                    .. "\n"
                    .. tr(
                        "Last change verified. Safety checkpoints: ",
                        "Dernier changement vérifié. Sauvegardes dans la copie : "
                    )
                    .. s.checkpoints
            end
            w.put(detail, text)
            w.put(message, dialog.message or s.message or "")
            w.put(primary.label, label)
            w.put(
                recovery.label,
                tr("Recover safety copy…", "Récupérer la copie de sécurité…")
            )
            w.put(remove.label, tr("Remove safety copy…", "Supprimer la copie de sécurité…"))
            w.put(
                cancel.label,
                dialog.intent and tr("Back", "Retour")
                    or (
                        s.phase == "prepared"
                            and tr("Cancel storage change", "Annuler le changement")
                        or tr("Close", "Fermer")
                    )
            )
            w.put(close.label, tr("Close", "Fermer"))
            if dialog.intent or s.phase == "prepared" then
                cancel:Show()
            else
                cancel:Hide()
            end
            if
                not s.error
                or dialog.intent == "recover"
                or s.phase == "applied"
                or (dialog.intent == "delete" and s.invalidSafety)
            then
                primary:Enable()
            else
                primary:Disable()
            end
            if s.hasSafety and s.token and s.persisted and not s.invalidSafety then
                recovery:Show()
            else
                recovery:Hide()
            end
            if s.phase == "complete" or (s.invalidSafety and s.token) then
                remove:Show()
            else
                remove:Hide()
            end
            if A.RebornRepairLayers then
                A.RebornRepairLayers()
            end
        end
        dialog.refresh = refresh
        dialog.primary, dialog.recovery, dialog.remove, dialog.cancel =
            primary, recovery, remove, cancel
    end
    dialog.intent = nil
    dialog.token = nil
    dialog.message = nil
    dialog:Show()
    dialog.blocker:Show()
    A.ApplyUI()
    dialog.refresh()
    if A.SyncScreenOverlays then
        A.SyncScreenOverlays()
    end
    return true
end
local command = A.RebornCommand
function A.RebornCommand(message)
    if string.lower(string.gsub(message or "", "^%s+", "")) == "storage" then
        A.OpenStorageSettings()
        return true
    end
    return command(message)
end
