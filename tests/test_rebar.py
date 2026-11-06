#!/usr/bin/env python3
"""
REBAR komutlarının senaryo testleri (AutoCAD olmadan, autolisp_sim ile).

Çalıştırma:  python3 tests/test_rebar.py
"""
import os
import sys
import unittest

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from autolisp_sim import Interp, LispError, Sym, static_check  # noqa: E402

BASE = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LSP_FILES = [f for f in os.listdir(BASE) if f.lower().endswith(".lsp")]


def responder(points, answers=None):
    """getpoint isteklerine sıradaki noktayı, diğer isteklere answers'tan
    (istem metninde geçen anahtar -> değer) ya da Enter (None) döndürür."""
    points = list(points)
    answers = answers or {}

    def r(prompt):
        for key, val in answers.items():
            if key in prompt:
                return val
        if "noktas" in prompt.lower():
            return points.pop(0) if points else None
        return None
    return r


def run(cmd, points, answers=None):
    it = Interp(BASE, responder(points, answers))
    it.load_file(os.path.join(BASE, "REBAR-Ana.lsp"))
    it.command(cmd)
    return it


def count(it, kind=None, layer=None):
    return sum(1 for e in it.entities
               if (kind is None or e["type"] == kind) and (layer is None or e["layer"] == layer))


def texts(it):
    return [e["data"][1][0] for e in it.entities if e["type"] == "TEXT"]


def out(it):
    return "".join(it.output)


class StaticTests(unittest.TestCase):
    def test_static(self):
        it = Interp(BASE)
        for f in LSP_FILES:
            with self.subTest(f=f):
                self.assertEqual(static_check(os.path.join(BASE, f), it.builtins), [])


class LoadTests(unittest.TestCase):
    def test_ana_loads_everything(self):
        it = Interp(BASE)
        it.load_file(os.path.join(BASE, "REBAR-Ana.lsp"))
        for c in ["REBAR", "REBAR-FOOTING", "REBAR-COLUMN", "REBAR-WALL", "REBAR-BEAM",
                  "REBAR-SLAB", "REBAR-AYAR", "RT", "RK", "RP", "RB", "RD", "TEMEL",
                  "KOLON", "PERDE", "KIRIS", "DOSEME"]:
            self.assertIsNotNone(it.get(Sym("C:" + c)), c)
        self.assertNotIn("UYARI", out(it))

    def test_each_module_loads_alone(self):
        for f in ["REBAR-Temel.lsp", "REBAR-Kolon.lsp", "REBAR-Kiris.lsp", "REBAR-Doseme.lsp"]:
            with self.subTest(f=f):
                it = Interp(BASE)
                it.load_file(os.path.join(BASE, f))
                self.assertEqual(it.alerts, [])


class CommonChecks:
    def assert_clean(self, it):
        self.assertEqual(it.undo_depth, 0, "undo işaretleri dengesiz")
        self.assertIsNone(it.get(Sym("*ERROR*")), "*error* geri yüklenmedi")
        self.assertEqual(it.vars["CMDECHO"], 1, "CMDECHO geri yüklenmedi")
        self.assertNotIn("REBAR hata", out(it))


class FootingTests(unittest.TestCase, CommonChecks):
    def test_tekil_defaults(self):
        it = run("REBAR-FOOTING", [[0, 0]])
        self.assert_clean(it)
        # 150 cm, paspayı 5, Ø14/15 -> (150-2*5.7)/15 = 9.2 -> 10 çubuk her yönde
        self.assertEqual(count(it, "LINE", "REBAR-FOOTING-BOT"), 20)
        self.assertEqual(count(it, "LINE", "REBAR-FOOTING-TOP"), 0)
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-FOOTING"), 1)
        self.assertEqual(len(it.dims), 2)
        self.assertTrue(any("10%%c14/15" in t for t in texts(it)))
        # Ağırlık: 2 * 10 * 1.40 m * 1.21 kg/m = 33.88 kg
        self.assertIn("TOPLAM: 33.88 kg", out(it))
        self.assertEqual(it.alerts, [])

    def test_radye_two_layers(self):
        it = run("RT", [[100, 100]], {"Temel tipi": "Radye"})
        self.assert_clean(it)
        self.assertGreater(count(it, "LINE", "REBAR-FOOTING-TOP"), 0)
        self.assertEqual(count(it, "LINE", "REBAR-FOOTING-TOP"), count(it, "LINE", "REBAR-FOOTING-BOT"))
        self.assertIn("DASHED", it.tables["LTYPE"])

    def test_warnings(self):
        it = run("RT", [[0, 0]], {"Paspayı": 2.0, "Alt X donatısı aralığı": 40.0})
        self.assert_clean(it)
        self.assertTrue(it.alerts, "uyarı özeti beklenirdi")
        self.assertIn("[UYARI] Paspayı", out(it))

    def test_cancel_point(self):
        it = run("RT", [])
        self.assert_clean(it)
        self.assertEqual(it.entities, [])


