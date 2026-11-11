#!/usr/bin/env python3
"""Ancient Bounties level generator.
   Usage: gen_maps.py <build dir> [MAPNAME ...]
Builds every expedition map (rooms on a slot lattice, 2-wide corridors, doors, puzzle gates,
arenas, balconies, loot/enemy spots) plus the base camp, and writes maps/*.wad + MAPINFO."""
import os, sys, random, zlib, collections, math
sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from gridmap import GridMap, Spec, CELL

# ---- thing numbers (see MAPINFO DoomEdNums)
T_START = 1
T_ENEMY, T_LOOT, T_SUPPLY, T_EXIT, T_ARENA, T_GREAT = 20000, 20001, 20002, 20003, 20004, 20005
T_CORE, T_LEVER, T_BRAZIER, T_PLATE, T_BLOCK, T_TOTEM, T_STELE, T_ALTAR, T_FRAGSPOT, T_SPIKE, T_DARTTRAP, T_URN = 20010, 20011, 20012, 20013, 20014, 20015, 20016, 20017, 20018, 20019, 20020, 20021
T_FERN, T_PALM, T_SHRUB, T_PINE, T_COLUMN, T_FLAGS, T_BONES, T_LANTERN, T_ANTENNA, T_CAMPFIRE, T_TORCH = 20030, 20031, 20032, 20033, 20034, 20035, 20036, 20037, 20038, 20039, 20040
T_STATION, T_CREW = 20050, 20051
T_BARREL, T_TECHLAMP = 2035, 85
PZ_GLYPHS, PZ_BRAZIERS, PZ_PLATES, PZ_SIMON, PZ_FRAGMENTS, PZ_TIMED = 1, 2, 3, 4, 5, 6

THEMES = {
 'PE': dict(win='JSTONE1', win2='JSTONE2', wbig='JSTONE3', wout='JROCK1', wout2='JFOLI1', fin='JFLOOR', fout='JGRASS', fpath='JDIRT', ceil='JCEIL', water='FWATER1',
            sky='ABSKYJ', lout=212, lin=150, outdoor=0.55, veg=[(T_FERN, 5), (T_PALM, 3), (T_COLUMN, 1)], indec=[(T_URN, 4), (T_COLUMN, 1), (T_BONES, 1)],
            music=['D_RUNNIN', 'D_STALKS', 'D_COUNTD', 'D_BETWEE', 'D_DOOM', 'D_THE_DA', 'D_SHAWN'], title='Peru'),
 'EG': dict(win='DSTONE1', win2='DSTONE2', wbig='DSTONE3', wout='DROCK1', wout2='DROCK1', fin='DFLOOR', fout='DSAND', fpath='DFLOOR', ceil='DCEIL', water='FWATER1',
            sky='ABSKYD', lout=236, lin=146, outdoor=0.35, veg=[(T_SHRUB, 4), (T_COLUMN, 3), (T_BONES, 1)], indec=[(T_URN, 6), (T_COLUMN, 2), (T_BONES, 1)],
            music=['D_DDTBLU', 'D_IN_CIT', 'D_DEAD', 'D_STLKS2', 'D_THEDA2', 'D_DOOM2', 'D_DDTBL2'], title='Egypt'),
 'CA': dict(win='CSTONE1', win2='CWOOD2', wbig='CWOOD1', wout='CROCK1', wout2='JFOLI1', fin='CFLOOR', fout='CSAND', fpath='CPLANK', ceil='CCEIL', water='FWATER1',
            sky='ABSKYC', lout=228, lin=140, outdoor=0.5, veg=[(T_PALM, 4), (T_FERN, 3), (T_BONES, 1)], indec=[(T_URN, 3), (T_BARREL, 3), (T_BONES, 2)],
            music=['D_RUNNI2', 'D_DEAD2', 'D_STLKS3', 'D_ROMERO', 'D_SHAWN2', 'D_MESSAG', 'D_COUNT2'], title='Caribbean'),
 'NE': dict(win='HWALL1', win2='HWALL2', wbig='HWOOD1', wout='HROCK1', wout2='HROCK1', fin='HFLOOR', fout='HSNOW', fpath='HSNOW', ceil='HCEIL', water='HICE',
            sky='ABSKYH', lout=224, lin=148, outdoor=0.45, veg=[(T_PINE, 4), (T_FLAGS, 2), (T_COLUMN, 1)], indec=[(T_URN, 4), (T_FLAGS, 1), (T_COLUMN, 1)],
            music=['D_DDTBL3', 'D_AMPIE', 'D_THEDA3', 'D_ADRIAN', 'D_MESSG2', 'D_ROMER2', 'D_TENSE'], title='Nepal'),
 'CI': dict(win='STARGR2', win2='COMPSTA1', wbig='METAL2', wout='CEMENT9', wout2='CEMENT9', fin='FLOOR4_8', fout='FLOOR0_1', fpath='FLAT5_4', ceil='CEIL3_5', water='FWATER1',
            sky='ABSKYS', lout=168, lin=160, outdoor=0.3, veg=[(T_BARREL, 3), (T_TECHLAMP, 2)], indec=[(T_BARREL, 3), (T_TECHLAMP, 2)],
            music=['D_SHAWN3', 'D_OPENIN', 'D_EVIL', 'D_ULTIMA'], title='Meridian Citadel', door='BIGDOOR2', gate='BIGDOOR7', banner=True),
}

