#!/usr/bin/env python3
"""OBLIVION - procedural pixel-art asset generator.

Regenerates every sprite in assets/sprites/ and every tileable texture in
assets/textures/ from code. Deterministic (fixed seeds).

    uv run --with pillow --with numpy python tools/gen_art.py [--preview DIR]

Sprites use hard pixel edges (no antialiasing). Only the soft FX particles
(dust, fog, glow, firefly) use smooth alpha on purpose.
"""
from __future__ import annotations

import argparse
import math
from pathlib import Path

import numpy as np
from PIL import Image, ImageDraw

ROOT = Path(__file__).resolve().parent.parent
SPR = ROOT / "assets" / "sprites"
TEX = ROOT / "assets" / "textures"
SEED = 1337

# ---------------------------------------------------------------------------
# generic helpers
# ---------------------------------------------------------------------------


def rng(tag: str) -> np.random.Generator:
    """Deterministic generator per asset (independent of generation order)."""
    h = SEED
    for ch in tag:
        h = (h * 131 + ord(ch)) % (2**32)
    return np.random.default_rng(h)


def hexc(s: str) -> tuple:
    s = s.lstrip("#")
    return tuple(int(s[i:i + 2], 16) for i in (0, 2, 4))


def ramp(*cols) -> list:
    """Material ramp: [deep, dark, base, light] (optionally a 5th: highlight)."""
    return [hexc(c) if isinstance(c, str) else c for c in cols]


def darker(r: list) -> list:
    """Shifted ramp for parts that sit farther from the viewer."""
    return [r[0], r[0], r[1], r[2]]


def nb(m: np.ndarray, dx: int, dy: int) -> np.ndarray:
    """m sampled at (x+dx, y+dy), False outside the image."""
    h, w = m.shape
    k = max(1, abs(dx), abs(dy))
    p = np.pad(m, k)
    return p[k + dy:k + dy + h, k + dx:k + dx + w]


def coords(w, h):
    ys, xs = np.mgrid[0:h, 0:w]
    return xs.astype(float), ys.astype(float)


def m_ellipse(w, h, cx, cy, rx, ry):
    xs, ys = coords(w, h)
    return ((xs - cx) / rx) ** 2 + ((ys - cy) / ry) ** 2 <= 1.0


def m_capsule(w, h, x0, y0, x1, y1, r):
    xs, ys = coords(w, h)
    dx, dy = x1 - x0, y1 - y0
    L2 = dx * dx + dy * dy
    if L2 == 0:
        t = np.zeros_like(xs)
    else:
        t = np.clip(((xs - x0) * dx + (ys - y0) * dy) / L2, 0, 1)
    px, py = x0 + t * dx, y0 + t * dy
    return (xs - px) ** 2 + (ys - py) ** 2 <= r * r


def m_chain(w, h, pts, r):
    m = np.zeros((h, w), bool)
    for (a, b) in zip(pts, pts[1:]):
        m |= m_capsule(w, h, a[0], a[1], b[0], b[1], r)
    return m


def m_poly(w, h, pts):
    im = Image.new("L", (w, h), 0)
    ImageDraw.Draw(im).polygon([tuple(p) for p in pts], fill=1, outline=1)
    return np.array(im, bool)


def m_rect(w, h, x0, y0, x1, y1):
    m = np.zeros((h, w), bool)
    m[max(0, y0):max(0, y1 + 1), max(0, x0):max(0, x1 + 1)] = True
    return m


def m_line(w, h, x0, y0, x1, y1):
    """1px Bresenham line."""
    m = np.zeros((h, w), bool)
    x0, y0, x1, y1 = int(round(x0)), int(round(y0)), int(round(x1)), int(round(y1))
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx, sy = (1 if x0 < x1 else -1), (1 if y0 < y1 else -1)
    err = dx + dy
    while True:
        if 0 <= x0 < w and 0 <= y0 < h:
            m[y0, x0] = True
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return m


class Sprite:
    """RGBA pixel canvas with part-based shading and outline passes."""

    def __init__(self, w, h):
        self.w, self.h = w, h
        self.img = np.zeros((h, w, 4), np.uint8)

    @property
    def occ(self):
        return self.img[..., 3] > 0

    def part(self, mask, r, light="l", dark="rb", sep=False, flat=False, lw=1, dw=1):
        """Paint a shaded part. Edges facing the light get r[3], shadowed edges
        r[1] (lw/dw = band widths); with sep, edges that touch earlier parts
        get the deep r[0]."""
        mask = mask.copy()
        if not mask.any():
            return mask
        c = np.zeros((self.h, self.w, 3), np.int32)
        c[:] = r[2]
        if not flat:
            dirs = {"l": (-1, 0), "r": (1, 0), "t": (0, -1), "b": (0, 1)}

            def edge(d, n):
                dx, dy = dirs[d]
                inside = mask.copy()
                for k in range(1, n + 1):
                    inside &= nb(mask, dx * k, dy * k)
                return mask & ~inside

            for d in light:
                c[edge(d, lw)] = r[3]
            for d in dark:
                c[edge(d, dw)] = r[1]
        if sep:
            other = self.occ & ~mask
            s = np.zeros_like(mask)
            for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
                s |= mask & ~nb(mask, dx, dy) & nb(other, dx, dy)
            c[s] = r[0]
        self.img[mask, :3] = c[mask]
        self.img[mask, 3] = 255
        return mask

    def fill(self, mask, col, a=255):
        self.img[mask, :3] = col[:3]
        self.img[mask, 3] = a

    def px(self, x, y, col, a=255):
        x, y = int(x), int(y)
        if 0 <= x < self.w and 0 <= y < self.h:
            self.img[y, x, :3] = col[:3]
            self.img[y, x, 3] = a

    def pxs(self, pts, col):
        for (x, y) in pts:
            self.px(x, y, col)

    def recolor(self, mask, col):
        """Recolor only already-opaque pixels."""
        m = mask & self.occ
        self.img[m, :3] = col[:3]

    def outline(self, tint=(14, 10, 24), k=0.28, diag=False):
        """Selective 1px outline: darkened copy of the neighbouring colour."""
        occ = self.occ
        out = ~occ & (nb(occ, 1, 0) | nb(occ, -1, 0) | nb(occ, 0, 1) | nb(occ, 0, -1))
        if diag:
            out |= ~occ & (nb(occ, 1, 1) | nb(occ, -1, 1) | nb(occ, 1, -1) | nb(occ, -1, -1))
        src = np.zeros((self.h, self.w, 3), np.float32)
        cnt = np.zeros((self.h, self.w), np.float32)
        rgb = self.img[..., :3].astype(np.float32)
        for dx, dy in ((1, 0), (-1, 0), (0, 1), (0, -1)):
            o = nb(occ, dx, dy)
            sh = np.zeros_like(rgb)
            pr = np.pad(rgb, ((1, 1), (1, 1), (0, 0)))
            sh[:] = pr[1 + dy:1 + dy + self.h, 1 + dx:1 + dx + self.w]
            src += sh * o[..., None]
            cnt += o
        cnt = np.maximum(cnt, 1)
        col = src / cnt[..., None] * k + np.array(tint, np.float32)
        col = np.clip(col, 0, 255).astype(np.uint8)
        self.img[out, :3] = col[out]
        self.img[out, 3] = 255

    def flip(self):
        s = Sprite(self.w, self.h)
        s.img = self.img[:, ::-1].copy()
        return s

    def image(self):
        return Image.fromarray(self.img, "RGBA")