class ColumnTests(unittest.TestCase, CommonChecks):
    def test_rect_defaults(self):
        it = run("REBAR-COLUMN", [[0, 0]])
        self.assert_clean(it)
        # 40x60, ρ>=%1 için nx=3 ny=5 -> 2*(3+5)-4 = 12 çubuk
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-COLUMN-BOYUNA"), 12)
        self.assertTrue(any(t.startswith("12%%c16") for t in texts(it)))
        self.assertGreaterEqual(count(it, "LINE", "REBAR-COLUMN-ETRIYE"), 1)  # çirozlar
        self.assertEqual(it.alerts, [], "varsayılan değerler uyarı vermemeli")

    def test_circular(self):
        it = run("RK", [[0, 0]], {"Kolon tipi": "Dairesel"})
        self.assert_clean(it)
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-COLUMN-BOYUNA"), 10)
        self.assertEqual(count(it, "CIRCLE"), 2)

    def test_square(self):
        it = run("KOLON", [[0, 0]], {"Kolon tipi": "Kare"})
        self.assert_clean(it)

    def test_low_ratio_warns(self):
        it = run("RK", [[0, 0]], {"Boyuna donatı çapı": 12, "X yüzündeki": 2, "Y yüzündeki": 2})
        self.assertIn("[UYARI] Boyuna donatı oranı", out(it))

    def test_wall(self):
        it = run("REBAR-WALL", [[0, 0]])
        self.assert_clean(it)
        self.assertEqual(count(it, "LINE", "REBAR-WALL-YATAY"), 2)
        self.assertGreater(count(it, "LWPOLYLINE", "REBAR-WALL-DIKEY"), 0)
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-WALL-DIKEY") % 2, 0)


class BeamTests(unittest.TestCase, CommonChecks):
    def test_defaults(self):
        it = run("REBAR-BEAM", [[0, 0], [500, 0]])
        self.assert_clean(it)
        self.assertEqual(count(it, "LINE", "REBAR-BEAM-BOT"), 1)
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-BEAM-BOT"), 3)   # kesitte 3 çubuk
        self.assertEqual(count(it, "LWPOLYLINE", "REBAR-BEAM-TOP"), 2)
        n_etr = count(it, "LINE", "REBAR-BEAM-ETRIYE")
        self.assertGreater(n_etr, 20)
        xs = sorted(e["data"][10][0][0] for e in it.entities
                    if e["type"] == "LINE" and e["layer"] == "REBAR-BEAM-ETRIYE")
        self.assertAlmostEqual(xs[0], 5.0)
        self.assertAlmostEqual(xs[-1], 495.0)
        self.assertTrue(all(b - a > 0 for a, b in zip(xs, xs[1:])), "etriyeler çakışıyor")

    def test_rotated(self):
        it = run("RB", [[0, 0], [0, 400]])
        self.assert_clean(it)
        line = next(e for e in it.entities if e["layer"] == "REBAR-BEAM-BOT" and e["type"] == "LINE")
        p1, p2 = line["data"][10][0], line["data"][11][0]
        self.assertAlmostEqual(p1[0], p2[0], places=6)   # Y eksenine paralel

    def test_short_beam(self):
        it = run("RB", [[0, 0], [150, 0]])
        self.assert_clean(it)


class SlabTests(unittest.TestCase, CommonChecks):
    def test_cift(self):
        it = run("REBAR-SLAB", [[0, 0]])
        self.assert_clean(it)
        self.assertGreater(count(it, "LINE", "REBAR-SLAB-BOT"), 50)
        self.assertEqual(count(it, "LINE", "REBAR-SLAB-TOP"), 0)

    def test_tek_with_top(self):
        it = run("RD", [[0, 0]], {"Döşeme tipi": "Tek", "Döşeme boyutu - Y": 1200.0,
                                  "Üst donatı ağı": "Evet"})
        self.assert_clean(it)
        self.assertGreater(count(it, "LINE", "REBAR-SLAB-TOP"), 0)
        self.assertIn("tek doğrultulu çalışır", out(it))


class MenuTests(unittest.TestCase, CommonChecks):
    def test_menu_dispatch(self):
        it = run("REBAR", [[0, 0], [400, 0]], {"Eleman seçiniz": "I"})
        self.assert_clean(it)
        self.assertGreater(count(it, "LINE", "REBAR-BEAM-ETRIYE"), 0)

    def test_ayar(self):
        it = run("REBAR-AYAR", [], {"Beton sınıfı": "C30", "Çelik sınıfı": "B500C"})
        self.assertEqual(it.get(Sym("*RB:BETON*")), "C30")
        self.assertEqual(it.get(Sym("*RB:CELIK*")), "B500C")


if __name__ == "__main__":
    unittest.main(verbosity=2)
