# Azeroth Stats Reborn

Dedicated port of [Azeroth Stats](https://github.com/Maidenquinn/AzerothStats) for **Azeroth Survivors Reborn**.

**Status: API audit complete; port under development. There is no installable Reborn release yet.**
The `AzerothStats/` runtime is the unchanged 2.0.4 baseline, not a Reborn-ready addon.

## Development

- `main`: reviewed development baseline for the Reborn port.
- `codex/*`: scoped development branches, reviewed through pull requests.
- `origin`: this dedicated Reborn repository.
- `original`: original Azeroth Stats reference; local pushes are disabled.
- `stats-reference` and FieldKit stay separate. Original history and player saves are never merged automatically.

The CI runs on pushes, pull requests and manual dispatch. It verifies the inherited offline suite, generated assets, formatting, security policy, storage benchmarks and packaging baseline. These checks do **not** claim Reborn runtime compatibility. Local probes additionally execute installed Reborn API Lua; the client sources are not redistributed or available on hosted CI.

The original game-specific publication workflows have been removed. Reborn candidate packaging and player releases will be enabled after the runtime namespace, build tools and in-client recipe have been ported. Like FieldKit, a candidate build and player publication are separate steps; no automatic player release is configured.

## Audit and port plan

- [Compatibility audit](docs/reborn/AUDIT.md)
- [Implementation and acceptance plan](docs/reborn/PORT-PLAN.md)
- [API inventory](docs/reborn/API-INVENTORY.json)
- [Installed API probes](docs/reborn/PROBES.json)
- [Original project documentation](docs/reborn/ORIGINAL-README.md)

Run `python -m pip install -r requirements-dev.txt`, then `python tools/checks.py` for baseline validation.
The game-path-dependent audit commands are documented in the audit.
