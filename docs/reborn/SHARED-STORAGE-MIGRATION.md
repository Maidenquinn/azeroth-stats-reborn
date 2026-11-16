# Shared backup migration — experimental opt-in

Candidate `.10-dev` can read/write explicit shared backup references. Existing profiles remain on the legacy format until a closed-client migration is explicitly applied. This is not a stable release or automatic upgrade. The `.9-dev` format-1 candidate is withdrawn after a failed native-client recipe.

## Format and safeguards

The active `AzerothStatsRebornDB` remains a full independent database. The manual backup root uses schema 3, format 2 and holds a data-only encoded payload containing both catalogues, an immutable version pool and checksums; the automatic root is an ownership marker. The three globals remain in the same existing physical SavedVariables file. Numbers inside immutable checkpoints are encoded as exact integer or dyadic mantissa/exponent strings. A bounded data-only parser reconstructs them without evaluating Lua code. This prevents the native SavedVariables writer from rounding backup payload numbers. The active database still follows normal client persistence. Run versions are reused only after full structural equality, never just matching IDs/dates/checksums. Each checkpoint independently freezes all non-run database fields, including settings, totals, pruned lifetime ledgers and extensions. Manual/automatic IDs, timestamps and next-ID counters are retained.

Restore reconstructs a new full database, validates it and uses the existing Reborn restore controller/safety backup. Old observers are detached only after successful initialization; current-run exclusion/resumption remains unchanged. Retention and deletion collect versions only when no remaining checkpoint uses them. Writes use copy-on-write maps and install a new validated root only after the operation succeeds. Corruption, partial root pairs and unknown metadata fail closed rather than falling back to a fresh empty legacy catalogue.

Checksums detect accidental damage; they are not cryptographic authentication. Per-checkpoint database and overall store limits remain bounded. New small profiles can have more overhead than legacy backups; the migration tool refuses an applied conversion without a reduction under equivalent serialization.

## Closed-client procedure

1. Fully close Reborn. Preserve the prior addon ZIP. Locate the actual `AzerothStatsReborn.lua` under the game's `WTF/Account/.../SavedVariables` directory; this file contains all three roots.
2. Install the `.10-dev` addon while closed. Do not open an older addon against schema-3 backups: first export them back to legacy format as described below.
3. Preview against a copy or the closed-client source:

```powershell
python tools/migrate_reborn_storage.py --source 'PATH/AzerothStatsReborn.lua' --output 'PRIVATE/shared-preview.lua' --report 'PRIVATE/preview.json'
```

The tool validates every checkpoint and a complete rollback before producing the candidate. The active database must be structurally unchanged. `canonicalSourceBytes` and `candidateBytes` use the same serializer; the original file's formatting can otherwise distort the savings calculation. This is not yet a measurement of the game's own writer.

4. Apply only with the game closed:

```powershell
python tools/migrate_reborn_storage.py --source 'PATH/AzerothStatsReborn.lua' --apply --safety-root 'INDEPENDENT-SAFETY-DIRECTORY' --report 'PRIVATE/applied.json'
```

The safety directory must be outside the live save directory. The tool copies the source and existing `.lua.bak`, records lengths/SHA-256, and retains the old `.8-dev` ZIP if available locally. It refuses changed input or a running client. A verified temporary candidate is atomically renamed over the source; old `.bak` files are not removed. Keep the safety directory independent of the game installation.

5. Start Reborn. Check `/azstatsr shared audit` and the backup manager. Compare both catalogue counts. Test a new manual backup on a disposable profile; test restoration on an isolated copy before touching any wanted progress. Then fully close the client so its native writer persists the format.
6. Verify the native-written file after shutdown:

```powershell
python tools/migrate_reborn_storage.py --source 'PATH/AzerothStatsReborn.lua' --mode verify --report 'PRIVATE/native-verification.json'
```

This validates integrity and reconstructs every checkpoint. The caller must separately establish that a real client start/save/shutdown occurred; a successful offline serializer test does not prove that. Record actual native-written byte length and startup/backup latency before judging real gains. Large 90–100 MB profiles and browser-client performance remain separate acceptance work.

## Roll back without losing newer backups

Close the client, then export **all current** shared checkpoints, including those created after migration:

```powershell
python tools/migrate_reborn_storage.py --source 'PATH/AzerothStatsReborn.lua' --mode rollback --output 'PRIVATE/rollback-preview.lua' --report 'PRIVATE/rollback-preview.json'
python tools/migrate_reborn_storage.py --source 'PATH/AzerothStatsReborn.lua' --mode rollback --apply --safety-root 'INDEPENDENT-SAFETY-DIRECTORY'
```

Only after the file is back in legacy format may the previous addon ZIP be restored. The active database remains unchanged by export. If integrity is damaged so export cannot safely reconstruct checkpoints, keep the failed file separately and recover the entire original SavedVariables file from its verified external safety copy. Never repair pool references or overwrite only one of the coupled logical roots manually.

## Validation scope

`tools/verify_reborn_shared_storage.py` tests migration, live manual/automatic backups, immutable versions, retention/deletion/GC, stale cleanup, current-run restoration safety, corruption and partial roots, serializer parity, rollback preserving newer checkpoints and the pinned `.8-dev` legacy decoder. Local verification also uses the preserved full `.8-dev` addon ZIP. All CI inputs are synthetic. The user's real file is tested only on private local copies; no saved contents, identifiers or safety copies enter Git or CI.

## Format-1 incident and recovery

The `.9-dev` native recipe exposed a checksum failure after creating a checkpoint. The native-written file retained the old and new checkpoint data, but new payload numeric literals were limited to 16 significant digits. The offline writer previously used 17. The older checkpoints matched their original authenticated copies; the new checkpoint's numeric checksums could not be authenticated after native persistence. The fail-closed catalogue then appeared empty in the UI. This was not a successful acceptance test.

Format 2 keeps exact checkpoint numbers within the string payload and uses portable dyadic fingerprints, removing dependence on decimal printf behavior. Regression tests reproduce numeric rounding and check exact backup values after simulated native save/reload; malformed wire data, duplicate keys, truncation and trailing input are rejected. Native creation/restart acceptance remains required.

Never bypass integrity or reseal an unverified format-1 checkpoint. Preserve the entire failed file and previous addon first. Recovery may use only individually authenticated checkpoints compared with the independent pre-migration copy, while retaining the current valid active database. Keep any unauthenticated newer checkpoint separately for diagnosis; do not silently certify it. This is an explicit local recovery operation, not an automatic in-game repair path.
