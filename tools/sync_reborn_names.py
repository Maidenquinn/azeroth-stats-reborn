"""Extract canonical labels only (no game code/assets) from the installed public content."""

from pathlib import Path
import argparse, json, hashlib
from lupa.lua51 import LuaRuntime

p = argparse.ArgumentParser()
p.add_argument("--game", type=Path, required=True)
args = p.parse_args()
root = Path(__file__).resolve().parents[1]
base = args.game / "Interface/AddOns/AzerothSurvivors"
lua = LuaRuntime(unpack_returned_tuples=True)
lua.execute((base / "Generated/Content.lua").read_text(encoding="utf8"))
gen = lua.globals().AZS_GEN
english = {}
for group, prefix in [
    ("classes", "class"),
    ("zones", "zone"),
    ("jewels", "jewel"),
    ("amulets", "amulet"),
]:
    for _, row in gen[group].items():
        if row["key"] and row["name"]:
            english[f"{prefix}.{row['key']}.name"] = row["name"]
for _, zone in gen.zones.items():
    for index, boss in zone["bosses"].items():
        english[f"boss.{zone['key']}.{index}.name"] = boss["name"]
for _, rows in gen.spells.items():
    for _, row in rows.items():
        english[f"ability.{row['key']}.name"] = row["name"]
result = {
    "schema": 1,
    "scope": "Canonical labels only; public installed game content, not player saves or gameplay logic.",
    "languages": {"en": english},
    "sources": {},
}
for code in [
    "deDE",
    "frFR",
    "esES",
    "ptBR",
    "ruRU",
    "itIT",
    "plPL",
    "trTR",
    "jaJP",
    "zhCN",
    "koKR",
]:
    lang = code[:2]
    lua.execute(
        "WORDS={};function AZS_LocaleStrings(code,dict) for k,v in pairs(dict) do WORDS[k]=v end end"
    )
    files = sorted(base.glob("Locale_" + code + "*.lua")) + sorted(
        (base / "Generated").glob("Content_" + code + "*.lua")
    )
    for file in files:
        lua.execute(file.read_text(encoding="utf8"))
        result["sources"][file.relative_to(base).as_posix()] = hashlib.sha256(
            file.read_bytes()
        ).hexdigest()
    result["languages"][lang] = {
        k: lua.globals().WORDS[v] or v for k, v in english.items()
    }
result["sources"]["Generated/Content.lua"] = hashlib.sha256(
    (base / "Generated/Content.lua").read_bytes()
).hexdigest()
(root / "data/reborn-names.json").write_text(
    json.dumps(result, ensure_ascii=False, indent=2, sort_keys=True) + "\n",
    encoding="utf8",
)
print(len(english), "canonical names;", len(result["languages"]), "languages")
