"""Explicit closed-client shared-backup migration/rollback. Dry-run by default.

Never opens network connections. Source files and independent safety copies are
private local artifacts, never CI inputs or repository assets.
"""

import argparse
from datetime import datetime, timezone
import hashlib
import json
import os
from pathlib import Path
import subprocess

from reborn_storage_io import ROOT, ROOTS, bind, dump, load, runtime, transform


def game_closed():
    if os.name == "nt":
        result = subprocess.run(
            [
                "powershell",
                "-NoProfile",
                "-Command",
                "if (Get-Process -Name AzerothSurvivorsGame -ErrorAction SilentlyContinue) {exit 1}",
            ],
            capture_output=True,
        )
        if result.returncode != 0:
            raise RuntimeError(
                "Close Azeroth Survivors Reborn completely before applying"
            )
    else:
        proc = Path("/proc")
        if not proc.exists():
            raise RuntimeError("Cannot verify closed client on this platform")
        for path in proc.glob("[0-9]*/comm"):
            try:
                if path.read_text().strip().lower().startswith("azerothsurviv"):
                    raise RuntimeError(
                        "Close Azeroth Survivors Reborn completely before applying"
                    )
            except (FileNotFoundError, PermissionError):
                pass


def digest(data):
    return hashlib.sha256(data).hexdigest()


def safety_copy(source, raw, parent):
    source, parent = source.resolve(), parent.resolve()
    if parent == source.parent or parent.is_relative_to(source.parent):
        raise RuntimeError("Safety copy must be outside the live save directory")
    folder = parent / datetime.now(timezone.utc).strftime("%Y%m%dT%H%M%S%fZ")
    folder.mkdir(parents=True, exist_ok=False)
    files = {source.name: raw}
    previous = source.with_suffix(".lua.bak")
    if previous.exists():
        files[previous.name] = previous.read_bytes()
    previous_addon = ROOT / "build/AzerothStatsReborn-0.1.0-reborn.8-dev.zip"
    if previous_addon.exists():
        files[previous_addon.name] = previous_addon.read_bytes()
    manifest = []
    for name, data in files.items():
        dest = folder / name
        dest.write_bytes(data)
        assert dest.read_bytes() == data
        manifest.append({"name": name, "bytes": len(data), "sha256": digest(data)})
    (folder / "manifest.json").write_text(
        json.dumps({"source": str(source), "files": manifest}, indent=2) + "\n",
        encoding="utf8",
    )
    return folder


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--source", required=True, type=Path)
    parser.add_argument(
        "--mode", choices=("migrate", "rollback", "verify"), default="migrate"
    )
    parser.add_argument("--output", type=Path)
    parser.add_argument("--report", type=Path)
    parser.add_argument("--safety-root", type=Path)
    parser.add_argument("--apply", action="store_true")
    args = parser.parse_args()
    source = args.source.resolve(strict=True)
    raw = source.read_bytes()
    lua = runtime()
    env = load(lua, raw)
    bind(lua, env)
    a = lua.globals().AzerothStatsReborn
    codec = a.SharedCodec
    assert a.ValidateDatabase(env[ROOTS[0]]), "live database validation failed"
    before = dump(lua, env)
    if args.mode == "verify":
        assert a.SharedBackupsEnabled(), "source is not shared storage"
        roots = a.ValidateSharedBackups(env[ROOTS[1]], env[ROOTS[2]])
        assert roots is not None and not isinstance(
            roots, tuple
        ), "shared integrity check failed"
        # Every checkpoint is reconstructed and validated, not merely counted.
        legacy, _ = transform(lua, env, rollback=True)
        roundtrip, decoded = transform(lua, load(lua, legacy))
        assert codec.sameData(decoded[ROOTS[0]], env[ROOTS[0]])
        encoded = raw
    else:
        encoded, converted = transform(lua, env, rollback=args.mode == "rollback")
        assert codec.sameData(converted[ROOTS[0]], env[ROOTS[0]]), "active DB changed"
        # Prove both directions before any live write.
        returned, returned_env = transform(
            lua, converted, rollback=args.mode == "migrate"
        )
        if args.mode == "migrate":
            for name in ROOTS[1:]:
                original = env[name]
                if original is not None and original.schema == 2:
                    assert codec.sameData(
                        original, returned_env[name]
                    ), "legacy catalogue rollback mismatch"
    assert source.read_bytes() == raw, "source changed during preparation"
    report = {
        "mode": args.mode,
        "sourceBytes": len(raw),
        "canonicalSourceBytes": len(before),
        "candidateBytes": len(encoded),
        "activeDatabaseUnchanged": True,
        "allCheckpointsValidated": True,
        "rollbackVerified": True,
        "applied": False,
        "nativeSerializerRoundtripObserved": False,
    }
    if args.output:
        output = args.output.resolve()
        if output == source:
            raise RuntimeError("Use --apply for live replacement")
        output.parent.mkdir(parents=True, exist_ok=True)
        output.write_bytes(encoded)
    if args.apply:
        assert (
            args.mode != "verify" and args.safety_root
        ), "Apply requires migration/rollback and an independent safety root"
        assert source.name == "AzerothStatsReborn.lua", "Unexpected save filename"
        if args.mode == "migrate" and len(encoded) >= len(before):
            raise RuntimeError(
                "No shared-storage reduction on equivalent serialization; source unchanged"
            )
        game_closed()
        folder = safety_copy(source, raw, args.safety_root)
        assert source.read_bytes() == raw, "source changed before replacement"
        temporary = source.with_suffix(".lua.storage-pending")
        with temporary.open("xb") as handle:
            handle.write(encoded)
            handle.flush()
            os.fsync(handle.fileno())
        assert temporary.read_bytes() == encoded
        load(lua, temporary.read_bytes())
        game_closed()
        assert source.read_bytes() == raw, "source changed before atomic replacement"
        os.replace(temporary, source)
        assert source.read_bytes() == encoded
        report["applied"] = True
        report["safetyDirectory"] = str(folder)
    if args.report:
        args.report.parent.mkdir(parents=True, exist_ok=True)
        args.report.write_text(json.dumps(report, indent=2) + "\n", encoding="utf8")
    print(json.dumps(report, ensure_ascii=False))


if __name__ == "__main__":
    main()
