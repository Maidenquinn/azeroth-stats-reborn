# Shared backup research on Reborn

Scope agreed with the owner: port the read-only audit and isolated research tests first. No native migration, compression, shared SavedVariables root or legacy cleanup is enabled.

`upstream/` contains immutable copies from the original AzerothStats research branch at commit `42d79130d3d50c24a6515114fc035a0473c02d41`. `provenance.json` records the source repository, paths and SHA-256 hashes. The runner verifies every hash before executing the tests. The upstream acceptance documents describe future migration gates; they are not evidence that migration is implemented in Reborn.

The player package contains only `reborn/RebornStorageAudit.lua`, adapted from the upstream audit. It reports retained runs and per-catalogue checkpoint/run-copy/ID counts in FR/EN. Repeated IDs are candidates, not proven duplicate content. Sparse lists, metatables, malformed data and scan budgets produce an incomplete result. It does not initialize missing roots, clone saves, create backups, restore, prune or estimate file savings.

Run:

```powershell
python tools/verify_reborn_storage_research.py
```

The runner reuses the generated-runtime synthetic harness, then loads the pinned research modules into an isolated Lua 5.1 process. Original addon namespace references are replaced with the Reborn namespace in memory only. It exercises original versioning/restoration/corruption/GC/migration-journal contracts, 100/500/1000-run fixtures and the Python surrogate model. Reborn-specific cases verify native run IDs, the game marker, interrupted/partial observations, reset masks, reset exclusion settings, native loadouts/segments, historical ledgers and disjoint manual/automatic IDs.

`build/reborn-storage-research-validation.json` reports the tests and synthetic Lua-serialization proxy sizes. These are backup-only synthetic measurements, not real SavedVariables byte savings. The active database would remain separate and unchanged in a future shared design.

Research files are excluded from the player ZIP and TOC. Tests assert the three existing SavedVariables roots, no model loaded before research execution, unchanged root pointers/content after audit, no private identifiers in command output, and no implicit migration through an unsupported command.

Before considering a real shared engine, implement and validate an opt-in durable migration against the actual Reborn serializer, startup/session boundaries, interruption recovery, large-save memory/time budgets and rollback. Original-client rules requiring a between-run interval cannot be copied blindly to Reborn; the validated `.7-dev` live backup/restore/cleanup behavior must be preserved.
