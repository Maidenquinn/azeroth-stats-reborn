# Azeroth Stats Reborn

Local run history and analysis for **Azeroth Survivors Reborn**. Works alongside Azeroth FieldKit Reborn without replacing its HUD.

Extract the `AzerothStatsReborn` folder into `Interface/AddOns`, enable it, and use `/azstatsr` to open Stats. The required `AzerothSurvivorsAPI` ships with the game. Install the release ZIP, not this repository's shared `AzerothStats` source folder.

Explore searchable run history, favorites, comparisons, progression and records, observed builds and ranks, real spell/NPC icons, encounters and build timelines. Recent combat windows cover 5–120 seconds; checkpoint segments measure an interval you choose. Five visual themes, scaling, opacity, language settings and an optional compact HUD are available.

## Backup storage

**New installations use shared backup storage by default.** Identical complete run versions can be reused across manual and automatic checkpoints; different versions remain independent. The active statistics database stays separate. Savings vary with your history.

Existing profiles keep their current storage until you choose to migrate. No Python, external tool or file editing is required:

1. Open **Settings → Manage backups → Backup storage**, or type `/azstatsr storage`.
2. Choose **Migrate to shared storage**, review the change, then **Save safety copy and reload**.
3. Reopen the same screen. Choose **Apply verified change and reload**.
4. The addon checks the saved result. The local safety copy remains available until you remove it explicitly.

The safety copy is stored in the addon's own SavedVariables file; it is not an independent external file backup. It temporarily uses additional space. After verification, **Remove safety copy** frees that copy without deleting current backups or statistics.

**Return to classic format** exports all current checkpoints, including ones created after migration, with the same safety/reload checks. The classic format follows the client's native numeric precision; the retained safety copy preserves exact values. **Recover safety copy** instead restores the older backup catalogues and can replace newer checkpoints; it requires explicit review. Storage changes never replace your current statistics or reset the running game.

While a storage change awaits verification, backup writes are paused to keep the reviewed catalogues stable. Statistics continue recording. Finish or cancel the change from the same screen. Do not install an older addon directly over shared-format saves: return to classic format first.

Regular history cleanup and backup creation/restoration/deletion work during runs. Restoring a statistics backup keeps a safety snapshot, detaches the old observation and resumes recording on the next native run so cumulative game counters do not overwrite the restored history. The game itself is not reset.

## Limits and privacy

All reports are local observations. Nothing is uploaded automatically. The original Azeroth Stats addon, commands and saved variables remain independent; its histories are not imported automatically.

Missing native data is shown as unavailable. Future endless bosses, received healing and unsupported proc classification are not invented. Reloads lose the game's short recent-event buffers. FR/EN and the main single-player workflow have been checked; multiplayer, extreme histories and every class/resolution combination are not independently certified.

Bundled artwork and fonts retain their original ownership and notices; see `CREDITS.md` and `IMAGE-CREDITS.md`.

## Development

Build with `python tools/build_reborn.py`; install the generated `AzerothStatsReborn` folder, not shared source `AzerothStats/`. Validation: `python tools/checks.py` and the Reborn suites in CI.

- [Implementation and acceptance](docs/reborn/IMPLEMENTATION.md)
- [Storage migration and recovery](docs/reborn/IN-ADDON-STORAGE.md)
- [Compatibility audit](docs/reborn/AUDIT.md)
- [Original project](https://github.com/Maidenquinn/AzerothStats)

This dedicated repository and saved data remain separate from the original addon. See [notices](NOTICE.md) and bundled asset credits.
