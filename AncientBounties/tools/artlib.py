"""Procedural pixel-art helpers for Ancient Bounties (numpy + Pillow only)."""
import os, struct, zlib, math, zipfile, tempfile
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter

def rng(seed): return np.random.default_rng(seed)

def _smooth(t): return t * t * (3 - 2 * t)

def tnoise(w, h, cell, seed):
    """Tileable value noise in [0,1]."""
    gw, gh = max(1, w // cell), max(1, h // cell)
    g = rng(seed).random((gh, gw))
    ys = (np.arange(h) / h) * gh; xs = (np.arange(w) / w) * gw
    y0 = np.floor(ys).astype(int); x0 = np.floor(xs).astype(int)
    fy = _smooth(ys - y0)[:, None]; fx = _smooth(xs - x0)[None, :]
    y1 = (y0 + 1) % gh; x1 = (x0 + 1) % gw; y0 %= gh; x0 %= gw
    a = g[y0][:, x0]; b = g[y0][:, x1]; c = g[y1][:, x0]; d = g[y1][:, x1]
    return (a * (1 - fx) + b * fx) * (1 - fy) + (c * (1 - fx) + d * fx) * fy

def fbm(w, h, seed, base=32, octaves=4, gain=0.5):
    out = np.zeros((h, w)); amp = 1.0; tot = 0.0; cell = base
    for o in range(octaves):
        out += amp * tnoise(w, h, max(1, cell), seed + o * 101); tot += amp; amp *= gain; cell = max(1, cell // 2)
    return out / tot

def grain(w, h, seed, amt=1.0): return (rng(seed).random((h, w)) - 0.5) * amt

def ramp(v, stops):
    """v: array in [0,1]; stops: [(pos,(r,g,b)),...] -> uint8 RGB array."""
    v = np.clip(v, 0, 1); pos = np.array([s[0] for s in stops]); col = np.array([s[1] for s in stops], float)
    out = np.zeros(v.shape + (3,))
    for c in range(3): out[..., c] = np.interp(v, pos, col[:, c])
    return out

def to_img(a):
    a = np.clip(a, 0, 255).astype(np.uint8)
    return Image.fromarray(a, 'RGBA' if a.shape[-1] == 4 else 'RGB')

def blocks(w, h, bw, bh, seed, bond=True, vary=0.0):
    """Returns (edge mask 0..1 of mortar, per-pixel block random value, bevel light map)."""
    r = rng(seed); rows = h // bh
    val = np.zeros((h, w)); mort = np.zeros((h, w)); bev = np.zeros((h, w))
    for ry in range(rows):
        off = (bw // 2 if (bond and ry % 2) else 0) + (int(r.integers(-bw // 6, bw // 6 + 1)) if vary else 0)
        x = -off
        while x < w:
            cw = bw + (int(r.integers(-int(bw * vary), int(bw * vary) + 1)) if vary else 0)
            v = r.random()
            y0 = ry * bh
            for xx in range(x, x + cw):
                px = xx % w
                val[y0:y0 + bh, px] = v
            mort[y0:y0 + bh, x % w] = 1; mort[y0, [(xx % w) for xx in range(x, x + cw)]] = 1
            for xx in range(x + 1, x + cw):
                px = xx % w
                bev[y0 + 1, px] += 0.5; bev[y0 + bh - 1, px] -= 0.5
            bev[y0 + 1:y0 + bh, (x + 1) % w] += 0.4; bev[y0 + 1:y0 + bh, (x + cw - 1) % w] -= 0.4
            x += cw
    return mort, val, bev

def stone_wall(w, h, bw, bh, seed, stops, moss=None, moss_amt=0.0, rough=0.25, mortar_dark=0.22, vary=0.15):
    mort, val, bev = blocks(w, h, bw, bh, seed, vary=vary)
    n = fbm(w, h, seed + 7, base=16, octaves=4); g = grain(w, h, seed + 9, 0.10)
    v = 0.52 + 0.22 * (val - 0.5) + rough * (n - 0.5) * 1.6 + 0.10 * bev + g
    v = np.where(mort > 0, mortar_dark + 0.1 * n, v)
    img = ramp(v, stops)
    if moss is not None and moss_amt > 0:
        m = fbm(w, h, seed + 31, base=32, octaves=4)
        grad = np.linspace(0.12, -0.10, h)[:, None]          # more moss low on the wall
        mask = np.clip((m + grad + 0.25 * mort - (1 - moss_amt)) * 6, 0, 1)
        mv = 0.35 + 0.5 * fbm(w, h, seed + 41, base=8, octaves=3) + grain(w, h, seed + 43, 0.15)
        mc = ramp(mv, moss)
        img = img * (1 - mask[..., None]) + mc * mask[..., None]
    return img

def rock(w, h, seed, stops, strata=0.0, ridged=True, contrast=1.0):
    n = fbm(w, h, seed, base=32, octaves=5)
    if ridged: n = 1 - np.abs(2 * n - 1); n = n ** 1.4
    n2 = fbm(w, h, seed + 5, base=8, octaves=3)
    v = 0.5 + contrast * (0.55 * (n - 0.5) + 0.3 * (n2 - 0.5)) + grain(w, h, seed + 3, 0.08)
    if strata:
        ys = np.arange(h)[:, None] + 6 * fbm(w, h, seed + 11, base=32, octaves=2)
        v += strata * 0.12 * np.sin(ys * 2 * math.pi * 4 / h)
    return ramp(v, stops)

def ground(w, h, seed, stops, base=16, speck=0.12, contrast=1.0):
    n = fbm(w, h, seed, base=base, octaves=4)
    v = 0.5 + contrast * (n - 0.5) + grain(w, h, seed + 1, speck)
    return ramp(v, stops)

def planks(w, h, seed, stops, pw=16, vertical=True, nails=True):
    r = rng(seed)
    W, H = (w, h) if vertical else (h, w)
    v = np.zeros((H, W)); x = 0
    while x < W:
        cw = pw
        tone = 0.5 + (r.random() - 0.5) * 0.25
        gr = fbm(cw, H, seed + x + 3, base=4, octaves=3)
        gr = np.repeat(gr[::max(1, H // 16)][:, :], max(1, H // 16), axis=0)[:H] if False else gr
        streak = tnoise(cw, H, 2, seed + x + 5).mean(axis=0)[None, :] * 0.0
        col = tone + 0.18 * (np.tile(rng(seed + x).random((1, cw)), (H, 1)) - 0.5) + 0.10 * (gr - 0.5)
        v[:, x:x + cw] = col[:, :min(cw, W - x)]
        v[:, x] = 0.15
        if x + 1 < W: v[:, x + 1] += 0.08
        if nails:
            for ny in (6, H - 7):
                if 0 <= ny < H and x + cw // 2 < W: v[ny, x + cw // 2] = 0.1
        x += cw
    v += grain(W, H, seed + 77, 0.06)
    if not vertical: v = v.T
    return ramp(v, stops)

# ---------------------------------------------------------------- PNG output
def save_png(img, path, offset=None):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    if isinstance(img, np.ndarray): img = to_img(img)
    img.save(path, 'PNG', optimize=True)
    if offset is not None:
        d = open(path, 'rb').read()
        pos = 8 + 4 + 4 + 13 + 4   # after signature + IHDR chunk
        data = struct.pack('>ii', int(offset[0]), int(offset[1]))
        chunk = struct.pack('>I', 8) + b'grAb' + data + struct.pack('>I', zlib.crc32(b'grAb' + data) & 0xffffffff)
        open(path, 'wb').write(d[:pos] + chunk + d[pos:])

# ---------------------------------------------------------------- sprite builder
class Spr:
    """Draw at SCALE x resolution with flat colours, then downsample + outline for a chunky pixel-art look."""
    def __init__(s, w, h, scale=4):
        s.w, s.h, s.k = w, h, scale
        s.im = Image.new('RGBA', (w * scale, h * scale), (0, 0, 0, 0)); s.d = ImageDraw.Draw(s.im)
    def _p(s, pts): return [(x * s.k, y * s.k) for x, y in pts]
    def poly(s, pts, col): s.d.polygon(s._p(pts), fill=col); return s
    def rect(s, x0, y0, x1, y1, col): s.d.rectangle([x0 * s.k, y0 * s.k, x1 * s.k - 1, y1 * s.k - 1], fill=col); return s
    def ell(s, x0, y0, x1, y1, col): s.d.ellipse([x0 * s.k, y0 * s.k, x1 * s.k - 1, y1 * s.k - 1], fill=col); return s
    def line(s, pts, col, wd=1): s.d.line(s._p(pts), fill=col, width=int(wd * s.k), joint='curve'); return s
    def arc(s, x0, y0, x1, y1, a0, a1, col, wd=1): s.d.arc([x0 * s.k, y0 * s.k, x1 * s.k, y1 * s.k], a0, a1, fill=col, width=int(wd * s.k)); return s
    def paste(s, img, x, y):
        s.im.alpha_composite(img.resize((img.width * s.k, img.height * s.k), Image.NEAREST), (x * s.k, y * s.k)); return s
    def finish(s, light=0.35, outline=(20, 14, 10, 255), noise=0.06, seed=1, glow=None):
        im = s.im.resize((s.w, s.h), Image.LANCZOS)
        a = np.array(im).astype(float)
        alpha = (a[..., 3] > 110)
        ys, xs = np.mgrid[0:s.h, 0:s.w]
        lm = 1 + light * (0.5 - (xs / max(1, s.w - 1)) * 0.6 - (ys / max(1, s.h - 1)) * 0.5) + grain(s.w, s.h, seed, noise)
        a[..., :3] *= lm[..., None]
        a[..., 3] = np.where(alpha, 255, 0)
        if outline is not None:
            pad = np.pad(alpha, 1)
            nb = pad[:-2, 1:-1] | pad[2:, 1:-1] | pad[1:-1, :-2] | pad[1:-1, 2:]
            edge = nb & ~alpha
            a[edge] = outline
        return to_img(a)

def darker(c, f=0.7): return tuple(int(x * f) for x in c[:3]) + (255,)
def lighter(c, f=1.3): return tuple(min(255, int(x * f + 10)) for x in c[:3]) + (255,)

# ---------------------------------------------------------------- fonts
_fontdir = None
def font(kind, size, branding=None):
    """kind: 'title' (Rabbid Highway Sign II, OFL) or 'body' (M PLUS 1 Code Bold, OFL); falls back to PIL default."""
    global _fontdir
    try:
        if _fontdir is None:
            _fontdir = tempfile.mkdtemp(prefix='abfonts')
            src = branding or os.environ.get('AB_BRANDING') or os.path.join(os.path.dirname(os.path.abspath(__file__)), '..', '..', 'branding', 'source')
            with zipfile.ZipFile(os.path.join(src, 'rabbid_highway_sign_ii.zip')) as z: z.extract('RabbidHighwaySignII.otf', _fontdir)
            with zipfile.ZipFile(os.path.join(src, 'M_PLUS_1_Code.zip')) as z:
                open(os.path.join(_fontdir, 'body.ttf'), 'wb').write(z.read('M_PLUS_1_Code/static/MPLUS1Code-Bold.ttf'))
        p = os.path.join(_fontdir, 'RabbidHighwaySignII.otf' if kind == 'title' else 'body.ttf')
        return ImageFont.truetype(p, size)
    except Exception as e:
        print('font fallback:', e); return ImageFont.load_default()
