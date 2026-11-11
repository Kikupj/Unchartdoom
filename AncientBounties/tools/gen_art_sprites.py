"""Original sprites for Ancient Bounties: treasure, puzzle props, decor, camp."""
import math
import numpy as np
from PIL import Image, ImageDraw
from artlib import *

STONE = (120, 116, 98, 255); STONE_D = (74, 72, 60, 255); STONE_L = (166, 160, 136, 255)
GOLD = (232, 180, 44, 255); GOLD_D = (150, 98, 18, 255); GOLD_L = (255, 236, 150, 255)
WOOD = (120, 80, 44, 255); WOOD_D = (70, 44, 24, 255); WOOD_L = (160, 116, 70, 255)
GLOWS = [(230, 60, 40), (70, 210, 80), (70, 140, 250), (250, 200, 60)]      # red green blue gold

def glow_layer(w, h, cx, cy, rad, col, strength=1.0):
    yy, xx = np.mgrid[0:h, 0:w]; r = np.hypot(xx - cx, (yy - cy)) / rad
    a = np.clip(1 - r, 0, 1) ** 1.6 * 255 * strength
    out = np.zeros((h, w, 4)); out[..., :3] = col; out[..., 3] = a
    return to_img(out)

def over(base, top):
    b = base.copy(); b.alpha_composite(top); return b

