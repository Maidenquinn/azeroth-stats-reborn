# Reborn implementation and acceptance status

Development candidate: `0.1.0-reborn.5-dev`. No stable release is authorized by this document.

## Historical deletion during play (.5-dev)

Historical deletion passed its impact review during play, but the required safety backup rejected every active run, leaving confirmation blocked. A current reviewed run/history removal plan may now create its mandatory automatic snapshot while another run is active. Normal manual/automatic backup requests, restore, resets, favorite protection and active-run deletion keep their existing restrictions. The detached backup freezes active observations as interrupted/partial; the live tracker and current run are not changed. Snapshot failure or stale review still prevents deletion. Successful confirmation explicitly closes the modal blocker. The confirmation now correctly states that removed contributions are deducted from totals.

This regression also exposed a catalogue-selection defect: an absent automatic root could fall through to an existing manual catalogue. Explicit root selection now keeps both catalogues independent, including first automatic backup creation and retention.

Generated-runtime tests exercise the actual confirmation button during play, automatic backup and restore, unchanged live run, active/favorite protection, invalid/stale backup context, snapshot failure, manual catalogue preservation and original-addon namespace isolation. All destructive testing uses isolated synthetic data; no player history is deleted or restored by this recipe.

## Expansion zone illustrations (.4-dev)

All 36 expansion zone IDs now have reviewed, locally bundled thumbnails: 12 Burning Crusade, 12 Lich King and 12 Cataclysm, including the future Cataclysm catalogue. BC/LK use the official Reborn campaign artwork; Cataclysm uses Blizzard press screenshots and concept art (two archived press mirrors). Sources, credits, immutable SHA-256 hashes, original dimensions and focal points are recorded in `data/reborn-run-image-sources.json`; the package includes `IMAGE-CREDITS.md`.

The Reborn-only adapter extends the common `ZoneIllustration` renderer used by history, analysis, selectors and comparisons. Classic framing and unknown-zone fallback remain intact. Textures are 256×256 RGBA with the same aspect-correct 178×66 cover recipe as Classic, across all five themes. Builds verify the complete zone catalogue, source hashes and exact encoded bytes without downloading assets.

Validation: 36 cropped banners inspected on a contact sheet; native dimensions, nonblank pixels and geometry verified offline. Generated Lua tests exercise every new zone across all five themes, stale tint/glyph/UV reset, Classic and unknown-zone fallbacks. The owner subsequently accepted the expansion rendering after a client recipe on 2026-11-16.

## Runtime and storage

The shared, regression-tested Stats modules live in `AzerothStats/`. Small optional hooks support native identity, per-frame collection, command routing and class icons. The generator namespaces the runtime, frames, paths, commands and all three SavedVariables roots into `AzerothStatsReborn`; the Reborn adapter loads before Core initialization. Shared tests continue to exercise the original contracts independently.

The generated addon depends on `AzerothSurvivorsAPI` and retains Interface 11200 so Reborn's per-addon legacy handler shims apply. Modern structured combat callbacks in the Reborn adapter keep their explicit arguments, which the shims preserve.

A game marker is required in the Reborn database and backups. Original-game histories cannot be restored into it accidentally. No user saves are read by the build/tests. New databases disable the compact Stats HUD by default, while the analysis window and minimap launcher remain available. FieldKit and native UI are not hidden or repositioned.

## Implemented

- Twelve classes, canonical native classes/zones/spells and current icons. A frozen label-only catalogue covers 607 canonical class, zone, boss, spell and jewelry names in twelve native languages. Native locale drives automatic language choice; the existing Stats UI languages and fallback behaviour remain. Original-game drop-location references are disabled where Reborn cannot substantiate them.
- Native death/quit result normalization (`dead` to defeat, or abandonment when `quit=1`); cumulative `bk/gk/ek/ck` counters without confusing cache price and opened-chest count. Earned gold and spendable balance stay separate in native evidence.
- Difficulty from `dt`; persistent server run IDs accepted before and after the API adds its `azs:` prefix. Same-run reload resumes; differing native IDs never merge merely because the hero/map match. Official summary identity conflicts are rejected and repeated final snapshots do not double-count.
- Native combat event normalization, `school`, damage/critical/periodic classification, healing ignored by the damage-event observer, `gap` handling and 0.2-second optional polling. The combat-intelligence setting remains opt-in. Misses are explicitly unavailable rather than measured zero.
- Structured loadouts, ranks, native item/spell descriptions when supplied, compact bounded build-change snapshots and UI rows/tooltips. Account equipment remains distinct from temporary run jewelry. Historical bonuses are captured, never recalculated with obsolete formulas.
- Recent self damage/performed-healing windows from 5–120 seconds, accessible from the combat report menu or `/azstatsr window 5` (through 120). Native partial-history/error states remain unavailable, not zero.
- Checkpoint segments through report actions or `/azstatsr segment start` and `end`; checkpoint resource release and bounded local segment results. No native meter reset is performed.
- Retained 15-second DPS/HPS observations every 15 run seconds, bounded to 120 samples, exposed as additional progression-curve metrics. Missing samples produce gaps, not interpolated values or healing substituted for damage.
- Separate campaign/endless metadata, honest missing endless future-boss information, comparison-context separation and history filter `/azstatsr mode campaign|endless|all`.
- Valid guardian observations/history, optional native totem/timer presence, party source snapshot data and existing coop/support reports. Presence spans are observations, not exact uptime or causal effectiveness.
- Structured incoming fatal-hit evidence with source, ability, damage and overkill. Confirmation requires an observed native fatal overkill value; unsupported/missed cases retain probable/unknown evidence. No dependency on internal death-log widgets.
- Detached read-only `AzerothStatsReborn.ExportRebornRun(id)` with explicit game and API version for optional FieldKit integration. Nothing is sent automatically.
- Deterministic Reborn ZIP, allowlisted files, source/generated checksums, namespace checks, runtime policy scan, Lua compilation, synthetic persistence roundtrip and five-theme widget/model checks.

