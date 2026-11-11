"""Grid-cell UDMF map builder.  Every cell is CELL x CELL map units and carries a sector Spec
(or None = solid rock).  Linedefs are generated along boundaries between differing cells and
merged into runs.  Output: a WAD (marker + TEXTMAP + ENDMAP); UZDoom builds nodes on load."""
import struct, itertools

CELL = 64

class Spec:
    """Sector description.  Cells sharing an equal Spec (by value) merge into one sector."""
    __slots__ = ('fz', 'cz', 'ftex', 'ctex', 'wall', 'light', 'special', 'tag', 'kind', 'step', 'top', 'props', 'uid', 'lspecial', 'largs', 'mid')
    def __init__(s, fz=0, cz=128, ftex='FLOOR0_1', ctex='CEIL1_1', wall='STONE2', light=160, special=0, tag=0, kind='', step=None, top=None,
                 props=None, uid=0, lspecial=0, largs=(), mid=None):
        s.fz, s.cz, s.ftex, s.ctex, s.wall, s.light, s.special, s.tag, s.kind = fz, cz, ftex, ctex, wall, light, special, tag, kind
        s.step, s.top, s.props, s.uid, s.lspecial, s.largs, s.mid = step, top, props or {}, uid, lspecial, tuple(largs), mid
    def key(s): return (s.fz, s.cz, s.ftex, s.ctex, s.wall, s.light, s.special, s.tag, s.kind, s.step, s.top, tuple(sorted(s.props.items())), s.uid, s.lspecial, s.largs, s.mid)
    def but(s, **kw):
        d = {k: getattr(s, k) for k in s.__slots__}; d['props'] = dict(s.props); d.update(kw); return Spec(**d)