def run(G):
    spr, gfx, glyph_mask = G.spr, G.gfx, G.glyph_mask
    # ------------------------------------------------------------ treasure
    s = Spr(22, 12); r = rng(5)
    for i in range(16):
        x, y = 3 + r.random() * 14, 3 + r.random() * 6 + (abs(x - 10) * 0.25 if i else 0)
        s.ell(x - 3, y - 1.5, x + 3, y + 1.5, GOLD_D); s.ell(x - 2.6, y - 1.8, x + 2.4, y + 0.8, GOLD if i % 3 else GOLD_L)
    spr('ABCNA0', s.finish(seed=1))
    s = Spr(24, 14)
    for (x, y) in [(2, 8), (12, 8), (7, 3)]:
        s.poly([(x, y + 5), (x + 2, y), (x + 9, y), (x + 11, y + 5)], GOLD_D); s.poly([(x + 2, y), (x + 9, y), (x + 8, y + 2), (x + 3, y + 2)], GOLD_L); s.poly([(x + 1, y + 5), (x + 3, y + 2), (x + 8, y + 2), (x + 10, y + 5)], GOLD)
    spr('ABBRA0', s.finish(seed=2))
    for i, c in enumerate([(220, 40, 50, 255), (50, 200, 90, 255), (60, 130, 240, 255)]):
        s = Spr(12, 12); s.poly([(6, 0.5), (11.5, 4.5), (6, 11.5), (0.5, 4.5)], c); s.poly([(6, 0.5), (8.5, 4.5), (6, 11.5), (3.5, 4.5)], lighter(c, 1.35)); s.poly([(0.5, 4.5), (11.5, 4.5), (6, 6)], darker(c, 0.8)); s.poly([(4, 2), (5.5, 1.5), (4.5, 4)], (255, 255, 255, 255))
        spr('ABJW%s0' % 'ABC'[i], s.finish(seed=3 + i, light=0.2))
    s = Spr(16, 22); s.ell(1, 0, 15, 8, GOLD_D); s.poly([(1, 4), (15, 4), (11, 12), (5, 12)], GOLD); s.ell(2, 1, 14, 6, (90, 20, 30, 255)); s.rect(7, 12, 9, 18, GOLD_D); s.ell(3, 17, 13, 22, GOLD); s.ell(6.5, 12.5, 9.5, 15.5, (220, 40, 50, 255)); s.poly([(3, 5), (5, 5), (6, 11), (5, 11)], GOLD_L)
    spr('ABCHA0', s.finish(seed=7))
    def idol(s, ox=0, oy=0, c=GOLD, cd=GOLD_D, cl=GOLD_L):
        s.rect(ox + 3, oy + 25, ox + 17, oy + 30, cd); s.poly([(ox + 5, oy + 25), (ox + 6, oy + 13), (ox + 14, oy + 13), (ox + 15, oy + 25)], c)
        s.poly([(ox + 2, oy + 14), (ox + 6, oy + 13), (ox + 6, oy + 20), (ox + 3, oy + 21)], cd); s.poly([(ox + 18, oy + 14), (ox + 14, oy + 13), (ox + 14, oy + 20), (ox + 17, oy + 21)], cd)
        s.rect(ox + 4, oy + 3, ox + 16, oy + 13, c); s.poly([(ox + 3, oy + 3), (ox + 10, oy - 1), (ox + 17, oy + 3)], cd)
        s.rect(ox + 6, oy + 6, ox + 9, oy + 8, (40, 20, 10, 255)); s.rect(ox + 11, oy + 6, ox + 14, oy + 8, (40, 20, 10, 255)); s.rect(ox + 7, oy + 10, ox + 13, oy + 11.5, (40, 20, 10, 255))
        s.rect(ox + 5, oy + 4, ox + 6.5, oy + 12, cl); s.rect(ox + 7, oy + 15, ox + 8.5, oy + 24, cl); s.ell(ox + 8.5, oy + 16, ox + 11.5, oy + 19, (220, 40, 50, 255))
    s = Spr(20, 31); idol(s, 0, 1); spr('ABIDA0', s.finish(seed=8))
    for f in range(2):                                   # great treasure, pulsing halo
        s = Spr(30, 46, 4); s.rect(3, 38, 27, 46, STONE_D); s.rect(5, 34, 25, 39, STONE); idol(s, 5, 3)
        base = s.finish(seed=9)
        big = Image.new('RGBA', (56, 64), (0, 0, 0, 0)); big.alpha_composite(glow_layer(56, 64, 28, 26, 26 + f * 3, (255, 220, 110), 0.55 + 0.15 * f)); big.alpha_composite(base, (13, 18))
        spr('ABRL%s0' % 'AB'[f], big, (28, 64))
    s = Spr(24, 17); s.rect(1, 4, 23, 17, (70, 50, 34, 255)); s.rect(1, 4, 23, 7, (50, 34, 22, 255)); s.rect(9, 1, 15, 4, (40, 28, 18, 255)); s.rect(10, 2, 14, 4, (0, 0, 0, 0)); s.rect(10, 8, 14, 11, (200, 180, 90, 255)); s.rect(3, 12, 21, 13, (176, 20, 26, 255)); s.poly([(14, 3), (22, 0), (23, 5), (15, 7)], (236, 228, 204, 255))
    spr('ABINA0', s.finish(seed=10))
    s = Spr(28, 20); s.rect(1, 3, 27, 20, (74, 86, 46, 255)); s.rect(1, 3, 27, 6, (96, 110, 60, 255)); s.rect(1, 10, 27, 12, (50, 58, 30, 255)); s.rect(4, 3, 6, 20, (50, 58, 30, 255)); s.rect(22, 3, 24, 20, (50, 58, 30, 255)); s.rect(11, 13, 17, 18, (236, 228, 204, 255)); s.rect(13, 14, 15, 17, (190, 30, 30, 255)); s.rect(12, 15, 16, 16, (190, 30, 30, 255)); s.rect(10, 0, 18, 3, (60, 60, 60, 255)); s.rect(11, 1, 17, 3, (0, 0, 0, 0))
    spr('ABSPA0', s.finish(seed=11))
    s = Spr(30, 18)
    for i in range(4): s.poly([(1, 13 - i * 2), (22, 9 - i * 2), (23, 11 - i * 2), (2, 15 - i * 2)], WOOD if i % 2 else WOOD_L)
    s.rect(16, 9, 29, 18, (150, 40, 34, 255)); s.rect(16, 9, 29, 11, (190, 60, 50, 255)); s.rect(20, 6, 25, 9, (60, 60, 64, 255)); s.rect(21, 7, 24, 9, (0, 0, 0, 0)); s.rect(21, 13, 24, 15, (220, 200, 90, 255)); s.ell(2, 14, 8, 18, (130, 134, 142, 255)); s.ell(3.5, 15.2, 6.5, 17, (60, 60, 64, 255))
    spr('ABMTA0', s.finish(seed=12))
    def urn(s, c=(150, 84, 50, 255)):
        s.ell(2, 8, 20, 28, c); s.rect(7, 2, 15, 9, c); s.ell(5, 0, 17, 4, darker(c)); s.ell(7, 1, 15, 3, (30, 16, 10, 255)); s.rect(5, 25, 17, 28, darker(c)); s.poly([(3, 14), (6, 12), (9, 14), (12, 12), (15, 14), (18, 12), (19, 14), (19, 16), (3, 16)], (226, 196, 120, 255)); s.rect(5, 11, 6.5, 22, lighter(c))
    s = Spr(22, 28); urn(s); spr('ABURA0', s.finish(seed=13))
    s = Spr(22, 28); urn(s, (90, 110, 130, 255)); spr('ABURB0', s.finish(seed=14))
    s = Spr(14, 14); s.poly([(2, 12), (1, 5), (6, 1), (11, 3), (13, 9), (8, 13)], GOLD); s.poly([(6, 1), (11, 3), (9, 6), (5, 5)], GOLD_L); s.rect(5, 7, 8, 9, (40, 20, 10, 255)); spr('ABFGA0', s.finish(seed=15))
    # ------------------------------------------------------------ puzzle props
    for f in range(2):
        s = Spr(26, 38); s.poly([(2, 38), (5, 26), (21, 26), (24, 38)], STONE); s.rect(5, 24, 21, 27, STONE_L); s.rect(11, 25, 15, 27, (30, 26, 20, 255))
        x1 = 6 if f == 0 else 20
        s.line([(13, 26), (x1, 6)], WOOD_D, 2.4); s.line([(13.4, 26), (x1 + .4, 6)], WOOD_L, 0.8); s.ell(x1 - 3.5, 2, x1 + 3.5, 9, (190, 40, 36, 255)); s.ell(x1 - 2, 3, x1 + 0.5, 5.5, (250, 150, 130, 255))
        spr('ABLV%s0' % 'AB'[f], s.finish(seed=20 + f))
    for i in range(6):                                    # glyph tablets (hover above levers) + lit
        m = glyph_mask(i, 24)
        for lit in range(2):
            s = Spr(30, 30); s.poly([(3, 30), (1, 4), (6, 0), (24, 0), (29, 4), (27, 30)], STONE if not lit else (150, 140, 110, 255)); s.poly([(4, 3), (7, 1), (23, 1), (26, 3)], STONE_L)
            im = s.finish(seed=30 + i)
            a = np.array(im).astype(float); reg = a[3:27, 3:27]; col = np.array((70, 60, 44, 255) if not lit else (255, 214, 80, 255), float)
            reg[:] = reg * (1 - m[..., None]) + col * m[..., None]; a[3:27, 3:27] = reg; im = to_img(a)
            if lit:
                big = Image.new('RGBA', (46, 46), (0, 0, 0, 0)); big.alpha_composite(glow_layer(46, 46, 23, 23, 23, (255, 210, 90), 0.6)); big.alpha_composite(im, (8, 8)); im = big
            spr('ABG%s%s0' % ('LM'[lit], 'ABCDEF'[i]), im, (im.width // 2, im.height + 34))
    def brazier(s):
        s.poly([(8, 44), (11, 24), (17, 24), (20, 44)], STONE_D); s.rect(6, 41, 22, 44, STONE); s.poly([(2, 16), (26, 16), (21, 25), (7, 25)], (96, 70, 40, 255)); s.ell(2, 12, 26, 20, (130, 96, 54, 255)); s.ell(4, 13.5, 24, 18.5, (30, 20, 14, 255))
    s = Spr(28, 44); brazier(s); spr('ABBZA0', s.finish(seed=40))
    for ci, col in enumerate(GLOWS):
        for f in range(2):
            s = Spr(28, 44); brazier(s); base = s.finish(seed=40)
            fl = Spr(28, 44); c = col + (255,); r = rng(41 + f)
            pts = [(6, 17), (8 + r.random() * 2, 8), (11, 12), (14 + r.random() * 2 - 1, 0 + f * 2), (17, 11), (20 - r.random() * 2, 7), (22, 17)]
            fl.poly(pts, c); fl.poly([(9, 17), (11, 11), (14, 6 + f), (17, 11), (19, 17)], lighter(c, 1.5)); fl.poly([(11.5, 17), (14, 11), (16.5, 17)], (255, 255, 230, 255))
            fim = fl.finish(outline=None, light=0, noise=0)
            big = Image.new('RGBA', (52, 60), (0, 0, 0, 0)); big.alpha_composite(glow_layer(52, 60, 26, 24, 26, col, 0.5)); big.alpha_composite(base, (12, 16)); big.alpha_composite(fim, (12, 16))
            spr('ABBZ%s0' % 'BCDEFGHI'[ci * 2 + f], big, (26, 60))
    for f in range(2):
        s = Spr(52, 12); y = 2 if f == 0 else 5
        s.ell(0, 3, 52, 12, STONE_D); s.ell(4, y, 48, y + 6, STONE_L if f == 0 else STONE); s.ell(16, y + 1.5, 36, y + 4.5, GOLD_D if f == 0 else (90, 220, 110, 255))
        spr('ABPP%s0' % 'AB'[f], s.finish(seed=50 + f, light=0.2))
    s = Spr(50, 50); s.rect(1, 1, 49, 50, STONE); s.rect(1, 1, 49, 4, STONE_L); s.rect(1, 46, 49, 50, STONE_D); s.rect(46, 1, 49, 50, STONE_D); s.rect(8, 9, 42, 43, STONE_D); s.rect(10, 11, 40, 41, STONE)
    im = s.finish(seed=52, noise=0.12); a = np.array(im).astype(float); m = glyph_mask(2, 28); reg = a[12:40, 11:39]; reg[..., :3] *= (1 - 0.45 * m[..., None]); im = to_img(a); spr('ABBKA0', im)
    for ci in range(5):                                   # totems: A dark, B..E lit
        s = Spr(30, 66); s.rect(4, 4, 26, 66, STONE); s.rect(2, 60, 28, 66, STONE_D); s.poly([(2, 6), (15, 0), (28, 6)], STONE_D); s.rect(4, 22, 26, 24, STONE_D); s.rect(4, 44, 26, 46, STONE_D); s.rect(4, 4, 6.5, 60, STONE_L)
        eye = (40, 34, 26, 255) if ci == 0 else GLOWS[ci - 1] + (255,)
        s.rect(8, 9, 13, 13, eye); s.rect(17, 9, 22, 13, eye); s.rect(10, 16, 20, 19, eye); s.ell(10, 28, 20, 40, eye); s.rect(9, 50, 21, 56, eye)
        im = s.finish(seed=55)
        if ci:
            big = Image.new('RGBA', (62, 82), (0, 0, 0, 0)); big.alpha_composite(glow_layer(62, 82, 31, 40, 34, GLOWS[ci - 1], 0.6)); big.alpha_composite(im, (16, 16)); spr('ABTT%s0' % 'ABCDE'[ci], big, (31, 82))
        else: spr('ABTTA0', im)
    s = Spr(40, 58); s.poly([(2, 58), (4, 8), (12, 0), (28, 0), (36, 8), (38, 58)], STONE); s.poly([(5, 8), (12, 2), (28, 2), (35, 8)], STONE_L); s.rect(7, 12, 33, 50, STONE_D)
    im = s.finish(seed=60, noise=0.1); a = np.array(im).astype(float)
    for k, (gx, gy) in enumerate([(8, 13), (21, 13), (8, 26), (21, 26)]):
        m = glyph_mask([0, 1, 3, 4][k], 11); reg = a[gy:gy + 11, gx:gx + 11]; reg[:] = reg * (1 - m[..., None]) + np.array((226, 190, 90, 255.)) * m[..., None]
    spr('ABSTA0', to_img(a))
    for f in range(2):
        s = Spr(44, 30); s.rect(2, 22, 42, 30, STONE_D); s.rect(6, 8, 38, 23, STONE); s.rect(3, 4, 41, 9, STONE_L); s.rect(10, 12, 34, 20, STONE_D)
        if f: s.ell(17, -4, 27, 6, GOLD)
        im = s.finish(seed=62)
        if f:
            big = Image.new('RGBA', (60, 46), (0, 0, 0, 0)); big.alpha_composite(glow_layer(60, 46, 30, 14, 22, (255, 220, 110), 0.6)); big.alpha_composite(im, (8, 16)); spr('ABALB0', big, (30, 46))
        else: spr('ABALA0', im)
    for f, hgt in enumerate([3, 12, 24]):
        s = Spr(34, 26); s.ell(0, 20, 34, 26, (36, 30, 26, 255))
        for i in range(5):
            x = 4 + i * 6.5; s.poly([(x - 2.2, 24), (x, 24 - hgt), (x + 2.2, 24)], (170, 176, 186, 255)); s.poly([(x - 0.3, 24), (x, 24 - hgt), (x + 2.2, 24)], (96, 100, 112, 255))
        spr('ABSK%s0' % 'ABC'[f], s.finish(seed=64, light=0.1))
    s = Spr(12, 5); s.rect(0, 2, 9, 3, WOOD); s.poly([(8, 0.5), (12, 2.5), (8, 4.5)], (190, 196, 206, 255)); s.poly([(0, 0.5), (3, 2.5), (0, 4.5)], (190, 40, 36, 255)); spr('ABDTA0', s.finish(seed=65, outline=None), (6, 3))
    for f in range(3):                                    # extraction flare smoke
        W, H = 40, 96; r = rng(70 + f); a = np.zeros((H, W, 4))
        im = Image.new('RGBA', (W, H), (0, 0, 0, 0)); d = ImageDraw.Draw(im)
        for i in range(26):
            y = H - 8 - i * 3.3; rad = 3 + i * 0.5; x = W / 2 + math.sin(i * 0.5 + f * 2.1) * (1 + i * 0.28) + r.random() * 2
            al = int(230 * (1 - i / 28)); g = 170 + int(r.random() * 70)
            d.ellipse([x - rad, y - rad, x + rad, y + rad], fill=(60 + i * 3, g, 70 + i * 2, al))
        d.rectangle([W / 2 - 2, H - 8, W / 2 + 2, H - 1], fill=(190, 40, 36, 255)); d.ellipse([W / 2 - 4, H - 13, W / 2 + 4, H - 5], fill=(220, 255, 200, 255))
        spr('ABEX%s0' % 'ABC'[f], im)
    # ------------------------------------------------------------ decor
    def leaves(s, cx, cy, n, ln, cols, seed, spread=math.pi, up=-math.pi / 2, droop=0.35, wd=3.0):
        r = rng(seed)
        for i in range(n):
            a = up + (i / (n - 1) - 0.5) * spread + (r.random() - 0.5) * 0.2; L = ln * (0.75 + r.random() * 0.4); c = cols[i % len(cols)]
            pts = []; px, py = cx, cy
            for t in range(7):
                aa = a + (t / 6) ** 2 * droop * (1 if math.cos(a) > 0 else -1) * 2.2
                px += math.cos(aa) * L / 6; py += math.sin(aa) * L / 6 + (t / 6) * droop * 1.5; pts.append((px, py))
            s.line([(cx, cy)] + pts, c, wd)
            s.line([(cx, cy)] + pts, darker(c, 0.75), wd * 0.25)
    GR = [(30, 84, 26, 255), (52, 116, 34, 255), (84, 150, 46, 255), (40, 100, 30, 255)]
    s = Spr(48, 32); leaves(s, 24, 31, 13, 22, GR, 80, spread=2.6, wd=3.2); spr('ABV1A0', s.finish(seed=80, light=0.25))
    s = Spr(100, 150); s.line([(48, 150), (50, 110), (54, 70), (52, 34)], (96, 70, 44, 255), 6); s.line([(47, 150), (49, 110), (53, 70), (51, 34)], (130, 98, 60, 255), 2)
    for y in range(40, 150, 9): s.line([(46 + (150 - y) * 0.04, y), (56 + (150 - y) * 0.04, y - 2)], (70, 50, 30, 255), 1)
    leaves(s, 52, 34, 11, 44, GR, 81, spread=5.6, droop=0.9, wd=5.5); s.ell(47, 30, 53, 37, (110, 70, 30, 255)); s.ell(52, 32, 58, 39, (90, 56, 24, 255))
    spr('ABV2A0', s.finish(seed=81, light=0.3))
    s = Spr(38, 28); r = rng(82)
    for i in range(14):
        a = -math.pi / 2 + (i / 13 - 0.5) * 2.4; L = 14 + r.random() * 10
        s.line([(19, 27), (19 + math.cos(a) * L * 0.6, 27 + math.sin(a) * L * 0.6), (19 + math.cos(a + 0.3) * L, 27 + math.sin(a + 0.3) * L)], (140, 110, 60, 255) if i % 2 else (104, 80, 44, 255), 1.2)
    spr('ABV3A0', s.finish(seed=82, light=0.2))
    s = Spr(72, 132); s.rect(33, 100, 39, 132, (70, 46, 28, 255))
    for i in range(7):
        y = 8 + i * 15; w = 8 + i * 4.4; s.poly([(36, y - 8), (36 + w, y + 14), (36 - w, y + 14)], (22, 62, 40, 255)); s.poly([(36, y - 8), (36 + w * 0.6, y + 6), (36 - w * 0.6, y + 6)], (236, 242, 250, 255)); s.poly([(36, y + 2), (36 + w * 0.8, y + 14), (36 - w * 0.2, y + 14)], (30, 84, 54, 255))
    spr('ABV4A0', s.finish(seed=83, light=0.3))
    s = Spr(30, 62); s.rect(3, 54, 27, 62, STONE_D); s.poly([(6, 54), (6, 10), (10, 4), (14, 12), (19, 2), (24, 9), (24, 54)], STONE)
    for x in (9, 14, 19): s.rect(x, 14, x + 1.4, 54, STONE_D)
    s.rect(6, 10, 8, 54, STONE_L); spr('ABV5A0', s.finish(seed=84, noise=0.1))
    s = Spr(64, 92); s.rect(6, 4, 9, 92, WOOD_D); s.line([(8, 6), (62, 34)], (60, 50, 40, 255), 0.8)
    for i, c in enumerate([(60, 110, 220, 255), (240, 240, 240, 255), (214, 50, 44, 255), (60, 170, 80, 255), (240, 200, 60, 255)]):
        x = 13 + i * 10; y = 9 + i * 5.2; s.poly([(x, y), (x + 8, y + 4.2), (x + 7, y + 15), (x - 1, y + 11)], c)
    spr('ABV6A0', s.finish(seed=85), (8, 92))
    s = Spr(28, 30); s.ell(8, 0, 22, 13, (226, 220, 196, 255)); s.rect(11, 11, 19, 16, (226, 220, 196, 255)); s.ell(10.5, 4, 14, 8.5, (30, 24, 20, 255)); s.ell(16, 4, 19.5, 8.5, (30, 24, 20, 255)); s.rect(12.5, 13, 13.5, 16, (30, 24, 20, 255)); s.rect(15, 13, 16, 16, (30, 24, 20, 255)); s.rect(16.5, 13, 17.5, 16, (30, 24, 20, 255))
    s.line([(2, 28), (26, 20)], (206, 200, 176, 255), 2.4); s.line([(2, 20), (26, 28)], (206, 200, 176, 255), 2.4); s.poly([(5, 2), (24, 0), (26, 3), (22, 5), (8, 6)], (110, 70, 40, 255))
    spr('ABV7A0', s.finish(seed=86))
    s = Spr(14, 64); s.rect(6, 12, 8, 64, WOOD_D); s.rect(3, 60, 11, 64, WOOD_D); s.rect(2, 0, 12, 13, (50, 50, 54, 255)); s.rect(3.5, 2, 10.5, 11, (255, 220, 120, 255)); s.rect(6, 4, 8, 9, (255, 255, 230, 255)); im = s.finish(seed=87)
    big = Image.new('RGBA', (54, 84), (0, 0, 0, 0)); big.alpha_composite(glow_layer(54, 84, 27, 26, 26, (255, 200, 100), 0.5)); big.alpha_composite(im, (20, 20)); spr('ABLNA0', big, (27, 84))
    s = Spr(26, 170)
    for y in range(0, 170, 14):
        s.line([(8 + y * 0.02, 170 - y), (18 - y * 0.02, 170 - y - 14)], (130, 134, 140, 255), 1); s.line([(18 - y * 0.02, 170 - y), (8 + y * 0.02, 170 - y - 14)], (96, 100, 108, 255), 1)
    s.line([(6, 170), (11, 4)], (150, 154, 160, 255), 1.6); s.line([(20, 170), (15, 4)], (110, 114, 122, 255), 1.6); s.ell(10, 0, 16, 6, (230, 40, 40, 255)); s.rect(1, 20, 25, 22, (150, 154, 160, 255))
    spr('ABANA0', s.finish(seed=88, light=0.1))
    for f in range(3):                                     # campfire
        s = Spr(40, 40); base = Spr(40, 40)
        base.line([(6, 37), (34, 31)], WOOD_D, 4); base.line([(6, 31), (34, 37)], WOOD, 4); base.ell(2, 34, 9, 40, STONE_D); base.ell(31, 34, 38, 40, STONE); base.ell(15, 36, 24, 40, STONE_D)
        bi = base.finish(seed=90); r = rng(91 + f)
        s.poly([(8, 35), (11 + r.random() * 3, 18), (15, 24), (19 + r.random() * 4 - 2, 4 + f * 3), (24, 22), (28 - r.random() * 3, 14), (32, 35)], (240, 110, 30, 255))
        s.poly([(12, 35), (15, 22), (20, 12 + f * 2), (24, 22), (28, 35)], (255, 190, 50, 255)); s.poly([(16, 35), (20, 22), (24, 35)], (255, 250, 200, 255))
        fi = s.finish(outline=None, light=0, noise=0)
        big = Image.new('RGBA', (72, 64), (0, 0, 0, 0)); big.alpha_composite(glow_layer(72, 64, 36, 40, 34, (255, 150, 50), 0.5)); big.alpha_composite(bi, (16, 24)); big.alpha_composite(fi, (16, 24))
        spr('ABFR%s0' % 'ABC'[f], big, (36, 64))
    f_body = font('body', 11)
    for i, (txt, col) in enumerate([('COMMAND', (214, 170, 60)), ('ARMORY', (200, 60, 50)), ('WORKSHOP', (90, 150, 210)), ('INFIRMARY', (80, 190, 110)), ('STORAGE', (190, 150, 100)), ('RADIO', (170, 120, 220)), ('EXPEDITION', (240, 220, 120)), ('ARCHIVE', (226, 190, 90))]):
        s = Spr(70, 60); s.rect(32, 26, 38, 60, WOOD_D); s.rect(2, 2, 68, 28, WOOD); s.rect(4, 4, 66, 26, (40, 30, 22, 255)); s.rect(2, 2, 68, 4, WOOD_L)
        im = s.finish(seed=95 + i); d = ImageDraw.Draw(im); bb = d.textbbox((0, 0), txt, font=f_body); d.text((35 - (bb[2] - bb[0]) / 2 - bb[0], 15 - (bb[3] - bb[1]) / 2 - bb[1]), txt, font=f_body, fill=col + (255,))
        spr('ABSG%s0' % 'ABCDEFGH'[i], im)