SLOT = 13
DIRS = [(1, 0), (-1, 0), (0, 1), (0, -1)]

class Room:
    def __init__(s, idx, slot): s.idx, s.slot = idx, slot; s.role = 'path'; s.parent = None; s.z = 0; s.outdoor = False; s.entr = []; s.seg = 0; s.clean = False; s.children = []
    def cells(s): return [(x, y) for y in range(s.y0, s.y1) for x in range(s.x0, s.x1)]
    @property
    def w(s): return s.x1 - s.x0
    @property
    def h(s): return s.y1 - s.y0

class GenBase:
    def __init__(s, name, code, kind, seed):
        s.name, s.code, s.kind, s.th = name, code, kind, THEMES[code]
        s.r = random.Random(seed)
        s.used = set(); s.rooms = []; s.corridors = []; s.pid = 0; s.nenemy = 0

    def room_spec(s, rm, **kw):
        t = s.th
        if rm.outdoor: sp = Spec(rm.z, rm.z + 320, t['fout'], 'F_SKY1', t['wout'], t['lout'], uid=rm.idx + 1)
        else: sp = Spec(rm.z, rm.z + (160 if rm.w * rm.h < 60 else 192), t['fin'], t['ceil'], t['win'], t['lin'], uid=rm.idx + 1)
        return sp.but(**kw) if kw else sp

    # ------------------------------------------------------------ layout
    def layout(s, npath, nbranch, gw=4, gh=3):
        r = s.r
        for attempt in range(300):
            start = (r.randrange(gw), r.randrange(gh)); path = [start]; seen = {start}
            while len(path) < npath:
                x, y = path[-1]; opts = [(x + dx, y + dy) for dx, dy in DIRS if 0 <= x + dx < gw and 0 <= y + dy < gh and (x + dx, y + dy) not in seen]
                if not opts: break
                r.shuffle(opts); nxt = opts[0]; path.append(nxt); seen.add(nxt)
            if len(path) == npath: break
        else: raise RuntimeError('no path')
        s.gw, s.gh = gw, gh
        s.m = GridMap(gw * SLOT + 2, gh * SLOT + 2)
        for i, sl in enumerate(path):
            rm = Room(i, sl); rm.parent = s.rooms[-1] if s.rooms else None; s.rooms.append(rm)
            if rm.parent: rm.parent.children.append(rm)
        free = [(x, y) for x in range(gw) for y in range(gh) if (x, y) not in seen]; r.shuffle(free); nb = 0
        wants = collections.deque(s.branch_parents(npath)) if nbranch else collections.deque()
        while wants and free and nb < nbranch:
            want = wants.popleft()
            for sl in list(free):
                cands = [rm for rm in s.rooms if rm.role == 'path' and rm.idx in want and abs(rm.slot[0] - sl[0]) + abs(rm.slot[1] - sl[1]) == 1]
                if cands:
                    par = r.choice(cands); rm = Room(len(s.rooms), sl); rm.role = 'branch'; rm.parent = par; par.children.append(rm); s.rooms.append(rm); free.remove(sl); seen.add(sl); nb += 1; break
        for rm in s.rooms:
            big = rm.role == 'path' and rm.idx == npath - 1
            w = r.randint(7, 10) if rm.role == 'path' else r.randint(5, 7); h = r.randint(6, 9) if rm.role == 'path' else r.randint(5, 7)
            if big: w, h = 10, 9
            ox = 1 + rm.slot[0] * SLOT + r.randint(1, SLOT - w - 2); oy = 1 + rm.slot[1] * SLOT + r.randint(1, SLOT - h - 2)
            rm.x0, rm.y0, rm.x1, rm.y1 = ox, oy, ox + w, oy + h; rm.cx, rm.cy = ox + w // 2 - 1, oy + h // 2 - 1

    def branch_parents(s, npath):
        if s.kind == 'P': return [set(range(0, 3)), set(range(3, 5)), set(range(0, 3)), set(range(3, 5))]
        return [set(range(1, npath - 1))] * 4

    def stations(s, a, b):
        """ordered 2-cell cross-sections of the L corridor from room a's centre to room b's centre"""
        ax, ay, bx, by = a.cx, a.cy, b.cx, b.cy; out = []
        if a.slot[1] == b.slot[1]:
            xs = list(range(min(ax, bx), max(ax, bx) + 2)); xs = xs if bx >= ax else xs[::-1]
            out += [((x, ay), (x, ay + 1)) for x in xs]
            ys = list(range(min(ay, by), max(ay, by) + 2)); ys = ys if by >= ay else ys[::-1]
            out += [((bx, y), (bx + 1, y)) for y in ys if y not in (ay, ay + 1)]
        else:
            ys = list(range(min(ay, by), max(ay, by) + 2)); ys = ys if by >= ay else ys[::-1]
            out += [((ax, y), (ax + 1, y)) for y in ys]
            xs = list(range(min(ax, bx), max(ax, bx) + 2)); xs = xs if bx >= ax else xs[::-1]
            out += [((x, by), (x, by + 1)) for x in xs if x not in (ax, ax + 1)]
        return out

    def inroom(s, rm, c): return rm.x0 <= c[0] < rm.x1 and rm.y0 <= c[1] < rm.y1

    def carve(s):
        t, r, m = s.th, s.r, s.m
        npath = len([q for q in s.rooms if q.role == 'path'])
        for rm in s.rooms:
            rm.outdoor = r.random() < t['outdoor'] * (1.5 if rm.idx < 2 else (0.5 if s.kind != 'A' else 0.9))
            if s.kind == 'V' and rm.idx == npath - 1: rm.outdoor = False
        links = []
        for rm in sorted(s.rooms, key=lambda q: q.idx):
            if rm.parent is None: continue
            st = s.stations(rm.parent, rm)
            mid = [x for x in st if not all(s.inroom(rm.parent, c) for c in x) and not all(s.inroom(rm, c) for c in x)]
            n = len(mid)
            lim = max(0, (n - 2) * 12 // 8 * 8)
            dz = r.choice([-48, -32, -16, 0, 0, 16, 32, 48]) if n >= 3 else 0
            dz = max(-lim, min(lim, dz)); rm.z = rm.parent.z + dz
            links.append((rm.parent, rm, st, mid))
        zmin = min(q.z for q in s.rooms)
        for rm in s.rooms: rm.z -= zmin
        for rm in s.rooms:
            sp = s.room_spec(rm)
            for (x, y) in rm.cells(): m.set(x, y, sp)
            rm.spec = sp
        for (a, b, st, mid) in links:
            out = a.outdoor and b.outdoor
            n = len(mid); cor = dict(a=a, b=b, st=mid, door=None, cells=[])
            gate = getattr(b, 'gate', None)
            for i, cs in enumerate(mid):
                z = a.z if i == 0 else a.z + int(round((b.z - a.z) * i / max(1, n - 1) / 8.0)) * 8
                if out: sp = Spec(z, max(a.z, b.z) + 320, t['fpath'], 'F_SKY1', t['wout'], t['lout'] - 8, uid=1000 + b.idx * 50 + i)
                else: sp = Spec(z, z + 128, t['fpath'] if a.outdoor or b.outdoor else t['fin'], t['ceil'], t['wbig'], t['lin'] - 12, uid=1000 + b.idx * 50 + i)
                if i == 0 and (gate or (not out and r.random() < 0.75)):
                    tag = gate or m.newtag()
                    sp = Spec(a.z, a.z, sp.ftex, t['ceil'], t['wbig'], t['lin'], kind='door', tag=tag, top=(t.get('gate', 'ABGATE') if gate else t.get('door', 'ABDOOR')), uid=900 + b.idx)
                    if not gate: sp = sp.but(lspecial=12, largs=(tag, 32, 140))
                    cor['door'] = cs
                for c in cs:
                    if not s.inroom(a, c) and not s.inroom(b, c): m.set(c[0], c[1], sp); cor['cells'].append(c)
            for rm_, seq in ((a, st), (b, st[::-1])):
                for cs in seq:
                    if all(s.inroom(rm_, c) for c in cs) and any(abs(c[0] - d[0]) + abs(c[1] - d[1]) == 1 for c in cs for d in cor['cells']): rm_.entr.append(cs); break
            s.corridors.append(cor)

    # ------------------------------------------------------------ analysis
    def passable(s, a, b):
        A, B = s.m.get(*a), s.m.get(*b)
        if A is None or B is None: return False
        if abs(A.fz - B.fz) > 24: return False
        ca = A.cz if A.kind != 'door' else A.fz + 128; cb = B.cz if B.kind != 'door' else B.fz + 128
        return min(ca, cb) - max(A.fz, B.fz) >= 56

    def reach(s, start):
        seen = {start}; q = collections.deque([start])
        while q:
            c = q.popleft()
            for dx, dy in DIRS:
                n = (c[0] + dx, c[1] + dy)
                if n not in seen and s.passable(c, n): seen.add(n); q.append(n)
        return seen

    def anchors(s):
        out = [(s.rooms[0].cx, s.rooms[0].cy)]
        for rm in s.rooms:
            for cs in rm.entr: out += list(cs)
        return out

    def connected(s):
        an = s.anchors(); rc = s.reach(an[0])
        return all(a in rc for a in an)

    def attempt(s, cells_specs):
        """apply {(x,y): spec} if the map stays fully connected, else roll back"""
        old = {c: s.m.get(*c) for c in cells_specs}
        for c, sp in cells_specs.items(): s.m.set(c[0], c[1], sp)
        if s.connected(): return True
        for c, sp in old.items(): s.m.set(c[0], c[1], sp)
        return False

    def entr_near(s, rm, c, d=1):
        return any(abs(c[0] - e[0]) <= d and abs(c[1] - e[1]) <= d for cs in rm.entr for e in cs) or (rm.idx == 0 and abs(c[0] - rm.cx) <= 1 and abs(c[1] - rm.cy) <= 1)

    def flat(s, rm, c):
        sp = s.m.get(*c); return sp is not None and sp.key() == rm.spec.key()

    def spots(s, rm, n=1, wall=None, gap=0, avoid_entr=True, open8=False):
        """pick free, plain-floor cells in a room. wall=True: next to a wall; False: away from walls."""
        cs = [c for c in rm.cells() if s.flat(rm, c) and c not in s.used and c in s.reachable]
        if avoid_entr: cs = [c for c in cs if not s.entr_near(rm, c)]
        def nwall(c): return sum(1 for dx, dy in DIRS if not s.flat(rm, (c[0] + dx, c[1] + dy)))
        if wall is True: cs = [c for c in cs if nwall(c) >= 1]
        if wall is False: cs = [c for c in cs if nwall(c) == 0]
        if open8: cs = [c for c in cs if all(s.flat(rm, (c[0] + dx, c[1] + dy)) for dx in (-1, 0, 1) for dy in (-1, 0, 1))]
        s.r.shuffle(cs); out = []
        for c in cs:
            if gap and any(abs(c[0] - o[0]) <= gap and abs(c[1] - o[1]) <= gap for o in out): continue
            out.append(c); s.used.add(c)
            if len(out) >= n: break
        return out

    def put(s, type_, c, angle=None, args=(), jitter=0.0, **kw):
        a = s.r.randrange(0, 360, 45) if angle is None else angle
        return s.m.thing(type_, c[0] + 0.5 + s.r.uniform(-jitter, jitter), c[1] + 0.5 + s.r.uniform(-jitter, jitter), a, args, **kw)

    def dist(s, start, gate_tag):
        seen = {start: 0}; q = collections.deque([start])
        while q:
            c = q.popleft(); sp = s.m.get(*c)
            if sp.kind == 'door' and sp.tag == gate_tag: return seen[c]
            for dx, dy in DIRS:
                n = (c[0] + dx, c[1] + dy)
                if n not in seen and s.passable(c, n): seen[n] = seen[c] + 1; q.append(n)
        return 30

class Gen(GenBase):
    # ------------------------------------------------------------ room features
    def dress(s, rm):
        t, r = s.th, s.r
        if rm.outdoor:
            for (cx, cy, sx, sy) in [(rm.x0, rm.y0, 1, 1), (rm.x1 - 1, rm.y0, -1, 1), (rm.x0, rm.y1 - 1, 1, -1), (rm.x1 - 1, rm.y1 - 1, -1, -1)]:
                k = r.randint(0, 2)
                cut = {(cx + sx * i, cy + sy * j): None for i in range(k + 1) for j in range(k + 1 - i)} if k else {}
                if cut and not any(s.entr_near(rm, c, 1) for c in cut): s.attempt(cut)
        if rm.clean: return
        opts = ['cover', 'cover', 'pillars', 'pool', 'balcony', 'crates', 'dais']
        if rm.outdoor: opts = ['cover', 'cover', 'pool', 'crates', 'rocks', 'balcony']
        if s.kind == 'P' and rm.role == 'path': opts = ['pillars', 'pool', 'dais', 'crates']
        nfe = (2 if rm.w * rm.h >= 56 else 1) + (1 if s.kind == 'A' else 0)
        for f in r.sample(opts, min(len(opts), nfe)): getattr(s, 'f_' + f)(rm)

    def f_cover(s, rm):
        t, r = s.th, s.r
        for _ in range(r.randint(2, 5)):
            c = (r.randint(rm.x0 + 1, rm.x1 - 2), r.randint(rm.y0 + 1, rm.y1 - 2))
            if s.entr_near(rm, c, 1) or not s.flat(rm, c): continue
            sp = rm.spec.but(fz=rm.z + 40, ftex=t['fin'], step=t['wbig'], uid=rm.spec.uid + 300)
            cells = {c: sp}
            if r.random() < 0.5:
                d = r.choice(DIRS); c2 = (c[0] + d[0], c[1] + d[1])
                if s.flat(rm, c2) and not s.entr_near(rm, c2, 1) and rm.x0 < c2[0] < rm.x1 - 1 and rm.y0 < c2[1] < rm.y1 - 1: cells[c2] = sp
            if s.attempt(cells): s.used.update(cells)

    def f_rocks(s, rm):
        for _ in range(s.r.randint(2, 4)):
            c = (s.r.randint(rm.x0 + 1, rm.x1 - 2), s.r.randint(rm.y0 + 1, rm.y1 - 2))
            if not s.entr_near(rm, c, 1) and s.flat(rm, c): s.attempt({c: None})

    def f_pillars(s, rm):
        if rm.outdoor or rm.w < 6 or rm.h < 6: return s.f_cover(rm)
        for x in range(rm.x0 + 2, rm.x1 - 2, 3):
            for y in range(rm.y0 + 2, rm.y1 - 2, 3):
                if not s.entr_near(rm, (x, y), 1) and s.flat(rm, (x, y)): s.attempt({(x, y): None})

    def f_pool(s, rm):
        t, r = s.th, s.r; w, h = r.randint(2, 3), r.randint(2, 3)
        x = r.randint(rm.x0 + 1, max(rm.x0 + 1, rm.x1 - w - 1)); y = r.randint(rm.y0 + 1, max(rm.y0 + 1, rm.y1 - h - 1))
        sp = rm.spec.but(fz=rm.z - (0 if t['water'] == 'HICE' else 16), ftex=t['water'], uid=rm.spec.uid + 400)
        cells = {(i, j): sp for i in range(x, x + w) for j in range(y, y + h) if s.flat(rm, (i, j))}
        if cells and s.attempt(cells): s.used.update(cells)

    def f_dais(s, rm):
        t = s.th
        x, y = (rm.cx + s.r.choice([-3, 2]) if rm.w >= 9 else rm.cx), rm.cy
        sp = rm.spec.but(fz=rm.z + 16, ftex=t['fpath'] if t['fpath'] != rm.spec.ftex else t['fin'], step=t['win2'], uid=rm.spec.uid + 500)
        cells = {(i, j): sp for i in range(x, x + 2) for j in range(y, y + 2) if s.flat(rm, (i, j)) and not s.entr_near(rm, (i, j), 0)}
        if len(cells) == 4: s.attempt(cells)

    def f_crates(s, rm):
        r = s.r
        for _ in range(r.randint(1, 3)):
            cs = [c for c in rm.cells() if s.flat(rm, c) and not s.entr_near(rm, c, 1) and any(s.m.get(c[0] + dx, c[1] + dy) is None for dx, dy in DIRS)]
            if not cs: return
            c = r.choice(cs); hgt = r.choice([32, 64, 64])
            sp = rm.spec.but(fz=rm.z + hgt, ftex='CRATOP1' if hgt == 64 else 'CRATOP2', step='CRATE1' if hgt == 64 else 'CRATE2', uid=rm.spec.uid + 600 + hgt)
            if s.attempt({c: sp}): s.used.add(c)

    def f_balcony(s, rm):
        """raised gallery along one wall with a two-step stair"""
        t, r = s.th, s.r
        if rm.w < 7 or rm.h < 7: return s.f_cover(rm)
        side = r.choice(['n', 's']); top = rm.spec.but(fz=rm.z + 48, ftex=t['fin'], step=t['win2'], uid=rm.spec.uid + 700)
        ys = [rm.y1 - 1, rm.y1 - 2] if side == 'n' else [rm.y0, rm.y0 + 1]; dy = -1 if side == 'n' else 1
        cells = {(x, y): top for x in range(rm.x0, rm.x1) for y in ys}
        xs = r.randint(rm.x0 + 1, rm.x1 - 3); y1 = ys[1] + dy; y2 = y1 + dy
        for x in (xs, xs + 1):
            cells[(x, y1)] = rm.spec.but(fz=rm.z + 32, ftex=t['fin'], step=t['win2'], uid=rm.spec.uid + 701)
            cells[(x, y2)] = rm.spec.but(fz=rm.z + 16, ftex=t['fin'], step=t['win2'], uid=rm.spec.uid + 702)
        if any(not s.flat(rm, c) or s.entr_near(rm, c, 0) for c in cells): return
        if s.attempt(cells):
            rm.balcony = [c for c in cells if cells[c] is top]
            for x in (xs, xs + 1): s.used.add((x, y1)); s.used.add((x, y2))

    # ------------------------------------------------------------ population
    def decorate(s, rm):
        t, r = s.th, s.r
        bag = [k for k, w in (t['veg'] if rm.outdoor else t['indec']) for _ in range(w)]
        n = max(2, rm.w * rm.h // (9 if rm.outdoor else 14))
        for c in s.spots(rm, n, wall=True):
            k = r.choice(bag)
            if k == T_BARREL and s.kind == 'P': k = T_URN
            s.put(k, c, jitter=0.25)
        if not rm.outdoor:
            for c in s.spots(rm, 2 if rm.w * rm.h < 60 else 4, wall=True, gap=2): s.put(T_TORCH if s.code != 'CI' else T_TECHLAMP, c)
        elif s.code in ('PE', 'CA') and r.random() < 0.7:
            for c in s.spots(rm, 3, wall=False): s.put(T_FERN, c, jitter=0.3); s.used.discard(c)

    def enemies(s, rm, n, tiers, group=0, always=False):
        cs = s.spots(rm, n); bal = list(getattr(rm, 'balcony', [])); s.r.shuffle(bal)
        ex, ey = (rm.entr[0][0] if rm.entr else (rm.cx, rm.cy))
        for c in cs:
            tier = s.r.choice(tiers)
            if tier == 4 and bal: c = bal.pop()
            ang = int(math.degrees(math.atan2(ey - c[1], ex - c[0])) // 45 * 45) % 360
            s.put(T_ENEMY, c, ang, (tier, group, 1 if always else 0), jitter=0.2); s.nenemy += 1

    def loot(s, rm, q0=0, q1=0, q2=0, ammo=0, health=0):
        for q, n in ((0, q0), (1, q1), (2, q2)):
            for c in s.spots(rm, n): s.put(T_LOOT, c, 0, (q,), jitter=0.25)
        for c in s.spots(rm, ammo): s.put(T_SUPPLY, c, 0, (0,), jitter=0.25)
        for c in s.spots(rm, health): s.put(T_SUPPLY, c, 0, (1,), jitter=0.25)

    # ------------------------------------------------------------ puzzles
    def add_puzzle(s, ptype, gate_room, others, gate_tag):
        """gate_room: the room in front of the locked gate; others: other rooms of the same segment"""
        r = s.r; s.pid += 1; pid = s.pid; count = 0
        branches = [q for q in others if q.role == 'branch'] or others
        clue_rm = r.choice(branches) if branches else gate_room
        def stele(rm):
            c = s.spots(rm, 1, wall=True) or s.spots(rm, 1)
            if c: s.put(T_STELE, c[0], 0, (pid, 0))
        if ptype == PZ_GLYPHS:
            cs = s.spots(gate_room, 4, wall=True, gap=1); count = len(cs)
            for i, c in enumerate(cs): s.put(T_LEVER, c, 0, (pid, i + 1))
            stele(clue_rm)
        elif ptype == PZ_BRAZIERS:
            cs = s.spots(gate_room, r.choice([3, 4]), wall=True, gap=1); count = len(cs)
            for i, c in enumerate(cs): s.put(T_BRAZIER, c, 0, (pid, i + 1))
            stele(clue_rm)
        elif ptype == PZ_PLATES:
            cs = s.spots(gate_room, 2, open8=True, gap=2); count = len(cs)
            for i, c in enumerate(cs): s.put(T_PLATE, c, 0, (pid, i + 1))
            for c in s.spots(gate_room, count + 1, open8=True, gap=1): s.put(T_BLOCK, c, 0, (pid,))
            stele(gate_room)
        elif ptype == PZ_SIMON:
            cs = s.spots(gate_room, 4, wall=False, gap=1); count = len(cs)
            for i, c in enumerate(cs): s.put(T_TOTEM, c, 0, (pid, i))
            stele(gate_room)
        elif ptype == PZ_FRAGMENTS:
            c = s.spots(gate_room, 1, wall=False) or s.spots(gate_room, 1)
            if c: s.put(T_ALTAR, c[0], 0, (pid, 0))
            pool = (branches + [q for q in others if q not in branches]) * 3
            for q in pool[:3]:
                c = s.spots(q, 1, wall=False) or s.spots(q, 1)
                if c: s.put(T_FRAGSPOT, c[0], 0, (pid,)); count += 1; s.enemies(q, 2, [0, 1], always=True)
            stele(gate_room)
        elif ptype == PZ_TIMED:
            far = clue_rm if clue_rm is not gate_room else (others[0] if others else gate_room)
            c = s.spots(far, 1, wall=True) or s.spots(far, 1)
            if c:
                s.put(T_LEVER, c[0], 0, (pid, 1))
                count = max(7, min(40, int(s.dist(c[0], gate_tag) * 64 / 260.0 + 5)))
            stele(far)
        if count == 0 or (ptype in (PZ_GLYPHS, PZ_SIMON) and count < 3) or (ptype == PZ_PLATES and count < 2): raise RuntimeError('puzzle did not fit')
        s.m.thing(T_CORE, gate_room.cx + 0.5, gate_room.cy + 0.5, 0, (pid, ptype, gate_tag, count))

    def traps(s, ncor):
        cands = [c for c in s.corridors if len(c['st']) >= 5]; s.r.shuffle(cands)
        for cor in cands[:ncor]:
            st = [x for x in cor['st'][2:-1] if all(s.m.get(*c) is not None and s.m.get(*c).kind != 'door' for c in x)]
            for i, cs in enumerate(st[::2][:3]):
                for c in cs:
                    if c in cor['cells']: s.m.thing(T_SPIKE, c[0] + 0.5, c[1] + 0.5, 0, (i * 3, 12))

    # ------------------------------------------------------------ recipes
    def build(s):
        k = s.kind
        if k == 'A': s.layout(s.r.choice([6, 7]), 3)
        elif k == 'P': s.layout(6, 3)
        else: s.layout(4, 1, gw=3, gh=3)
        path = [q for q in s.rooms if q.role == 'path']; branches = [q for q in s.rooms if q.role == 'branch']
        if k == 'P':
            path[3].gate = s.m.newtag(); path[5].gate = s.m.newtag(); path[2].clean = True; path[4].clean = True
            for q in s.rooms: q.seg = 0 if (q.idx if q.role == 'path' else q.parent.idx) <= 2 else 1
        if k == 'V': path[2].gate = s.m.newtag(); path[1].clean = True
        s.carve()
        if not s.connected(): raise RuntimeError('layout not connected')
        for rm in s.rooms: s.dress(rm)
        s.reachable = s.reach((path[0].cx, path[0].cy))
        for a in ((path[0].cx, path[0].cy), (path[0].cx + 1, path[0].cy), (path[0].cx, path[0].cy + 1), (path[0].cx + 1, path[0].cy + 1)): s.used.add(a)
        e = path[0].entr[0][0] if path[0].entr else (path[0].cx + 1, path[0].cy)
        s.m.thing(T_START, path[0].cx + 1.0, path[0].cy + 1.0, int(round(math.degrees(math.atan2(e[1] - path[0].cy, e[0] - path[0].cx)) / 90.0) * 90) % 360)
        getattr(s, 'pop_' + k)(path, branches)
        for rm in s.rooms: s.decorate(rm)
        return s

    def exit_at(s, rm):
        c = s.spots(rm, 1, wall=False) or s.spots(rm, 1)
        s.put(T_EXIT, c[0] if c else (rm.cx, rm.cy), 0)

    def pop_A(s, path, branches):
        r = s.r; n = len(path)
        s.loot(path[0], q0=1, ammo=1)
        for i, rm in enumerate(path[1:], 1):
            last = i == n - 1
            tiers = [0, 0, 0, 1] if i <= 2 else ([0, 0, 1, 1, 2] if not last else [0, 1, 1, 2, 2])
            s.enemies(rm, 3 + min(3, i) + r.randint(0, 2), tiers + ([4] if getattr(rm, 'balcony', None) else []))
            s.loot(rm, q0=r.randint(1, 3), q1=1 if i % 2 == 0 else 0, ammo=r.randint(1, 2), health=1 if i % 2 else 0)
        mid = path[n // 2]
        s.enemies(mid, 4, [0, 1, 1], group=1); s.m.thing(T_ARENA, mid.cx + 0.5, mid.cy + 0.5, 0, (1, 3, 0))
        s.enemies(path[-2], 3, [1, 1, 2], group=2); s.enemies(path[-1], 2, [1, 2], group=2)
        s.m.thing(T_ARENA, path[-1].cx + 0.5, path[-1].cy + 0.5, 0, (2, 4, 0))
        for b in branches:
            s.enemies(b, r.randint(2, 4), [0, 1, 1, 2]); s.loot(b, q0=2, q1=1, q2=1, ammo=1, health=1)
        s.exit_at(path[-1])

    def pop_P(s, path, branches):
        r = s.r
        types = r.sample([PZ_GLYPHS, PZ_BRAZIERS, PZ_PLATES, PZ_SIMON, PZ_FRAGMENTS, PZ_TIMED], 2)
        seg0 = [q for q in s.rooms if q.seg == 0 and q is not path[2]]; seg1 = [q for q in s.rooms if q.seg == 1 and q not in (path[4], path[5])]
        seg0.sort(key=lambda q: q.role != 'branch'); seg1.sort(key=lambda q: q.role != 'branch')
        s.add_puzzle(types[0], path[2], seg0, path[3].gate)
        s.add_puzzle(types[1], path[4], seg1 or [path[3]], path[5].gate)
        s.ptypes = types
        s.loot(path[0], q0=1, ammo=1)
        for i, rm in enumerate(path[1:5], 1):
            s.enemies(rm, r.randint(1, 3), [0, 0, 1]); s.loot(rm, q0=r.randint(1, 2), ammo=1, health=1 if i == 3 else 0)
        for b in branches:
            s.enemies(b, r.randint(1, 3), [0, 1]); s.loot(b, q0=1, q1=1, q2=1, ammo=1)
        s.loot(path[5], q0=2, q1=1, health=1)
        for c in s.spots(path[5], 1): s.put(T_LOOT, c, 0, (4,))
        s.enemies(path[3], 3, [0, 1, 1], group=1); s.m.thing(T_ARENA, path[3].cx + 0.5, path[3].cy + 0.5, 0, (1, 3, 0))
        s.traps(2)
        s.exit_at(path[5])

    def pop_V(s, path, branches):
        r = s.r; citadel = s.code == 'CI'
        ptype = r.choice([PZ_GLYPHS, PZ_BRAZIERS, PZ_SIMON])
        s.add_puzzle(ptype, path[1], branches + [path[0]], path[2].gate); s.ptypes = [ptype]
        s.loot(path[0], q0=1, ammo=2, health=1)
        s.enemies(path[1], 4, [0, 1, 1]); s.loot(path[1], q0=2, ammo=1)
        for b in branches: s.enemies(b, 3, [0, 1, 2]); s.loot(b, q1=1, q2=1, ammo=1, health=1)
        ante, vault = path[2], path[3]
        s.enemies(ante, 5, [1, 1, 2]); s.loot(ante, q0=2, q1=1, ammo=2, health=1)
        t = s.th
        dz = vault.spec.but(fz=vault.z + 16, ftex='ABGOLDF', step=t['win2'], uid=vault.spec.uid + 800)
        cx, cy = vault.cx, vault.cy
        cells = {(i, j): dz for i in range(cx - 1, cx + 3) for j in range(cy - 1, cy + 3) if s.flat(vault, (i, j)) and not s.entr_near(vault, (i, j), 0)}
        s.attempt(cells); s.used.update(cells)
        s.m.thing(T_GREAT, cx + 1.0, cy + 1.0, 0)
        s.reachable = s.reach((path[0].cx, path[0].cy))
        bc = s.spots(vault, 1, wall=False) or s.spots(vault, 1)
        s.put(T_ENEMY, bc[0], 0, (6 if citadel else 5, 0, 1))
        s.enemies(vault, 4 if citadel else 3, [1, 2, 2, 3] if citadel else [1, 1, 2], always=True)
        s.loot(vault, q0=4, q1=3, q2=1, health=2, ammo=2)
        s.enemies(ante, 3, [1, 2], group=9); s.enemies(path[1], 3, [0, 1, 1], group=9); s.enemies(path[0], 2, [0, 1], group=9)
        s.exit_at(path[0])