## Remaining acceptance work

The initial client test exposed missing dialog controls, generic spell/encounter icons and recent-window actions routed to the generic Reborn report. The second candidate explicitly orders Stats child frames above their parent surfaces, decodes structured native icon descriptors, resolves bundled NPC portraits/native creature icons, and separates recent-window and segment reports. Offline regression tests now simulate non-inherited child frame levels, including a native raise and restore of the main window.

All five recent windows are retained at bounded sampling points for new observations. Older histories retain only evidence actually recorded by their candidate; missing windows have an explicit unavailable state. Segment actions require selection of the active run, so browsing an old run cannot silently create a checkpoint in the live run.

Corrective live-client recipe completed on 2026-11-15 at 1920×1080, window scale 0.80, with candidate `.2-dev` visibly loaded. The user's Arathi Basin run stayed paused at 00:54 throughout the controls:

- All five theme previews rendered with visible, clickable child controls; Cancel restored the original Chroniques theme and English preference was preserved.
- Backup-manager controls rendered. Creating a backup correctly refused during the active run with the between-runs restriction. Actual creation/listing still needs a between-runs check.
- Local-data preview rendered its scope controls, candidate history, protected-run count, report preview and Cancel/Review actions. Cancel exited without deletion.
- The active Paladin loadout displayed distinct actual spell icons. The historical Un'Goro encounter list displayed the five distinct bundled NPC portraits rather than a common sword.
- The live 5-second report correctly showed insufficient native history after reload; 120 seconds returned 502/s total and source rates. The old run explicitly reported its 120-second window as unrecorded.
- Start segment on the old run opened the segment page with a current-run-selection notice, without creating a live checkpoint. The active start/end measurement path remains covered offline and needs a gameplay check with elapsed combat time.

These observations do not establish all three new-class gameplay scenarios or real multiplayer. Backup restoration is exercised on synthetic saves; the live recipe must not overwrite or delete the user's history.

Candidate `.3-dev` replaces the escaped separators in compact journal highlights with actual line breaks. Two regression assertions verify multiline output without literal escape text (8,185 shared assertions in total).

Follow-up client recipe completed on 2026-11-16 with Reborn 0.6.7:

- The retained Zangarmarsh history rendered four journal highlights on separate lines, with no literal escape separators.
- A checkpoint started on the current Hunter run at approximately 00:02. After a short real combat interval and a level-choice transition, the run was paused at 00:14; End segment recorded approximately 14.5k damage and zero performed healing, matching the difference from the meter before the checkpoint. The row retained its start/stop clocks and elapsed duration.
- After the owner authorized ending the test attempt, the segment remained visible in the interrupted historical run. It also survived the later UI reload and was present in the persisted manual backup.
- The hero-selection screen hides Lua addon windows. The between-runs backup recipe therefore used the terminal result screen, where Stats is accessible without an active combat run. Creating Manual No. 1 succeeded and triggered the expected UI reload. Reopening the manager showed Manual No. 1 and Automatic No. 1, both containing eight retained runs; manual selection displayed its metadata.
- Production restore logic was exercised against that actual persisted manual snapshot in an isolated local Lua process. After changing only the isolated database's preferences and emptying its run list, restore recovered all eight runs byte-for-byte at the model-signature level, including the elapsed combat segment, and the saved preference. The source save's checksum was unchanged. No live player history was restored or deleted and no private save data was committed or uploaded.

The client was left at hero selection after the recipe. The backup/segment/newline corrective acceptance is complete; the broader gameplay and multiplayer coverage listed below remains separate.

Required live checks: discovery/enabling after a new folder install; clean launch; automatic FR and manual EN; all five themes; character/equipment rows and tooltips; selection/pause overlays; window sizing and resolution; actual damage/healing changes; reload continuity; portal transitions; victory/death/abandon; campaign/endless; native/FieldKit coexistence; coop; long-run memory behaviour.

No player release or registry update until this acceptance is completed. Candidate CI artifacts are for review, not a stability claim.

## Contract limits

The game does not provide a reliable future endless boss sequence, received healing, encounter healing or dependable proc classification through these meter contracts. Recent native history is lost at reload, and the short combat-event ring can report gaps under load. Names unavailable in the game's own translation catalogue use documented fallbacks; a complete new translation of Stats-specific prose into every native language is not implied.

## Reproduce

```powershell
python tools/checks.py
python tools/verify_reborn.py
python tools/verify_reborn.py --game 'H:\Users\kevin\Desktop\AzerothSurvivorsReborn\Azeroth Survivors'
python tools/build_reborn.py
```

`tools/sync_reborn_names.py --game <game>` refreshes label data from public content only, never player saves. Review its diff when the game changes.
