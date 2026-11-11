#!/usr/bin/env python3
"""Synthesises Ancient Bounties' original sound effects (numpy -> 16-bit mono WAV).
   Usage: gen_sfx.py <build dir>"""
import os, sys, wave, struct
import numpy as np
SR = 22050
B = sys.argv[1] if len(sys.argv) > 1 else 'build'
OUT = os.path.join(B, 'sounds', 'ab'); os.makedirs(OUT, exist_ok=True)
R = np.random.default_rng(7)
def t(d): return np.arange(int(SR * d)) / SR
def env(x, a=0.005, decay=6.0):
    n = len(x); tt = np.arange(n) / SR
    return x * np.minimum(1, tt / a) * np.exp(-decay * tt)
def tone(f, d, decay=6.0, kind='sin', vib=0.0, slide=0.0):
    tt = t(d); ff = f * (1 + slide * tt / d) + vib * np.sin(2 * np.pi * 6 * tt)
    ph = 2 * np.pi * np.cumsum(ff) / SR
    w = np.sin(ph) if kind == 'sin' else (np.sign(np.sin(ph)) * 0.5 if kind == 'sq' else 2 / np.pi * np.arcsin(np.sin(ph)))
    return env(w, decay=decay)
def noise(d, decay=10.0, lp=0.3, hp=0.0):
    x = R.standard_normal(int(SR * d)); y = np.zeros_like(x); acc = 0.0
    for i in range(len(x)): acc += lp * (x[i] - acc); y[i] = acc
    if hp:
        z = np.zeros_like(y); acc = 0.0
        for i in range(len(y)): acc += hp * (y[i] - acc); z[i] = y[i] - acc
        y = z
    return env(y / (np.abs(y).max() + 1e-9), decay=decay)
def seq(parts):
    """parts: [(start_seconds, samples, gain)]"""
    n = max(int(s * SR) + len(x) for s, x, g in parts); out = np.zeros(n)
    for s, x, g in parts:
        i = int(s * SR); out[i:i + len(x)] += x * g
    return out
