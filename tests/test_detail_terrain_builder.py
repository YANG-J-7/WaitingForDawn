"""地形合成工具测试；所有纯色与梯度均为测试夹具，不用于游戏美术。"""

import sys
import unittest
from pathlib import Path

import numpy as np
from PIL import Image

sys.dont_write_bytecode = True
sys.path.insert(0, str(Path(__file__).resolve().parents[1] / "tools"))
from build_detail_terrain import regions, stitch


class TerrainBuilderTests(unittest.TestCase):
    def test_vertical_overlap_preserves_exact_source(self):
        pixels = np.arange(8 * 20 * 3, dtype=np.uint16).reshape(8, 20, 3).astype(np.uint8)
        first = Image.fromarray(pixels[:, :12])
        second = Image.fromarray(pixels[:, 8:])
        np.testing.assert_array_equal(np.asarray(stitch(first, second, 4)), pixels)

    def test_horizontal_overlap_preserves_exact_source(self):
        pixels = np.arange(20 * 8 * 3, dtype=np.uint16).reshape(20, 8, 3).astype(np.uint8)
        np.testing.assert_array_equal(np.asarray(stitch(Image.fromarray(pixels[:12]), Image.fromarray(pixels[8:]), 4, True)), pixels)

    def test_unmatched_edges_keep_untouched_outer_content(self):
        first = Image.new("RGB", (20, 12), (20, 30, 40))
        second = Image.new("RGB", (20, 12), (90, 80, 70))
        result = np.asarray(stitch(first, second, 8))
        self.assertEqual(result.shape, (12, 32, 3))
        np.testing.assert_array_equal(result[:, :12], np.asarray(first)[:, :12])
        np.testing.assert_array_equal(result[:, -12:], np.asarray(second)[:, -12:])
        mixed = (result[:, :, 0] != 20) & (result[:, :, 0] != 90)
        self.assertLessEqual(mixed.sum(), 12 * 4)

    def test_invalid_overlap_rejected(self):
        for overlap in [0, -1, 21]:
            with self.assertRaises(ValueError):
                stitch(Image.new("RGB", (20, 12)), Image.new("RGB", (20, 12)), overlap)

    def test_mismatched_dimensions_rejected(self):
        with self.assertRaises(ValueError):
            stitch(Image.new("RGB", (20, 12)), Image.new("RGB", (20, 11)), 4)

    def test_four_reference_regions_cover_canvas(self):
        expected = [(0, 0, 900, 534), (772, 0, 1672, 534), (0, 406, 900, 941), (772, 406, 1672, 941)]
        self.assertEqual(regions((1672, 941)), expected)


if __name__ == "__main__":
    unittest.main()
