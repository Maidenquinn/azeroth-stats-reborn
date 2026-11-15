# Reborn implementation and acceptance status

Development candidate: `0.1.0-reborn.2-dev`. No stable release is authorized by this document.

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

The corrective actual-client recipe is pending reload of the second candidate while the user's game remains paused. Offline mocks are not evidence for pixels, asset loading, native UI input, all three new-class gameplay scenarios or real multiplayer. Backup restoration is exercised on synthetic saves; the live recipe must not overwrite or delete the user's history.

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
