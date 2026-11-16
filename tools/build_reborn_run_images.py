"""Build reviewed official expansion artwork; never downloads at build/runtime."""

import argparse
import hashlib
import io
import json
from pathlib import Path

from PIL import Image
from build_run_images import framing

ROOT = Path(__file__).resolve().parents[1]


def recipe():
    return json.loads(
        (ROOT / "data/reborn-run-image-sources.json").read_text(encoding="utf8")
    )


def build(check=False):
    data = recipe()
    names = json.loads((ROOT / "data/reborn-names.json").read_text(encoding="utf8"))
    known = {
        k.split(".")[1]
        for k in names["languages"]["en"]
        if k.startswith("zone.") and k.endswith(".name")
    }
    classic = set(
        json.loads((ROOT / "data/run-image-sources.json").read_text(encoding="utf8"))[
            "zones"
        ]
    )
    classic |= {"naxxramas", "scholomance"}
    assert set(data["zones"]) == known - classic, "expansion artwork catalogue drift"
    mapping = {}
    for zone, entry in sorted(data["zones"].items()):
        assert entry["texture"] == f"RunZone-Reborn-{zone}.tga"
        source = ROOT / entry["source"]
        assert source.resolve().is_relative_to(
            (ROOT / "design/reborn-run-images").resolve()
        )
        assert hashlib.sha256(source.read_bytes()).hexdigest() == entry["sha256"], zone
        with Image.open(source) as original:
            assert list(original.size) == entry["size"]
            image = original.convert("RGBA").resize(
                (256, 256), Image.Resampling.LANCZOS
            )
        buf = io.BytesIO()
        image.save(buf, format="TGA")
        path = ROOT / "reborn/media" / entry["texture"]
        if check:
            assert path.read_bytes() == buf.getvalue(), zone
        else:
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_bytes(buf.getvalue())
        mapping[zone] = {
            "texture": entry["texture"],
            **dict(
                zip(
                    ("left", "right", "top", "bottom"),
                    framing(entry["size"], entry["focus"], data["viewport"]),
                )
            ),
        }
    print(f"{len(mapping)} Reborn zone illustrations verified")
    return mapping


if __name__ == "__main__":
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    build(parser.parse_args().check)
