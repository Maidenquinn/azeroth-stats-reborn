"""Build the isolated Reborn addon from shared modules and explicit Reborn adapters."""

from pathlib import Path
import argparse, hashlib, json, re, zipfile
from package_policy import public_files
from build_reborn_run_images import build as zone_images, recipe as zone_image_recipe
from security_review import tokens, FORBIDDEN

ROOT = Path(__file__).resolve().parents[1]
VERSION = "0.1.0-reborn.1"
NAME = "AzerothStatsReborn"


def lua_literal(value):
    if isinstance(value, dict):
        return (
            "{\n"
            + "".join(
                "[" + json.dumps(k, ensure_ascii=False) + "]=" + lua_literal(v) + ",\n"
                for k, v in sorted(value.items())
            )
            + "}"
        )
    return json.dumps(value, ensure_ascii=False)


def build(output=ROOT / "build"):
    source = ROOT / "AzerothStats"
    target = output / NAME
    target.mkdir(parents=True, exist_ok=True)
    files = {}
    expected = dict(
        (line.split("  ", 1)[1], line.split("  ", 1)[0])
        for line in (source / "SHA256SUMS.txt").read_text().splitlines()
    )
    for name in public_files(source):
        data = (source / name).read_bytes()
        assert hashlib.sha256(data).hexdigest() == expected[name], (
            "shared source manifest drift",
            name,
        )
        dest = name.replace("AzerothStats", NAME)
        if Path(name).suffix in {".lua", ".toc", ".md"}:
            text = (
                data.decode("utf8")
                .replace("\r\n", "\n")
                .replace("AzerothStats", NAME)
                .replace("Azeroth Stats", "Azeroth Stats Reborn")
                .replace("/azstats", "/azstatsr")
                .replace('"AZEROTHSTATS"', '"AZEROTHSTATSREBORN"')
                .replace("AZEROTH STATS", "AZEROTH STATS REBORN")
                .replace("SLASH_AZEROTHSTATS", "SLASH_AZEROTHSTATSREBORN")
                .replace("SlashCmdList.AZEROTHSTATS", "SlashCmdList.AZEROTHSTATSREBORN")
            )
            if name == "Util.lua":
                text = re.sub(
                    r'version = "[^"]+"', f'version = "{VERSION}"', text, count=1
                )
            if name.endswith(".toc"):
                text = re.sub(r"## Version: .*", f"## Version: {VERSION}", text)
                text = text.replace(
                    "## Author:", "## Dependencies: AzerothSurvivorsAPI\n## Author:"
                )
                text = text.replace(
                    "## SavedVariables: AzerothStatsRebornDB, AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup",
                    "## SavedVariables: AzerothStatsRebornDB, AzerothStatsRebornBackup, AzerothStatsRebornAutoBackup, AzerothStatsRebornStorageSafety",
                )
                text = text.replace(
                    "Core.lua",
                    "RebornNames.lua\nReborn.lua\nRebornFixes.lua\nRebornStorageAudit.lua\nRebornSharedCodec.lua\nRebornSharedWire.lua\nRebornSharedStorage.lua\nRebornStorageLifecycle.lua\nRebornStorageUI.lua\nCore.lua",
                )
            if name == "Core.lua":
                text = text.replace(
                    '"Combat Intelligence",',
                    '"Combat Intelligence",\n "Reborn", "RebornWindow", "RebornSegments",',
                )
            if name in {"Core.lua", "V2UI.lua"}:
                text = text.replace(
                    '{ "kills", "gold", "level", "damage", "healing", "taken" }',
                    '{ "kills", "gold", "level", "damage", "healing", "taken", "recentDps", "recentHps" }',
                )
            if name == "V2UI.lua":
                text = text.replace(
                    '{ "Combat Intelligence", "Combat Intelligence" },',
                    '{ "Combat Intelligence", "Combat Intelligence" },\n'
                    + "\n".join(
                        '{ "Reborn:%d", "Reborn · %d s" },' % (n, n)
                        for n in (5, 15, 30, 60, 120)
                    )
                    + '\n{ "Reborn:segments", "Segments" },\n{ "Reborn:start", "Start segment" },\n{ "Reborn:end", "End segment" },',
                )
            data = text.encode("utf8")
        files[dest] = data
    files["Reborn.lua"] = (
        (ROOT / "reborn/Reborn.lua").read_text(encoding="utf8").encode("utf8")
    )
    files["RebornFixes.lua"] = (
        (ROOT / "reborn/RebornFixes.lua").read_text(encoding="utf8").encode("utf8")
    )
    files["RebornStorageAudit.lua"] = (
        (ROOT / "reborn/RebornStorageAudit.lua")
        .read_text(encoding="utf8")
        .encode("utf8")
    )
    for module in (
        "RebornSharedCodec.lua",
        "RebornSharedWire.lua",
        "RebornSharedStorage.lua",
        "RebornStorageLifecycle.lua",
        "RebornStorageUI.lua",
    ):
        files[module] = (
            (ROOT / "reborn" / module).read_text(encoding="utf8").encode("utf8")
        )
    names = json.loads((ROOT / "data/reborn-names.json").read_text(encoding="utf8"))
    files["RebornNames.lua"] = (
        NAME + ".rebornNames = " + lua_literal(names["languages"]) + "\n"
    ).encode("utf8")
    creatures = json.loads(
        (ROOT / "data/reborn-creature-icons.json").read_text(encoding="utf8")
    )
    files["RebornNames.lua"] += (
        NAME + ".rebornCreatureIcons = " + lua_literal(creatures["names"]) + "\n"
    ).encode("utf8")
    images = zone_images(check=True)
    files["RebornNames.lua"] += (
        NAME + ".rebornZoneImages = " + lua_literal(images) + "\n"
    ).encode("utf8")
    for entry in images.values():
        name = entry["texture"]
        files["media/" + name] = (ROOT / "reborn/media" / name).read_bytes()
    files["IMAGE-CREDITS.md"] = (
        "# Expansion zone illustrations\n\n"
        "Artwork remains copyrighted by its respective owners. "
        "Reborn campaign media and Blizzard press artwork are bundled locally; "
        "no network access occurs in the addon. "
        "Classic image credits are unchanged.\n\n"
        + "\n".join(
            f"- {zone}: {entry['credit']}. Source: {entry['page']}"
            for zone, entry in sorted(zone_image_recipe()["zones"].items())
        )
        + "\n"
    ).encode("utf8")
    files["README.md"] = (
        (ROOT / "reborn/PLAYER-README.md").read_text(encoding="utf8").encode("utf8")
    )
    for name, data in files.items():
        if name.endswith(".lua"):
            for token in tokens(data.decode("utf8")):
                assert (
                    token.kind != "identifier"
                    or token.text not in FORBIDDEN
                    or (
                        name in {"UI.lua", "RebornStorageUI.lua"}
                        and token.text == "ReloadUI"
                    )
                ), (name, token.line, token.text)
    files["SHA256SUMS.txt"] = "".join(
        hashlib.sha256(v).hexdigest() + "  " + k + "\n"
        for k, v in sorted(files.items())
    ).encode()
    # An obsolete generated file must never silently enter the package.
    for path in target.rglob("*"):
        if path.is_file() and path.relative_to(target).as_posix() not in files:
            raise AssertionError(f"Unexpected build file: {path}")
    for name, data in files.items():
        path = target / name
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(data)
    archive = output / f"{NAME}-{VERSION}.zip"
    with zipfile.ZipFile(archive, "w", zipfile.ZIP_DEFLATED, compresslevel=9) as z:
        for name, data in sorted(files.items()):
            info = zipfile.ZipInfo(NAME + "/" + name, (1980, 1, 1, 0, 0, 0))
            info.create_system = 3
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            z.writestr(info, data)
    archive.with_suffix(".zip.sha256").write_text(
        hashlib.sha256(archive.read_bytes()).hexdigest() + "  " + archive.name + "\n"
    )
    print(archive)
    return target


if __name__ == "__main__":
    p = argparse.ArgumentParser()
    p.add_argument("--output", type=Path, default=ROOT / "build")
    args = p.parse_args()
    build(args.output)
