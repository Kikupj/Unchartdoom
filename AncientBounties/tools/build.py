#!/usr/bin/env python3
"""Ancient Bounties build script.
   python3 tools/build.py [--modding DIR] [--out FILE.pk3] [--no-import] [--no-zip]
Steps: import third-party packs -> generate art -> generate maps -> copy src -> assemble root lumps -> zip."""
import os, sys, shutil, subprocess, zipfile, argparse, glob
HERE = os.path.dirname(os.path.abspath(__file__)); ROOT = os.path.dirname(HERE)
ap = argparse.ArgumentParser()
ap.add_argument('--modding', default=os.path.join(ROOT, '..', '_modding'))
ap.add_argument('--build', default=os.path.join(ROOT, 'build'))
ap.add_argument('--out', default=os.path.join(ROOT, 'AncientBounties.pk3'))
ap.add_argument('--no-import', action='store_true'); ap.add_argument('--no-zip', action='store_true')
ap.add_argument('--no-art', action='store_true'); ap.add_argument('--no-maps', action='store_true')
a = ap.parse_args()
B = a.build; SRC = os.path.join(ROOT, 'src')
def run(*cmd): print('>', ' '.join(cmd)); subprocess.check_call([sys.executable, '-I', *cmd])
def rd(p): return open(p, encoding='latin1').read() if os.path.exists(p) else ''
def wr(rel, s):
    p = os.path.join(B, rel); os.makedirs(os.path.dirname(p), exist_ok=True); open(p, 'w', encoding='latin1', newline='\n').write(s)
if not a.no_import:
    shutil.rmtree(B, ignore_errors=True); os.makedirs(B)
    run(os.path.join(HERE, 'import_packs.py'), a.modding, B)
if not a.no_art:
    os.environ.setdefault('AB_BRANDING', os.path.join(ROOT, '..', 'branding', 'source'))
    run(os.path.join(HERE, 'gen_art.py'), B); run(os.path.join(HERE, 'gen_sfx.py'), B)
if not a.no_maps and os.path.exists(os.path.join(HERE, 'gen_maps.py')): run(os.path.join(HERE, 'gen_maps.py'), B)
# copy hand-written source tree (zscript/, graphics/, etc.)
for dp, dn, fn in os.walk(SRC):
    for f in fn:
        rel = os.path.relpath(os.path.join(dp, f), SRC)
        if rel.startswith('lumps' + os.sep): continue
        dst = os.path.join(B, rel); os.makedirs(os.path.dirname(dst), exist_ok=True); shutil.copyfile(os.path.join(dp, f), dst)
G = os.path.join(B, '_gen'); L = os.path.join(SRC, 'lumps')
zs_mine = sorted(os.path.relpath(p, SRC).replace(os.sep, '/') for p in glob.glob(os.path.join(SRC, 'zscript', 'ab', '*.zs')))
wr('zscript.zs', 'version "4.12"\n' + rd(os.path.join(G, 'zscript_includes.txt')) + '\n' + '\n'.join(f'#include "{z}"' for z in zs_mine) + '\n')
wr('decorate.txt', rd(os.path.join(G, 'decorate_includes.txt')) + '\n' + rd(os.path.join(L, 'decorate_ab.txt')))
wr('sndinfo.txt', rd(os.path.join(L, 'sndinfo.txt')) + '\n' + rd(os.path.join(G, 'sndinfo_imports.txt')))
wr('gldefs.txt', rd(os.path.join(L, 'gldefs.txt')) + '\n' + rd(os.path.join(G, 'gldefs_imports.txt')))
wr('modeldef.txt', rd(os.path.join(G, 'modeldef_imports.txt')))
wr('textures.txt', rd(os.path.join(G, 'textures_imports.txt')) + '\n' + rd(os.path.join(G, 'textures_art.txt')))
wr('cvarinfo.txt', rd(os.path.join(L, 'cvarinfo.txt')) + '\n' + rd(os.path.join(G, 'cvarinfo_tactical.txt')))
wr('menudef.txt', rd(os.path.join(L, 'menudef.txt')) + '\n' + rd(os.path.join(G, 'menudef_tactical.txt')))
wr('mapinfo.txt', rd(os.path.join(L, 'mapinfo.txt')) + '\n' + rd(os.path.join(G, 'mapinfo_maps.txt')))
for extra in ('keyconf.txt', 'language.txt', 'animdefs.txt', 'credits.txt', 'terrain.txt', 'sbarinfo.txt', 'decaldef.txt', 'gameinfo.txt'):
    if os.path.exists(os.path.join(L, extra)): wr(extra, rd(os.path.join(L, extra)))
wr('CREDITS-THIRD-PARTY.txt', rd(os.path.join(G, 'credits_imports.txt')))
if not a.no_zip:
    tmp = a.out + '.tmp'
    with zipfile.ZipFile(tmp, 'w', zipfile.ZIP_DEFLATED, compresslevel=6) as z:
        for dp, dn, fn in os.walk(B):
            if os.path.basename(dp) == '_gen': continue
            for f in sorted(fn):
                p = os.path.join(dp, f); z.write(p, os.path.relpath(p, B).replace(os.sep, '/'))
    os.replace(tmp, a.out); print('wrote', a.out, os.path.getsize(a.out)//1024, 'KB')
