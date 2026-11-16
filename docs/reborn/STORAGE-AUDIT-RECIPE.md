# Reborn storage audit recipe — read-only

Candidate `.8-dev` adds only a diagnostic command to the validated `.7-dev` backup system. It performs no migration or compression. Research models are not loaded in the game.

1. Load the updated addon with `/reload`, then check the existing history and backup manager still display normally.
2. Run `/azstatsr storage` to inspect the existing catalogue counts.
3. Run `/azstatsr shared audit`. Review retained-run count and manual/automatic checkpoint counts, run copies, distinct/repeated/missing IDs. Check FR/EN output according to the selected addon language. No run IDs, names or contents are printed.
4. Compare the counts with the backup manager. Repeated IDs can represent edited versions; they do not prove byte-identical data or a compression percentage.
5. Run `/reload` and repeat the audit. Normal tracking and automatic backups can legitimately change counts during play; this is not evidence of an audit mutation.
6. If it reports an incomplete audit, keep only the diagnostic message. Do not edit or repair saved files manually.

No deletion, restoration or cleanup is needed for this recipe. The existing backup controls remain available during runs; full-reset/restoration next-run collection behavior is unchanged.

Offline verification proves that audit/help calls leave all three logical roots and their contents unchanged, including absent roots. Real client file-size/hash comparisons require a controlled disposable profile and full client shutdown; normal save activity can otherwise change them. Those measurements and durable migration acceptance are outside this read-only candidate.
