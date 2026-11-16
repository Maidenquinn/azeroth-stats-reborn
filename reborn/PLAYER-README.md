# Azeroth Stats Reborn — development candidate

Local history and analysis for Azeroth Survivors Reborn. This candidate is for testing; it is not a stable player release.

Install only the `AzerothStatsReborn` folder. The dependency `AzerothSurvivorsAPI` ships with Reborn.
Use `/azstatsr` to open the window. The original `/azstats` and its three saved-variable roots are independent and are never imported automatically.

The Reborn report adds recent 5–120 second damage/healing windows, native loadout observations and campaign/endless context. Gaps and unavailable data remain explicit; missing future endless bosses are never guessed. Combat Intelligence is optional in the analysis settings.

Stats can run with FieldKit. Its compact HUD and minimap button are optional. Stats does not hide or reposition native or FieldKit elements. Five inherited Stats themes are available.

Local cleanup and backup creation/restoration/deletion are available during runs. Restoration requires confirmation and keeps a safety backup of the current database. After a full reset or restoration, recording resumes at the next run so current game counters cannot refill or overwrite the cleared/restored history. The game itself is not reset.

`/azstatsr shared audit` prints a read-only storage inventory in French/English. Repeated run IDs are not proof of identical contents. The shared backup engine is experimental and used only by explicitly migrated profiles; existing profiles keep the legacy format. Both formats use the same backup manager. A closed-client migration keeps an independent safety copy and supports exporting all checkpoints back to the older format. Never downgrade the addon against shared-format saves without converting them back first.

Reports are local observations, not leaderboard-verified results. Reloads lose the game's short recent-event/history buffers. Actual-client acceptance testing is required before release.

The experimental `.9-dev` shared format was withdrawn after the native save writer rounded checkpoint numbers and caused integrity rejection. `.10-dev` uses exact encoded backup numbers; native acceptance must be repeated. Keep the external safety copy. Do not bypass integrity checks or downgrade a shared save directly.
