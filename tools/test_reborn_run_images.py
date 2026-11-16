"""Offline regression coverage for complete expansion art and geometric framing."""

import unittest
from PIL import Image, ImageStat
from build_reborn_run_images import ROOT, build, recipe
from build_run_images import framing


class RebornZoneImages(unittest.TestCase):
    def test_complete_reviewed_images_and_aspect(self):
        mapping = build(check=True)
        self.assertEqual(len(mapping), 36)
        data = recipe()
        for zone, entry in data["zones"].items():
            with self.subTest(zone=zone):
                with Image.open(ROOT / "reborn/media" / entry["texture"]) as native:
                    self.assertEqual(native.size, (256, 256))
                    self.assertEqual(native.mode, "RGBA")
                    self.assertGreater(
                        sum(ImageStat.Stat(native.convert("RGB")).stddev), 15
                    )
                l, r, t, b = framing(entry["size"], entry["focus"], data["viewport"])
                width, height = entry["size"]
                self.assertAlmostEqual(
                    (r - l) * width / ((b - t) * height), 178 / 66, places=4
                )
                self.assertTrue(0 <= l < r <= 1 and 0 <= t < b <= 1)


if __name__ == "__main__":
    unittest.main()
