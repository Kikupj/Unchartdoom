#!/usr/bin/env python3
"""Imports the weapon packs, DeePaybackEnemies and TacticalDuckDodge from _modding
into the pk3 build tree.  Usage: import_packs.py <_modding dir> <out dir>"""
import os, sys, struct, zipfile, shutil, re, io

TEXT = {'DECORATE','SNDINFO','KEYCONF','GLDEFS','ZSCRIPT','MODELDEF','CREDITS','INFO','OLDCODE'}

def wad_lumps(path):
    d = open(path,'rb').read()
    n, off = struct.unpack('<ii', d[4:12])
    for i in range(n):
        p, s, name = struct.unpack('<ii8s', d[off+i*16:off+i*16+16])
        yield name.rstrip(b'\0').decode('latin1'), d[p:p+s]

class Out:
    def __init__(s, root):
        s.root = root; s.dec = []; s.snd = []; s.gl = []; s.mdl = []; s.tex = []; s.zs = []; s.credits = []
    def write(s, rel, data):
        p = os.path.join(s.root, rel); os.makedirs(os.path.dirname(p), exist_ok=True)
        open(p,'wb').write(data)

def txt(b): return b.decode('latin1').replace('\r\n','\n').replace('\r','\n')

def handle_text(out, pack, base, data):
    t = txt(data)
    if base == 'DECORATE':
        out.write(f'decorate/weapons/{pack}.txt', t.encode('latin1')); out.dec.append(f'decorate/weapons/{pack}.txt')
    elif base == 'SNDINFO': out.snd.append(f'// ---- {pack}\n{t}\n')
    elif base == 'GLDEFS': out.gl.append(f'// ---- {pack}\n{t}\n')
    elif base == 'MODELDEF': out.mdl.append(f'// ---- {pack}\n{t}\n')
    elif base == 'TEXTURES': out.tex.append(f'// ---- {pack}\n{t}\n')
    elif base == 'ZSCRIPT':
        t = re.sub(r'(?im)^\s*version\s+"[^"]*"\s*;?', '', t)
        out.write(f'zscript/weapons/{pack}.zs', t.encode('latin1')); out.zs.append(f'zscript/weapons/{pack}.zs')
    elif base == 'CREDITS': out.credits.append((pack, t.strip()))

def import_wad(out, pack, path):
    insprite = False
    for name, data in wad_lumps(path):
        u = name.upper()
        if u in ('SS_START','S_START'): insprite = True; continue
        if u in ('SS_END','S_END'): insprite = False; continue
        if u in TEXT: handle_text(out, pack, u, data); continue
        if not data: continue
        if insprite or data[:4] == b'\x89PNG':
            # some packs keep sprites outside markers
            out.write(f'sprites/weapons/{pack}/{name}.lmp', data)
        else:
            out.write(f'sounds/weapons/{pack}/{name}.lmp', data)

def import_pk3(out, pack, path):
    z = zipfile.ZipFile(path)
    for n in z.namelist():
        if n.endswith('/'): continue
        low = n.lower(); data = z.read(n)
        base = os.path.basename(n); stem = base.split('.')[0].upper()
        top = low.split('/')[0] if '/' in low else ''
        if top == '':
            if stem in TEXT or stem == 'TEXTURES': handle_text(out, pack, stem, data)
            continue
        if top == 'altsprites': continue
        if top == 'sprites':   out.write(f'sprites/weapons/{pack}/{base}', data)
        elif top == 'sounds':  out.write(f'sounds/weapons/{pack}/{base}', data)
        elif top == 'brightmaps': out.write('brightmaps/' + n.split('/',1)[1], data)
        elif top == 'models':  out.write('models/' + n.split('/',1)[1].lower(), data)
        elif top in ('graphics','textures','patches'): out.write(top + '/' + n.split('/',1)[1], data)
        else: print('  ?? skipped', pack, n)

def main(mod, root):
    out = Out(root)
    packs = sorted(f for f in os.listdir(mod) if f.lower().endswith('.zip'))
    for zf in packs:
        z = zipfile.ZipFile(os.path.join(mod, zf))
        for n in z.namelist():
            if n.lower().endswith(('.wad','.pk3')):
                pack = re.sub(r'[^a-z0-9]', '', os.path.basename(n).rsplit('.',1)[0].lower())
                tmp = os.path.join(root, '_tmp_' + pack); open(tmp,'wb').write(z.read(n))
                (import_wad if n.lower().endswith('.wad') else import_pk3)(out, pack, tmp)
                os.remove(tmp); print('imported weapon pack', pack)
    # ---- enemies
    dp = os.path.join(mod, 'DeePaybackEnemies')
    for sub in ('sprites','sounds'):
        shutil.copytree(os.path.join(dp, sub), os.path.join(root, sub, 'deepayback'), dirs_exist_ok=True)
    for f in os.listdir(os.path.join(dp,'actors')):
        out.write(f'decorate/enemies/{f.lower()}', txt(open(os.path.join(dp,'actors',f),'rb').read()).encode('latin1'))
    dec = txt(open(os.path.join(dp,'DECORATE.lmp'),'rb').read())
    for m in re.finditer(r'#include\s+"actors/([^"]+)"', dec): out.dec.append('decorate/enemies/' + m.group(1).lower())
    out.snd.append('// ---- DeePaybackEnemies\n' + txt(open(os.path.join(dp,'SNDINFO.lmp'),'rb').read()) + '\n')
    out.credits.append(('DeePaybackEnemies (DeeDeeOZ)', txt(open(os.path.join(dp,'credits.txt'),'rb').read()).strip()))
    # ---- tactical AI
    td = os.path.join(mod, 'TacticalDuckDodge')
    zs = txt(open(os.path.join(td,'ZSCRIPT.zs'),'rb').read())
    zs = re.sub(r'(?im)^\s*version\s+"[^"]*"\s*;?', '', zs)
    # compatibility patch: 'Class<Actor>(x)' is not valid ZScript cast syntax
    zs = re.sub(r'\bClass<Actor>\(([^()]+)\)', r'((class<Actor>)(\1))', zs)
    out.write('zscript/tactical/tactical_ai.zs', zs.encode('latin1')); out.zs.append('zscript/tactical/tactical_ai.zs')
    out.write('_gen/cvarinfo_tactical.txt', txt(open(os.path.join(td,'CVARINFO.txt'),'rb').read()).encode('latin1'))
    out.write('_gen/menudef_tactical.txt', txt(open(os.path.join(td,'MENUDEF.txt'),'rb').read()).encode('latin1'))
    # ---- merged lumps
    out.write('_gen/decorate_includes.txt', '\n'.join(f'#include "{d}"' for d in out.dec).encode())
    out.write('_gen/sndinfo_imports.txt', '\n'.join(out.snd).encode('latin1'))
    out.write('_gen/gldefs_imports.txt', '\n'.join(out.gl).encode('latin1'))
    out.write('_gen/modeldef_imports.txt', '\n'.join(out.mdl).encode('latin1'))
    out.write('_gen/textures_imports.txt', '\n'.join(out.tex).encode('latin1'))
    out.write('_gen/zscript_includes.txt', '\n'.join(f'#include "{d}"' for d in out.zs).encode())
    cr = ['THIRD-PARTY RESOURCE CREDITS (as shipped with each pack in _modding)', '='*70, '']
    for p, t in out.credits: cr += [f'--- {p} ---', t, '']
    out.write('_gen/credits_imports.txt', '\n'.join(cr).encode('latin1','replace'))

if __name__ == '__main__': main(sys.argv[1], sys.argv[2])