def save(name, x, vol=0.8):
    x = x / (np.abs(x).max() + 1e-9) * vol
    fade = min(len(x), 200); x[-fade:] *= np.linspace(1, 0, fade)
    with wave.open(os.path.join(OUT, name + '.wav'), 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes((x * 32767).astype('<i2').tobytes())

save('abcoin',  seq([(0, tone(1900, .18, 14), 1), (0.05, tone(2550, .25, 12), .8), (0.0, noise(.03, 60, .9), .3)]))
save('abgem',   seq([(0, tone(1568, .25, 9), 1), (0.07, tone(2093, .25, 9), .9), (0.14, tone(2637, .4, 7), .8)]))
save('abrelic', seq([(i * .09, tone(f, .5, 5), .9) for i, f in enumerate([523, 659, 784, 1047])] + [(0.36, tone(1568, .8, 4), .5)]))
save('abgreat', seq([(i * .14, tone(f, 1.2, 2.5, vib=3), .8) for i, f in enumerate([392, 523, 659, 784, 1047])] + [(0.7, tone(1568, 1.6, 2), .5), (0.7, tone(1319, 1.6, 2), .4), (0, noise(1.6, 2, .02), .25)]))
save('abintel', seq([(0, noise(.12, 25, .5, .2), 1), (0.1, noise(.1, 30, .6, .2), .8), (0.2, tone(880, .12, 20, 'sq'), .3), (0.3, tone(1320, .15, 18, 'sq'), .3)]))
save('abcrate', seq([(0, noise(.15, 22, .12), 1), (0, tone(110, .2, 16), .9), (0.12, noise(.1, 30, .2), .6)]))
save('aburn',   seq([(0, noise(.25, 14, .9, .5), 1), (0.02, tone(2400, .08, 40), .4), (0.05, tone(3100, .1, 30), .3), (0.09, noise(.3, 9, .8, .6), .5)]))
save('ablever', seq([(0, noise(.06, 50, .25), 1), (0, tone(160, .12, 25), .8), (0.11, noise(.08, 40, .15), 1), (0.11, tone(95, .2, 16), 1)]))
save('abplate', seq([(0, noise(.3, 9, .06), 1), (0, tone(70, .4, 8), 1), (0.25, tone(52, .5, 6), .8)]))
save('abstone', seq([(0, noise(.5, 5, .05), 1), (0, noise(.5, 6, .3, .3), .25)]))
save('abflame', seq([(0, noise(.45, 7, .2, .05), 1), (0, tone(180, .3, 10, slide=1.5), .3)]))
save('abtotem', seq([(0, tone(440, .5, 6, 'tri'), 1), (0, tone(880, .5, 8), .4), (0, tone(220, .5, 6), .5)]))
save('abwrong', seq([(0, tone(150, .35, 5, 'sq'), 1), (0, tone(158, .35, 5, 'sq'), 1), (0.0, noise(.1, 20, .2), .4)]))
save('absolve', seq([(i * .11, tone(f, .9, 3.5, 'tri'), .8) for i, f in enumerate([392, 494, 587, 784, 988])] + [(0, noise(1.4, 3, .04), .6), (0, tone(55, 1.4, 2), .7)]))
save('abclue',  seq([(0, noise(.25, 10, .7, .4), .7), (0.05, tone(659, .3, 8, 'tri'), .6), (0.18, tone(988, .5, 6, 'tri'), .6)]))
save('abdart',  seq([(0, noise(.12, 30, .9, .5), 1), (0, tone(1400, .1, 30, slide=-.6), .5)]))
save('abspike', seq([(0, noise(.1, 30, .9, .3), 1), (0, tone(900, .15, 20, slide=-.5), .6), (0.02, tone(2100, .2, 16), .3)]))
save('abspikew', seq([(0, tone(300, .08, 30, 'sq'), .6), (0.0, noise(.06, 40, .3), .6)]))
save('abalarm', seq([(i * .28, tone(740, .22, 3, 'sq', slide=.25), .8) for i in range(4)]))
save('abfail',  seq([(i * .22, tone(f, .9, 3, 'tri'), .9) for i, f in enumerate([392, 349, 311, 233])] + [(0, tone(58, 1.8, 1.5), .8)]))
save('abextract', seq([(0, noise(1.2, 3, .15, .1), .5)] + [(i * .12, tone(f, .6, 4, 'tri'), .8) for i, f in enumerate([523, 659, 784, 1047, 1319])]))
save('abdodge', seq([(0, noise(.28, 9, .12, .02), 1), (0.05, noise(.2, 12, .5, .3), .3)]))
save('abmedkit', seq([(0, noise(.1, 30, .5, .2), .8), (0.12, tone(660, .2, 10), .6), (0.24, tone(880, .35, 7), .6)]))
save('abrevive', seq([(0, tone(110, .8, 3, slide=3), .8), (0.3, tone(880, .6, 5, 'tri'), .6), (0.4, tone(1320, .7, 4, 'tri'), .5)]))
save('abbuild', seq([(i * .17, noise(.08, 35, .25), 1) for i in range(3)] + [(i * .17, tone(240 - i * 10, .1, 25), .9) for i in range(3)] + [(0.55, tone(784, .5, 6, 'tri'), .5)]))
save('abbuy',   seq([(0, tone(1244, .12, 16), .8), (0.08, tone(1865, .3, 9), .8), (0, noise(.05, 50, .8, .4), .4)]))
save('abradio', seq([(0, noise(.5, 3, .9, .7), .6), (0.1, tone(1200, .08, 20, 'sq'), .4), (0.25, tone(1200, .08, 20, 'sq'), .4), (0.4, tone(1600, .15, 14, 'sq'), .4)]))
fire = noise(2.0, 0.0, .35, .05) * (0.6 + 0.4 * np.abs(noise(2.0, 0.0, .002)))
for i in range(40):
    p = R.integers(0, len(fire) - 400); fire[p:p + 300] += noise(300 / SR + 0.001, 80, .9, .5)[:300] * R.uniform(.5, 1.5)
save('abfire', fire, .6)
save('abmove',  tone(520, .05, 40, 'tri'), .4)
save('abok',    seq([(0, tone(700, .07, 30, 'tri'), 1), (0.05, tone(1050, .1, 22, 'tri'), 1)]), .5)
save('abno',    seq([(0, tone(200, .12, 16, 'sq'), 1)]), .4)
save('abtravel', seq([(0, noise(1.6, 1.2, .05), 1), (0, tone(82, 1.6, 1.0, vib=4), .8), (0, tone(123, 1.6, 1.2, vib=5), .5)]))
print('sfx generated:', len(os.listdir(OUT)))
