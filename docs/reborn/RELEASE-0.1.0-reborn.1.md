# Azeroth Stats Reborn — first public release

Run history, combat analysis and progression tracking adapted to Azeroth Survivors Reborn. This is a separate addon from the original Azeroth Stats, with its own commands and local saved data.

## Features

- Searchable run history, filters, favorites, comparisons, records, progression and Nemesis views.
- Combat breakdowns, recent 5–120 second windows and checkpoint segments.
- Observed spells, ranks, equipment bonuses, build timelines and encounter portraits.
- Five visual themes, scaling/opacity options and an optional compact HUD.
- Native Reborn names and icons, local observations for campaign/endless runs, and compatibility with FieldKit.
- Shared backup storage enabled for new installations. Existing profiles migrate from inside the addon, with a persisted local safety copy, verification and classic-format rollback; no external tool is needed.

## Install and migrate

Extract only `AzerothStatsReborn` into `Interface/AddOns`. The bundled game API is required. Open `/azstatsr` for Stats or `/azstatsr storage` for backup storage. Existing profiles stay on their current format until you choose to migrate.

Migration first saves a safety copy and reloads; a second confirmed step applies the change and reloads for verification. The copy is in the addon's local SavedVariables file, not an independent external backup. It adds temporary overhead and can be removed explicitly after validation. Returning to classic exports current checkpoints, including newer ones; recovering an older safety copy is a separate reviewed action. Classic storage uses the client's native numeric precision.

## Validation and limits

Automated suites cover the original runtime, generated Reborn contracts, shared snapshot integrity, native numeric rounding, migration/reload barriers, rollback/recovery, actual dialog callbacks and FR/EN across five themes. Native client 0.6.7 acceptance passed for fresh shared defaults, checkpoint persistence, classic rollback, shared migration and safety recovery across real UI reloads. See IN-ADDON-STORAGE.md for scope; release assets include SHA-256 checksums.

Data stays local; nothing is uploaded automatically. Missing native information is displayed as unavailable: no invented future endless boss sequence, received healing or unsupported proc classification. Native recent-event buffers do not survive reload. Multiplayer, extreme histories and every class/resolution combination are not independently certified.

See the bundled README, credits and font/artwork notices. The original addon and FieldKit remain independent.
