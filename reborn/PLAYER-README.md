# Azeroth Stats Reborn — development candidate

Local history and analysis for Azeroth Survivors Reborn. This candidate is for testing; it is not a stable player release.

Install only the `AzerothStatsReborn` folder. The dependency `AzerothSurvivorsAPI` ships with Reborn.
Use `/azstatsr` to open the window. The original `/azstats` and its three saved-variable roots are independent and are never imported automatically.

The Reborn report adds recent 5–120 second damage/healing windows, native loadout observations and campaign/endless context. Gaps and unavailable data remain explicit; missing future endless bosses are never guessed. Combat Intelligence is optional in the analysis settings.

Stats can run with FieldKit. Its compact HUD and minimap button are optional. Stats does not hide or reposition native or FieldKit elements. Five inherited Stats themes are available.

Reports are local observations, not leaderboard-verified results. Reloads lose the game's short recent-event/history buffers. Actual-client acceptance testing is required before release.
