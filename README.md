# Azeroth Stats Reborn

Dedicated port of [Azeroth Stats](https://github.com/Maidenquinn/AzerothStats) for **Azeroth Survivors Reborn**.

**Status: first Reborn development candidate implemented; live-client acceptance pending. No stable player release.**
`AzerothStats/` contains shared runtime modules and optional extension hooks. `reborn/Reborn.lua` adapts the native Reborn contracts. `python tools/build_reborn.py` produces a fully namespaced `build/AzerothStatsReborn/` addon and deterministic ZIP. Never install the shared source folder as the Reborn port.

## Development

- `main`: reviewed development baseline for the Reborn port.
- `codex/*`: scoped development branches, reviewed through pull requests.
- `origin`: this dedicated Reborn repository.
- `original`: original Azeroth Stats reference; local pushes are disabled.
- `stats-reference` and FieldKit stay separate. Original history and player saves are never merged automatically.

The CI runs on pushes, pull requests and manual dispatch. It verifies the inherited offline suite, generated assets, formatting, security policy, storage benchmarks and packaging baseline. These checks do **not** claim Reborn runtime compatibility. Local probes additionally execute installed Reborn API Lua; the client sources are not redistributed or available on hosted CI.

The original game-specific publication workflows have been removed. The Reborn candidate workflow creates a review ZIP without publishing a player release. Player publication follows successful live-client acceptance. Like FieldKit, a candidate build and player publication are separate steps; no automatic player release is configured.

## Audit and port plan

- [Compatibility audit](docs/reborn/AUDIT.md)
- [Implementation and acceptance plan](docs/reborn/PORT-PLAN.md)
- [API inventory](docs/reborn/API-INVENTORY.json)
- [Installed API probes](docs/reborn/PROBES.json)
- [Original project documentation](docs/reborn/ORIGINAL-README.md)

Run `python -m pip install -r requirements-dev.txt`, then `python tools/checks.py` for baseline validation.
The game-path-dependent audit commands are documented in the audit.

See [implementation and recipe status](docs/reborn/IMPLEMENTATION.md) for completed work, limitations and reproduction commands.