class GridMap:
    def __init__(s, w, h):
        s.w, s.h = w, h; s.g = [[None] * w for _ in range(h)]; s.things = []; s._tag = itertools.count(100); s._tid = itertools.count(1000)
    # ---- cells
    def inb(s, x, y): return 0 <= x < s.w and 0 <= y < s.h
    def get(s, x, y): return s.g[y][x] if s.inb(x, y) else None
    def set(s, x, y, spec):
        if 1 <= x < s.w - 1 and 1 <= y < s.h - 1: s.g[y][x] = spec
    def rect(s, x0, y0, x1, y1, spec):
        for y in range(y0, y1):
            for x in range(x0, x1): s.set(x, y, spec)
    def newtag(s): return next(s._tag)
    def newtid(s): return next(s._tid)
    # ---- things (positions in cell coordinates; .5 = cell centre)
    def thing(s, type_, cx, cy, angle=0, args=(), tid=0, z=0, **flags):
        t = dict(type=type_, x=cx * CELL, y=cy * CELL, angle=angle, args=tuple(args), tid=tid, z=z); t.update(flags); s.things.append(t); return t
    # ---- output
    def textmap(s):
        keys = {}; sectors = []
        def sec(spec):
            k = spec.key()
            if k not in keys: keys[k] = len(sectors); sectors.append(spec)
            return keys[k]
        verts = {}; vlist = []
        def vert(x, y):
            if (x, y) not in verts: verts[(x, y)] = len(vlist); vlist.append((x, y))
            return verts[(x, y)]
        sides = []; lines = []
        def side(sector, off, top='-', mid='-', bot='-'):
            sides.append((sector, off % 512, top, mid, bot)); return len(sides) - 1
        def emit(a, b, p1, p2, off1, off2):
            """a = front spec (must be open), b = back spec or None; p1->p2 with a on the right."""
            sa = sec(a)
            if b is None:
                lines.append(dict(v1=vert(*p1), v2=vert(*p2), front=side(sa, off1, mid=a.wall), blocking=True)); return
            sb = sec(b)
            if sa == sb: return
            hi = a if a.fz >= b.fz else b; lo_c = a if a.cz <= b.cz else b
            bot = (hi.step or hi.wall) if a.fz != b.fz else '-'
            top = (lo_c.top or lo_c.wall) if (a.cz != b.cz and not (a.ctex == 'F_SKY1' and b.ctex == 'F_SKY1')) else '-'
            midt = a.mid or b.mid or '-'
            ln = dict(v1=vert(*p1), v2=vert(*p2), front=side(sa, off1, top, midt, bot), back=side(sb, off2, top, midt, bot), twosided=True)
            d = a if a.lspecial else (b if b.lspecial else None)
            if d is not None:
                ln.update(special=d.lspecial, args=d.largs, playeruse=True, playeruseback=True, repeatspecial=True, monsteruse=True)
            if midt != '-': ln.update(blocking=True, wrapmidtex=False)
            if a.kind == 'door' or b.kind == 'door': ln['dontpegtop'] = False
            lines.append(ln)
        g = s.g; K = lambda sp: None if sp is None else sp.key()
        # horizontal boundaries (between row y-1 [south] and row y [north])
        for y in range(0, s.h + 1):
            x = 0
            while x < s.w:
                A = g[y - 1][x] if y > 0 else None; B = g[y][x] if y < s.h else None
                if (A is None and B is None) or (A is not None and B is not None and K(A) == K(B)): x += 1; continue
                x0 = x; ka, kb = K(A), K(B)
                while x < s.w and K(g[y - 1][x] if y > 0 else None) == ka and K(g[y][x] if y < s.h else None) == kb: x += 1
                X0, X1, Y = x0 * CELL, x * CELL, y * CELL
                if A is not None: emit(A, B, (X0, Y), (X1, Y), X0, -X1)       # A is south: west->east
                else: emit(B, None, (X1, Y), (X0, Y), -X1, X0)                # B north of a solid: east->west
        # vertical boundaries (between column x-1 [west] and column x [east])
        for x in range(0, s.w + 1):
            y = 0
            while y < s.h:
                L = g[y][x - 1] if x > 0 else None; R = g[y][x] if x < s.w else None
                if (L is None and R is None) or (L is not None and R is not None and K(L) == K(R)): y += 1; continue
                y0 = y; kl, kr = K(L), K(R)
                while y < s.h and K(g[y][x - 1] if x > 0 else None) == kl and K(g[y][x] if x < s.w else None) == kr: y += 1
                Y0, Y1, X = y0 * CELL, y * CELL, x * CELL
                if L is not None: emit(L, R, (X, Y1), (X, Y0), -Y1, Y0)       # L is west: north->south
                else: emit(R, None, (X, Y0), (X, Y1), Y0, -Y1)                # R east of a solid: south->north
        out = ['namespace = "zdoom";']
        for x, y in vlist: out.append('vertex{x=%d;y=%d;}' % (x, y))
        for (sc, off, top, mid, bot) in sides:
            t = 'sidedef{sector=%d;offsetx=%d;' % (sc, off)
            if top != '-': t += 'texturetop="%s";' % top
            if mid != '-': t += 'texturemiddle="%s";' % mid
            if bot != '-': t += 'texturebottom="%s";' % bot
            out.append(t + '}')
        for ln in lines:
            t = 'linedef{v1=%d;v2=%d;sidefront=%d;' % (ln['v1'], ln['v2'], ln['front'])
            if 'back' in ln: t += 'sideback=%d;twosided=true;' % ln['back']
            if ln.get('blocking'): t += 'blocking=true;'
            if ln.get('special'):
                t += 'special=%d;' % ln['special'] + ''.join('arg%d=%d;' % (i, v) for i, v in enumerate(ln['args']) if v)
                for f in ('playeruse', 'playeruseback', 'repeatspecial', 'monsteruse'):
                    if ln.get(f): t += f + '=true;'
            out.append(t + '}')
        for sp in sectors:
            t = 'sector{heightfloor=%d;heightceiling=%d;texturefloor="%s";textureceiling="%s";lightlevel=%d;' % (sp.fz, sp.cz, sp.ftex, sp.ctex, sp.light)
            if sp.special: t += 'special=%d;' % sp.special
            if sp.tag: t += 'id=%d;' % sp.tag
            for k, v in sp.props.items(): t += '%s=%s;' % (k, ('"%s"' % v) if isinstance(v, str) else (('true' if v else 'false') if isinstance(v, bool) else v))
            out.append(t + '}')
        for th in s.things:
            t = 'thing{x=%.1f;y=%.1f;type=%d;angle=%d;' % (th['x'], th['y'], th['type'], th['angle'])
            if th.get('z'): t += 'height=%d;' % th['z']
            if th.get('tid'): t += 'id=%d;' % th['tid']
            for i, v in enumerate(th['args']):
                if v: t += 'arg%d=%d;' % (i, v)
            for f in ('ambush', 'dormant', 'friend'):
                if th.get(f): t += f + '=true;'
            t += 'skill1=true;skill2=true;skill3=true;skill4=true;skill5=true;single=true;coop=true;dm=true;class1=true;class2=true;class3=true;}'
            out.append(t)
        s.stats = dict(vertices=len(vlist), lines=len(lines), sides=len(sides), sectors=len(sectors), things=len(s.things))
        return '\n'.join(out) + '\n'

    def write_wad(s, path, mapname):
        tm = s.textmap().encode('ascii')
        lumps = [(mapname.upper(), b''), ('TEXTMAP', tm), ('ENDMAP', b'')]
        data = b''; dirs = b''; pos = 12
        for name, d in lumps:
            dirs += struct.pack('<ii8s', pos, len(d), name.encode('ascii')); data += d; pos += len(d)
        open(path, 'wb').write(b'PWAD' + struct.pack('<ii', len(lumps), pos) + data + dirs)
