# In-addon storage lifecycle (.11-dev)

The current candidate makes format-2 shared storage the default only when all three existing roots and the new safety root are absent. An existing database or catalogue is never silently converted. A deliberately selected classic profile remains classic after reload.

The additional `AzerothStatsRebornStorageSafety` global is declared in the same addon TOC and physical SavedVariables file. It is an internal recovery journal, not an independent external backup. No filesystem, shell, network or saved-code evaluation API is used by the runtime. The older offline conversion helper is maintenance tooling, not a player prerequisite.

## State machine

`PrepareStorageChange` validates the active DB and all source checkpoints, proves their shared representation/export, records the source catalogue signature and stores a bounded, exact wire snapshot of the catalogue roots. The active DB and source roots remain unchanged. Replacing an existing completed safety copy requires its current review token.

The prepared journal blocks backup creation, restoration's prerequisite snapshot, deletion and manual cleanup. The running statistics observer remains active. The journal must be loaded from SavedVariables during a later module initialization; calling InitDB again in the same session cannot satisfy the reload barrier. Source signatures include the deterministic native 16-digit projection for classic catalogues, so a newly created automatic checkpoint can migrate without losing its pre-save precision.

`ApplyStorageChange` requires the persisted proof, an unchanged source and a valid target. It swaps only the two catalogue roots, then marks the journal applied and requests another UI reload. On startup the addon verifies the saved target against the expected exact format-2 payload or the classic format's native numeric projection. Only then is the change complete and backup writing resumed. Initialization/collection never automatically commits a prepared change.

Cancellation keeps the current validated source catalogues. Integrity failure leaves the journal and target intact for explicit recovery. Recovering a persisted safety copy restores only its catalogue roots, not the current statistics database or native game. All later checkpoints remain included when converting the current store back to classic; recovering the earlier safety snapshot is a distinct, reviewed action that can replace newer checkpoints.

The lossless safety payload survives classic numeric rounding. Classic export itself follows the old client's numeric precision. Retained safety data uses extra space until the user explicitly removes it. Removing a complete copy validates the current catalogues first and changes no backup/statistics root. A malformed safety copy can be explicitly discarded only after the current catalogues validate completely; it is never automatically overwritten.

## UI and validation

The themed dialog is accessible from the existing backup manager and `/azstatsr storage`. All ordinary actions and explanations are in French/English. Standard Stats widget constructors preserve theme repaint, opacity, fonts and modal ordering. Confirmation clicks precede copy replacement, recovery and removal. ReloadUI is allowlisted only for this persistence dialog and the existing UI module.

`tools/verify_reborn_storage_lifecycle.py` uses synthetic profiles and fresh Lua VMs with native 16-significant-digit save/reloads. It covers new installation, untouched old profiles, both reload barriers, writes blocked during review, unchanged active DB, source drift/cancellation, all-checkpoint rollback including newer captures, exact safety recovery, malformed copies, stale proofs, actual dialog callbacks and FR/EN across five themes. The native UI recipe remains pending for this candidate; prior `.10-dev` persistence acceptance does not certify this new workflow.