def sheet(frames, cols):
    """frames: list of Sprite (same size) -> Sprite grid."""
    fw, fh = frames[0].w, frames[0].h
    rows = (len(frames) + cols - 1) // cols
    s = Sprite(fw * cols, fh * rows)
    for i, f in enumerate(frames):
        x, y = (i % cols) * fw, (i // cols) * fh
        s.img[y:y + fh, x:x + fw] = f.img
    return s


def save(sprite_or_arr, path: Path):
    path.parent.mkdir(parents=True, exist_ok=True)
    if isinstance(sprite_or_arr, Sprite):
        im = sprite_or_arr.image()
    elif isinstance(sprite_or_arr, np.ndarray):
        a = sprite_or_arr
        if a.shape[-1] == 3:
            a = np.concatenate([a, np.full(a.shape[:2] + (1,), 255, a.dtype)], -1)
        im = Image.fromarray(a.astype(np.uint8), "RGBA")
    else:
        im = sprite_or_arr.convert("RGBA")
    im.save(path)
    OUTPUTS.append(path)


OUTPUTS: list[Path] = []

# ---------------------------------------------------------------------------
# characters
# ---------------------------------------------------------------------------

OUTLINE_TINT = (16, 12, 26)

CHAR_A = dict(
    key="a",
    skin=ramp("9c7a80", "c9a39e", "e8cdc2", "f7e6dc"),
    hair=ramp("15121c", "221d2b", "2f2939", "4a4258"),
    top=ramp("4a4c5c", "6c6e7e", "8e909e", "b2b4c0"),
    top_trim=ramp("3a3c4a", "55576a", "6c6e7e", "8e909e"),
    legs=ramp("1e2438", "2e3752", "3f4b6e", "56658c"),
    shoes=ramp("7c7c8a", "b8b8c2", "e4e4e8", "fbfbfb"),
    sole=hexc("9a9aa6"),
    eye=hexc("1c1826"),
    mouth=hexc("b48a8c"),
    tall=0, broad=0, hair_style="bob", top_style="hoodie",
)

CHAR_B = dict(
    key="b",
    skin=ramp("8e6454", "c09078", "deb49a", "f0d0b8"),
    hair=ramp("4a1e18", "6e2c1e", "92402a", "b8603c"),
    top=ramp("262e1c", "38442a", "4c5c38", "66784a"),
    top_trim=ramp("1e2416", "2e3822", "38442a", "4c5c38"),
    legs=ramp("141418", "1e1e26", "2c2c36", "40404c"),
    shoes=ramp("2e1e14", "4c3222", "6c4a30", "8c6440"),
    sole=hexc("2a1c14"),
    eye=hexc("1c1826"),
    mouth=hexc("a07060"),
    tall=2, broad=1, hair_style="messy", top_style="jacket",
)

FW, FH = 32, 48


class Rig:
    """Vertical landmarks of a character (per frame, with bob)."""

    def __init__(self, spec, bob=0):
        T = spec["tall"]
        self.cx = 15.5
        self.cy = 14 - T + bob          # head centre
        self.S = 21 - T + bob           # shoulder line (top of torso)
        self.H = 33 - (1 if T else 0) + bob  # hem / hip line
        self.ankle = 44                 # shoes occupy ankle..46, outline at 47
        self.b = spec["broad"]


def draw_head(sp: Sprite, spec, rig: Rig, view: str):
    """view: down | left | up."""
    W, H = sp.w, sp.h
    cx, cy = rig.cx, rig.cy
    skin, hair = spec["skin"], spec["hair"]
    messy = spec["hair_style"] == "messy"

    # neck
    nx0, nx1 = (15, 16) if not messy else (14, 17)
    sp.part(m_rect(W, H, nx0, int(cy) + 5, nx1, rig.S + 1), darker(skin), sep=False)

    if view == "down":
        back = m_ellipse(W, H, cx, cy - 0.5, 6.5, 6.4)
        if not messy:  # bob: side panels to the jaw
            back |= m_rect(W, H, 9, int(cy), 11, int(cy) + 5)
            back |= m_rect(W, H, 20, int(cy), 22, int(cy) + 5)
        else:
            back |= m_rect(W, H, 10, int(cy), 11, int(cy) + 3)
            back |= m_rect(W, H, 20, int(cy), 21, int(cy) + 3)
        sp.part(back, hair, light="lt", dark="rb")
        face = m_ellipse(W, H, cx, cy + 1.2, 5.0, 5.3)
        sp.part(face, skin, light="l", dark="rb")
        # bangs
        bang = m_ellipse(W, H, cx, cy - 0.5, 6.5, 6.4) & coords(W, H)[1].__le__(cy - 2)
        bang = bang.astype(bool)
        if messy:
            fr = [(11, cy - 1), (12, cy - 1), (12, cy), (14, cy - 1), (15, cy - 1), (15, cy), (17, cy - 1),
                  (18, cy - 1), (18, cy), (20, cy - 1)]
        else:
            fr = [(11, cy - 1), (12, cy - 1), (13, cy - 1), (17, cy - 1), (18, cy - 1), (19, cy - 1), (20, cy - 1),
                  (11, cy), (20, cy)]
        for (x, y) in fr:
            bang[int(y), int(x)] = True
        # locks framing the face
        bang |= m_rect(W, H, 10, int(cy) - 1, 10, int(cy) + (4 if not messy else 2))
        bang |= m_rect(W, H, 21, int(cy) - 1, 21, int(cy) + (4 if not messy else 2))
        sp.part(bang, hair, light="t", dark="b")
        # eyes, mouth, cheeks
        ey = int(cy) + 1
        for ex in (13, 18):
            sp.px(ex, ey, spec["eye"])
            sp.px(ex, ey + 1, spec["eye"])
        sp.px(15, ey + 4, spec["mouth"])
        sp.px(16, ey + 4, spec["mouth"])
        sp.px(12, ey + 2, skin[1])
        sp.px(19, ey + 2, skin[1])
        # hair shine
        for x in range(12, 16):
            sp.px(x, int(cy) - 5, hair[3])
        sp.px(16, int(cy) - 4, hair[3])
    elif view == "up":
        back = m_ellipse(W, H, cx, cy - 0.3, 6.5, 6.5)
        if not messy:
            back |= m_rect(W, H, 9, int(cy), 22, int(cy) + 5)
            back &= ~(m_rect(W, H, 9, int(cy) + 5, 9, int(cy) + 5) | m_rect(W, H, 22, int(cy) + 5, 22, int(cy) + 5))
        sp.part(back, hair, light="lt", dark="rb")
        # strands / shading on the back of the head
        for (x0, y0, x1, y1) in ((13, cy - 3, 12, cy + 3), (17, cy - 2, 18, cy + 4), (15, cy - 4, 15, cy + 1)):
            sp.recolor(m_line(W, H, x0, y0, x1, y1), hair[1])
        for x in range(12, 17):
            sp.px(x, int(cy) - 5, hair[3])
        if messy:
            sp.px(14, int(cy) + 5, hair[1])
            sp.px(17, int(cy) + 5, hair[1])
    else:  # left
        head = m_ellipse(W, H, 15.0, cy, 5.8, 6.4)
        sp.part(head, skin, light="l", dark="rb")
        hr = m_ellipse(W, H, 16.4, cy - 0.6, 6.0, 6.2)
        hr |= m_ellipse(W, H, cx, cy - 2.0, 6.0, 4.6)
        if not messy:
            hr |= m_rect(W, H, 15, int(cy), 21, int(cy) + 5)
            hr &= ~m_rect(W, H, 21, int(cy) + 5, 21, int(cy) + 5)
        # keep the face open
        face_cut = m_ellipse(W, H, 12.2, cy + 2.4, 3.9, 4.4) & (coords(W, H)[0] < 15)
        hr &= ~face_cut
        sp.part(hr, hair, light="lt", dark="rb")
        # fringe tip over forehead
        sp.px(10, int(cy) - 1, hair[2])
        sp.px(11, int(cy) - 1, hair[2])
        # nose, eye, mouth
        sp.px(9, int(cy) + 2, skin[2])
        ey = int(cy) + 1
        sp.px(12, ey, spec["eye"])
        sp.px(12, ey + 1, spec["eye"])
        sp.px(13, ey + 3, skin[1])
        sp.px(10, ey + 4, spec["mouth"])
        if messy:  # ear
            sp.px(15, ey + 1, skin[2])
            sp.px(15, ey + 2, skin[1])
        for x in range(13, 18):
            sp.px(x, int(cy) - 5, hair[3])

    if messy:  # tufts around the crown
        ang = {
            "down": [(-165, 0.8), (-140, -0.6), (-112, 0.9), (-85, -0.8), (-58, 0.9), (-30, -0.6), (-8, 0.7)],
            "up": [(-165, 0.8), (-140, -0.6), (-112, 0.9), (-85, -0.8), (-58, 0.9), (-30, -0.6), (-8, 0.7),
                   (150, 0.6), (120, -0.5), (60, 0.5), (30, -0.6)],
            "left": [(-150, 0.8), (-118, -0.7), (-88, 0.9), (-58, -0.8), (-28, 0.8), (0, 0.7), (30, 0.8)],
        }[view]
        ccx = cx if view != "left" else 16.4
        m = tufts(W, H, ccx, cy - 0.5, 6.3, 6.2, ang)
        m &= ~sp.occ
        sp.part(m, hair, light="lt", dark="rb")


def tufts(W, H, cx, cy, rx, ry, angles, length=1.3, width=1.7):
    """Small triangular hair tufts sticking out of an ellipse outline."""
    m = np.zeros((H, W), bool)
    for a, lean in angles:
        t = math.radians(a)
        c, s_ = math.cos(t), math.sin(t)
        bx, by = cx + rx * 0.8 * c, cy + ry * 0.8 * s_
        px, py = -s_, c
        tx = cx + (rx + length) * c + px * lean * 1.1
        ty = cy + (ry + length) * s_ + py * lean * 1.1
        m |= m_poly(W, H, [(bx + px * width, by + py * width), (bx - px * width, by - py * width), (tx, ty)])
    return m


def draw_torso(sp: Sprite, spec, rig: Rig, view: str):
    W, H = sp.w, sp.h
    S, Hh, b = rig.S, rig.H, rig.b
    top, trim = spec["top"], spec["top_trim"]
    hoodie = spec["top_style"] == "hoodie"
    if view in ("down", "up"):
        pts = [(11 - b, S), (20 + b, S), (21 + b, S + 1), (22 + b, S + 3), (22 + b, Hh - 1), (21 + b, Hh),
               (10 - b, Hh), (9 - b, Hh - 1), (9 - b, S + 3), (10 - b, S + 1)]
        body = sp.part(m_poly(W, H, pts), top, light="l", dark="rb")
        # hem band
        sp.recolor(m_rect(W, H, 9 - b, Hh - 1, 22 + b, Hh) & body, trim[2])
        sp.recolor(m_rect(W, H, 9 - b, Hh, 22 + b, Hh) & body, trim[1])
        if view == "down":
            if hoodie:
                hood = m_ellipse(W, H, 15.5, S + 0.5, 5.2, 2.0)
                sp.part(hood, trim, light="t", dark="b")
                sp.recolor(m_rect(W, H, 13, S + 1, 18, S + 1), trim[0])
                for x in (14, 17):  # drawstrings
                    sp.recolor(m_rect(W, H, x, S + 2, x, S + 5), top[3])
                    sp.px(x, S + 6, spec["shoes"][2])
                # kangaroo pocket
                py = Hh - 6
                sp.recolor(m_line(W, H, 12, py, 19, py), trim[1])
                sp.recolor(m_line(W, H, 11, py + 1, 11, py + 4), trim[1])
                sp.recolor(m_line(W, H, 20, py + 1, 20, py + 4), trim[1])
                sp.recolor(m_line(W, H, 12, py + 1, 19, py + 1), top[3])
            else:
                # collar + zipper + chest pockets + belt
                collar = m_poly(W, H, [(11 - b, S), (15, S + 3), (16, S + 3), (20 + b, S), (18, S - 1), (13, S - 1)])
                sp.part(collar, spec["top"], light="lt", dark="b")
                sp.recolor(m_rect(W, H, 14, S, 17, S + 1), hexc("6e6a64"))
                sp.recolor(m_line(W, H, 15, S + 3, 15, Hh), top[0])
                sp.recolor(m_line(W, H, 16, S + 3, 16, Hh), top[1])
                for x0 in (10, 18):
                    sp.recolor(m_rect(W, H, x0, S + 4, x0 + 3, S + 4), top[1])
                    sp.recolor(m_rect(W, H, x0, S + 5, x0 + 3, S + 7), top[2])
                    sp.recolor(m_rect(W, H, x0, S + 8, x0 + 3, S + 8), top[1])
                    sp.px(x0 + 1, S + 5, top[3])
                sp.recolor(m_rect(W, H, 9 - b, Hh - 3, 22 + b, Hh - 3), top[1])
                sp.recolor(m_rect(W, H, 11, Hh - 2, 13, Hh - 2), top[0])
                sp.recolor(m_rect(W, H, 18, Hh - 2, 20, Hh - 2), top[0])
        else:  # back
            if hoodie:
                hood = m_poly(W, H, [(11, S), (20, S), (19, S + 5), (15, S + 7), (12, S + 5)])
                sp.part(hood, top, light="lt", dark="rb", sep=True)
                sp.recolor(m_line(W, H, 15, S + 1, 15, S + 5), top[1])
                sp.recolor(m_line(W, H, 13, S + 1, 13, S + 3), top[3])
            else:
                sp.recolor(m_rect(W, H, 11 - b, S, 20 + b, S + 1), top[3])
                sp.recolor(m_line(W, H, 11 - b, S + 2, 20 + b, S + 2), top[1])
                sp.recolor(m_line(W, H, 11, S + 9, 20, S + 9), top[1])  # back yoke seam
                sp.recolor(m_rect(W, H, 9 - b, Hh - 3, 22 + b, Hh - 3), top[1])
    else:  # left
        pts = [(13, S), (18 + b, S), (20 + b, S + 2), (20 + b, Hh - 1), (19 + b, Hh), (12 - b, Hh), (11 - b, Hh - 1),
               (11 - b, S + 2)]
        body = sp.part(m_poly(W, H, pts), top, light="l", dark="rb")
        sp.recolor(m_rect(W, H, 10, Hh - 1, 22, Hh) & body, trim[2])
        sp.recolor(m_rect(W, H, 10, Hh, 22, Hh) & body, trim[1])
        if hoodie:
            hood = m_poly(W, H, [(15, S - 1), (20, S - 1), (21, S + 3), (19, S + 5), (16, S + 3)])
            sp.part(hood, top, light="t", dark="rb", sep=True)
            sp.px(12, S + 2, top[3])
            sp.px(12, S + 3, top[3])
            sp.px(12, S + 4, spec["shoes"][2])
        else:
            collar = m_poly(W, H, [(12, S - 1), (18, S - 1), (19, S + 1), (13, S + 2)])
            sp.part(collar, top, light="lt", dark="b", sep=True)
            sp.recolor(m_line(W, H, 11 - b, Hh - 3, 20 + b, Hh - 3), top[1])
            sp.recolor(m_rect(W, H, 12, S + 5, 14, S + 5), top[1])


def draw_legs(sp, spec, rig: Rig, view: str, frame: int):
    W, H = sp.w, sp.h
    legs, shoes = spec["legs"], spec["shoes"]
    Hh, A = rig.H, rig.ankle
    boots = spec["top_style"] == "jacket"
    if view in ("down", "up", "climb"):
        lift = {0: (0, 0), 1: (2, 0), 2: (0, 0), 3: (0, 2)}[frame]
        if view == "climb":
            lift = {0: (0, 4), 1: (0, 0), 2: (4, 0), 3: (0, 0)}[frame]
        # crotch
        sp.part(m_rect(W, H, 12, Hh - 1, 19, Hh + 1), legs, light="", dark="")
        for i, (lx, lf) in enumerate(((12.5, lift[0]), (18.5, lift[1]))):
            m = m_capsule(W, H, lx, Hh - 1, lx, A - lf, 1.6)
            if view == "climb" and lf:
                m = m_chain(W, H, [(lx, Hh - 1), (lx + (-1 if i == 0 else 1), A - lf - 2), (lx, A - lf)], 1.6)
            sp.part(m, legs, light="l", dark="r")
            # shoe
            y0 = A - lf
            x0 = int(lx - 2) if i == 0 else int(lx - 1)
            sm = m_rect(W, H, x0, y0, x0 + 3, y0 + 2)
            sm[y0, x0] = False if not boots else sm[y0, x0]
            sm[y0, x0 + 3] = False if not boots else sm[y0, x0 + 3]
            if boots:
                sm |= m_rect(W, H, x0, y0 - 2, x0 + 3, y0)
            sp.part(sm, shoes, light="lt", dark="r")
            sp.recolor(m_rect(W, H, x0, y0 + 2, x0 + 3, y0 + 2), spec["sole"])
            if view == "down" and not boots:
                sp.px(x0 + 1 + (1 if i == 0 else 0), y0, shoes[1])  # laces
            if boots:
                sp.recolor(m_rect(W, H, x0, y0 - 2, x0 + 3, y0 - 2), shoes[1])
        # inner leg separation
        sp.recolor(m_line(W, H, 15, Hh + 2, 15, A - 1 - max(lift)), legs[0])
        sp.recolor(m_line(W, H, 16, Hh + 2, 16, A - 1 - max(lift)), legs[0])
        if view == "up" or view == "climb":
            sp.recolor(m_rect(W, H, 11, Hh + 1, 20, Hh + 1), legs[1])
    else:  # left
        hip = (16.0, Hh - 1)
        # (knee, ankle) for near and far leg per frame
        poses = {
            0: (((15.5, Hh + 5), (15.5, A)), ((17.5, Hh + 5), (17.5, A))),
            1: (((13.5, Hh + 5), (11.5, A)), ((18.5, Hh + 5), (20.5, A - 1))),
            2: (((15.5, Hh + 5), (15.5, A)), ((14.5, Hh + 4), (17.5, A - 3))),
            3: (((18.5, Hh + 5), (20.5, A - 1)), ((13.5, Hh + 5), (11.5, A))),
        }[frame]
        for idx in (1, 0):  # far first
            knee, ank = poses[idx]
            r = legs if idx == 0 else darker(legs)
            sr = shoes if idx == 0 else darker(shoes)
            m = m_chain(W, H, [(hip[0] + (1 if idx else 0), hip[1]), knee, ank], 1.6)
            sp.part(m, r, light="l", dark="r", sep=(idx == 0))
            ax, ay = int(ank[0]), int(ank[1])
            sm = m_rect(W, H, ax - 3, ay, ax + 1, ay + 2)
            sm[ay, ax - 3] = False
            if boots:
                sm |= m_rect(W, H, ax - 1, ay - 2, ax + 1, ay)
            sp.part(sm, sr, light="t", dark="r", sep=(idx == 0))
            sp.recolor(m_rect(W, H, ax - 3, ay + 2, ax + 1, ay + 2), spec["sole"] if idx == 0 else darker(shoes)[0])
            if not boots and idx == 0:
                sp.px(ax - 1, ay, shoes[1])


def draw_arms(sp, spec, rig: Rig, view: str, frame: int, layer: str):
    """layer: 'back' (behind torso) or 'front'."""
    W, H = sp.w, sp.h
    S, Hh, b = rig.S, rig.H, rig.b
    top, skin = spec["top"], spec["skin"]
    hoodie = spec["top_style"] == "hoodie"
    arms = []  # (points, ramp, sep)
    if view in ("down", "up"):
        if layer != "front":
            return
        sw = {0: 0, 1: 1, 2: 0, 3: -1}[frame]
        if view == "up":
            sw = -sw
        hy = Hh - 2
        arms.append(([(9.5 - b, S + 2), (8.5 - b, S + 6), (8.8 - b - (sw > 0), hy + sw)], top, True))
        arms.append(([(21.5 + b, S + 2), (22.5 + b, S + 6), (22.2 + b + (sw < 0), hy - sw)], top, True))
    elif view == "climb":
        if layer != "front":
            return
        up_left = frame == 0
        up_right = frame == 2
        L = [(10.5, S + 2), (8.5, S - 3), (8.5, rig.cy - 3)] if up_left else [(9.5, S + 2), (7.5, S + 3), (9.0, S - 3)]
        R = [(20.5, S + 2), (22.5, S - 3), (22.5, rig.cy - 3)] if up_right else [(21.5, S + 2), (23.5, S + 3), (22.0, S - 3)]
        arms.append((L, top, True))
        arms.append((R, top, True))
    else:  # left
        sw = {0: 0, 1: 3, 2: 0, 3: -3}[frame]
        if layer == "back":
            arms.append(([(17.0, S + 2), (17.5 - sw * 0.6, S + 6), (17.0 - sw, Hh - 2)], darker(top), False))
        else:
            arms.append(([(15.0, S + 2), (15.5 + sw * 0.6, S + 6), (15.5 + sw, Hh - 2)], top, True))
    for pts, r, sep in arms:
        m = m_chain(W, H, pts, 1.6 if not hoodie else 1.75)
        sp.part(m, r, light="l", dark="rb", sep=sep)
        hx, hy = pts[-1]
        up = hy < pts[0][1]
        # cuff and hand
        cuff = m_capsule(W, H, hx, hy + (1 if up else -1), hx, hy + (1 if up else -1), 1.6) & m
        sp.recolor(cuff, spec["top_trim"][1])
        hand = m_ellipse(W, H, hx, hy + (-1.5 if up else 1.6), 1.45, 1.45)
        hr = skin if r is not darker(top) else darker(skin)
        if r[0] == darker(top)[0] and r[2] == darker(top)[2]:
            hr = darker(skin)
        sp.part(hand, hr, light="l", dark="rb")


def draw_char_frame(spec, view, frame):
    sp = Sprite(FW, FH)
    bob = {0: 0, 1: 0, 2: -1, 3: 0}[frame] if view != "climb" else {0: 0, 1: -1, 2: 0, 3: -1}[frame]
    rig = Rig(spec, bob)
    hv = "up" if view == "climb" else view
    draw_arms(sp, spec, rig, hv if view != "climb" else "climb", frame, "back")
    draw_legs(sp, spec, rig, view, frame)
    if view == "left":
        pass
    draw_torso(sp, spec, rig, hv)
    if view == "up" or view == "climb":
        # arms over the back, head last
        draw_head(sp, spec, rig, "up")
        draw_arms(sp, spec, rig, view, frame, "front")
    else:
        draw_arms(sp, spec, rig, view, frame, "front")
        draw_head(sp, spec, rig, hv)
    sp.outline(OUTLINE_TINT)
    return sp


def gen_char(spec):
    frames = []
    for view in ("down", "left", "right", "up", "climb"):
        for f in range(4):
            if view == "right":
                frames.append(draw_char_frame(spec, "left", f).flip())
            else:
                frames.append(draw_char_frame(spec, view, f))
    save(sheet(frames, 4), SPR / f"char_{spec['key']}.png")


# ---------------------------------------------------------------------------
# portraits (64x64 busts)
# ---------------------------------------------------------------------------


def gen_portrait(spec):
    W = H = 64
    sp = Sprite(W, H)
    skin, hair, top, trim = spec["skin"], spec["hair"], spec["top"], spec["top_trim"]
    messy = spec["hair_style"] == "messy"
    cx, cy = 31.5, 27.0
    xs, ys = coords(W, H)

    # shoulders / clothing
    b = 2 if messy else 0
    torso = m_poly(W, H, [(6 - b, 63), (8 - b, 52), (14 - b, 47), (24, 44), (40, 44), (50 + b, 47), (56 + b, 52),
                          (58 + b, 63)])
    sp.part(torso, top, light="lt", dark="r", lw=2, dw=2)
    # neck
    neck = m_rect(W, H, 26, 36, 37, 48) if not messy else m_rect(W, H, 25, 36, 38, 48)
    sp.part(neck, darker(skin), light="l", dark="r", lw=1, dw=2)
    sp.recolor(m_rect(W, H, 26, 38, 37, 40), skin[0])  # jaw shadow on the neck
    if not messy:
        # hood bunched around the neck + drawstrings
        hood = m_ellipse(W, H, 31.5, 47.5, 15.5, 5.5) & ~m_ellipse(W, H, 31.5, 45.5, 7.0, 3.6)
        sp.part(hood, trim, light="t", dark="b", lw=1, dw=2, sep=True)
        for x in (26, 37):
            sp.recolor(m_rect(W, H, x, 51, x, 60), top[3])
            sp.recolor(m_rect(W, H, x + 1, 51, x + 1, 60), top[1])
            sp.recolor(m_rect(W, H, x, 61, x + 1, 62), spec["shoes"][2])
        sp.recolor(m_line(W, H, 12, 56, 16, 63), top[1])
        sp.recolor(m_line(W, H, 51, 56, 47, 63), top[1])
    else:
        shirt = m_poly(W, H, [(25, 44), (38, 44), (35, 55), (28, 55)])
        sp.part(shirt, ramp("3e3c3a", "5c5a56", "74726c", "8e8c86"), light="", dark="", sep=True)
        for side in (-1, 1):
            c0 = 31.5 + side * 7
            col = m_poly(W, H, [(c0, 43), (31.5 + side * 16, 47), (31.5 + side * 13, 54), (31.5 + side * 3, 58)])
            sp.part(col, top, light="lt", dark="rb", lw=1, dw=2, sep=True)
        sp.recolor(m_line(W, H, 31, 58, 31, 63), top[0])
        sp.recolor(m_line(W, H, 32, 58, 32, 63), top[3])
        for x0 in (11, 42):
            sp.recolor(m_rect(W, H, x0, 57, x0 + 8, 57), top[0])
            sp.recolor(m_rect(W, H, x0, 58, x0 + 8, 58), top[3])
            sp.px(x0 + 4, 59, trim[0])

    # hair behind the head
    back = m_ellipse(W, H, cx, cy - 2, 16.5, 16.0)
    if not messy:
        back |= m_poly(W, H, [(15, 22), (48, 22), (49, 41), (45, 43), (18, 43), (14, 41)])
    sp.part(back, hair, light="lt", dark="rb", lw=2, dw=2)
    # face
    face = m_ellipse(W, H, cx, cy + 2.5, 12.0, 13.0)
    face &= ~(m_ellipse(W, H, cx, 50, 30, 10) & (ys > 36) & (np.abs(xs - cx) > 7))
    chin = m_poly(W, H, [(21, 34), (42, 34), (37, 40), (33, 42), (30, 42), (26, 40)])
    face = (face & (ys < 36)) | chin
    sp.part(face, skin, light="l", dark="rb", lw=1, dw=3)
    # ears for B
    if messy:
        for ex in (18.5, 44.5):
            sp.part(m_ellipse(W, H, ex, 29, 2.2, 3.5) & ~face, skin, light="l", dark="r")
    # fringe
    fr = m_ellipse(W, H, cx, cy - 3, 16.0, 15.0) & (ys <= 19)
    if not messy:
        for i, x in enumerate(range(18, 46)):
            depth = 21 + ((x * 7) % 5 > 2) + (1 if x in (21, 22, 33, 34, 41) else 0)
            fr |= (xs == x) & (ys <= depth) & m_ellipse(W, H, cx, cy - 3, 16.0, 17.0)
        fr |= m_poly(W, H, [(16, 16), (20, 18), (20, 36), (17, 40), (15, 34)])
        fr |= m_poly(W, H, [(47, 16), (43, 18), (43, 36), (46, 40), (48, 34)])
    else:
        for (x0, y0, x1, y1) in ((20, 16, 21, 25), (24, 16, 25, 24), (28, 16, 30, 22), (33, 16, 35, 24),
                                 (38, 16, 40, 23), (42, 16, 44, 25)):
            fr |= m_poly(W, H, [(x0 - 2, y0), (x0 + 3, y0), (x1, y1)])
        fr |= m_poly(W, H, [(15, 16), (20, 18), (19, 28), (16, 26)])
        fr |= m_poly(W, H, [(48, 16), (43, 18), (44, 28), (47, 26)])
    sp.part(fr, hair, light="t", dark="b", lw=1, dw=1)
    if messy:
        ang = [(-170, 1), (-150, -1), (-128, 1), (-105, -1), (-80, 1), (-55, -1), (-32, 1), (-10, -1)]
        m = tufts(W, H, cx, cy - 2, 16.0, 15.5, ang, length=2.2, width=3.6) & ~sp.occ
        sp.part(m, hair, light="lt", dark="rb", lw=1, dw=2)
    # hair strands + shine
    for (x0, y0, x1, y1) in ((24, 13, 22, 19), (30, 12, 29, 19), (37, 13, 39, 20), (43, 15, 45, 21)):
        sp.recolor(m_line(W, H, x0, y0, x1, y1) & fr, hair[1])
    d = np.hypot(xs - cx, (ys - (cy - 2)) * 1.05)
    ang_ = np.arctan2(ys - (cy - 2), xs - cx)
    shine = (d > 11.5) & (d < 13.2) & (ang_ > -2.5) & (ang_ < -1.2)
    sp.recolor(shine & (back | fr), hair[3])
    sp.recolor(((d > 13.2) & (d < 14.5) & (ang_ > -2.2) & (ang_ < -1.5)) & (back | fr), hair[2])

    # eyes
    iris = hexc("56627e") if not messy else hexc("5a6a3e")
    for ex, flip in ((24, 1), (35, -1)):
        ey = 27
        sp.recolor(m_rect(W, H, ex, ey - 1, ex + 4, ey - 1), spec["eye"])       # lash line
        sp.px(ex - 1 if flip > 0 else ex + 5, ey, spec["eye"])
        sp.recolor(m_rect(W, H, ex, ey, ex + 4, ey + 2), hexc("e8e4e4"))       # sclera
        sp.recolor(m_rect(W, H, ex + 1, ey, ex + 3, ey + 2), iris)
        sp.recolor(m_rect(W, H, ex + 2, ey, ex + 2, ey + 1), spec["eye"])     # pupil
        sp.px(ex + 1, ey, hexc("f4f4f8"))
        sp.recolor(m_rect(W, H, ex, ey + 3, ex + 4, ey + 3), skin[1])          # lower lid / tired
        brow_y = 23 if messy else 22
        sp.recolor(m_line(W, H, ex - 1, brow_y + (1 if flip > 0 else 0), ex + 4, brow_y + (0 if flip > 0 else 1)) & ~fr,
                   hair[1] if messy else hair[2])
    # nose, mouth
    sp.px(31, 31, skin[1])
    sp.px(32, 32, skin[1])
    sp.px(31, 33, skin[1])
    sp.px(32, 33, skin[0])
    sp.recolor(m_rect(W, H, 29, 37, 34, 37), spec["mouth"])
    sp.px(28, 36, skin[1])
    sp.recolor(m_rect(W, H, 30, 38, 33, 38), skin[3])
    sp.outline(OUTLINE_TINT)
    save(sp, SPR / f"char_{spec['key']}_portrait.png")


# ---------------------------------------------------------------------------
# monster, corpse, crow
# ---------------------------------------------------------------------------

M_BODY = ramp("0e0c14", "1a1624", "282234", "3c3450")
M_FACE = ramp("6c6266", "a69a98", "cec4bc", "ece6de")
M_IRON = ramp("16161c", "30303a", "4c4c58", "7a7a88")
M_RUST = ramp("3a1e14", "5a3020", "7a4a2c", "96643c")
M_GOLD = ramp("3a3024", "5e4c32", "7e6a44", "a08a5a")


def chain_links(sp, pts, iron=M_IRON, step=3):
    """Iron chain following a polyline: alternating front/side links."""
    W, H = sp.w, sp.h
    path = []
    for (a, b_) in zip(pts, pts[1:]):
        L = math.hypot(b_[0] - a[0], b_[1] - a[1])
        n = max(1, int(L / step))
        for i in range(n):
            t = i / n
            path.append((a[0] + (b_[0] - a[0]) * t, a[1] + (b_[1] - a[1]) * t,
                         math.atan2(b_[1] - a[1], b_[0] - a[0])))
    path.append((pts[-1][0], pts[-1][1], 0))
    for i, (x, y, ang) in enumerate(path):
        if i % 2 == 0:  # ring seen from the front
            ring = m_ellipse(W, H, x, y, 2.0, 2.0) & ~m_ellipse(W, H, x, y, 0.9, 0.9)
            sp.part(ring, iron, light="lt", dark="rb", sep=False)
        else:  # link seen edge-on
            dx, dy = math.cos(ang) * 1.6, math.sin(ang) * 1.6
            sp.part(m_capsule(W, H, x - dx, y - dy, x + dx, y + dy, 0.8), iron, light="t", dark="b")


def monster_frame(f):
    W, H = 96, 128
    sp = Sprite(W, H)
    br = f  # breathing: 0 exhale, 1 inhale
    sh = -br  # shoulders rise
    # chains trailing on the ground behind the creature
    # legs (crouched)
    for (hip, knee, ank, r) in (((40, 86), (22, 100), (28, 120), M_BODY), ((56, 86), (74, 100), (68, 120), M_BODY)):
        sp.part(m_capsule(W, H, *hip, *knee, 4.2), r, light="lt", dark="rb", lw=1, dw=2)
        sp.part(m_capsule(W, H, *knee, *ank, 3.0), r, light="l", dark="rb", dw=2, sep=True)
        sp.px(knee[0], knee[1] - 2, r[3])
        foot = m_poly(W, H, [(ank[0] - 3, ank[1] - 2), (ank[0] + 3, ank[1] - 2), (ank[0] + 6, 125), (ank[0] - 7, 125)])
        sp.part(foot, r, light="t", dark="b", sep=True)
        for tx in (-7, -3, 1, 5):
            sp.part(m_poly(W, H, [(ank[0] + tx, 124), (ank[0] + tx + 2, 124), (ank[0] + tx + (0 if tx < 0 else 2), 126)]),
                    M_FACE, light="", dark="r")
    # pelvis / abdomen
    sp.part(m_ellipse(W, H, 48, 84, 8, 5), M_BODY, light="t", dark="rb", sep=True)
    # hunched torso with ribs
    torso = m_ellipse(W, H, 48, 65 + sh * 0.5, 12.5 + br, 19 + br * 0.5)
    torso |= m_poly(W, H, [(40, 80), (56, 80), (53, 88), (43, 88)])
    sp.part(torso, M_BODY, light="lt", dark="rb", lw=2, dw=3, sep=True)
    for i, ry in enumerate((58, 63, 68, 73)):
        y = ry + sh
        for side in (-1, 1):
            x0, x1 = 48 + side * 3, 48 + side * (11 - i * 1.5)
            sp.recolor(m_line(W, H, x0, y, x1, y + 3), M_BODY[3] if side < 0 else M_BODY[2])
            sp.recolor(m_line(W, H, x0, y + 1, x1, y + 4), M_BODY[0])
    sp.recolor(m_line(W, H, 48, 52 + sh, 48, 80), M_BODY[0])  # sternum groove
    # bony shoulders
    for sx in (31, 65):
        sp.part(m_ellipse(W, H, sx, 51 + sh, 8, 6), M_BODY, light="lt", dark="rb", lw=1, dw=2, sep=True)
        sp.px(sx - 2, 47 + sh, M_BODY[3])
        sp.px(sx - 1, 47 + sh, M_BODY[3])
    # nemes headdress (sphinx)
    hy = 43 + sh
    lap = m_poly(W, H, [(34, hy - 4), (41, hy + 2), (40, hy + 22), (32, hy + 24), (30, hy + 6)])
    lap |= m_poly(W, H, [(62, hy - 4), (55, hy + 2), (56, hy + 22), (64, hy + 24), (66, hy + 6)])
    lap |= m_ellipse(W, H, 48, hy - 5, 17, 12) & (coords(W, H)[1] < hy + 2)
    sp.part(lap, M_GOLD, light="lt", dark="rb", lw=1, dw=2, sep=True)
    ys_ = coords(W, H)[1]
    stripes = lap & (((ys_.astype(int) - hy) % 4) >= 2)
    sp.recolor(stripes, M_BODY[1])
    # face
    face = m_ellipse(W, H, 48, hy + 1, 9.5, 12.5)
    sp.part(face, M_FACE, light="l", dark="rb", lw=1, dw=2, sep=True)
    sp.recolor(m_rect(W, H, 38, hy - 9, 58, hy - 7) & face, M_GOLD[1])  # headband
    sp.recolor(m_rect(W, H, 38, hy - 7, 58, hy - 7) & face, M_GOLD[3])
    # hollow eyes
    for ex in (43.5, 52.5):
        sp.recolor(m_ellipse(W, H, ex, hy - 1, 3.4, 4.0) & face, M_FACE[1])  # sunken socket
        eye = m_ellipse(W, H, ex, hy - 1, 2.2, 2.8)
        sp.fill(eye, M_BODY[0])
        sp.px(int(ex) + (1 if ex < 48 else 0), hy - 1, (255, 244, 224))
        sp.recolor(m_line(W, H, ex - 3, hy - 5, ex + 2, hy - 4 if ex < 48 else hy - 6) & face, M_FACE[1])
    sp.px(48, hy + 2, M_FACE[1])
    for side in (-1, 1):  # hollow cheeks
        sp.recolor(m_line(W, H, 48 + side * 7, hy + 1, 48 + side * 6, hy + 5) & face, M_FACE[1])
    sp.px(47, hy + 3, M_FACE[0])
    sp.px(49, hy + 3, M_FACE[0])
    # the grin: wide crescent with teeth
    grin = m_ellipse(W, H, 48, hy + 3, 9, 7) & ~m_ellipse(W, H, 48, hy - 1, 10, 7)
    grin &= face
    sp.fill(grin, (30, 10, 16))
    for x in range(40, 57):
        col = [yy for yy in range(hy, hy + 12) if grin[yy, x]]
        if len(col) >= 2 and x % 2 == 0:
            sp.px(x, col[0], (236, 230, 214))
            if len(col) > 2:
                sp.px(x, col[-1], (200, 192, 178))
    # corners of the mouth curling up
    sp.px(38, hy + 2, (30, 10, 16))
    sp.px(58, hy + 2, (30, 10, 16))
    sp.px(37, hy + 1, M_FACE[0])
    sp.px(59, hy + 1, M_FACE[0])
    # iron collar
    col_ = m_rect(W, H, 40, hy + 13, 56, hy + 15)
    sp.part(col_, M_IRON, light="t", dark="b", sep=True)
    # long arms
    arms = (((31, 52 + sh), (18, 78), (14, 102)), ((65, 52 + sh), (80, 76), (82, 102)))
    for (s_, e_, w_) in arms:
        sp.part(m_capsule(W, H, *s_, *e_, 4.0), M_BODY, light="l", dark="rb", lw=1, dw=2, sep=True)
        sp.part(m_capsule(W, H, *e_, *w_, 3.2), M_BODY, light="l", dark="rb", lw=1, dw=2, sep=True)
        sp.px(e_[0] - 1, e_[1], M_BODY[3])
        # long fingers with pale claws
        for i, dx in enumerate((-5, 0, 5)):
            tip = (w_[0] + dx * 1.2, 124 - abs(dx) * 0.4)
            mid = (w_[0] + dx * 0.9, 114)
            sp.part(m_chain(W, H, [(w_[0] + dx * 0.4, w_[1] + 5), mid, tip], 1.1), M_BODY, light="l", dark="r",
                    sep=True)
            sp.px(int(tip[0]), int(tip[1]) + 1, M_FACE[2])
            sp.px(int(tip[0]), int(tip[1]) + 2, M_FACE[1])
        palm = m_ellipse(W, H, w_[0], w_[1] + 5, 5, 4)
        sp.part(palm, M_BODY, light="t", dark="b", sep=True)
        # shackle
        cuff = m_rect(W, H, int(w_[0]) - 5, int(w_[1]) - 2, int(w_[0]) + 5, int(w_[1]) + 2)
        sp.part(cuff, M_IRON, light="lt", dark="rb", sep=True)
        sp.recolor(m_rect(W, H, int(w_[0]) - 5, int(w_[1]), int(w_[0]) + 5, int(w_[1])), M_IRON[1])
        sp.px(int(w_[0]) - 3, int(w_[1]) - 1, M_RUST[2])
        sp.px(int(w_[0]) + 2, int(w_[1]) + 1, M_RUST[1])
    # chains from the shackles to the ground, and from the collar
    chain_links(sp, [(9, 103), (6, 112), (4, 120), (1, 126)])
    chain_links(sp, [(87, 103), (90, 112), (92, 120), (95, 126)])
    chain_links(sp, [(48, hy + 16), (47, hy + 26), (48, hy + 34)])
    sp.outline((8, 6, 12), k=0.2)
    return sp


def gen_monster():
    save(sheet([monster_frame(0), monster_frame(1)], 2), SPR / "monster.png")


def gen_corpse():
    """Body lying face-down, seen from the ~40 degree game camera (its back)."""
    W, H = 64, 32
    sp = Sprite(W, H)
    coat = ramp("1a1c26", "2a2e3c", "3c4254", "545c70")
    trou = ramp("141418", "202028", "2e2e38", "42424e")
    skin = ramp("6e686c", "9a9496", "c4bebc", "e0dcd8")
    hair = ramp("150f10", "2a1c1c", "3e2a28", "5c4038")
    shoe = ramp("120e0c", "241c16", "3a2c22", "54423a")
    sole = hexc("6a6058")
    # legs (slightly apart), far one first
    sp.part(m_capsule(W, H, 37, 12.5, 55, 8.5, 3.3), darker(trou), light="t", dark="b")
    sp.part(m_capsule(W, H, 37, 19.5, 55, 22.5, 3.5), trou, light="t", dark="b", sep=True)
    sp.recolor(m_line(W, H, 44, 20, 52, 22), trou[1])
    for (x0, y0, y1) in ((56, 6, 11), (56, 20, 25)):
        sp.part(m_rect(W, H, x0, y0, x0 + 3, y1), shoe, light="t", dark="rb", sep=True)
        sp.recolor(m_rect(W, H, x0 + 3, y0 + 1, x0 + 3, y1 - 1), sole)   # soles facing up
        sp.px(x0 + 2, y0 + 2, shoe[3])
    # torso (coat), back up
    torso = m_ellipse(W, H, 25, 16, 13, 8.2)
    torso |= m_poly(W, H, [(14, 9), (36, 10), (39, 13), (39, 20), (36, 23), (14, 24)])
    sp.part(torso, coat, light="t", dark="b", lw=1, dw=2, sep=True)
    sp.recolor(m_line(W, H, 16, 16, 38, 16), coat[1])           # back seam
    sp.recolor(m_line(W, H, 18, 15, 30, 15), coat[3])            # moonlit crease
    sp.recolor(m_rect(W, H, 35, 10, 35, 22) & torso, coat[0])   # belt / hem
    sp.recolor(m_line(W, H, 22, 10, 28, 12), coat[1])            # fold
    sp.recolor(m_line(W, H, 24, 21, 31, 20), coat[1])
    # near arm lying along the body, hand palm-up on the ground
    sp.part(m_chain(W, H, [(16, 23), (22, 26.5), (29, 27)], 2.0), coat, light="t", dark="b", sep=True)
    sp.part(m_ellipse(W, H, 31.5, 27, 2.2, 1.7), skin, light="t", dark="rb", sep=True)
    sp.px(33, 26, skin[2])
    # far arm flung past the head, hand reaching
    sp.part(m_chain(W, H, [(16, 9.5), (12, 5), (6, 4.5)], 2.0), coat, light="t", dark="b", sep=True)
    hand = m_ellipse(W, H, 3.5, 5, 2.0, 1.8)
    sp.part(hand, skin, light="t", dark="rb", sep=True)
    for (x, y) in ((1, 4), (1, 6), (2, 7)):
        sp.px(x, y, skin[2])
    # head, face down: only hair visible, a pale ear
    head = m_ellipse(W, H, 9.5, 16, 5.6, 5.4)
    sp.part(head, hair, light="lt", dark="rb", sep=True)
    sp.recolor(m_line(W, H, 6, 13, 10, 12), hair[3])
    sp.recolor(m_line(W, H, 5, 15, 7, 13), hair[3])
    sp.recolor(m_line(W, H, 8, 17, 12, 19), hair[1])
    for (x, y) in ((3, 19), (4, 21), (2, 17)):   # strands on the ground
        sp.px(x, y, hair[2])
    sp.px(12, 21, skin[1])
    sp.px(13, 21, skin[0])
    sp.outline((8, 6, 12), k=0.2)
    # ground shadow (flat alpha, hard edge)
    shadow = (m_ellipse(W, H, 33, 22, 31, 7) | m_ellipse(W, H, 8, 21, 8, 5)) & ~sp.occ
    sp.img[shadow, :3] = (6, 6, 12)
    sp.img[shadow, 3] = 90
    save(sp, SPR / "corpse.png")


def from_ascii(rows, pal):
    h, w = len(rows), max(len(r) for r in rows)
    sp = Sprite(w, h)
    for y, row in enumerate(rows):
        for x, ch in enumerate(row):
            if ch in pal:
                c = pal[ch]
                sp.px(x, y, c[:3], c[3] if len(c) > 3 else 255)
    return sp


CROW_PAL = {"k": (10, 9, 14), "d": (30, 28, 40), "m": (50, 48, 66), "l": (74, 74, 96), "b": (96, 90, 96),
            "e": (220, 214, 200), "f": (60, 56, 60)}
CROW = [
    [
        "................",
        "................",
        "................",
        "................",
        "....kkk.........",
        "...kdmdk........",
        ".bbkdedk........",
        "..kkdddkk.......",
        "...kddddmkk.....",
        "...kdmllmddkk...",
        "....kdmmmdddkkk.",
        ".....kkddddddkk.",
        ".......kkkkkkk..",
        "........kfk.....",
        "........kfk.....",
        ".......fffff....",
    ],
    [
        "..........kk....",
        ".........kmdk...",
        "........kmldk...",
        "....kkk.kmddk...",
        "...kdmdkkmdk....",
        ".bbkdedkmddk....",
        "..kkdddkddkk....",
        "...kddddddkk....",
        "...kdmllmdddkk..",
        "....kdmmmdddkkk.",
        ".....kkddddddkk.",
        ".......kkkkkkk..",
        "................",
        "........kfk.....",
        "........kfk.....",
        ".......fffff....",
    ],
]


def gen_crow():
    save(sheet([from_ascii(fr, CROW_PAL) for fr in CROW], 2), SPR / "crow.png")


# ---------------------------------------------------------------------------
# foliage / props
# ---------------------------------------------------------------------------

LEAF = ramp("122022", "1e3430", "2c4a3c", "406450", "5a7e5e")
PINE = ramp("101c1c", "1a2e2c", "284236", "3a5a46", "527458")
BARK = ramp("1c1612", "2e241c", "443428", "5c4836")
DEAD = ramp("18151a", "2a2528", "403838", "5a5250")
GRASS = ramp("16241c", "243a28", "385434", "527048", "6e8c5a")


def gen_tree_pine():
    W, H = 64, 128
    sp = Sprite(W, H)
    r = rng("pine")
    xs, ys = coords(W, H)
    trunk = m_poly(W, H, [(29, 96), (34, 96), (35, 124), (38, 127), (25, 127), (28, 124)])
    sp.part(trunk, BARK, light="l", dark="r", lw=1, dw=2)
    for y in range(100, 126, 3):
        sp.px(31 + (y % 2), y, BARK[1])
    tiers = [(4, 26, 9), (14, 42, 14), (26, 58, 19), (40, 76, 24), (56, 94, 28), (72, 108, 30)]
    for i, (yt, yb, hw) in enumerate(tiers):
        t = np.clip((ys - yt) / (yb - yt), 0, 1)
        edge = yb - 3 * (((xs.astype(int) + i * 2) % 5) / 4.0)  # drooping saw-tooth tips
        halfw = hw * t ** 0.85 + r.normal(0, 0.6, (H, W))
        m = (ys >= yt) & (ys <= edge) & (np.abs(xs - 31.5) <= halfw)
        sp.part(m, PINE, light="lt", dark="rb", lw=2, dw=2)
        # inner shading: right half darker, bottom band shadow
        sp.recolor(m & (xs > 31.5 + hw * 0.35 * t) & (r.random((H, W)) < 0.6), PINE[1])
        sp.recolor(m & (ys > edge - 2) & ~(xs < 31.5 - hw * 0.5), PINE[1])
        sp.recolor(m & (xs < 31.5 - hw * 0.3 * t) & (r.random((H, W)) < 0.25) & (ys < edge - 3), PINE[4])
    sp.px(31, 3, PINE[3])
    sp.px(32, 3, PINE[2])
    sp.outline((6, 10, 12), k=0.25)
    save(sp, SPR / "tree_pine.png")


def branch(sp, r, x, y, ang, length, thick, depth, ramp_):
    if depth == 0 or length < 3:
        return
    pts = [(x, y)]
    cx, cy, a = x, y, ang
    segs = 3
    for _ in range(segs):
        a += r.normal(0, 0.28)
        cx += math.cos(a) * length / segs
        cy += math.sin(a) * length / segs
        pts.append((cx, cy))
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
        th = max(0.5, thick * (1 - 0.25 * i / segs))
        m = m_capsule(sp.w, sp.h, *p0, *p1, th) if th >= 0.9 else m_line(sp.w, sp.h, *p0, *p1)
        sp.part(m, ramp_, light="l", dark="r")
    n = 2 if depth > 1 else 3
    for k in range(n):
        na = a + r.uniform(-0.9, 0.9) + (0.35 if k % 2 else -0.35)
        branch(sp, r, cx, cy, na, length * r.uniform(0.55, 0.75), thick * 0.62, depth - 1, ramp_)


def gen_tree_dead():
    W, H = 64, 128
    sp = Sprite(W, H)
    r = rng("dead")
    # roots
    for (dx, a) in ((-6, 2.8), (5, 0.35), (-2, 2.2), (2, 0.9)):
        sp.part(m_capsule(W, H, 32, 122, 32 + dx * 1.3, 127, 1.6), DEAD, light="t", dark="rb")
    # twisted trunk
    pts = [(32, 127), (31, 114), (34, 100), (30, 86), (33, 72), (31, 62)]
    for i, (p0, p1) in enumerate(zip(pts, pts[1:])):
        sp.part(m_capsule(W, H, *p0, *p1, 4.2 - i * 0.5), DEAD, light="l", dark="r", lw=1, dw=2)
    sp.recolor(m_line(W, H, 33, 118, 32, 106), DEAD[1])
    sp.recolor(m_line(W, H, 31, 98, 33, 88), DEAD[1])
    sp.fill(m_ellipse(W, H, 32, 92, 1.4, 2.2), DEAD[0])  # knot hole
    branch(sp, r, 31, 64, -1.9, 26, 2.4, 4, DEAD)
    branch(sp, r, 32, 66, -1.2, 24, 2.2, 4, DEAD)
    branch(sp, r, 31, 84, -2.6, 20, 2.0, 3, DEAD)
    branch(sp, r, 33, 78, -0.45, 20, 1.9, 3, DEAD)
    branch(sp, r, 32, 100, -0.3, 12, 1.4, 2, DEAD)
    sp.outline((8, 6, 10), k=0.25)
    save(sp, SPR / "tree_dead.png")


def canopy(sp, blobs, pal, r, light=(-0.55, -0.85), jag=1.3):
    """Leafy canopy from blobs (cx, cy, radius) drawn back to front, shaded by
    a fake normal so each clump reads as a rounded volume."""
    W, H = sp.w, sp.h
    xs, ys = coords(W, H)
    for (cx, cy, rad) in sorted(blobs, key=lambda b: b[1]):
        ang = np.arctan2(ys - cy, xs - cx)
        wob = np.sin(ang * 7 + cx) * jag + np.sin(ang * 13 + cy) * jag * 0.6
        d = np.hypot(xs - cx, ys - cy)
        m = d <= rad + wob
        nx, ny = (xs - cx) / rad, (ys - cy) / rad
        lam = -(nx * light[0] + ny * light[1])  # >0 lit
        v = 0.5 + 0.5 * lam - 0.25 * (d / rad) ** 2 + r.normal(0, 0.12, (H, W))
        idx = np.clip((v * 4.2).astype(int), 0, 4)
        col = np.array(pal)[idx]
        # separate from what is behind with the darkest tone on the rim
        rim = m & ~nb(m, 1, 0) | m & ~nb(m, 0, 1)
        sp.img[m, :3] = col[m]
        sp.img[m, 3] = 255
        sp.img[rim & (ny > 0), :3] = pal[0]
    return sp


def gen_tree_oak():
    W, H = 96, 128
    sp = Sprite(W, H)
    r = rng("oak")
    trunk = m_poly(W, H, [(42, 70), (52, 70), (54, 118), (60, 127), (35, 127), (40, 118)])
    sp.part(trunk, BARK, light="l", dark="r", lw=2, dw=3)
    for x in (44, 48, 51):
        sp.recolor(m_line(W, H, x, 84, x + (x % 3) - 1, 124), BARK[1])
    for (p0, p1, t) in (((46, 78), (28, 58), 3.0), ((49, 76), (66, 54), 3.0), ((47, 74), (47, 48), 2.6)):
        sp.part(m_capsule(W, H, *p0, *p1, t), BARK, light="l", dark="r")
    blobs = [(48, 22, 18), (26, 34, 16), (70, 34, 16), (38, 46, 17), (60, 48, 17), (14, 52, 12), (82, 52, 12),
             (28, 62, 13), (68, 64, 13), (48, 60, 14), (48, 34, 17)]
    canopy(sp, blobs, LEAF, r)
    sp.outline((6, 10, 12), k=0.25)
    save(sp, SPR / "tree_oak.png")


def gen_bush():
    W, H = 32, 24
    sp = Sprite(W, H)
    r = rng("bush")
    canopy(sp, [(10, 15, 7), (21, 14, 7.5), (15, 9, 7), (5, 19, 4.5), (27, 19, 4.5), (16, 17, 7)], LEAF, r, jag=0.8)
    sp.img[23, :, 3] = 0
    sp.outline((6, 10, 12), k=0.25)
    save(sp, SPR / "bush.png")


def blade(sp, x0, y0, x1, y1, col):
    sp.fill(m_line(sp.w, sp.h, x0, y0, x1, y1) & ~np.zeros((sp.h, sp.w), bool), col)


def gen_grass():
    r = rng("grass")
    tufts_ = []
    for t in range(3):
        sp = Sprite(16, 16)
        n = (7, 10, 8)[t]
        for i in range(n):
            bx = 8 + (i - n / 2) * 1.2 + r.uniform(-0.5, 0.5)
            ht = r.uniform(6, 14) if t != 0 else r.uniform(5, 9)
            lean = (bx - 8) * 0.5 + r.uniform(-2, 2)
            col = GRASS[1 + (i * 7 + t) % 4]
            blade(sp, bx, 15, bx + lean, 15 - ht, col)
            sp.px(int(round(bx + lean)), int(round(15 - ht)), GRASS[4] if col != GRASS[1] else GRASS[2])
        if t == 2:  # seed heads
            for (x, y) in ((5, 3), (11, 2)):
                sp.fill(m_rect(16, 16, x, y, x, y + 2), hexc("8a8660"))
        sp.outline((6, 10, 10), k=0.25)
        sp.img[15, :, 3] = np.where(sp.img[15, :, :3].sum(-1) < 90, 0, sp.img[15, :, 3])
        tufts_.append(sp)
    save(sheet(tufts_, 3), SPR / "grass.png")


def gen_fern():
    W, H = 24, 16
    sp = Sprite(W, H)
    fern = ramp("1a2e20", "2c4a30", "42663e", "5c8450", "7aa062")
    for k, (ang, L) in enumerate(((-3.0, 11), (-0.15, 11), (-2.6, 13), (-0.55, 13), (-2.1, 14), (-1.05, 14),
                                  (-1.6, 14))):
        x, y = 12.0, 15.0
        a = ang
        for s in range(L):
            a += 0.05 if ang < -1.57 else -0.05
            nx, ny = x + math.cos(a), y + math.sin(a) + (0.1 * (s - L * 0.6) if s > L * 0.6 else 0)
            col = fern[2 + (k % 2)]
            sp.px(round(nx), round(ny), col)
            if s % 2 == 0 and s > 1 and s < L - 1:  # leaflets
                px, py = -math.sin(a), math.cos(a)
                sp.px(round(nx + px), round(ny + py), fern[4] if k < 3 else fern[3])
                sp.px(round(nx - px), round(ny - py), fern[2])
            x, y = nx, ny
    sp.outline((6, 10, 10), k=0.25)
    save(sp, SPR / "fern.png")


def gen_reeds():
    W, H = 16, 24
    sp = Sprite(W, H)
    rd = ramp("1e2418", "34402a", "4c5a38", "68764a")
    for (x, top, lean, c) in ((4, 8, -1, 2), (7, 3, 0, 3), (9, 6, 1, 2), (12, 10, 2, 1), (6, 12, -2, 1), (10, 13, 1, 3)):
        sp.fill(m_line(W, H, x, 23, x + lean, top), rd[c])
    for (x, y) in ((7, 3), (9, 6)):
        cat = m_rect(W, H, x + (0 if x == 7 else 1) - 1, y, x + (0 if x == 7 else 1), y + 4)
        sp.part(cat, ramp("2a1810", "4a2c1c", "6a4228", "84583a"), light="l", dark="r")
        sp.px(x + (0 if x == 7 else 1), y - 1, rd[2])
    sp.outline((6, 10, 8), k=0.25)
    save(sp, SPR / "reeds.png")


def gen_flower():
    W, H = 16, 16
    sp = Sprite(W, H)
    st = GRASS
    sp.fill(m_line(W, H, 8, 15, 7, 7), st[2])
    sp.fill(m_line(W, H, 8, 15, 11, 10), st[2])
    sp.px(6, 11, st[3])
    sp.px(5, 10, st[3])
    sp.px(9, 13, st[3])
    petal = ramp("8a8c9a", "c0c2cc", "e6e8ee", "fbfbff")
    for (cx, cy, r_) in ((7, 5, 2.6), (11.5, 8.5, 1.9)):
        m = np.zeros((H, W), bool)
        for a in range(5):
            t = a * 2 * math.pi / 5 - math.pi / 2
            m |= m_ellipse(W, H, cx + math.cos(t) * r_ * 0.75, cy + math.sin(t) * r_ * 0.75, r_ * 0.55, r_ * 0.55)
        sp.part(m, petal, light="lt", dark="rb")
        sp.px(round(cx), round(cy), hexc("d8b850"))
    sp.outline((10, 12, 14), k=0.25)
    save(sp, SPR / "flower_white.png")


def gen_vines():
    W, H = 32, 64
    sp = Sprite(W, H)
    r = rng("vines")
    ivy = ramp("0e1c16", "1a3024", "2a4832", "3e6242", "567c52")
    stem = hexc("3a3426")
    ys = np.arange(H)
    for (x0, amp, k, ph) in ((7, 3.0, 1, 0.3), (17, 4.0, 2, 1.7), (26, 2.5, 1, 4.0)):
        xs = x0 + amp * np.sin(2 * math.pi * k * ys / H + ph)
        for y in range(H):
            sp.px(int(round(xs[y])), y, stem)
        for j, y in enumerate(range(int(r.integers(0, 6)), H, 7)):
            side = 1 if j % 2 else -1
            lx = xs[y] + side * 2.2
            leaf = np.zeros((H, W), bool)
            for dy in (-1, 0, 1):  # wrap vertically
                leaf |= m_ellipse(W, H, lx, y + dy * H + 1, 1.9, 1.5)
                leaf |= m_ellipse(W, H, lx + side, y + dy * H, 1.3, 1.3)
            sp.part(leaf, ivy, light="lt", dark="rb")
    # outline on a 3x stacked copy so the outline also wraps vertically
    tall = Sprite(W, H * 3)
    tall.img = np.concatenate([sp.img] * 3, 0)
    tall.outline((6, 10, 8), k=0.25)
    sp.img = tall.img[H:2 * H].copy()
    save(sp, SPR / "vines.png")


def gen_cobweb():
    W = H = 32
    sp = Sprite(W, H)
    col = (230, 232, 240)
    angles = [0.05, 0.35, 0.7, 1.05, 1.4]
    Ls = [31, 30, 32, 30, 31]
    for a, L in zip(angles, Ls):
        m = m_line(W, H, 0, 0, math.cos(a) * L, math.sin(a) * L)
        sp.fill(m, col, 190)
    for rad in (5, 10, 15, 20, 25):
        for (a0, a1) in zip(angles, angles[1:]):
            p0 = (math.cos(a0) * rad, math.sin(a0) * rad)
            p1 = (math.cos(a1) * rad, math.sin(a1) * rad)
            mid = ((p0[0] + p1[0]) / 2 * 0.9, (p0[1] + p1[1]) / 2 * 0.9)  # sag toward the corner
            sp.fill(m_line(W, H, *p0, *mid) | m_line(W, H, *mid, *p1), col, 150)
    sp.fill(m_rect(W, H, 0, 0, 1, 1), col, 220)
    save(sp, SPR / "cobweb.png")


# ---------------------------------------------------------------------------
# FX
# ---------------------------------------------------------------------------

FIRE = [hexc("8c2410"), hexc("d05a18"), hexc("f09a30"), hexc("ffd46a"), hexc("fff4d0")]


def fire_frame(w, h, f, tag, base_w, tongues):
    r = rng(f"{tag}{f}")
    sp = Sprite(w, h)
    xs, ys = coords(w, h)
    cx = (w - 1) / 2
    t = (h - 1 - ys) / (h - 1)  # 0 bottom .. 1 top
    lean = [0, 0.8, -0.4, -0.9][f]
    sway = lean * t ** 1.5 * (w / 8)
    halfw = base_w * np.sqrt(np.clip(1 - t, 0, 1)) * np.clip(t * 4 + 0.4, 0, 1)
    d = np.abs(xs - cx - sway) / np.maximum(halfw, 0.01)
    heat = (1 - d) * (1 - t * 0.7) + r.normal(0, 0.06, (h, w))
    heat[halfw < 0.3] = -1
    for (tx, ty, tr) in tongues[f]:  # extra flickering tongues
        heat = np.maximum(heat, 0.35 * (1 - np.hypot(xs - cx - tx - sway, (ys - ty) * 0.6) / tr))
    levels = [(0.02, 0), (0.25, 1), (0.45, 2), (0.65, 3), (0.82, 4)]
    for thr, i in levels:
        m = heat > thr
        sp.fill(m, FIRE[i])
    return sp


def gen_flame():
    tong = [[(0, 3, 1.5)], [(1, 2, 1.4)], [(0, 4, 1.6)], [(-1, 3, 1.3)]]
    frames = [fire_frame(8, 16, f, "flame", 2.6, tong) for f in range(4)]
    for fr in frames:  # blue root of a candle flame
        fr.px(3, 15, hexc("5a6ab0"))
        fr.px(4, 15, hexc("7080c0"))
    save(sheet(frames, 4), SPR / "flame.png")


def gen_torch():
    tong = [[(-3, 6, 2.2), (3, 9, 2.0)], [(2, 4, 2.4), (-3, 10, 1.8)], [(-2, 5, 2.0), (3, 7, 2.2)],
            [(3, 5, 2.2), (-2, 8, 2.0)]]
    frames = [fire_frame(16, 24, f, "torch", 5.5, tong) for f in range(4)]
    r = rng("embers")
    for fr in frames:
        for _ in range(2):
            fr.px(int(r.integers(3, 13)), int(r.integers(0, 6)), FIRE[3])
    save(sheet(frames, 4), SPR / "torch.png")


def soft(w, h, fn):
    a = np.zeros((h, w, 4), np.float32)
    xs, ys = coords(w, h)
    rgb, alpha = fn(xs, ys)
    a[..., :3] = rgb
    a[..., 3] = np.clip(alpha, 0, 1) * 255
    return np.round(a).astype(np.uint8)


def gen_soft_fx():
    save(soft(4, 4, lambda x, y: ((236, 255, 160), [[.25, .6, .6, .25], [.6, 1, 1, .6], [.6, 1, 1, .6],
                                                        [.25, .6, .6, .25]])), SPR / "firefly.png")
    save(soft(8, 8, lambda x, y: ((255, 255, 255), np.exp(-(((x - 3.5) ** 2 + (y - 3.5) ** 2) / 5.0)))),
         SPR / "dust.png")
    save(soft(64, 64, lambda x, y: ((255, 255, 255),
                                    np.clip(1 - np.hypot(x - 31.5, y - 31.5) / 32, 0, 1) ** 2.2)), SPR / "glow.png")
    r = rng("fog")
    n = fbm(128, 64, r, 4, 2, 4)
    def fog(x, y):
        e = np.exp(-(((x - 63.5) / 52) ** 2 + ((y - 34) / 20) ** 2) * 2.2)
        return (255, 255, 255), np.clip(e * (0.35 + 0.9 * n) * 0.75, 0, 0.7)
    save(soft(128, 64, fog), SPR / "fog.png")


# ---------------------------------------------------------------------------
# UI icons (16x16)
# ---------------------------------------------------------------------------

ICON_PAL = {
    "k": (16, 12, 22), "y": (196, 160, 84), "Y": (240, 212, 130), "o": (128, 96, 48),
    "w": (226, 222, 206), "W": (250, 248, 238), "s": (168, 160, 144), "l": (120, 128, 150),
    "r": (122, 42, 44), "R": (164, 70, 66), "p": (70, 22, 28), "g": (190, 160, 90),
    "i": (80, 110, 150), "I": (130, 170, 210), "P": (18, 14, 24), "h": (232, 200, 180), "H": (250, 226, 210),
    "d": (186, 146, 132),
}
ICONS = {
    "key": [
        "................",
        "....kkkkk.......",
        "...kYYYYyk......",
        "..kYk...kyk.....",
        "..kyk...kok.....",
        "..kyk...kok.....",
        "...kyyyyok......",
        "....kkyok.......",
        ".....kyok.......",
        ".....kyokkk.....",
        ".....kyYyyk.....",
        ".....kyokkk.....",
        ".....kyok.......",
        ".....kyYyk......",
        ".....kyokk......",
        "......kk........",
    ],
    "note": [
        "................",
        "..kkkkkkkkkk....",
        "..kWWWWWWWWwk...",
        "..kWllllllwwwk..",
        "..kWWWWWWWWWwk..",
        "..kWlllllllwwk..",
        "..kWWWWWWWWWwk..",
        "..kWllllllwwwk..",
        "..kWWWWWWWWWwk..",
        "..kWlllllllwwk..",
        "..kWWWWWWWWWwk..",
        "..kWllllwwwkkk..",
        "..kWWWWWWWksk...",
        "..kwwwwwwwkk....",
        "..kkkkkkkkk.....",
        "................",
    ],
    "journal": [
        "................",
        "..kkkkkkkkkkk...",
        "..kpRRRRRRRRrk..",
        "..kpRrrrrrrrrk..",
        "..kprrrrrrrrrk..",
        "..kprrkkkkkrrk..",
        "..kprrkggggkrk..",
        "..kprrkkkkkrrk..",
        "..kprrrrrrrrkkk.",
        "..kprrrrrrrkoyk.",
        "..kprrrrrrrkoyk.",
        "..kprrrrrrrrkkk.",
        "..kpWWWWWWWWwk..",
        "..kpswswswswsk..",
        "..kkkkkkkkkkkk..",
        "................",
    ],
    "hand": [
        "................",
        "......kk........",
        ".....kHhk.......",
        ".....kHhk.......",
        ".....kHhk.......",
        ".....kHhkkkk....",
        ".....kHhkHhkkk..",
        "..kk.kHhkHhkHhk.",
        ".kHhkkHhhhhhhhk.",
        ".kHhhkHhhhhhhhk.",
        "..kHhhhhhhhhhhk.",
        "..kHhhhhhhhhhdk.",
        "...kHhhhhhhhhdk.",
        "....khhhhhhhdk..",
        ".....kddddddk...",
        ".....kkkkkkkk...",
    ],
    "eye": [
        "................",
        "................",
        "................",
        "....kkkkkkkk....",
        "..kkWWWkkWWWkk..",
        ".kWWWWkIIkWWWwk.",
        "kWWWWkiIIikWWWwk",
        "kWWWWkiPPikWWwwk",
        "kWWWWkiPPikWwwwk",
        ".kwWWWkiikWwwwk.",
        "..kkwwwkkwwwkk..",
        "....kkkkkkkk....",
        "................",
        "................",
        "................",
        "................",
    ],
}


def gen_icons():
    for name, rows in ICONS.items():
        assert all(len(r) == 16 for r in rows) and len(rows) == 16, name
        save(from_ascii(rows, ICON_PAL), SPR / f"icon_{name}.png")


# ---------------------------------------------------------------------------
# tileable textures
# ---------------------------------------------------------------------------

TS = 64
BAYER4 = np.array([[0, 8, 2, 10], [12, 4, 14, 6], [3, 11, 1, 9], [15, 7, 13, 5]]) / 16.0 - 0.47


def tnoise(w, h, cx, cy, r):
    """Periodic value noise with cx x cy lattice cells (tiles seamlessly)."""
    g = r.random((cy, cx))
    def axis(n, cells):
        u = np.arange(n) * cells / n
        i0 = np.floor(u).astype(int)
        f = u - i0
        f = f * f * (3 - 2 * f)
        return i0 % cells, (i0 + 1) % cells, f
    x0, x1, fx = axis(w, cx)
    y0, y1, fy = axis(h, cy)
    a = g[y0[:, None], x0[None, :]]
    b = g[y0[:, None], x1[None, :]]
    c = g[y1[:, None], x0[None, :]]
    d = g[y1[:, None], x1[None, :]]
    fx, fy = fx[None, :], fy[:, None]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy


def fbm(w, h, r, cx=4, cy=4, octaves=4, persist=0.5):
    out = np.zeros((h, w))
    amp, tot = 1.0, 0.0
    for o in range(octaves):
        k = 2 ** o
        out += amp * tnoise(w, h, min(cx * k, w), min(cy * k, h), r)
        tot += amp
        amp *= persist
    out /= tot
    return (out - out.min()) / (out.max() - out.min() + 1e-9)


def lerp_pal(c0, c1, n):
    c0, c1 = np.array(hexc(c0) if isinstance(c0, str) else c0, float), np.array(
        hexc(c1) if isinstance(c1, str) else c1, float)
    return [tuple((c0 + (c1 - c0) * i / (n - 1)).round().astype(int)) for i in range(n)]


def quant(v, pal, dither=0.5):
    """Map v in [0,1] to a palette with ordered dithering (seamless on 64px)."""
    h, w = v.shape
    b = np.tile(BAYER4, (h // 4, w // 4))
    n = len(pal)
    idx = np.clip(np.floor(v * n + b * dither), 0, n - 1).astype(int)
    return np.array(pal, np.uint8)[idx]


def wrapd(n, c):
    """Signed wrapped distance along an axis of length n."""
    a = np.arange(n, dtype=float)
    return (a - c + n / 2) % n - n / 2


def w_ellipse(cx, cy, rx, ry, ang=0.0, n=TS):
    dx = wrapd(n, cx)[None, :]
    dy = wrapd(n, cy)[:, None]
    ca, sa = math.cos(ang), math.sin(ang)
    u, v = dx * ca + dy * sa, -dx * sa + dy * ca
    return (u / rx) ** 2 + (v / ry) ** 2 <= 1


def w_line(img_mask, x0, y0, x1, y1, n=TS):
    steps = int(max(abs(x1 - x0), abs(y1 - y0))) + 1
    for i in range(steps + 1):
        t = i / max(steps, 1)
        img_mask[int(round(y0 + (y1 - y0) * t)) % n, int(round(x0 + (x1 - x0) * t)) % n] = True
    return img_mask


def voronoi(n_pts, r, n=TS, jitter=0.8):
    """Tileable Voronoi: returns (F1, F2, id, points)."""
    g = int(math.ceil(math.sqrt(n_pts)))
    pts = []
    for i in range(g):
        for j in range(g):
            pts.append(((i + 0.5 + r.uniform(-jitter, jitter) / 2) * n / g,
                        (j + 0.5 + r.uniform(-jitter, jitter) / 2) * n / g))
    pts = np.array(pts)
    d = np.stack([np.hypot(wrapd(n, px)[None, :], wrapd(n, py)[:, None]) for (px, py) in pts])
    order = np.argsort(d, 0)
    ds = np.take_along_axis(d, order, 0)
    return ds[0], ds[1], order[0], pts


def rollmask(m, dx, dy):
    return np.roll(np.roll(m, dy, 0), dx, 1)


def bevel(img, mask, light, dark, amt=1):
    """Tile-aware bevel: lit top-left rim, shadowed bottom-right rim."""
    out = img.astype(int).copy()
    for k in range(1, amt + 1):
        tl = mask & ~rollmask(mask, k, 0) | mask & ~rollmask(mask, 0, k)
        br = mask & ~rollmask(mask, -k, 0) | mask & ~rollmask(mask, 0, -k)
        out[tl] = out[tl] + light
        out[br] = out[br] - dark
    return np.clip(out, 0, 255).astype(np.uint8)


def shade(img, v):
    return np.clip(img.astype(int) + v, 0, 255).astype(np.uint8)


def tex(name, img):
    assert img.shape[:2] == (TS, TS) or name == "", name
    save(img, TEX / f"{name}.png")


def t_grass():
    r = rng("t_grass")
    v = fbm(TS, TS, r, 4, 4, 4) * 0.7 + tnoise(TS, TS, 16, 16, r) * 0.3
    img = quant(v, lerp_pal("3a4c34", "76905e", 6))
    for _ in range(240):
        x, y = int(r.integers(0, TS)), int(r.integers(0, TS))
        L = int(r.integers(2, 4))
        c = r.choice([-22, -14, 18, 26])
        for k in range(L):
            img[(y - k) % TS, (x + (k == L - 1) * int(r.integers(-1, 2))) % TS] = shade(
                img[(y - k) % TS, x % TS], c)
    tex("grass", img)


def t_dirt(name="dirt", c0="4e3e32", c1="8e765e", seed="t_dirt", pebbles=40):
    r = rng(seed)
    v = fbm(TS, TS, r, 4, 4, 4)
    img = quant(v, lerp_pal(c0, c1, 5))
    for _ in range(pebbles):
        x, y = int(r.integers(0, TS)), int(r.integers(0, TS))
        c = shade(img[y, x], int(r.integers(14, 30)))
        img[y, x] = c
        img[y, (x + 1) % TS] = c
        img[(y + 1) % TS, x] = shade(img[(y + 1) % TS, x], -26)
        img[(y + 1) % TS, (x + 1) % TS] = shade(img[(y + 1) % TS, (x + 1) % TS], -26)
    for _ in range(pebbles // 2):
        x, y = int(r.integers(0, TS)), int(r.integers(0, TS))
        img[y, x] = shade(img[y, x], -24)
    tex(name, img)


def t_forest_floor():
    r = rng("t_forest")
    v = fbm(TS, TS, r, 4, 4, 4)
    img = quant(v, lerp_pal("3c3028", "64503e", 4))
    leaf_cols = [hexc(c) for c in ("7a5a3a", "8c6a3e", "6a6440", "74443a", "9a7a4c", "5a5a3c")]
    for _ in range(110):
        cx, cy = r.uniform(0, TS), r.uniform(0, TS)
        m = w_ellipse(cx, cy, r.uniform(1.8, 3.2), r.uniform(1.0, 1.7), r.uniform(0, math.pi))
        c = np.array(leaf_cols[int(r.integers(len(leaf_cols)))])
        img[m] = c
        hi = m & ~rollmask(m, 1, 1)
        img[hi] = shade(c, 16)[None, :]
        lo = m & ~rollmask(m, -1, -1)
        img[lo] = shade(c, -22)[None, :]
    for _ in range(8):  # twigs
        x0, y0 = r.uniform(0, TS), r.uniform(0, TS)
        a, L = r.uniform(0, math.pi), r.uniform(5, 11)
        m = w_line(np.zeros((TS, TS), bool), x0, y0, x0 + math.cos(a) * L, y0 + math.sin(a) * L)
        img[m] = hexc("3a2c22")
    tex("forest_floor", img)


def t_stones(name, n_pts, gap_pal, stone_pal, gap_w, seed, round_=False, gap_grass=False):
    r = rng(seed)
    F1, F2, ids, pts = voronoi(n_pts, r)
    stone = (F2 - F1) > gap_w
    tone = r.uniform(-0.18, 0.18, len(pts))[ids]
    n = fbm(TS, TS, r, 8, 8, 3)
    if round_:
        v = 0.55 + tone + 0.35 * (1 - F1 / (F1 + (F2 - F1) / 2 + 1e-6)) * 0.6 + (n - 0.5) * 0.3
    else:
        v = 0.5 + tone + (n - 0.5) * 0.45
    img = quant(np.clip(v, 0, 1), stone_pal, 0.6)
    gn = fbm(TS, TS, r, 4, 4, 3)
    gimg = quant(gn, gap_pal, 0.8)
    img[~stone] = gimg[~stone]
    img = bevel(img, stone, 20, 26, 1)
    if round_:
        # top-left highlight on each cobble
        for (px, py) in pts:
            m = w_ellipse(px - 2.2, py - 2.2, 2.0, 1.4) & stone
            img[m] = shade(img[m], 14)
    tex(name, img)


def t_rows_blocks(name, rows, widths_fn, stone_pal, mortar, seed, moss=None, bevel_amt=1, noise_amt=0.45):
    """Generic masonry: rows of (height) with blocks per row, all wrapping."""
    r = rng(seed)
    img = np.zeros((TS, TS, 3), np.uint8)
    ids = np.full((TS, TS), -1)
    blk = 0
    y = 0
    n = fbm(TS, TS, r, 8, 8, 3)
    for ri, hgt in enumerate(rows):
        x = int(r.integers(0, TS))
        ws = widths_fn(ri, r)
        for w_ in ws:
            for yy in range(y, y + hgt - 1):
                for xx in range(x, x + w_ - 1):
                    ids[yy % TS, xx % TS] = blk
            blk += 1
            x += w_
        y += hgt
    tones = r.uniform(-0.16, 0.16, blk + 1)
    v = np.clip(0.5 + tones[ids] + (n - 0.5) * noise_amt, 0, 1)
    img = quant(v, stone_pal, 0.6)
    solid = ids >= 0
    img[~solid] = mortar
    img = bevel(img, solid, 18, 24, bevel_amt)
    if moss is not None:
        mn = fbm(TS, TS, r, 4, 4, 4)
        top = solid & ~rollmask(solid, 0, 1)
        near_top = top | rollmask(top, 0, -1) & solid
        mm = (mn > 0.72) | (near_top & (mn > 0.52)) | (~solid & (mn > 0.55))
        mimg = quant(np.clip((mn - 0.4) * 2, 0, 1), moss, 0.8)
        img[mm] = mimg[mm]
    return img, ids, solid


def fixed_widths(total, w):
    return lambda ri, r: [w] * (total // w)


def rand_widths(lo, hi):
    def f(ri, r):
        out, s = [], 0
        while TS - s > hi:
            w = int(r.integers(lo, hi + 1))
            out.append(w)
            s += w
        rest = TS - s
        if rest < lo:
            out[-1] += rest
        else:
            out.append(rest)
        return out
    return f


def t_brick():
    r = rng("t_brick")
    img = np.zeros((TS, TS, 3), np.uint8)
    n = fbm(TS, TS, r, 8, 8, 3)
    solid = np.zeros((TS, TS), bool)
    tone = np.zeros((TS, TS))
    for row in range(8):
        off = 8 if row % 2 else 0
        for b in range(4):
            x0 = b * 16 + off
            t = r.uniform(-0.2, 0.2)
            for yy in range(row * 8, row * 8 + 7):
                for xx in range(x0, x0 + 15):
                    solid[yy, xx % TS] = True
                    tone[yy, xx % TS] = t
    v = np.clip(0.5 + tone + (n - 0.5) * 0.5, 0, 1)
    img = quant(v, lerp_pal("5c3a34", "a0685a", 6), 0.6)
    img[~solid] = hexc("6c6660")
    img = bevel(img, solid, 16, 22)
    for _ in range(30):  # chips
        x, y = int(r.integers(0, TS)), int(r.integers(0, TS))
        if solid[y, x]:
            img[y, x] = shade(img[y, x], -30)
    tex("brick", img)


def t_stone_wall():
    img, _, _ = t_rows_blocks("stone_wall", [12, 10, 11, 10, 11, 10], rand_widths(10, 22),
                              lerp_pal("5a5c64", "a0a2a8", 6), hexc("3e3c40"), "t_stonewall")
    tex("stone_wall", img)


def t_dungeon_stone():
    img, _, _ = t_rows_blocks("dungeon_stone", [16, 16, 16, 16], lambda ri, r: [32, 32],
                              lerp_pal("4c5054", "8e9092", 6), hexc("2e3030"), "t_dungeon",
                              moss=lerp_pal("34462e", "586e46", 4), bevel_amt=2)
    tex("dungeon_stone", img)


def t_gravestone():
    r = rng("t_grave")
    v = fbm(TS, TS, r, 4, 4, 5) * 0.8 + tnoise(TS, TS, 32, 32, r) * 0.2
    img = quant(v, lerp_pal("6a6c70", "a4a4a6", 6), 0.7)
    lich = fbm(TS, TS, r, 8, 8, 3)
    m = lich > 0.78
    img[m] = quant(lich, lerp_pal("6c705a", "84886a", 3))[m]
    for _ in range(50):
        x, y = int(r.integers(0, TS)), int(r.integers(0, TS))
        img[y, x] = shade(img[y, x], -28)
        img[(y + 1) % TS, x] = shade(img[(y + 1) % TS, x], 12)
    tex("gravestone", img)


def planks(name, pal, seed, horizontal=True, count=8, gap=hexc("24180f"), grain_cells=(2, 16), knots=3,
           nails=True, jitter_w=False, seams=True):
    r = rng(seed)
    gx, gy = grain_cells
    n = fbm(TS, TS, r, gx, gy, 3) if horizontal else fbm(TS, TS, r, gy, gx, 3)
    stripes = tnoise(TS, TS, 1 if horizontal else 32, 32 if horizontal else 1, r)
    img = np.zeros((TS, TS, 3), np.uint8)
    if jitter_w:
        widths = rand_widths(6, 12)(0, r)
    else:
        widths = [TS // count] * count
    solid = np.ones((TS, TS), bool)
    tone = np.zeros((TS, TS))
    pos = 0
    for w_ in widths:
        t = r.uniform(-0.15, 0.15)
        seam = int(r.integers(0, TS))
        if horizontal:
            tone[pos:pos + w_, :] = t
            solid[pos + w_ - 1, :] = False
            if seams:
                solid[pos:pos + w_, seam] = False
                tone[pos:pos + w_, seam:] += r.uniform(-0.08, 0.08) if seam < TS else 0
        else:
            tone[:, pos:pos + w_] = t
            solid[:, pos + w_ - 1] = False
            if seams:
                solid[seam, pos:pos + w_] = False
        if nails and seams:
            for dd in (-2, 2):
                if horizontal:
                    img_pos = ((pos + w_ // 2 - 1) % TS, (seam + dd) % TS)
                else:
                    img_pos = ((seam + dd) % TS, (pos + w_ // 2 - 1) % TS)
                tone[img_pos] = -0.45
        pos += w_
    v = np.clip(0.5 + tone + (n - 0.5) * 0.5 + (stripes - 0.5) * 0.25, 0, 1)
    img = quant(v, pal, 0.55)
    for _ in range(knots):
        cx, cy = r.uniform(0, TS), r.uniform(0, TS)
        m = w_ellipse(cx, cy, 2.2 if horizontal else 1.3, 1.3 if horizontal else 2.2) & solid
        img[m] = pal[0]
        img[w_ellipse(cx, cy, 1, 1) & solid] = pal[1]
    img[~solid] = gap
    img = bevel(img, solid, 10, 0)
    return img


def t_woods():
    tex("wood_floor", planks("wood_floor", lerp_pal("5a4232", "a07a58", 6), "t_woodfloor"))
    tex("wood_wall", planks("wood_wall", lerp_pal("5a4a3c", "9a8468", 6), "t_woodwall", horizontal=False,
                            jitter_w=True, seams=False, knots=4))
    tex("planks_dark", planks("planks_dark", lerp_pal("342820", "6a5240", 5), "t_planksdark",
                              gap=hexc("221812"), knots=5))
    tex("ceiling_wood", planks("ceiling_wood", lerp_pal("46342a", "82644a", 5), "t_ceiling", count=4,
                               nails=False, knots=2))


def t_bark():
    r = rng("t_bark")
    n = fbm(TS, TS, r, 8, 2, 4)
    ridge = 1 - np.abs(n - 0.5) * 2
    v = np.clip(ridge * 0.8 + fbm(TS, TS, r, 16, 16, 2) * 0.3, 0, 1)
    img = quant(v, lerp_pal("3c3230", "8a7a68", 6), 0.5)
    tex("bark", img)


def t_metal(rust=False):
    r = rng("t_metal" + ("r" if rust else ""))
    brushed = fbm(TS, TS, r, 2, 32, 3)
    v = 0.45 + (brushed - 0.5) * 0.35 + (fbm(TS, TS, r, 4, 4, 3) - 0.5) * 0.3
    img = quant(np.clip(v, 0, 1), lerp_pal("3e4048", "7e828e", 6), 0.6)
    solid = np.ones((TS, TS), bool)
    solid[31, :] = solid[63, :] = False
    solid[:, 31] = solid[:, 63] = False
    img[~solid] = hexc("26262c")
    img = bevel(img, solid, 16, 18)
    for bx in (4, 27, 36, 59):
        for by in (4, 27, 36, 59):
            m = w_ellipse(bx, by, 1.5, 1.5)
            img[m] = hexc("6a6e78")
            img[by - 1, bx - 1] = hexc("a4a8b2")
            img[(by + 1) % TS, (bx + 1) % TS] = hexc("2c2c34")
    if rust:
        rn = fbm(TS, TS, r, 4, 4, 5)
        streak = fbm(TS, TS, r, 8, 2, 3)
        m = (rn * 0.7 + streak * 0.3) > 0.58
        rimg = quant(np.clip((rn - 0.4) * 1.8, 0, 1), lerp_pal("5a3222", "a8683c", 5), 0.8)
        img[m] = rimg[m]
        pits = r.random((TS, TS)) < 0.03
        img[pits & m] = hexc("3a1e14")
    tex("rust_metal" if rust else "metal", img)


def t_wallpaper_stripes():
    r = rng("t_wps")
    xs = np.arange(TS)
    img = np.zeros((TS, TS, 3), np.uint8)
    base = np.array(hexc("2e3a58"), int)
    band = np.array(hexc("3c4c70"), int)
    line = np.array(hexc("56668c"), int)
    for x in range(TS):
        p = x % 16
        c = band if p < 7 else base
        if p in (8, 15):
            c = line
        img[:, x] = c
    # small dots on the dark band
    for y in range(0, TS, 4):
        for x in range(0, TS, 16):
            img[y, x + 11 + (y // 4) % 2] = band
    age = fbm(TS, TS, r, 2, 4, 4)
    img = shade(img, ((age - 0.5) * 26).astype(int)[..., None])
    stain = fbm(TS, TS, r, 4, 2, 3) > 0.7
    img[stain] = shade(img[stain], -10)
    tex("wallpaper_stripes", img)


def t_wallpaper_damask():
    r = rng("t_dmk")
    base, motif, hi = hexc("2c3754"), hexc("40507a"), hexc("526490")
    img = np.zeros((TS, TS, 3), np.uint8)
    img[:] = base
    for (cx, cy, s) in ((16, 16, 1.0), (48, 48, 1.0), (48, 16, 0.5), (16, 48, 0.5)):
        m = np.zeros((TS, TS), bool)
        m |= w_ellipse(cx, cy, 2.2 * s + 0.6, 6.5 * s)
        m |= w_ellipse(cx, cy - 8 * s, 1.2 * s + 0.5, 2.2 * s + 0.4)
        m |= w_ellipse(cx, cy + 8 * s, 1.5 * s + 0.5, 1.5 * s + 0.4)
        for side in (-1, 1):
            m |= w_ellipse(cx + side * 5.5 * s, cy - 2 * s, 1.6 * s + 0.4, 4.2 * s, side * 0.6)
            m |= w_ellipse(cx + side * 5 * s, cy + 5 * s, 3.2 * s, 1.2 * s + 0.4, -side * 0.5)
            ring = w_ellipse(cx + side * 9 * s, cy - 6 * s, 2.2 * s + 0.4, 2.2 * s + 0.4) & ~w_ellipse(
                cx + side * 9 * s, cy - 6 * s, 1.1 * s, 1.1 * s)
            m |= ring if s > 0.6 else np.zeros_like(m)
        img[m] = motif
        hl = m & ~rollmask(m, 1, 0)
        img[hl] = hi
    # diamond lattice of fine dots
    for y in range(0, TS, 8):
        for x in range((y // 8) % 2 * 4, TS, 8):
            if (img[y, x] == base).all():
                img[y, x] = shade(np.array(base), 10)
    age = fbm(TS, TS, r, 2, 4, 4)
    img = shade(img, ((age - 0.5) * 22).astype(int)[..., None])
    tex("wallpaper_damask", img)


def contour(n, level):
    """1px iso-lines of a tileable field (wraps)."""
    a = n > level
    return (a ^ np.roll(a, -1, 1)) | (a ^ np.roll(a, -1, 0))


def marble(v_pal, vein_col, seed, vein_w=None, n_cells=3):
    r = rng(seed)
    n = fbm(TS, TS, r, n_cells, n_cells, 5)
    img = quant(fbm(TS, TS, r, 4, 4, 4), v_pal, 0.7)
    main = contour(n, 0.5)
    faint = contour(n, 0.32) | contour(fbm(TS, TS, r, 2, 2, 5), 0.6)
    img[faint] = ((np.array(vein_col, int) + img[faint].astype(int) * 2) // 3).astype(np.uint8)
    img[main] = vein_col
    return img


def t_tile_checker():
    wht = marble(lerp_pal("b8b8c0", "dcdce2", 4), hexc("9a9aa6"), "t_mw")
    blk = marble(lerp_pal("34343e", "4c4c58", 3), hexc("74747e"), "t_mb")
    ys, xs = np.mgrid[0:TS, 0:TS]
    chk = ((xs // 32) + (ys // 32)) % 2 == 0
    img = np.where(chk[..., None], wht, blk)
    grout = (xs % 32 == 31) | (ys % 32 == 31)
    img[grout] = hexc("5c5c64")
    tex("tile_checker", img.astype(np.uint8))


def tiles(name, size, pal_fn, grout, seed, bevel_=True):
    r = rng(seed)
    ys, xs = np.mgrid[0:TS, 0:TS]
    img = np.zeros((TS, TS, 3), np.uint8)
    n = fbm(TS, TS, r, 8, 8, 2)
    for ty in range(TS // size):
        for tx in range(TS // size):
            pal = pal_fn(tx, ty)
            t = r.uniform(-0.12, 0.12)
            sl = (slice(ty * size, ty * size + size), slice(tx * size, tx * size + size))
            v = np.clip(0.55 + t + (n[sl] - 0.5) * 0.4, 0, 1)
            img[sl] = quant(v, pal, 0.5)
    solid = ~((xs % size == size - 1) | (ys % size == size - 1))
    img[~solid] = grout
    if bevel_:
        img = bevel(img, solid, 14, 16)
    tex(name, img)


def t_tiles():
    tiles("tile_bath", 8, lambda x, y: lerp_pal("c4c8ce", "e6eaee", 3), hexc("8a9096"), "t_bath")
    tiles("tile_kitchen", 16, lambda x, y: lerp_pal("c2b89c", "dcd2b6", 3) if (x + y) % 2 == 0 else
          lerp_pal("5e7a76", "7e9894", 3), hexc("6a665c"), "t_kitchen")


def t_roof():
    r = rng("t_roof")
    ys, xs = np.mgrid[0:TS, 0:TS]
    img = np.zeros((TS, TS, 3), np.uint8)
    n = fbm(TS, TS, r, 8, 8, 3)
    tone = np.zeros((TS, TS))
    solid = np.ones((TS, TS), bool)
    for row in range(8):
        off = 4 if row % 2 else 0
        for b in range(8):
            t = r.uniform(-0.18, 0.18)
            x0 = b * 8 + off
            for yy in range(row * 8, row * 8 + 8):
                for xx in range(x0, x0 + 8):
                    tone[yy, xx % TS] = t
            # rounded bottom corners + gap
            for xx in (x0, x0 + 7):
                solid[row * 8 + 7, xx % TS] = False
            solid[row * 8 + 6, x0 % TS] = False
            solid[row * 8 + 7, (x0 + 1) % TS] = False
            solid[row * 8 + 7, (x0 + 6) % TS] = False
            for yy in range(row * 8, row * 8 + 5):
                solid[yy, (x0 + 7) % TS] = False
    grad = (ys % 8) / 7.0  # each shingle lighter at the bottom lip
    v = np.clip(0.35 + tone + grad * 0.35 + (n - 0.5) * 0.35, 0, 1)
    img = quant(v, lerp_pal("3a3e4a", "7a808e", 6), 0.6)
    img[~solid] = hexc("22242c")
    tex("roof", img)


def t_carpet():
    r = rng("t_carpet")
    ys, xs = np.mgrid[0:TS, 0:TS]
    fib = fbm(TS, TS, r, 16, 16, 2)
    v = 0.5 + (fib - 0.5) * 0.4 + (fbm(TS, TS, r, 4, 4, 3) - 0.5) * 0.3
    img = quant(np.clip(v, 0, 1), lerp_pal("5a1c22", "92363a", 5), 0.8)
    dx, dy = np.abs((xs % 16) - 7.5), np.abs((ys % 16) - 7.5)
    diamond = np.abs(dx + dy - 6) < 0.6
    dot = (dx + dy) < 1.5
    img[diamond] = hexc("8a6a44")
    img[dot] = hexc("a88450")
    lattice = ((xs % 32 == 0) | (ys % 32 == 0))
    img[lattice] = hexc("3e1418")
    tex("carpet_red", img)


def t_bed_cloth():
    r = rng("t_bed")
    ys, xs = np.mgrid[0:TS, 0:TS]
    folds = fbm(TS, TS, r, 2, 3, 3)
    weave = ((xs + ys) % 2) * 0.05
    v = np.clip(0.35 + folds * 0.55 + weave, 0, 1)
    img = quant(v, lerp_pal("948f8c", "d2d0cc", 6), 0.6)
    quilt = ((xs + ys) % 16 == 0) | ((xs - ys) % 16 == 0)
    img[quilt] = shade(img[quilt], -14)
    tex("bed_cloth", img)


def t_marble_white():
    tex("marble_white", marble(lerp_pal("e2e2e6", "f8f8fa", 3), hexc("c6c8d0"), "t_marbw", vein_w=0.025))


def t_plaster():
    r = rng("t_plaster")
    v = fbm(TS, TS, r, 4, 4, 5) * 0.7 + r.random((TS, TS)) * 0.3
    img = quant(v, lerp_pal("968e82", "bcb4a6", 5), 0.8)
    m = np.zeros((TS, TS), bool)
    x, y = r.uniform(0, TS), r.uniform(0, TS)
    for _ in range(40):
        nx, ny = x + r.uniform(-1.5, 1.5), y + r.uniform(0.3, 1.6)
        w_line(m, x, y, nx, ny)
        x, y = nx, ny
    img[m] = hexc("6e685e")
    tex("plaster", img)


def t_water():
    r = rng("t_water")
    ys, xs = np.mgrid[0:TS, 0:TS].astype(float)
    n = fbm(TS, TS, r, 4, 4, 3)
    ph = 2 * math.pi * (xs * 1 + ys * 3) / TS + n * 4
    ph2 = 2 * math.pi * (xs * -2 + ys * 2) / TS + n * 3
    v = 0.5 + 0.25 * np.sin(ph) + 0.15 * np.sin(ph2) + (n - 0.5) * 0.3
    img = quant(np.clip(v, 0, 1), lerp_pal("1e3a48", "4a7a86", 6), 0.5)
    hl = (np.sin(ph) > 0.93) & (n > 0.45)
    img[hl] = hexc("7aa6ae")
    tex("water", img)


def t_curtain():
    r = rng("t_curtain")
    ys, xs = np.mgrid[0:TS, 0:TS].astype(float)
    ph = 2 * math.pi * xs * 4 / TS + 0.8 * np.sin(2 * math.pi * xs / TS + 0.4)
    wob = fbm(TS, TS, r, 4, 2, 3)
    v = 0.5 + 0.42 * np.sin(ph + (wob - 0.5) * 0.8) + (fbm(TS, TS, r, 8, 16, 2) - 0.5) * 0.12
    img = quant(np.clip(v, 0, 1), lerp_pal("3e141a", "8e3a3e", 6), 0.4)
    tex("curtain", img)


def gen_textures():
    t_grass()
    t_dirt()
    t_forest_floor()
    t_stones("stone_path", 12, lerp_pal("3e3a30", "5a5444", 3), lerp_pal("6a6a6c", "a8a6a0", 6), 1.6, "t_path")
    t_stones("cobble", 25, lerp_pal("34322e", "4a4640", 2), lerp_pal("5e6068", "9c9ea4", 6), 1.1, "t_cobble",
             round_=True)
    t_brick()
    t_stone_wall()
    t_woods()
    t_wallpaper_stripes()
    t_wallpaper_damask()
    t_tile_checker()
    t_tiles()
    t_roof()
    t_bark()
    t_metal()
    t_metal(rust=True)
    t_carpet()
    t_bed_cloth()
    t_marble_white()
    t_plaster()
    t_water()
    t_gravestone()
    t_dungeon_stone()
    t_dirt("dirt_dark", "30282a", "5e5048", "t_dirtdark", 30)
    t_curtain()


# ---------------------------------------------------------------------------
# preview
# ---------------------------------------------------------------------------


def contact_sheets(outdir: Path):
    outdir.mkdir(parents=True, exist_ok=True)
    bg = (38, 44, 62, 255)
    sprites = [p for p in OUTPUTS if p.parent == SPR]
    texs = [p for p in OUTPUTS if p.parent == TEX]

    def pack(paths, scale, maxw, name, tile=False):
        ims = []
        for p in paths:
            im = Image.open(p).convert("RGBA")
            if tile:
                t = Image.new("RGBA", (im.width * 2, im.height * 2))
                for i in range(2):
                    for j in range(2):
                        t.paste(im, (i * im.width, j * im.height))
                im = t
            im = im.resize((im.width * scale, im.height * scale), Image.NEAREST)
            ims.append((p.stem, im))
        x = y = 8
        rowh = 0
        placed = []
        for name_, im in ims:
            if x + im.width + 8 > maxw:
                x = 8
                y += rowh + 20
                rowh = 0
            placed.append((name_, im, x, y))
            x += im.width + 8
            rowh = max(rowh, im.height)
        H = y + rowh + 20
        out = Image.new("RGBA", (maxw, H), bg)
        d = ImageDraw.Draw(out)
        for name_, im, x, y in placed:
            out.alpha_composite(im, (x, y))
            d.text((x, y + im.height + 2), name_, fill=(220, 220, 230, 255))
        out.save(outdir / f"{name}.png")

    chars = [p for p in sprites if p.stem.startswith("char_") and "portrait" not in p.stem]
    if chars:
        pack(chars, 4, 1100, "sheet_chars")
    rest = [p for p in sprites if p not in chars]
    big = [p for p in rest if Image.open(p).width * Image.open(p).height > 64 * 64]
    small = [p for p in rest if p not in big]
    if big:
        pack(big, 3, 1400, "sheet_big")
    if small:
        pack(small, 4, 1400, "sheet_small")
    if texs:
        pack(texs[:15], 2, 1400, "sheet_tex1", tile=True)
        pack(texs[15:], 2, 1400, "sheet_tex2", tile=True)


def main():
    ap = argparse.ArgumentParser()
    ap.add_argument("--preview", type=Path, default=None, help="write contact sheets here")
    ap.add_argument("--only", default="", help="comma list of groups: chars,props,fx,ui,tex")
    args = ap.parse_args()
    groups = set(args.only.split(",")) if args.only else {"chars", "props", "fx", "ui", "tex"}
    if "chars" in groups:
        gen_char(CHAR_A)
        gen_char(CHAR_B)
        gen_portrait(CHAR_A)
        gen_portrait(CHAR_B)
        gen_monster()
        gen_corpse()
        gen_crow()
    if "props" in groups:
        gen_tree_pine()
        gen_tree_dead()
        gen_tree_oak()
        gen_bush()
        gen_grass()
        gen_fern()
        gen_reeds()
        gen_flower()
        gen_vines()
        gen_cobweb()
    if "fx" in groups:
        gen_flame()
        gen_torch()
        gen_soft_fx()
    if "ui" in groups:
        gen_icons()
    if "tex" in groups:
        gen_textures()
    for p in OUTPUTS:
        print(p.relative_to(ROOT))
    if args.preview:
        contact_sheets(args.preview)


if __name__ == "__main__":
    main()
