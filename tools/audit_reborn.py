"""Read-only static compatibility inventory. No client launch or SavedVariables reads."""

from pathlib import Path
import argparse, hashlib, json, re, subprocess, datetime

p = argparse.ArgumentParser()
p.add_argument("--game", type=Path, required=True)
a = p.parse_args()
root = Path(__file__).resolve().parents[1]
addon = root / "AzerothStats"
out = root / "docs/reborn"
out.mkdir(parents=True, exist_ok=True)
mods = [
    s.strip()
    for s in (addon / "AzerothStats.toc").read_text(encoding="utf8").splitlines()
    if s.strip().endswith(".lua")
]


# Preserve strings for fixed dynamic-reader names; strip Lua comments only.
def clean(s):
    # Tokenize strings first: '--' inside a quoted label is not a comment.
    token = re.compile(
        r""""(?:\\.|[^"\\])*"|'(?:\\.|[^'\\])*'|\[(=*)\[.*?\]\1\]|--\[(=*)\[.*?\]\2\]|--[^\n]*""",
        re.S,
    )
    return token.sub(
        lambda m: (
            re.sub(r"[^\n]", " ", m.group())
            if m.group().startswith("--")
            else m.group()
        ),
        s,
    )


used = {}
events = {}
modules = []
host = {}
for name in mods:
    raw = (addon / name).read_text(encoding="utf8")
    s = clean(raw)
    modules.append(
        {
            "file": name,
            "lines": len(raw.splitlines()),
            "sha256": hashlib.sha256(raw.encode()).hexdigest(),
        }
    )
    for pattern, target in [
        (r"\bAZS_[A-Za-z0-9_]+\b", used),
        (
            r"(?<![.:\w])(?:Get|Unit|Create|Play|Set|Send|Register|Cast|Target|Equip|Pickup|Show|Hide|Clear|Is)[A-Z][A-Za-z0-9_]*\b",
            host,
        ),
    ]:
        for m in re.finditer(pattern, s):
            symbol = m.group()
            target.setdefault(symbol, []).append(
                {"file": name, "line": s[: m.start()].count("\n") + 1}
            )
    for m in re.finditer(r'RegisterEvent\(\s*["\']([^"\']+)', s):
        events.setdefault(m.group(1), []).append(name)
    if name == "Core.lua":
        block = re.search(r"for _, eventName in ipairs\(\{(.*?)\}\)", s, re.S)
        if block:
            for event in re.findall(r'"([A-Z_]+)"', block.group(1)):
                events.setdefault(event, []).append(name)
# The native core owns raw tables, while the compatibility addon defines readers.
base = a.game / "Interface/AddOns"
native = (
    list((base / "AzerothSurvivorsAPI").glob("*.lua"))
    + list((base / "AzerothSurvivors").glob("*.lua"))
    + [base / "AzerothSurvivors/Generated/Content.lua"]
)
definitions = {}
references = {}
hashes = {}
for path in native:
    raw = path.read_text(encoding="utf8")
    s = clean(raw)
    rel = path.relative_to(base).as_posix()
    hashes[rel] = hashlib.sha256(path.read_bytes()).hexdigest()
    for m in re.finditer(r"\bAZS_[A-Za-z0-9_]+\b", s):
        references.setdefault(m.group(), set()).add(rel)
    for m in re.finditer(r"(?:function\s+)(AZS_\w+)\s*\(|\b(AZS_\w+)\s*=", s):
        definitions.setdefault(m.group(1) or m.group(2), set()).add(rel)
rows = []
for name, sites in sorted(used.items()):
    defined = sorted(definitions.get(name, []))
    mentioned = sorted(references.get(name, []))
    rows.append(
        {
            "symbol": name,
            "kind": (
                "function"
                if re.match(r"AZS_(Get|Set|Register|Unregister|Project|Is|Open)", name)
                else "data"
            ),
            "sites": sites,
            "nativeDefinitions": defined,
            "nativeReferences": mentioned,
            "status": (
                "declared"
                if defined
                else (
                    "native-reference-only"
                    if mentioned
                    else "not-found-in-installed-Lua"
                )
            ),
        }
    )
report = {
    "sourceCommit": subprocess.check_output(
        ["git", "rev-parse", "HEAD"], cwd=root, text=True
    ).strip(),
    "sourceVersion": "2.0.4",
    "generatedUTC": datetime.datetime.now(datetime.timezone.utc).isoformat(),
    "modules": modules,
    "api": rows,
    "hostCalls": [
        {
            "symbol": k,
            "sites": v,
            "status": "host-contract; not proved by static Lua search",
        }
        for k, v in sorted(host.items())
    ],
    "literalEvents": events,
    "nativeFiles": hashes,
    "scope": "All TOC-loaded runtime modules; Lua/static presence is not semantic or live compatibility. C functions and computed exports may lack literal definitions.",
}
report["nativeFunctionCandidatesNotReferenced"] = sorted(
    k
    for k in definitions
    if k not in used
    and re.match(
        r"AZS_(Get|Set|Create|Release|Register|Project|Unregister|Is|Open|API_)", k
    )
)
report["hostScope"] = (
    "Identifier candidates, including functions passed to A.Call/pcall/getglobal. Methods on frames are host UI contracts, not AZS exports. Not a live execution guarantee."
)
(out / "API-INVENTORY.json").write_text(
    json.dumps(report, ensure_ascii=False, indent=2) + "\n", encoding="utf8"
)
print(
    json.dumps(
        {
            "modules": len(modules),
            "lines": sum(x["lines"] for x in modules),
            "azsSymbols": len(rows),
            "hostCalls": len(host),
            "literalEvents": len(events),
            "nativeLuaFiles": len(native),
        },
        ensure_ascii=False,
    )
)
print(
    "NOT FOUND:",
    ",".join(r["symbol"] for r in rows if r["status"] == "not-found-in-installed-Lua"),
)
print("FUNCTIONS:", ",".join(r["symbol"] for r in rows if r["kind"] == "function"))
