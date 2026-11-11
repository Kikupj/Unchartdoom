#!/usr/bin/env python3
"""Generates every original texture, sprite and UI graphic for Ancient Bounties.
   Usage: gen_art.py <build dir>     (deterministic: fixed seeds)"""
import os, sys, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
import numpy as np
from PIL import Image, ImageDraw, ImageFilter
from artlib import *

B = sys.argv[1] if len(sys.argv) > 1 else 'build'
TEX = os.path.join(B, 'textures'); SPR = os.path.join(B, 'sprites', 'ab'); GFX = os.path.join(B, 'graphics', 'ab')
def tex(name, img): save_png(img, os.path.join(TEX, name + '.png'))
def spr(name, img, off=None):
    if off is None: off = (img.width // 2, img.height)          # feet at bottom centre
    save_png(img, os.path.join(SPR, name + '.png'), off)
def gfx(name, img): save_png(img, os.path.join(GFX, name + '.png'))

# ------------------------------------------------------------------ palettes
P_JSTONE = [(0, (24, 26, 20)), (0.3, (64, 66, 54)), (0.6, (112, 110, 92)), (1, (168, 162, 136))]
P_MOSS   = [(0, (16, 34, 12)), (0.5, (48, 86, 28)), (1, (104, 142, 46))]
P_JROCK  = [(0, (18, 20, 16)), (0.35, (58, 56, 44)), (0.7, (104, 98, 78)), (1, (150, 142, 112))]
P_DSTONE = [(0, (66, 44, 24)), (0.3, (146, 106, 62)), (0.6, (198, 158, 102)), (1, (236, 208, 150))]
P_DROCK  = [(0, (58, 34, 20)), (0.35, (132, 86, 50)), (0.7, (186, 136, 84)), (1, (226, 186, 128))]
P_HROCK  = [(0, (26, 30, 38)), (0.4, (84, 90, 102)), (0.7, (142, 148, 160)), (1, (214, 220, 230))]
P_SNOW   = [(0, (150, 168, 196)), (0.5, (214, 224, 238)), (1, (252, 253, 255))]
P_CROCK  = [(0, (10, 18, 22)), (0.4, (42, 62, 66)), (0.7, (82, 106, 102)), (1, (150, 170, 150))]
P_CSTONE = [(0, (54, 46, 36)), (0.4, (134, 122, 98)), (0.7, (186, 176, 146)), (1, (228, 222, 194))]
P_WOOD   = [(0, (26, 16, 8)), (0.4, (86, 56, 30)), (0.7, (130, 90, 50)), (1, (176, 132, 82))]
P_DKWOOD = [(0, (14, 8, 6)), (0.4, (58, 34, 22)), (0.7, (92, 56, 36)), (1, (130, 86, 56))]
P_GOLD   = [(0, (70, 40, 6)), (0.4, (170, 112, 16)), (0.7, (236, 184, 40)), (1, (255, 244, 170))]
GOLD = (232, 180, 44, 255); GOLD_D = (150, 98, 18, 255); GOLD_L = (255, 236, 150, 255)

# ------------------------------------------------------------------ glyphs
GLYPH_NAMES = ['sun', 'serpent', 'jaguar', 'moon', 'eye', 'hand']
def glyph_mask(i, size=64):
    k = 4; S = size * k; im = Image.new('L', (S, S), 0); d = ImageDraw.Draw(im)
    def L(pts, w=5): d.line([(x * S / 64, y * S / 64) for x, y in pts], fill=255, width=int(w * k), joint='curve')
    def E(x0, y0, x1, y1, f=255): d.ellipse([x0 * S / 64, y0 * S / 64, x1 * S / 64, y1 * S / 64], fill=f)
    def Pg(pts, f=255): d.polygon([(x * S / 64, y * S / 64) for x, y in pts], fill=f)
    if i == 0:      # sun
        E(21, 21, 43, 43); E(27, 27, 37, 37, 0)
        for a in range(8):
            c, s_ = math.cos(a * math.pi / 4), math.sin(a * math.pi / 4)
            L([(32 + c * 15, 32 + s_ * 15), (32 + c * 25, 32 + s_ * 25)], 4)
    elif i == 1:    # serpent
        pts = [(12 + t * 40 / 20, 34 + 12 * math.sin(t * math.pi * 2.2 / 20)) for t in range(21)]
        L(pts, 6); E(46, 22, 58, 34); E(51, 25, 54, 28, 0); L([(57, 28), (62, 24)], 2); L([(57, 28), (62, 31)], 2)
    elif i == 2:    # jaguar
        Pg([(14, 12), (24, 22), (40, 22), (50, 12), (52, 34), (42, 50), (32, 54), (22, 50), (12, 34)])
        E(20, 28, 28, 34, 0); E(36, 28, 44, 34, 0); Pg([(29, 40), (35, 40), (32, 44)], 0)
        Pg([(25, 46), (28, 46), (26.5, 51)], 0); Pg([(36, 46), (39, 46), (37.5, 51)], 0)
    elif i == 3:    # moon
        E(12, 10, 54, 54); E(24, 6, 60, 46, 0); E(40, 40, 46, 46)
    elif i == 4:    # eye
        Pg([(6, 32), (20, 18), (32, 14), (44, 18), (58, 32), (44, 44), (32, 48), (20, 44)])
        Pg([(13, 32), (22, 23), (32, 20), (42, 23), (51, 32), (42, 39), (32, 42), (22, 39)], 0)
        E(25, 24, 39, 40); E(29, 28, 35, 34, 0); L([(32, 50), (32, 58)], 3); L([(22, 48), (18, 55)], 3); L([(42, 48), (46, 55)], 3)
    else:           # hand
        Pg([(20, 30), (44, 30), (44, 50), (38, 58), (26, 58), (20, 50)])
        for x in (20, 26.5, 33, 39.5): d.rounded_rectangle([x * S / 64, 8 * S / 64 if x in (26.5, 33) else 12 * S / 64, (x + 4.5) * S / 64, 34 * S / 64], radius=2 * k, fill=255)
        Pg([(44, 36), (54, 26), (57, 30), (46, 46)]); E(28, 38, 36, 46, 0)
    return np.array(im.resize((size, size), Image.LANCZOS)) / 255.0

def carve(img, mask, x0, y0, depth=0.55, hl=1.25, tint=None):
    """Carve glyph mask into an RGB float array at x0,y0."""
    h, w = mask.shape; reg = img[y0:y0 + h, x0:x0 + w]
    sh = np.roll(np.roll(mask, 1, 0), 1, 1)
    lit = np.clip(sh - mask, 0, 1)
    reg *= (1 - mask[..., None] * (1 - depth))
    reg *= (1 + lit[..., None] * (hl - 1))
    if tint is not None: reg[:] = reg * (1 - 0.6 * mask[..., None]) + np.array(tint) * 0.6 * mask[..., None]
    return img

def gen_textures():
    # ---------------- jungle
    tex('JSTONE1', stone_wall(128, 128, 32, 16, 11, P_JSTONE, P_MOSS, 0.50))
    j2 = stone_wall(128, 128, 64, 32, 12, P_JSTONE, P_MOSS, 0.38, vary=0.0)
    for gx in range(2): carve(j2, glyph_mask((gx * 2 + 1) % 6, 48), 8 + gx * 64, 40)
    j2[30:33] *= 0.55; j2[96:99] *= 0.55; tex('JSTONE2', j2)
    tex('JSTONE3', stone_wall(128, 128, 64, 64, 13, P_JSTONE, P_MOSS, 0.30, vary=0.0, rough=0.35))
    tex('JROCK1', rock(128, 128, 14, P_JROCK) * 0.9 + stone_wall(128, 128, 128, 128, 15, P_JSTONE, P_MOSS, 0.55) * 0.1)
    jr = rock(128, 128, 14, P_JROCK); m = np.clip((fbm(128, 128, 16, 32) - 0.48) * 7, 0, 1)[..., None]
    tex('JROCK1', jr * (1 - m) + ramp(0.3 + 0.6 * fbm(128, 128, 17, 8), P_MOSS) * m)
    # foliage wall: layered leaves
    r = rng(21); fol = Image.new('RGB', (128, 128), (10, 26, 10)); d = ImageDraw.Draw(fol)
    for layer, (n, lo, hi) in enumerate([(260, (12, 34, 12), (22, 58, 18)), (220, (22, 62, 20), (44, 104, 30)), (130, (50, 112, 34), (98, 160, 52))]):
        for _ in range(n):
            x, y = r.integers(0, 128), r.integers(0, 128); ln = r.integers(7, 15); an = r.uniform(0, math.pi); wd = r.integers(3, 6)
            t = r.random(); col = tuple(int(lo[c] + (hi[c] - lo[c]) * t) for c in range(3))
            dx, dy = math.cos(an) * ln, math.sin(an) * ln
            for ox in (-128, 0, 128):
                for oy in (-128, 0, 128):
                    px, py = x + ox, y + oy
                    d.polygon([(px - dx, py - dy), (px - dy * wd / ln, py + dx * wd / ln), (px + dx, py + dy), (px + dy * wd / ln, py - dx * wd / ln)], fill=col)
                    d.line([(px - dx, py - dy), (px + dx, py + dy)], fill=tuple(int(c * 0.72) for c in col))
    tex('JFOLI1', np.array(fol).astype(float) * (0.85 + 0.3 * fbm(128, 128, 22, 32)[..., None]))
    tex('JGRASS', ground(64, 64, 23, [(0, (14, 34, 10)), (0.5, (40, 78, 24)), (1, (86, 128, 40))], base=8, speck=0.25))
    tex('JDIRT', ground(64, 64, 24, [(0, (34, 22, 12)), (0.5, (84, 60, 36)), (1, (128, 100, 64))], base=16, speck=0.16))
    jf = stone_wall(64, 64, 32, 32, 25, P_JSTONE, P_MOSS, 0.42, vary=0.0); tex('JFLOOR', jf)
    tex('JCEIL', stone_wall(64, 64, 32, 32, 26, P_JSTONE, None, 0, vary=0.0) * 0.6)
    # ---------------- desert
    tex('DSTONE1', stone_wall(128, 128, 64, 32, 31, P_DSTONE, vary=0.0, rough=0.18, mortar_dark=0.3))
    d2 = stone_wall(128, 128, 128, 64, 32, P_DSTONE, vary=0.0, rough=0.15, mortar_dark=0.3)
    seq = [0, 4, 1, 5, 3, 2, 4, 0]
    for i in range(8): carve(d2, glyph_mask(seq[i], 28), 3 + (i % 4) * 32, 2 + (i // 4) * 64 + 16, depth=0.5, tint=(70, 40, 20))
    for y in (10, 54, 74, 118): d2[y:y + 2] *= 0.6
    tex('DSTONE2', d2)
    tex('DSTONE3', stone_wall(128, 128, 32, 16, 33, P_DSTONE, vary=0.2, rough=0.22, mortar_dark=0.32))
    tex('DROCK1', rock(128, 128, 34, P_DROCK, strata=1.0, ridged=False, contrast=0.9))
    sv = fbm(64, 64, 35, 16, 3); ys = np.arange(64)[:, None] + 5 * tnoise(64, 64, 16, 36)
    tex('DSAND', ramp(0.5 + 0.5 * (sv - 0.5) + 0.07 * np.sin(ys * 2 * math.pi * 4 / 64) + grain(64, 64, 37, 0.1), [(0, (150, 108, 60)), (0.5, (208, 168, 106)), (1, (244, 218, 160))]))
    tex('DFLOOR', stone_wall(64, 64, 32, 32, 38, P_DSTONE, vary=0.0, rough=0.2, mortar_dark=0.3))
    tex('DCEIL', stone_wall(64, 64, 64, 32, 39, P_DSTONE, vary=0.0, rough=0.2) * 0.55)
    # ---------------- himalaya
    hr = rock(128, 128, 41, P_HROCK); sn = np.clip((fbm(128, 128, 42, 32) + np.linspace(0.22, -0.18, 128)[:, None] - 0.5) * 7, 0, 1)[..., None]
    tex('HROCK1', hr * (1 - sn) + ramp(0.5 + 0.6 * (fbm(128, 128, 43, 16) - 0.5), P_SNOW) * sn)
    hw = ramp(0.62 + 0.25 * (fbm(128, 128, 44, 32) - 0.5) + grain(128, 128, 45, 0.05), [(0, (120, 110, 96)), (0.6, (206, 198, 182)), (1, (244, 240, 230))])
    hw[0:20] = planks(128, 20, 46, [(0, (40, 6, 6)), (0.5, (122, 22, 18)), (1, (176, 50, 34))], pw=16)            # red timber frieze
    hw[20:24] = ramp(0.6 + grain(128, 4, 47, 0.3), P_GOLD)
    hw[100:128] = planks(128, 28, 48, P_DKWOOD, pw=16); hw[98:100] *= 0.5
    for x in range(0, 128, 32):                                                                           # gold studs
        hw[8:12, x + 14:x + 18] = (236, 190, 60)
    tex('HWALL1', hw)
    tex('HWOOD1', planks(128, 128, 49, P_DKWOOD, pw=16))
    ht = planks(128, 128, 50, [(0, (40, 6, 6)), (0.5, (122, 22, 18)), (1, (176, 50, 34))], pw=32)
    for i in range(4): carve(ht, glyph_mask([0, 3, 4, 1][i], 24), 4 + i * 32, 52, depth=0.2, tint=(240, 196, 70))
    tex('HWALL2', ht)
    tex('HSNOW', ground(64, 64, 51, P_SNOW, base=16, speck=0.05, contrast=0.8))
    tex('HFLOOR', planks(64, 64, 52, P_DKWOOD, pw=16, vertical=False))
    tex('HICE', ground(64, 64, 53, [(0, (60, 110, 150)), (0.5, (130, 180, 214)), (1, (226, 244, 252))], base=16, speck=0.04, contrast=1.3))
    tex('HCEIL', planks(64, 64, 54, P_DKWOOD, pw=8) * 0.7)
    # ---------------- caribbean
    tex('CROCK1', rock(128, 128, 61, P_CROCK, contrast=1.1))
    tex('CSTONE1', stone_wall(128, 128, 32, 16, 62, P_CSTONE, P_MOSS, 0.22, vary=0.2))
    tex('CWOOD1', planks(128, 128, 63, P_WOOD, pw=16))
    cw = planks(128, 128, 64, P_WOOD, pw=16, vertical=False); cw[60:68] *= 0.45
    for x in range(8, 128, 24): cw[61:67, x:x + 3] = (60, 60, 64)
    tex('CWOOD2', cw)
    tex('CSAND', ground(64, 64, 65, [(0, (170, 146, 100)), (0.5, (222, 204, 160)), (1, (250, 242, 214))], base=16, speck=0.08, contrast=0.7))
    tex('CPLANK', planks(64, 64, 66, P_WOOD, pw=16, vertical=False))
    tex('CFLOOR', stone_wall(64, 64, 32, 32, 67, P_CSTONE, P_MOSS, 0.2, vary=0.0))
    tex('CCEIL', rock(64, 64, 68, P_CROCK) * 0.7)
    # ---------------- shared set pieces
    for i in range(6):                                           # glyph tiles for murals
        t = stone_wall(64, 64, 64, 64, 70 + i, P_JSTONE, None, 0, vary=0.0, rough=0.3); t[:3] *= 0.6; t[-3:] *= 0.6; t[:, :3] *= 0.6; t[:, -3:] *= 0.6
        carve(t, glyph_mask(i, 48), 8, 8, depth=0.35, tint=(226, 176, 50)); tex('ABGLY%d' % i, t)
    # stone gate (sun seal)
    g = stone_wall(128, 128, 128, 128, 80, P_JSTONE, P_MOSS, 0.18, vary=0.0, rough=0.3)
    yy, xx = np.mgrid[0:128, 0:128]; rr = np.hypot(xx - 64, yy - 64)
    g *= np.where((rr > 44) & (rr < 48), 0.5, 1)[..., None]; g *= np.where((rr > 27) & (rr < 29), 0.6, 1)[..., None]
    carve(g, glyph_mask(0, 48), 40, 40, depth=0.4, tint=(226, 176, 50))
    for a in range(12):
        cx, cy = int(64 + 37 * math.cos(a * math.pi / 6)), int(64 + 37 * math.sin(a * math.pi / 6)); g[cy - 2:cy + 2, cx - 2:cx + 2] *= 0.5
    g[:, 62:66] *= 0.45; g[:4] *= 0.5; g[-4:] *= 0.5; tex('ABGATE', g)
    # timber door
    dr = planks(64, 128, 81, P_WOOD, pw=16)
    for y in (14, 108): dr[y:y + 8] = ramp(0.35 + grain(64, 8, 82 + y, 0.2), [(0, (20, 20, 24)), (1, (110, 112, 120))])
    dr[60:68, 50:56] = (214, 170, 60); tex('ABDOOR', dr)
    # rival banner: crimson with meridian compass emblem
    bn = ramp(0.5 + 0.35 * (fbm(64, 128, 83, 16) - 0.5) + 0.08 * np.sin(np.arange(64)[None, :] * 0.6), [(0, (60, 4, 8)), (0.5, (150, 16, 22)), (1, (206, 44, 40))])
    em = Image.new('L', (256, 256), 0); d = ImageDraw.Draw(em)
    d.ellipse([28, 28, 228, 228], outline=255, width=14); d.line([128, 4, 128, 252], fill=255, width=12); d.line([4, 128, 252, 128], fill=255, width=12)
    d.polygon([(128, 40), (150, 128), (128, 216), (106, 128)], fill=255); d.ellipse([110, 110, 146, 146], fill=0)
    emk = np.array(em.resize((44, 44), Image.LANCZOS)) / 255.0
    bn[30:74, 10:54] = bn[30:74, 10:54] * (1 - emk[..., None]) + np.array((244, 232, 206)) * emk[..., None]
    bn[:4] = (226, 180, 60); bn[122:] *= 0.6; bn[:, :2] *= 0.6; bn[:, -2:] *= 0.6
    for x in range(64):                                           # swallow-tail bottom
        cut = 116 + abs(x - 32) // 3
    tex('ABBANNER', bn)
    tex('ABCANVAS', ramp(0.55 + 0.3 * (fbm(128, 128, 84, 32) - 0.5) + 0.05 * np.sin(np.arange(128)[None, :] * 0.4) + grain(128, 128, 85, 0.08),
                         [(0, (52, 50, 30)), (0.5, (128, 122, 82)), (1, (184, 178, 130))]))
    cam = fbm(64, 64, 86, 16, 3)
    tex('ABCAMO', ramp(np.round(cam * 4) / 4 + grain(64, 64, 87, 0.05), [(0, (22, 30, 16)), (0.4, (58, 70, 36)), (0.7, (96, 92, 54)), (1, (40, 44, 26))]))
    # gold hoard wall / floor
    r = rng(88); gh = Image.new('RGB', (128, 128), (60, 34, 6)); d = ImageDraw.Draw(gh)
    for _ in range(900):
        x, y = int(r.integers(0, 128)), int(r.integers(0, 128)); t = r.random(); c = tuple(int(v) for v in ramp(np.array([0.3 + 0.7 * t]), P_GOLD)[0])
        for ox in (-128, 0, 128):
            d.ellipse([x + ox - 4, y - 2, x + ox + 4, y + 2], fill=c, outline=tuple(int(v * 0.55) for v in c))
    tex('ABGOLDW', np.array(gh).astype(float))
    tex('ABGOLDF', np.array(gh.resize((64, 64), Image.LANCZOS)).astype(float))
    # campaign map table top
    mt = ramp(0.7 + 0.2 * (fbm(64, 64, 89, 16) - 0.5), [(0, (120, 96, 60)), (1, (236, 220, 176))]); mt[:3] = mt[-3:] = (60, 40, 22); mt[:, :3] = mt[:, -3:] = (60, 40, 22)
    mi = to_img(mt); d = ImageDraw.Draw(mi); d.line([(10, 40), (22, 30), (34, 34), (48, 18)], fill=(170, 20, 20), width=1)
    for p in [(10, 40), (48, 18)]: d.ellipse([p[0] - 2, p[1] - 2, p[0] + 2, p[1] + 2], fill=(170, 20, 20))
    d.polygon([(14, 14), (26, 10), (30, 20), (20, 24)], outline=(90, 70, 40)); d.polygon([(36, 44), (54, 40), (52, 54), (40, 56)], outline=(90, 70, 40))
    tex('ABMAPTB', mi)

def gen_skies():
    def sky(name, top, mid, hor, seed, ridge_col, ridge_h=0.22, cloud=(255, 255, 255), cloud_amt=0.5, sun=None, stars=False, ridge2=None):
        W, H = 1024, 256
        t = np.linspace(0, 1, H)[:, None] * np.ones((1, W))
        img = ramp(t, [(0, top), (0.55, mid), (0.82, hor), (1, hor)])
        if stars:
            r = rng(seed + 9)
            for _ in range(500):
                x, y = r.integers(0, W), r.integers(0, int(H * 0.7)); img[y, x] = (255, 255, 240) if r.random() > 0.3 else (160, 170, 200)
        if sun:
            yy, xx = np.mgrid[0:H, 0:W]; rr = np.hypot(xx - sun[0], yy - sun[1])
            img += np.clip(1 - rr / sun[2], 0, 1)[..., None] ** 2 * np.array(sun[3]) ; img = np.clip(img, 0, 255)
            img[rr < sun[2] * 0.12] = sun[4]
        c = fbm(W, H, seed, base=128, octaves=5); c = np.clip((c - (1 - cloud_amt * 0.9)) * 5, 0, 1) * np.clip(1.2 - t * 1.2, 0, 1)
        img = img * (1 - c[..., None] * 0.85) + np.array(cloud) * c[..., None] * 0.85
        for rc, rh, sd in ([(ridge2, ridge_h * 1.5, seed + 3)] if ridge2 else []) + [(ridge_col, ridge_h, seed + 5)]:
            hgt = tnoise(W, 1, 64, sd)[0] * 0.6 + tnoise(W, 1, 16, sd + 1)[0] * 0.3 + tnoise(W, 1, 4, sd + 2)[0] * 0.1
            top_y = (H * (0.86 - rh * hgt)).astype(int)
            for x in range(W): img[top_y[x]:, x] = np.array(rc) * (0.8 + 0.2 * (np.arange(H - top_y[x]) / max(1, H - top_y[x])))[:, None][::-1]
        tex(name, img)
    sky('ABSKYJ', (40, 110, 190), (130, 190, 226), (214, 232, 214), 101, (20, 52, 26), 0.25, cloud_amt=0.55, ridge2=(74, 120, 110))
    sky('ABSKYD', (40, 96, 190), (140, 180, 220), (246, 220, 170), 102, (156, 104, 56), 0.16, cloud_amt=0.30, sun=(760, 60, 150, (90, 80, 40), (255, 252, 230)), ridge2=(206, 160, 110))
    sky('ABSKYH', (24, 60, 140), (110, 150, 206), (214, 226, 240), 103, (226, 232, 244), 0.55, cloud_amt=0.45, ridge2=(150, 166, 198))
    sky('ABSKYC', (20, 120, 200), (120, 200, 230), (236, 240, 220), 104, (16, 70, 60), 0.10, cloud_amt=0.60, sun=(300, 50, 130, (80, 80, 50), (255, 255, 236)))
    sky('ABSKYN', (10, 10, 36), (60, 30, 70), (226, 110, 50), 105, (10, 16, 14), 0.24, cloud=(120, 60, 70), cloud_amt=0.45, stars=True, sun=(512, 214, 190, (120, 60, 10), (255, 214, 130)), ridge2=(40, 26, 44))
    sky('ABSKYS', (14, 18, 30), (50, 56, 74), (110, 116, 130), 106, (16, 18, 24), 0.12, cloud=(90, 94, 110), cloud_amt=0.85)

if __name__ == '__main__':
    import gen_art_sprites, gen_art_ui
    gen_textures(); gen_skies()
    gen_art_sprites.run(sys.modules[__name__]); gen_art_ui.run(sys.modules[__name__])
    print('art generated')
