#!/usr/bin/env python3
"""OBLIVION: generate all sound effects, ambiences and music procedurally.

Only numpy + scipy; no samples are downloaded. Output is deterministic (fixed seed).

Run from the project root:
    uv run --with numpy --with scipy python tools/gen_audio.py              # everything
    uv run --with numpy --with scipy python tools/gen_audio.py bell amb_forest
    uv run --with numpy --with scipy python tools/gen_audio.py --list
    uv run --with numpy --with scipy python tools/gen_audio.py --verify-only

SFX   -> assets/audio/sfx/<name>.wav     16-bit mono 44.1 kHz, peak ~-3 dBFS.
Loops -> assets/audio/music/<name>.ogg   Vorbis q4 44.1 kHz stereo (ffmpeg or oggenc);
         without an encoder they fall back to 16-bit WAV 22.05 kHz.

Loops are built to be exactly periodic: one-shot events are written with wrap-around,
drones use frequencies with a whole number of cycles per loop, reverb is circular
(FFT convolution modulo the loop length) and non-periodic noise beds are rendered
2 s longer and their tail is crossfaded into the head.
"""
from __future__ import annotations

import argparse
import os
import shutil
import subprocess
import sys
import tempfile
import wave
import zlib
from functools import lru_cache
from pathlib import Path

import numpy as np
from scipy import signal

SR = 44100
SEED = 20230917
TAU = 2.0 * np.pi
ROOT = Path(__file__).resolve().parent.parent
SFX_DIR = ROOT / "assets" / "audio" / "sfx"
MUS_DIR = ROOT / "assets" / "audio" / "music"
TMP = Path(os.environ.get("OBLIVION_AUDIO_TMP") or tempfile.gettempdir()) / "oblivion_audio"

SFX_PEAK_DB = -3.0
MUSIC_PEAK_DB = -3.0
AMB_PEAK_DB = -6.0  # ambience plays under music on the same bus


# ----------------------------------------------------------------------------- basics

def rng_for(name: str) -> np.random.Generator:
    return np.random.default_rng([SEED, zlib.crc32(name.encode())])


def ns(sec: float) -> int:
    return max(1, int(round(sec * SR)))


def tt(n: int) -> np.ndarray:
    return np.arange(n) / SR


def nz(x: np.ndarray) -> np.ndarray:
    return x / (np.max(np.abs(x)) + 1e-12)


def mtof(m: float) -> float:
    return 440.0 * 2.0 ** ((m - 69) / 12.0)


_PC = {"C": 0, "D": 2, "E": 4, "F": 5, "G": 7, "A": 9, "B": 11}


def N(name: str) -> int:
    """'C#4' -> midi."""
    pc = _PC[name[0]]
    rest = name[1:]
    while rest and rest[0] in "#b":
        pc += 1 if rest[0] == "#" else -1
        rest = rest[1:]
    return (int(rest) + 1) * 12 + pc


def fout(x: np.ndarray, sec: float = 0.004) -> np.ndarray:
    """Copy of x with a short cosine fade-out (removes truncation clicks)."""
    x = np.array(x, float, copy=True)
    n = min(ns(sec), x.shape[-1])
    x[..., -n:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, n))
    return x


def put(buf: np.ndarray, sig: np.ndarray, t0: float) -> None:
    i = int(round(t0 * SR))
    if i < 0:
        sig, i = sig[..., -i:], 0
    j = min(buf.shape[-1], i + sig.shape[-1])
    if j > i:
        buf[..., i:j] += fout(sig[..., : j - i])


def put_wrap(buf: np.ndarray, sig: np.ndarray, t0: float) -> None:
    """Add sig into a loop buffer, wrapping past the end back to the start."""
    L = buf.shape[-1]
    n = sig.shape[-1]
    assert n <= L
    idx = (int(round(t0 * SR)) + np.arange(n)) % L
    buf[..., idx] += fout(sig)


def pan(x: np.ndarray, p: float) -> np.ndarray:
    a = (np.clip(p, -1, 1) + 1) * np.pi / 4
    return np.stack([x * np.cos(a), x * np.sin(a)])


# ----------------------------------------------------------------------------- filters

def _sos(kind, fc, order):
    return signal.butter(order, fc, btype=kind, fs=SR, output="sos")


def lp(x, fc, order=2):
    return signal.sosfilt(_sos("lowpass", min(fc, SR * 0.45), order), x, axis=-1)


def hp(x, fc, order=2):
    return signal.sosfilt(_sos("highpass", fc, order), x, axis=-1)


def bp(x, lo, hi, order=2):
    return signal.sosfilt(_sos("bandpass", [lo, min(hi, SR * 0.45)], order), x, axis=-1)


def reson(x, f, bw):
    """Unity-peak 2-pole resonator."""
    f = min(f, SR * 0.45)
    b, a = signal.iirpeak(f, max(f / bw, 0.5), fs=SR)
    return signal.lfilter(b, a, x, axis=-1)


def fft_shape(x, gain_fn):
    """Circular (loop-safe) zero-phase filtering by a gain curve g(f)."""
    L = x.shape[-1]
    f = np.fft.rfftfreq(L, 1 / SR)
    return np.fft.irfft(np.fft.rfft(x, axis=-1) * gain_fn(f), n=L, axis=-1)


def g_lp(fc, order=2):
    return lambda f: 1 / np.sqrt(1 + (f / fc) ** (2 * order))


def g_hp(fc, order=2):
    def g(f):
        r = np.maximum(f, 1e-9) / fc
        return r**order / np.sqrt(1 + r ** (2 * order))
    return g


def g_bp(lo, hi, order=2):
    a, b = g_hp(lo, order), g_lp(hi, order)
    return lambda f: a(f) * b(f)


def _frame_interp(ft, v, n):
    v = np.asarray(v, float)
    if v.ndim == 0:
        return np.full(len(ft), float(v))
    return np.interp(ft, np.arange(len(v)) / SR, v)


def stft_apply(x, mask_fn, nper=2048):
    """Time-varying spectral filter: mask_fn(freqs, frame_times) -> gain matrix."""
    n = len(x)
    nov = nper * 3 // 4
    f, ft, Z = signal.stft(x, fs=SR, nperseg=nper, noverlap=nov)
    _, y = signal.istft(Z * mask_fn(f, ft), fs=SR, nperseg=nper, noverlap=nov)
    y = y[:n]
    if len(y) < n:
        y = np.pad(y, (0, n - len(y)))
    return y


def stft_band(x, center, bw_oct, nper=2048):
    """Gaussian (in log-frequency) band around a moving centre frequency."""
    n = len(x)

    def m(f, ft):
        c = _frame_interp(ft, center, n)
        b = _frame_interp(ft, bw_oct, n)
        lf = np.log2(np.maximum(f, 10.0)[:, None] / c[None])
        return np.exp(-0.5 * (lf / b[None]) ** 2)

    return stft_apply(x, m, nper)


# ----------------------------------------------------------------------------- sources

def white(r, n, ch=None):
    return r.standard_normal(n if ch is None else (ch, n))


def _colored(r, n, ch, power):
    x = white(r, n, ch)
    X = np.fft.rfft(x, axis=-1)
    f = np.fft.rfftfreq(n, 1 / SR)
    g = np.zeros_like(f)
    g[1:] = (f[1:] / 100.0) ** (-power / 2)
    y = np.fft.irfft(X * g, n=n, axis=-1)  # circular -> periodic in n
    return y / (np.std(y) + 1e-12)


def pink(r, n, ch=None):
    return _colored(r, n, ch, 1.0)


def brown(r, n, ch=None):
    return _colored(r, n, ch, 2.0)


def smooth(r, n, rate, lo=0.0, hi=1.0, periodic=False):
    """Smooth random curve (cosine-interpolated random points, `rate` points/s)."""
    k = max(1, int(np.ceil(n / SR * rate)))
    pts = r.uniform(lo, hi, k + 1)
    if periodic:
        pts[-1] = pts[0]
    x = np.arange(n) * (k / n)
    i = np.minimum(x.astype(int), k - 1)
    fr = x - i
    w = 0.5 - 0.5 * np.cos(np.pi * fr)
    return pts[i] * (1 - w) + pts[i + 1] * w


def sine(freq, n, ph0=0.0):
    f = np.broadcast_to(np.asarray(freq, float), (n,))
    return np.sin(TAU * (ph0 + np.cumsum(f) / SR))


def saw(freq, n, ph0=0.0):
    """Band-limited (PolyBLEP) sawtooth."""
    f = np.broadcast_to(np.asarray(freq, float), (n,))
    dt = f / SR
    p = (ph0 + np.cumsum(dt)) % 1.0
    y = 2 * p - 1
    m = p < dt
    x = p[m] / dt[m]
    y[m] -= x + x - x * x - 1
    m = p > 1 - dt
    x = (p[m] - 1) / dt[m]
    y[m] -= x * x + x + x + 1
    return y


def qf(f, L):
    """Round a frequency so it completes a whole number of cycles in L samples."""
    per = L / SR
    return max(1, round(f * per)) / per


# ----------------------------------------------------------------------------- envelopes

def expdec(n, tau):
    return np.exp(-tt(n) / tau)


def attack(n, a):
    return 1 - np.exp(-tt(n) / max(a, 1e-5))


def env_ar(n, a, rel):
    e = np.ones(n)
    na = min(n, ns(a))
    nr = min(n - na, ns(rel))
    e[:na] = 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, na))
    if nr > 0:
        e[n - nr:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, nr))
    return e


def fade(x, a=0.002, rel=0.02):
    x = np.array(x, float, copy=True)
    n = x.shape[-1]
    na = min(ns(a), n // 2)
    nr = min(ns(rel), n // 2)
    x[..., :na] *= 0.5 - 0.5 * np.cos(np.linspace(0, np.pi, na))
    x[..., n - nr:] *= 0.5 + 0.5 * np.cos(np.linspace(0, np.pi, nr))
    return x


# ----------------------------------------------------------------------------- building blocks

def modal(r, n, modes):
    """Sum of exponentially decaying sines: modes = [(freq, amp, tau), ...]."""
    t = tt(n)
    y = np.zeros(n)
    for f, a, tau in modes:
        if 20 < f < SR * 0.45:
            y += a * np.sin(TAU * f * t + r.uniform(0, TAU)) * np.exp(-t / tau)
    return fout(y * attack(n, 0.0004), min(0.03, n / SR / 4))


def tick(r, n, tau=0.002, fc=2500):
    return hp(white(r, n), fc) * expdec(n, tau)


def thump(n, f0, f1, tau, glide=0.012):
    t = tt(n)
    return sine(f1 + (f0 - f1) * np.exp(-t / glide), n) * np.exp(-t / tau) * attack(n, 0.001)


def stick_slip(r, rate, res, jitter=0.0005, amp_var=0.4, noise=0.02, exc_lp=2500.0):
    """Friction creak: impulse train at `rate` Hz exciting resonators [(f, bw, gain)]."""
    n = len(rate)
    ph = np.cumsum(rate) / SR
    idx = np.nonzero(np.diff(np.floor(ph)) > 0)[0] + 1
    js = int(jitter * SR)
    if js:
        idx = np.clip(idx + r.integers(-js, js + 1, len(idx)), 0, n - 1)
    exc = np.zeros(n)
    np.add.at(exc, idx, 1 - amp_var * r.uniform(0, 1, len(idx)))
    exc += noise * white(r, n)
    exc = lp(exc, exc_lp, 2)  # soften each slip so the resonators, not the clicks, carry the sound
    return sum(g * reson(exc, f, bw) for f, bw, g in res)


def bubble(r, f0, dur=0.12, rise=2.0, tau=0.03):
    n = ns(dur)
    t = tt(n)
    f = f0 * (1 + (rise - 1) * (1 - np.exp(-t / 0.03)))
    return sine(f, n) * np.exp(-t / tau) * attack(n, 0.0008)


def make_ir(r, decay, ch=1, predelay=0.015, damp=6000.0, hpf=80.0):
    m = ns(decay)
    t = tt(m)
    env = 10 ** (-3 * t / decay) * (1 - np.exp(-t / 0.004))
    ir = r.standard_normal((ch, m)) * env
    dark = lp(ir, damp * 0.25, 1)
    w = np.sqrt(t / decay)
    ir = ir * (1 - w) + dark * w  # high frequencies die first
    ir = hp(lp(ir, damp, 2), hpf, 1)
    ir /= np.sqrt(np.sum(ir**2) / ch)
    return np.concatenate([np.zeros((ch, ns(predelay))), ir], axis=1)


def reverb(x, r, decay, wet, **kw):
    """Mono convolution reverb; output is longer by the tail."""
    ir = make_ir(r, decay, 1, **kw)[0]
    w = signal.fftconvolve(x, ir)
    out = np.zeros(len(w))
    out[: len(x)] = x
    return out + wet * w


def creverb(x, r, decay, wet, **kw):
    """Stereo circular reverb for loops (the tail wraps into the head)."""
    if x.ndim == 1:
        x = np.stack([x, x])
    L = x.shape[-1]
    ir = make_ir(r, decay, 2, **kw)
    H = np.fft.rfft(ir, n=L, axis=-1)
    y = np.fft.irfft(np.fft.rfft(x, axis=-1) * H, n=L, axis=-1)
    return x + wet * y


def loopify(x, L, X):
    """Equal-power crossfade of the tail x[L:L+X] into the head x[:X]."""
    th = np.linspace(0, np.pi / 2, X)
    y = x[..., :L].copy()
    y[..., :X] = x[..., :X] * np.sin(th) + x[..., L:L + X] * np.cos(th)
    return y


def formant_noise(r, n, times, amp, formants, hiss=None, nper=1024):
    """Whisper-like noise: keyframed formants [(F[], B[], A[]), ...] over `times`."""
    x = white(r, n)
    nov = nper * 3 // 4
    f, ft, Z = signal.stft(x, fs=SR, nperseg=nper, noverlap=nov)
    at = lambda v: np.interp(ft, times, v)  # noqa: E731
    M = np.zeros((len(f), len(ft)))
    for F, B, A in formants:
        Fc, Bc, Ac = at(F), at(B), at(A)
        M += Ac[None] * np.exp(-0.5 * ((f[:, None] - Fc[None]) / Bc[None]) ** 2)
    M *= at(amp)[None]
    if hiss is not None:
        shape = 1 / (1 + np.exp(-(f - 4200) / 600)) / (1 + (f / 11000) ** 4)
        M += at(hiss)[None] * shape[:, None]
    _, y = signal.istft(Z * M, fs=SR, nperseg=nper, noverlap=nov)
    y = y[:n]
    return np.pad(y, (0, n - len(y))) if len(y) < n else y


# ----------------------------------------------------------------------------- instruments

@lru_cache(maxsize=None)
def piano_raw(midi: int, velq: int) -> np.ndarray:
    """Additive piano: inharmonic partials, 3 detuned strings, 2-stage decay, hammer."""
    vel = velq / 10.0
    r = np.random.default_rng([SEED, 7, midi, velq])
    f0 = mtof(midi)
    n = ns(5.0)
    t = tt(n)
    B = 0.00035
    cut = 700 + 3800 * vel**1.5
    scale = (261.63 / f0) ** 0.55
    y = np.zeros(n)
    for k in range(1, 25):
        fk = k * f0 * np.sqrt(1 + B * k * k)
        if fk > 16000:
            break
        a = k**-0.9 / np.sqrt(1 + (fk / cut) ** 4) * (abs(np.sin(np.pi * k / 7.3)) + 0.05)
        t1 = 0.28 * scale / (1 + 0.3 * (k - 1))
        t2 = 2.8 * scale / (1 + 0.14 * (k - 1))
        e = 0.55 * np.exp(-t / t1) + 0.45 * np.exp(-t / t2)
        s = np.zeros(n)
        for d in (-1, 0, 1):
            cents = d * r.uniform(0.3, 1.0)
            s += np.sin(TAU * fk * 2 ** (cents / 1200) * t + r.uniform(0, TAU))
        y += a * e * s / 3
    y *= attack(n, 0.0012 + 0.002 * (1 - vel))
    hn = ns(0.04)
    ham = lp(r.standard_normal(hn), 900 + 3000 * vel) * expdec(hn, 0.006)
    y[:hn] += nz(ham) * np.max(np.abs(y)) * (0.08 + 0.12 * vel)
    return y * (0.25 + 0.75 * vel)


def piano(midi, hold, vel=0.6, damp=None):
    raw = piano_raw(int(midi), int(np.clip(round(vel * 10), 1, 10)))
    rel = damp if damp is not None else (0.18 if midi < 60 else 0.1)
    n = min(len(raw), ns(hold + rel * 6))
    y = raw[:n].copy()
    h = min(n, ns(hold))
    y[h:] *= np.exp(-tt(n - h) / rel)
    return fade(y, 0.0005, 0.02)


def bell_tone(r, f, n, partials, warble=0.6):
    t = tt(n)
    y = np.zeros(n)
    for ratio, a, tau in partials:
        fk = f * ratio
        if fk >= SR * 0.45:
            continue
        for d in (-1, 1):
            y += 0.5 * a * np.sin(TAU * (fk + d * warble * r.uniform(0.3, 1)) * t + r.uniform(0, TAU)) * np.exp(-t / tau)
    return fout(y * attack(n, 0.0006), n / SR / 3)


CHIME = [(1, 1.0, 1.0), (2.0, 0.35, 0.55), (2.99, 0.15, 0.4), (4.18, 0.2, 0.25), (5.43, 0.1, 0.15), (6.8, 0.05, 0.1)]
HANDBELL = [(1, 1.0, 1.1), (2.0, 0.25, 0.6), (2.76, 0.45, 0.45), (5.4, 0.22, 0.2), (8.93, 0.1, 0.09)]
BIG_BELL = [(0.5, 0.6, 4.5), (1.0, 0.8, 3.4), (1.19, 0.55, 2.6), (1.5, 0.35, 2.0), (2.0, 1.0, 2.2),
            (2.5, 0.3, 1.2), (2.66, 0.35, 1.1), (3.0, 0.25, 0.9), (4.0, 0.2, 0.7), (5.33, 0.12, 0.5),
            (6.4, 0.08, 0.35)]


def music_box_note(r, midi, dur=1.6, detune_cents=0.0):
    n = ns(dur)
    f = mtof(midi) * 2 ** (detune_cents / 1200)
    sc = (523.0 / f) ** 0.4
    y = modal(r, n, [(f, 1.0, 0.9 * sc), (2 * f, 0.08, 0.4 * sc), (6.27 * f, 0.3, 0.1 * sc),
                     (17.55 * f, 0.08, 0.025)])
    y += 0.15 * tick(r, n, 0.0015, 3000)
    return y


def pad_voice(r, midis, n, attack_s, release_s, bright=0.25, detune=7.0, voices=3, vib=0.0012):
    """Soft chorused pad: detuned sine stacks with a few decaying harmonics, stereo."""
    t = tt(n)
    y = np.zeros((2, n))
    for m in midis:
        f = mtof(m)
        for v in range(voices):
            c = (v - (voices - 1) / 2) * detune + r.uniform(-1.5, 1.5)
            fr = f * 2 ** (c / 1200) * (1 + vib * np.sin(TAU * r.uniform(0.1, 0.3) * t + r.uniform(0, TAU)))
            ph = TAU * np.cumsum(fr) / SR + r.uniform(0, TAU)
            s = sum(bright ** (k - 1) * np.sin(k * ph) for k in range(1, 6))
            y += pan(s, r.uniform(-0.7, 0.7))
    return y * env_ar(n, attack_s, release_s) / (len(midis) * voices)


def string_voice(r, midis, n, cutoff, detune=9.0, voices=4, width=True):
    """Saw-based string section note, stereo (different detune per side)."""
    y = np.zeros((2, n))
    for m in midis:
        f = mtof(m)
        for ch in range(2):
            s = np.zeros(n)
            for _ in range(voices):
                s += saw(f * 2 ** (r.uniform(-detune, detune) / 1200), n, r.uniform())
            y[ch] += s
    y = lp(y, cutoff, 2)
    return y / (len(midis) * voices)


# ============================================================================= SFX

SFX = {}


def sfx(fn):
    SFX[fn.__name__] = fn
    return fn


@sfx
def ui_hover(r):
    n = ns(0.09)
    t = tt(n)
    y = sine(2100 * (1 + 0.06 * np.exp(-t / 0.008)), n) * np.exp(-t / 0.018)
    y += 0.25 * sine(3150, n) * np.exp(-t / 0.008)
    return reverb(y * attack(n, 0.0015), r, 0.35, 0.25, damp=9000)


@sfx
def ui_click(r):
    n = ns(0.14)
    y = 0.5 * tick(r, n, 0.0025)
    y += modal(r, n, [(880, 1, 0.035), (1320, 0.5, 0.02), (2640, 0.25, 0.01)])
    y += 0.6 * thump(n, 260, 170, 0.02)
    return reverb(y, r, 0.4, 0.2, damp=8000)


@sfx
def ui_back(r):
    y = np.zeros(ns(0.25))
    for t0, f, d in ((0.0, 620, 0.07), (0.06, 440, 0.13)):
        n = ns(d + 0.05)
        t = tt(n)
        fr = f * (1 - 0.03 * t / d)
        s = (sine(fr, n) + 0.3 * sine(2 * fr, n)) * np.exp(-t / (d * 0.5)) * attack(n, 0.002)
        put(y, s, t0)
    return reverb(y, r, 0.4, 0.2, damp=7000)


@sfx
def type_blip(r):
    n = ns(0.04)
    sq = lp(np.sign(sine(1250, n)), 2600, 2) * 0.5
    y = sq * expdec(n, 0.007) + 0.25 * tick(r, n, 0.0012, 3000)
    return lp(y, 5000) * attack(n, 0.0008)


def step_grass(r):
    n = ns(0.32)
    y = np.zeros(n)
    for t0 in np.sort(r.uniform(0, 0.13, r.integers(5, 9))):
        d = ns(0.06)
        lo = r.uniform(900, 2000)
        b = bp(white(r, d), lo, min(lo * r.uniform(2.5, 5), 12000)) * expdec(d, r.uniform(0.006, 0.02))
        put(y, b * r.uniform(0.4, 1.0), t0)
    y = nz(y) + 0.35 * nz(lp(white(r, n), 350) * expdec(n, 0.03))
    return lp(y, 9000)


def step_wood(r):
    n = ns(0.35)
    f0 = r.uniform(95, 125)
    hit = nz(thump(n, f0 * 1.6, f0, 0.05))
    hit += 0.6 * nz(bp(white(r, n), 350, 1400) * expdec(n, 0.012))
    hit += 0.7 * nz(modal(r, n, [(r.uniform(200, 240), 0.5, 0.06), (r.uniform(430, 520), 0.35, 0.045),
                                 (r.uniform(850, 1000), 0.2, 0.03), (r.uniform(1700, 2100), 0.08, 0.02)]))
    y = hit.copy()
    put(y, 0.35 * hit, r.uniform(0.035, 0.055))  # heel -> toe
    return reverb(y, r, 0.6, 0.25, damp=5000)


def step_stone(r):
    n = ns(0.3)
    exc = np.zeros(n)
    for _ in range(25):
        exc[int(r.uniform(0, 0.07) * SR)] += r.uniform(-1, 1)
    y = 0.6 * nz(tick(r, n, 0.004))
    y += 0.5 * nz(bp(exc, 1500, 7000)) + 0.3 * nz(bp(white(r, n), 700, 3000) * expdec(n, 0.02))
    y += 0.6 * nz(thump(n, 150, 85, 0.03) + 0.5 * lp(white(r, n), 300) * expdec(n, 0.02))
    return reverb(y, r, 1.1, 0.35, damp=5000)


for _i in (1, 2, 3):
    SFX[f"step_grass_{_i}"] = step_grass
    SFX[f"step_wood_{_i}"] = step_wood
    SFX[f"step_stone_{_i}"] = step_stone

WOOD_RES = [(480, 35, 1.0), (1050, 50, 0.7), (1720, 70, 0.5), (2900, 110, 0.3), (230, 40, 0.6)]
IRON_RES = [(190, 6, 1.0), (415, 8, 0.8), (760, 10, 0.7), (1230, 14, 0.5), (1810, 18, 0.35), (2650, 25, 0.2)]


def creak(r, dur, pts, vals, res=WOOD_RES, jitter=0.0006, rough=0.15):
    n = ns(dur)
    t = tt(n)
    rate = np.interp(t, pts, vals) * (1 + rough * (smooth(r, n, 20) - 0.5) * 2)
    y = stick_slip(r, rate, res, jitter=jitter)
    return y * env_ar(n, 0.05, 0.25) * (0.6 + 0.4 * smooth(r, n, 6))


@sfx
def door_open(r):
    y = np.zeros(ns(1.8))
    latch = modal(r, ns(0.1), [(2300, 1, 0.01), (3900, 0.6, 0.007), (700, 0.5, 0.02)])
    put(y, 0.5 * nz(latch), 0.0)
    put(y, nz(creak(r, 1.65, [0, 0.3, 0.7, 1.1, 1.45, 1.65], [20, 140, 60, 260, 90, 30])), 0.1)
    return reverb(y, r, 1.3, 0.35, damp=5000)


@sfx
def gate_open(r):
    y = np.zeros(ns(3.0))
    n = ns(2.4)
    c = creak(r, 2.4, [0, 0.4, 0.9, 1.4, 1.9, 2.4], [12, 70, 35, 110, 50, 15], res=IRON_RES, rough=0.2)
    rumble = lp(brown(r, n), 180) * env_ar(n, 0.3, 0.5)
    put(y, nz(c) + 0.3 * nz(rumble), 0.0)
    m = ns(0.5)
    clank = modal(r, m, [(140, 1, 0.4), (310, 0.7, 0.35), (620, 0.5, 0.25), (1080, 0.4, 0.2), (1690, 0.3, 0.12)])
    clank = nz(clank) + 0.5 * nz(lp(white(r, m), 400) * expdec(m, 0.03))
    put(y, 0.8 * clank, 2.3)
    return reverb(y, r, 2.2, 0.45, damp=4500)


def metal_hit(r, n, lo, hi, tau=0.03):
    f = r.uniform(lo, hi)
    return modal(r, n, [(f, 1, tau), (f * r.uniform(1.8, 2.1), 0.6, tau * 0.6),
                        (f * r.uniform(2.9, 3.4), 0.4, tau * 0.4)])


@sfx
def door_locked(r):
    y = np.zeros(ns(0.9))
    for t0 in (0.0, 0.07, 0.13, 0.2, 0.42, 0.49, 0.57):
        n = ns(0.15)
        h = nz(metal_hit(r, n, 1100, 1300)) + 0.7 * nz(modal(r, n, [(r.uniform(420, 520), 1, 0.05)]))
        h += 0.5 * nz(tick(r, n, 0.002)) + 0.5 * nz(thump(n, 220, 150, 0.02))
        put(y, h * r.uniform(0.5, 1.0), t0 + r.uniform(0, 0.01))
    return reverb(y, r, 0.8, 0.25)


@sfx
def lock_open(r):
    y = np.zeros(ns(0.9))
    n = ns(0.1)
    put(y, 0.6 * nz(modal(r, n, [(3100, 1, 0.012), (4700, 0.6, 0.008), (6200, 0.3, 0.005)]) + 0.4 * tick(r, n)), 0)
    n = ns(0.4)
    clunk = nz(modal(r, n, [(150, 1, 0.08), (380, 0.8, 0.07), (820, 0.5, 0.05), (1500, 0.4, 0.04)]))
    clunk += 0.6 * nz(lp(white(r, n), 500) * expdec(n, 0.02))
    put(y, clunk, 0.11)
    n = ns(0.7)
    put(y, 0.25 * nz(modal(r, n, [(1850, 1, 0.25), (2950, 0.6, 0.18)])), 0.12)
    return reverb(y, r, 0.7, 0.2)


@sfx
def lever(r):
    y = np.zeros(ns(1.0))
    for i, t0 in enumerate((0.0, 0.035, 0.07, 0.105)):
        n = ns(0.05)
        put(y, (0.2 + 0.08 * i) * nz(metal_hit(r, n, 2600, 3400, 0.008)), t0)
    n = ns(0.6)
    clack = nz(modal(r, n, [(240, 1, 0.12), (590, 0.8, 0.1), (1010, 0.6, 0.08), (1690, 0.4, 0.05), (2750, 0.25, 0.03)]))
    clack += 0.6 * nz(lp(white(r, n), 400) * expdec(n, 0.025)) + 0.3 * nz(tick(r, n, 0.003))
    put(y, clack, 0.16)
    return reverb(y, r, 1.0, 0.3)


@sfx
def stone_grind(r):
    n = ns(2.2)
    env = env_ar(n, 0.25, 0.5)
    grind = bp(brown(r, n), 60, 600) * smooth(r, n, 30, 0.2, 1.0)
    exc = np.zeros(n)
    idx = r.integers(0, n, 330)
    exc[idx] += r.uniform(0.2, 1.0, 330)
    grit = lp(bp(exc, 700, 3000), 2500, 4)
    sub = sine(42 * (1 + 0.1 * (smooth(r, n, 3) - 0.5)), n) * smooth(r, n, 4, 0.5, 1.0)
    y = (nz(grind) + 0.2 * nz(grit) + 0.5 * sub) * env
    return reverb(y, r, 1.6, 0.3, damp=3000)


@sfx
def paper(r):
    n = ns(0.75)
    t = tt(n)
    dens = np.exp(-0.5 * ((t - 0.15) / 0.07) ** 2) + 0.8 * np.exp(-0.5 * ((t - 0.48) / 0.09) ** 2)
    exc = np.zeros(n)
    times = r.uniform(0, 0.75, 1400)
    keep = r.uniform(0, 1, 1400) < np.interp(times, t, dens) / dens.max()
    idx = (times[keep] * SR).astype(int)
    exc[idx] += r.uniform(0.1, 1.0, len(idx)) * r.choice([-1, 1], len(idx))
    crk = bp(signal.lfilter([1], [1, -0.93], exc), 1800, 11000)
    hiss = bp(white(r, n), 3000, 12000) * dens
    body = bp(white(r, n), 400, 1500) * dens
    return nz(crk) + 0.25 * nz(hiss) + 0.12 * nz(body)


@sfx
def success(r):
    y = np.zeros(ns(3.6))
    for t0, m, a in ((0, "D4", 0.7), (0.11, "F4", 0.7), (0.22, "A4", 0.75), (0.36, "D5", 0.9), (0.36, "A4", 0.4)):
        n = ns(3.2)
        put(y, a * nz(bell_tone(r, mtof(N(m)), n, CHIME, 0.4)), t0)
    n = ns(2.2)
    put(y, 0.35 * sine(mtof(N("D3")), n) * env_ar(n, 0.02, 1.8) * expdec(n, 0.9), 0.36)
    return reverb(y, r, 2.5, 0.5, damp=6000)


@sfx
def error(r):
    n = ns(0.45)
    t = tt(n)
    env = attack(n, 0.005) * (0.3 + 0.7 * np.exp(-t / 0.12)) * env_ar(n, 0.0, 0.12)
    buzz = lp(saw(68, n) + 0.8 * saw(71.5, n, 0.3), 380, 4) * env
    y = 0.7 * nz(buzz) + 0.6 * nz(thump(n, 100, 55, 0.08))
    return reverb(y, r, 0.6, 0.15)


def whisper_voice(r, scale=1.0, stretch=1.0):
    T = np.array([0, 0.08, 0.26, 0.33, 0.42, 0.58, 0.68, 0.8, 0.92, 1.03, 1.3, 1.55]) * stretch
    s_amp = [0, 0.8, 1.0, 0.2, 0, 0, 0, 0, 0, 0, 0, 0]
    v_amp = [0, 0, 0.1, 0.8, 1.0, 1.0, 0.9, 0.75, 0.85, 0.95, 0.5, 0]
    F1 = np.array([800, 800, 800, 780, 780, 760, 500, 320, 320, 700, 780, 780]) * scale
    F2 = np.array([1250, 1250, 1250, 1250, 1250, 1300, 1900, 2300, 2250, 1400, 1250, 1250]) * scale
    F3 = np.array([2600, 2600, 2600, 2600, 2600, 2650, 2900, 3050, 3000, 2700, 2600, 2600]) * scale
    k = len(T)
    forms = [(F1, np.full(k, 170 * scale), np.full(k, 1.0)),
             (F2, np.full(k, 220 * scale), np.full(k, 0.7)),
             (F3, np.full(k, 320 * scale), np.full(k, 0.4)),
             (F3 * 1.35, np.full(k, 500 * scale), np.full(k, 0.12))]
    n = ns(T[-1] + 0.05)
    return formant_noise(r, n, T, v_amp, forms, hiss=np.array(s_amp) * 0.35)


@sfx
def whisper_saia(r):
    y = np.zeros(ns(2.4))
    t0 = 0.4
    v1 = nz(whisper_voice(r, 1.0, 0.85))
    layers = [(v1, 1.0, 0.0), (whisper_voice(r, 0.86, 0.92), 0.55, 0.05),
              (whisper_voice(r, 1.15, 0.8), 0.45, 0.1), (whisper_voice(r, 0.74, 1.05), 0.4, -0.06)]
    for v, g, dt in layers:
        put(y, g * nz(v), t0 + dt)
    ir = make_ir(r, 0.45, 1, predelay=0.0, damp=7000)[0]
    swell = signal.fftconvolve(v1[::-1], ir)[::-1]  # reversed reverb leading into the word
    put(y, 0.9 * nz(swell), t0 - (len(ir) - 1) / SR)
    y = hp(y, 250)
    y = reverb(y, r, 2.2, 0.55, damp=6000, predelay=0.03)
    y = y[: ns(2.4)]
    return fade(y, 0.01, 0.4)


@sfx
def heartbeat(r):
    y = np.zeros(ns(0.9))

    def beat(n, f0, f1, tau):
        return nz(thump(n, f0, f1, tau, 0.02)) + 0.3 * nz(lp(white(r, n), 220) * expdec(n, tau * 0.6))

    put(y, beat(ns(0.35), 75, 48, 0.08), 0.01)
    put(y, 0.75 * beat(ns(0.3), 90, 58, 0.06), 0.29)
    return lp(y, 600)


@sfx
def jumpscare(r):
    n = ns(1.9)
    t = tt(n)
    bend = 2 ** (-0.6 * (t / 1.6) ** 1.5 / 12)
    strings = np.zeros(n)
    for m in (38, 50, 51, 57, 62, 63, 68, 74, 75, 81):
        trem = 1 + 0.35 * np.sin(TAU * r.uniform(11, 15) * t + r.uniform(0, TAU))
        for _ in range(4):
            strings += trem * saw(mtof(m) * 2 ** (r.uniform(-15, 15) / 1200) * bend, n, r.uniform())
    strings = lp(strings, 5000)
    env = attack(n, 0.004) * (0.35 + 0.65 * np.exp(-t / 0.12))
    noise = hp(white(r, n), 800) * expdec(n, 0.18)
    boom = thump(n, 90, 40, 0.45, 0.05)
    y = nz(strings) * env + 0.5 * nz(noise) + 0.8 * nz(boom)
    y = np.tanh(2.5 * y)
    y = reverb(y, r, 2.0, 0.3, damp=6000)[: ns(1.6)]
    return fade(y, 0.001, 0.3)


def piano_sfx(r, midis, vel=0.75, spread=0.0):
    y = np.zeros(ns(2.6))
    for m in midis:
        put(y, piano(m, 2.0, vel, damp=0.25), r.uniform(0, spread))
    return reverb(y, r, 1.2, 0.2, damp=7000)[: ns(2.6)]


for _nm in "cdefgab":
    SFX[f"piano_{_nm}"] = (lambda m: (lambda r: piano_sfx(r, [m])))(N(_nm.upper() + "4"))
SFX["piano_wrong"] = lambda r: piano_sfx(r, [59, 60, 61, 66, 67], vel=1.0, spread=0.018)


@sfx
def music_box(r):
    beat = 0.36
    mel = [("E5", 0), ("A5", 1), ("C6", 2), ("B5", 3), ("A5", 4), ("E5", 5), ("F5", 6), ("E5", 7),
           ("D5", 8), ("E5", 9), ("C5", 10.5), ("B4", 11.5), ("A4", 12.5)]
    bass = [("A3", 0), ("E4", 2), ("A3", 4), ("D4", 6), ("A3", 8), ("E4", 10.5), ("A3", 12.5)]
    y = np.zeros(ns(6.6))

    def when(b):  # the spring winds down: gaps stretch towards the end
        return beat * (b + 0.02 * b * b) + r.uniform(-0.012, 0.012)

    for nm, b in mel:
        put(y, nz(music_box_note(r, N(nm), 1.8, r.uniform(-9, 9))) * r.uniform(0.75, 1.0), when(b))
    for nm, b in bass:
        put(y, 0.45 * nz(music_box_note(r, N(nm), 1.8, r.uniform(-9, 9))), when(b) + 0.003)
    y = reverb(y, r, 1.0, 0.3, damp=7000)[: ns(6.6)]
    return fade(y, 0.002, 0.3)


@sfx
def clock_tick(r):
    n = ns(0.15)
    y = 0.7 * nz(tick(r, n, 0.0015, 3000))
    y += nz(modal(r, n, [(2300, 0.6, 0.012), (3700, 0.4, 0.009), (5200, 0.3, 0.006), (950, 0.5, 0.02)]))
    return reverb(y, r, 0.5, 0.2)


@sfx
def clock_chime(r):
    n = ns(7.0)
    y = nz(bell_tone(r, 110.0, n, BIG_BELL, 0.9))
    y += 0.3 * nz(lp(white(r, n), 300) * expdec(n, 0.03)) + 0.15 * nz(tick(r, n, 0.003, 1500))
    y = reverb(y, r, 3.0, 0.45, damp=4000)[: ns(6.5)]
    return fade(y, 0.001, 1.5)


def chain(r, dur=1.6, gestures=(0.05, 0.45, 0.9), count=36):
    y = np.zeros(ns(dur))
    for _ in range(count):
        t0 = r.choice(gestures) + abs(r.normal(0, 0.08))
        n = ns(0.15)
        f = r.uniform(1800, 5200)
        h = modal(r, n, [(f, 1, r.uniform(0.01, 0.05)), (f * r.uniform(1.4, 1.6), 0.6, r.uniform(0.01, 0.03)),
                         (f * r.uniform(2.2, 2.8), 0.3, 0.01)])
        put(y, h * r.uniform(0.2, 1.0), t0)
    for _ in range(6):
        n = ns(0.2)
        put(y, 0.8 * metal_hit(r, n, 700, 1300, r.uniform(0.05, 0.1)), r.choice(gestures) + abs(r.normal(0, 0.05)))
    n = len(y)
    t = tt(n)
    genv = sum(np.exp(-0.5 * ((t - g - 0.1) / 0.1) ** 2) for g in gestures)
    y = nz(y) + 0.08 * nz(bp(white(r, n), 1500, 6000) * genv)
    return y


@sfx
def chain_rattle(r):
    return reverb(chain(r), r, 1.2, 0.3, damp=6000)


def growl(r, dur=2.8):
    n = ns(dur)
    t = tt(n)
    f = np.interp(t, [0, 0.4, 1.2, 2.0, dur], [42, 58, 62, 50, 38]) * (1 + 0.12 * (smooth(r, n, 9) - 0.5))
    src = saw(f, n) + 0.6 * saw(f * 0.5, n, 0.3) + 0.3 * saw(f * 1.01, n, 0.6)
    src *= 1 + 1.6 * (smooth(r, n, 28) - 0.5)
    form = reson(src, 280, 90) + 0.8 * reson(src, 620, 120) + 0.4 * reson(src, 1150, 180) + 0.15 * reson(src, 2400, 300)
    breath = bp(white(r, n), 150, 1500) * smooth(r, n, 12, 0.3, 1.0)
    y = np.tanh(2.2 * (nz(form) + 0.25 * nz(breath)))
    y *= env_ar(n, 0.35, 0.9) * (0.7 + 0.3 * smooth(r, n, 3))
    return lp(y, 3500)


@sfx
def monster_growl(r):
    return reverb(growl(r), r, 2.2, 0.35, damp=3500)[: ns(3.6)]


@sfx
def wind_gust(r):
    n = ns(3.2)
    t = tt(n)
    c = np.interp(t, [0, 0.8, 1.6, 2.4, 3.2], [300, 700, 1300, 800, 400])
    body = stft_band(pink(r, n), c, 1.2)
    whistle = stft_band(white(r, n), c * 1.6, 0.06)
    env = np.sin(np.pi * np.clip(t / 3.2, 0, 1)) ** 1.5
    return (nz(body) + 0.2 * nz(whistle)) * env


@sfx
def crow_caw(r):
    y = np.zeros(ns(1.6))
    for t0 in (0.0, 0.42, 0.86):
        d = r.uniform(0.26, 0.32)
        n = ns(d)
        t = tt(n)
        f0 = np.interp(t, [0, 0.05, d], [560, 600, 470]) * (1 + 0.03 * (smooth(r, n, 40) - 0.5))
        src = saw(f0, n) + 0.6 * hp(white(r, n), 500)
        src *= 1 + 0.6 * sine(55, n)
        form = reson(src, 1100, 250) + 0.9 * reson(src, 1800, 300) + 0.5 * reson(src, 2900, 400)
        c = np.tanh(1.5 * nz(form)) * env_ar(n, 0.015, 0.15) * (1 - 0.3 * t / d)
        put(y, c * r.uniform(0.8, 1.0), t0)
    y = lp(y, 7000)
    return reverb(y, r, 1.6, 0.3, damp=5000)


@sfx
def switch_char(r):
    n = ns(0.55)
    t = tt(n)
    c = np.interp(t, [0, 0.2, 0.55], [500, 2800, 900])
    y = stft_band(white(r, n), c, 1.0, nper=1024)
    return y * np.sin(np.pi * t / 0.55) ** 2


@sfx
def key_pickup(r):
    y = np.zeros(ns(1.0))
    for i, t0 in enumerate((0.0, 0.05, 0.11, 0.19, 0.27, 0.36)):
        n = ns(0.5)
        f = r.uniform(2400, 4800)
        j = modal(r, n, [(f, 1, r.uniform(0.08, 0.25)), (f * 1.53, 0.5, 0.08), (f * 2.41, 0.3, 0.05), (f * 3.9, 0.15, 0.03)])
        put(y, (1 - 0.1 * i) * (nz(j) + 0.2 * nz(tick(r, n, 0.001, 4000))), t0)
    n = ns(0.8)
    put(y, 0.3 * nz(modal(r, n, [(1650, 1, 0.35), (2600, 0.4, 0.2)])), 0.02)
    return reverb(y, r, 0.9, 0.25, damp=9000)


@sfx
def drip(r):
    y = np.zeros(ns(0.3))
    put(y, nz(bubble(r, 1100, 0.15, 2.2, 0.035)), 0.005)
    put(y, 0.15 * nz(tick(r, ns(0.02), 0.001, 3000)), 0.0)
    return reverb(y, r, 1.4, 0.5, damp=6000, predelay=0.02)


@sfx
def monitor_beep(r):
    n = ns(0.16)
    y = (sine(1000, n) + 0.08 * sine(2000, n)) * env_ar(n, 0.004, 0.012)
    return reverb(y, r, 0.4, 0.08, damp=8000)


@sfx
def bell(r):
    n = ns(1.8)
    y = nz(bell_tone(r, 1320, n, HANDBELL, 1.5)) + 0.1 * nz(tick(r, n, 0.001, 4000))
    return reverb(y, r, 1.2, 0.3, damp=9000)


@sfx
def splash(r):
    n = ns(1.0)
    y = 0.8 * nz(bp(white(r, n), 300, 3500) * expdec(n, 0.08) * attack(n, 0.003))
    y += 0.6 * nz(lp(white(r, n), 600) * expdec(n, 0.02))
    for _ in range(10):
        put(y, r.uniform(0.15, 0.5) * nz(bubble(r, r.uniform(900, 2600), 0.1, r.uniform(1.5, 2.5), 0.02)), r.uniform(0.02, 0.4))
    for i in range(20):
        t0 = r.uniform(0.15, 0.7)
        put(y, 0.15 * (1 - t0) * nz(tick(r, ns(0.02), 0.0015, 2500)), t0)
    return reverb(y, r, 0.8, 0.25)


@sfx
def dart_thud(r):
    n = ns(0.45)
    t = tt(n)
    y = nz(thump(n, 140, 90, 0.03)) + 0.5 * nz(lp(white(r, n), 800) * expdec(n, 0.02))
    y += 0.5 * nz(bp(white(r, n), 600, 1500) * expdec(n, 0.015))
    twang = sine(190 * (1 + 0.02 * np.sin(TAU * 30 * t)), n) * expdec(n, 0.12) * attack(n, 0.004)
    y += 0.25 * twang
    return reverb(y, r, 0.6, 0.15)


@sfx
def wheel_click(r):
    y = np.zeros(ns(0.07))
    for t0, a in ((0.0, 1.0), (0.009, 0.6)):
        n = ns(0.04)
        c = nz(modal(r, n, [(3300, 1, 0.004), (5200, 0.6, 0.003), (1150, 0.5, 0.008)])) + 0.4 * nz(tick(r, n, 0.001))
        put(y, a * c, t0)
    return reverb(y, r, 0.25, 0.1)


@sfx
def glass_squeak(r):
    n = ns(0.9)
    t = tt(n)
    rate = np.interp(t, [0, 0.15, 0.45, 0.7, 0.9], [380, 720, 650, 820, 500]) * (1 + 0.08 * (smooth(r, n, 15) - 0.5))
    y = stick_slip(r, rate, [(1650, 120, 1.0), (2900, 180, 0.7), (4400, 250, 0.4), (900, 100, 0.3)],
                   jitter=0.00005, amp_var=0.3, noise=0.01, exc_lp=5000)
    y *= env_ar(n, 0.03, 0.12) * smooth(r, n, 10, 0.4, 1.0)
    return reverb(lp(y, 8000), r, 0.9, 0.3, damp=7000)


@sfx
def breath(r):
    T = [0, 0.15, 0.6, 0.9, 1.0, 1.1, 1.3, 1.8, 2.25]
    amp = [0, 0.35, 0.6, 0.2, 0, 0.3, 1.0, 0.55, 0]
    F1 = [1000, 1000, 1000, 1000, 700, 700, 700, 650, 620]
    F2 = [1800, 1800, 1850, 1800, 1250, 1250, 1250, 1200, 1150]
    F3 = [3000, 3000, 3000, 3000, 2600, 2600, 2600, 2550, 2500]
    k = len(T)
    B1 = [500, 500, 500, 500, 250, 250, 250, 250, 250]
    B2 = [700, 700, 700, 700, 350, 350, 350, 350, 350]
    forms = [(F1, B1, np.full(k, 1.0)), (F2, B2, np.full(k, 0.7)), (F3, np.full(k, 500), np.full(k, 0.35))]
    hiss = [0, 0.05, 0.08, 0.02, 0, 0.01, 0.025, 0.015, 0]
    n = ns(2.3)
    y = formant_noise(r, n, T, amp, forms, hiss=hiss)
    t = tt(n)
    y *= 1 + 0.15 * np.sin(TAU * 6 * t)  # shaky
    rasp = lp(saw(88 * (1 + 0.05 * (smooth(r, n, 10) - 0.5)), n) * white(r, n), 700)
    rasp *= np.interp(t, T, [0, 0, 0, 0, 0, 0.3, 1.0, 0.4, 0])
    return hp(nz(y) + 0.12 * nz(rasp), 120)


@sfx
def flash(r):
    n = ns(1.9)
    t = tt(n)
    env = np.where(t < 0.85, (t / 0.85) ** 2, np.exp(-(t - 0.85) / 0.35))
    c = 500 * (7000 / 500) ** np.clip(t / 1.1, 0, 1)
    sweep = stft_band(pink(r, n), c, 1.5)
    shim = np.zeros(n)
    for _ in range(40):
        f = r.uniform(2500, 10000)
        trem = 0.5 + 0.5 * np.sin(TAU * r.uniform(6, 18) * t + r.uniform(0, TAU))
        shim += np.sin(TAU * f * t + r.uniform(0, TAU)) * trem * smooth(r, n, 4)
    air = lp(pink(r, n), 200)
    y = (0.8 * nz(sweep) + 0.5 * nz(shim) + 0.25 * nz(air)) * env
    y = reverb(y, r, 3.0, 0.6, damp=11000)[: ns(2.4)]
    return fade(y, 0.005, 0.4)


# ----------------------------------------------------------------------------- terror (O Esquecido, hospital)


@sfx
def radio_static(r):
    """Rádio mal sintonizado: chiado em faixa estreita, estalos e rajadas."""
    n = ns(2.6)
    t = tt(n)
    gate = 0.35 + 0.65 * smooth(r, n, 9, 0.0, 1.0) ** 2
    hiss = bp(white(r, n), 900, 4200, 2) * gate
    crackle = np.zeros(n)
    for t0 in r.uniform(0, 2.5, 60):
        put(crackle, r.uniform(0.3, 1.0) * nz(tick(r, ns(0.01), 0.0015, 3500)), t0)
    whine = sine(1720 + 40 * np.sin(TAU * 0.7 * t), n) * 0.04
    y = nz(hiss) + 0.5 * nz(crackle) + whine
    y *= env_ar(n, 0.05, 0.35)
    return lp(y, 6500)


@sfx
def flatline(r):
    n = ns(4.2)
    y = (sine(1000, n) + 0.08 * sine(2000, n)) * env_ar(n, 0.004, 0.6)
    return reverb(y, r, 0.5, 0.1, damp=8000)


@sfx
def stalker_step(r):
    """Passo pesado e molhado, descalço."""
    n = ns(0.55)
    y = nz(thump(n, 85, 45, 0.09, 0.02))
    squelch = bp(white(r, n), 500, 2200) * expdec(n, 0.07) * (1 + 0.6 * np.sin(TAU * 38 * tt(n)))
    drip_ = np.zeros(n)
    put(drip_, nz(bubble(r, 900, 0.1, 1.8, 0.02)), 0.18)
    y = y + 0.45 * nz(squelch) + 0.2 * drip_
    return reverb(lp(y, 2500), r, 1.2, 0.3, damp=4000)


@sfx
def whisper_many(r):
    """Muitas vozes sussurrando ao mesmo tempo, sem palavra clara."""
    y = np.zeros(ns(3.4))
    for i in range(9):
        v = whisper_voice(r, r.uniform(0.7, 1.25), r.uniform(0.7, 1.3))
        put(y, r.uniform(0.3, 0.8) * nz(v), r.uniform(0.0, 1.6))
    y = hp(y, 300)
    y = reverb(y, r, 2.6, 0.6, damp=6000, predelay=0.02)[: ns(3.4)]
    return fade(y, 0.2, 0.6)


@sfx
def light_out(r):
    """Lâmpada que estoura e morre num chiado."""
    n = ns(1.1)
    pop = nz(hp(white(r, ns(0.03)), 1500)) * expdec(ns(0.03), 0.006)
    fizz = bp(white(r, n), 2500, 7000) * smooth(r, n, 30, 0.0, 1.0) ** 3 * expdec(n, 0.35)
    y = np.zeros(n)
    put(y, pop, 0.0)
    y += 0.5 * nz(fizz)
    y += 0.4 * nz(thump(n, 120, 60, 0.05))
    return reverb(y, r, 0.9, 0.25, damp=7000)


@sfx
def dread_sting(r):
    """Sopro invertido que cresce e corta num baque grave."""
    n = ns(2.6)
    t = tt(n)
    rise = np.clip(t / 2.0, 0, 1) ** 3 * (t < 2.0)
    swell = stft_band(pink(r, n), 300 * (4000 / 300) ** np.clip(t / 2.0, 0, 1), 1.0) * rise
    y = nz(swell)
    hit = np.zeros(n)
    put(hit, nz(thump(ns(0.6), 70, 32, 0.3, 0.03)) + 0.4 * nz(hp(white(r, ns(0.6)), 900) * expdec(ns(0.6), 0.08)), 2.0)
    y = 0.7 * y + hit
    return fade(reverb(np.tanh(1.8 * y), r, 1.8, 0.3, damp=5000)[:n], 0.01, 0.3)


def finish_sfx(x):
    x = hp(np.asarray(x, float), 20, 2)
    thr = np.max(np.abs(x)) * 10 ** (-66 / 20)
    last = np.nonzero(np.abs(x) > thr)[0][-1]
    x = x[: last + ns(0.01)]
    x = fade(x, 0.0015, min(0.03, len(x) / SR * 0.1))
    x = nz(x) * 10 ** (SFX_PEAK_DB / 20)
    assert np.all(np.isfinite(x))
    return x


# ============================================================================= loops

X_FADE = 2.0  # seconds of tail rendered for non-periodic layers


def owl_call(r):
    y = np.zeros(ns(2.2))
    for t0 in (0.0, 0.45, 0.62, 1.15, 1.6):
        d = 0.3 if t0 not in (0.45,) else 0.14
        n = ns(d)
        t = tt(n)
        f = 360 * (1 + 0.04 * np.sin(np.pi * t / d) - 0.03 * t / d)
        s = (sine(f, n) + 0.15 * sine(2 * f, n)) * np.sin(np.pi * t / d) ** 1.5
        s += 0.05 * bp(white(r, n), 300, 900) * np.sin(np.pi * t / d)
        put(y, s, t0)
    return lp(y, 1500)


def amb_forest(r, L):
    N_ = L + ns(X_FADE)
    gust = smooth(r, N_, 0.12, 0.25, 1.0) ** 1.5
    wind = np.zeros((2, N_))
    for ch in range(2):
        c = 250 * 2 ** (1.8 * smooth(r, N_, 0.08)) * (0.8 + 0.4 * gust)
        w = stft_band(pink(r, N_), c, 1.4) * gust
        wh = stft_band(white(r, N_), c * 2.1, 0.1) * gust**2
        wind[ch] = nz(w) + 0.12 * nz(wh)
    leaves = lp(hp(white(r, N_, 2), 2500), 9000) * (smooth(r, N_, 0.6) * gust) ** 2
    crickets = np.zeros((2, N_))
    for _ in range(4):
        fc = r.uniform(4000, 5600)
        syl = 1 / r.uniform(25, 40)
        nsyl = int(r.integers(2, 5))
        period = r.uniform(0.55, 1.2)
        m = ns(syl * nsyl)
        tm = tt(m)
        gate = np.clip(np.sin(np.pi * (tm % syl) / (syl * 0.7)), 0, None) ** 2 * ((tm % syl) < syl * 0.7)
        chirp = (sine(fc, m) + 0.2 * sine(2 * fc, m)) * gate
        mono = np.zeros(N_)
        tp = r.uniform(0, period)
        while tp < N_ / SR:
            put(mono, chirp * r.uniform(0.7, 1.0), tp)
            tp += period * r.uniform(0.9, 1.1)
        crickets += pan(mono * smooth(r, N_, 0.05, 0.15, 1.0) * r.uniform(0.4, 1.0), r.uniform(-0.8, 0.8))
    chorus = np.stack([stft_band(white(r, N_), 4700, 0.07) for _ in range(2)])
    chorus *= (0.5 + 0.5 * np.sin(TAU * 31 * tt(N_))) ** 4 * smooth(r, N_, 0.1, 0.4, 1.0)
    bed = wind + 0.05 * nz(leaves) + 0.35 * nz(crickets) + 0.08 * nz(chorus)
    bed = loopify(bed, L, ns(X_FADE))

    owls = np.zeros((2, L))
    for t0 in (17.3, 43.1):
        put_wrap(owls, pan(nz(owl_call(r)), r.uniform(-0.6, 0.6)), t0)
    for t0 in r.uniform(0, L / SR, 3):  # twig snaps
        n = ns(0.1)
        put_wrap(owls, pan(0.15 * nz(modal(r, n, [(r.uniform(1500, 2500), 1, 0.01), (r.uniform(3000, 4500), 0.5, 0.006)])),
                           r.uniform(-0.9, 0.9)), t0)
    owls = creverb(owls, r, 2.5, 1.0, damp=4000)
    mix = bed + 0.35 * nz(owls)
    return creverb(mix, r, 1.8, 0.2, damp=5000)


def distant_creaks(r, L, count, dist_lp=2500, gain=(0.15, 0.4)):
    ev = np.zeros((2, L))
    slots = np.sort(r.uniform(0, L / SR, count))
    for t0 in slots:
        d = r.uniform(0.4, 1.2)
        k = 5
        pts = np.linspace(0, d, k)
        vals = r.uniform(15, 90, k)
        c = lp(creak(r, d, pts, vals, res=[(f * r.uniform(0.8, 1.2), bw, g) for f, bw, g in WOOD_RES]), dist_lp)
        put_wrap(ev, pan(nz(c) * r.uniform(*gain), r.uniform(-0.9, 0.9)), t0)
    return ev


def drone(r, L, freqs, amps, lfo_cycles=(1, 5)):
    t = tt(L)
    y = np.zeros((2, L))
    for f, a in zip(freqs, amps):
        ff = qf(f, L)
        k = int(r.integers(*lfo_cycles))
        am = 0.7 + 0.3 * np.sin(TAU * k / (L / SR) * t + r.uniform(0, TAU))
        y += pan(a * np.sin(TAU * ff * t + r.uniform(0, TAU)) * am, r.uniform(-0.4, 0.4))
    return y


def amb_house(r, L):
    t = tt(L)
    dr = drone(r, L, [55, 55.4, 82.4, 110.2, 164.9], [1.0, 0.8, 0.5, 0.3, 0.12])
    room = fft_shape(brown(r, L, 2), g_lp(250)) * smooth(r, L, 0.1, 0.6, 1.0, periodic=True)
    outside = fft_shape(pink(r, L, 2), g_bp(200, 600)) * smooth(r, L, 0.08, 0.1, 1.0, periodic=True) ** 2
    ev = distant_creaks(r, L, 7)
    for t0 in r.uniform(0, L / SR, 2):
        n = ns(0.6)
        th = nz(thump(n, 140, 80, 0.12)) + 0.5 * nz(lp(white(r, n), 200) * expdec(n, 0.05))
        put_wrap(ev, pan(0.35 * th, r.uniform(-0.7, 0.7)), t0)
    ev = creverb(ev, r, 2.5, 0.8, damp=3500)
    mix = 0.45 * nz(dr) + 0.15 * nz(room) + 0.08 * nz(outside) + 0.6 * nz(ev)
    del t
    return creverb(mix, r, 1.5, 0.15, damp=5000)


def amb_attic(r, L):
    X = ns(X_FADE)
    N_ = L + X
    gust = smooth(r, N_, 0.15, 0.2, 1.0) ** 1.5
    wind = np.zeros((2, N_))
    for ch in range(2):
        c = 400 * 2 ** (1.4 * smooth(r, N_, 0.1)) * (0.85 + 0.3 * gust)
        body = stft_band(pink(r, N_), c, 1.2) * gust
        wh = sum(stft_band(white(r, N_), f0 * (1 + 0.05 * (smooth(r, N_, 0.2) - 0.5)), 0.035) for f0 in (620, 910))
        wind[ch] = nz(body) + 0.3 * nz(wh * gust**2)
    wind = loopify(wind, L, X)
    ev = distant_creaks(r, L, 10, dist_lp=5000, gain=(0.2, 0.6))
    for t0 in r.uniform(0, L / SR, 4):  # loose shingle rattles
        for k in range(int(r.integers(3, 7))):
            n = ns(0.05)
            put_wrap(ev, pan(0.08 * nz(metal_hit(r, n, 900, 1800, 0.01)), r.uniform(-0.6, 0.6)), t0 + k * r.uniform(0.04, 0.08))
    ev = creverb(ev, r, 1.4, 0.4, damp=5000)
    mix = 0.8 * wind + 0.6 * nz(ev)
    return creverb(mix, r, 1.4, 0.2, damp=5000)


def amb_dungeon(r, L):
    t = tt(L)
    dr = drone(r, L, [36.7, 36.95, 55.0, 73.4, 110.0], [1.0, 0.8, 0.5, 0.35, 0.12])
    sw = np.zeros((2, L))
    for ch in range(2):
        sw[ch] = saw(qf(73.4, L) * (1 + 0.0), L, r.uniform())
    sw = fft_shape(sw, g_lp(260, 3)) * (0.6 + 0.4 * np.sin(TAU * 2 / (L / SR) * t))
    air = fft_shape(brown(r, L, 2), g_lp(400)) * smooth(r, L, 0.1, 0.5, 1.0, periodic=True)
    drips = np.zeros((2, L))
    for t0 in r.uniform(0, L / SR, 16):
        b = nz(bubble(r, r.uniform(700, 1900), 0.15, r.uniform(1.6, 2.4), 0.03))
        put_wrap(drips, pan(b * r.uniform(0.2, 0.6), r.uniform(-0.9, 0.9)), t0)
    for t0 in r.uniform(0, L / SR, 3):
        c = lp(chain(r, 1.2, (0.05, 0.5), 18), 3000)
        put_wrap(drips, pan(0.12 * nz(c), r.uniform(-0.8, 0.8)), t0)
    put_wrap(drips, pan(0.1 * nz(lp(growl(r, 2.8), 800)), -0.3), 33.0)
    drips = creverb(drips, r, 3.5, 1.2, damp=5000)
    mix = 0.45 * nz(dr) + 0.08 * nz(sw) + 0.15 * nz(air) + 0.6 * nz(drips)
    return creverb(mix, r, 2.5, 0.2, damp=4000)


def amb_white(r, L):
    per = L / SR
    chords = [[50, 57, 64, 66, 69], [43, 50, 59, 66, 69], [47, 54, 57, 62, 64], [45, 52, 61, 64, 71]]
    slot = per / len(chords)
    pad = np.zeros((2, L))
    for i, ch in enumerate(chords):
        n = ns(slot + 7.0)
        put_wrap(pad, pad_voice(r, ch, n, 5.0, 6.5, bright=0.22), i * slot - 3.0)
    airy = fft_shape(pink(r, L, 2), g_bp(3000, 12000)) * smooth(r, L, 0.1, 0.3, 1.0, periodic=True)
    spark = np.zeros((2, L))
    for t0 in r.uniform(0, per, 10):
        m = r.choice([N("D6"), N("F#6"), N("A6"), N("E6"), N("B6")])
        n = ns(2.5)
        put_wrap(spark, pan(nz(bell_tone(r, mtof(m), n, CHIME, 0.3)) * r.uniform(0.5, 1.0), r.uniform(-0.8, 0.8)), t0)
    mix = nz(pad) + 0.04 * nz(airy) + 0.07 * nz(spark)
    return creverb(mix, r, 5.0, 0.6, damp=8000)


def amb_hospital(r, L):
    """Zumbido de lâmpada fria, respirador ao longe e um monitor que apita."""
    t = tt(L)
    per = L / SR
    hum = drone(r, L, [120.0, 240.0, 360.0, 60.0], [1.0, 0.45, 0.2, 0.6], lfo_cycles=(2, 7))
    buzz = fft_shape(white(r, L, 2), g_bp(3000, 5000)) * 0.15
    vent = np.zeros((2, L))
    cycle = 5.0
    k = int(per / cycle)
    for i in range(k):
        n = ns(cycle)
        tn = tt(n)
        breath_env = np.sin(np.pi * np.clip(tn / 2.2, 0, 1)) ** 2 + 0.6 * np.sin(np.pi * np.clip((tn - 2.6) / 2.0, 0, 1)) ** 2
        b = lp(pink(r, n), 900) * breath_env
        put_wrap(vent, pan(0.5 * nz(b), 0.5), i * cycle)
    beeps = np.zeros((2, L))
    beat = 1.1
    for i in range(int(per / beat)):
        nb_ = ns(0.16)
        y = (sine(1000, nb_) + 0.08 * sine(2000, nb_)) * env_ar(nb_, 0.004, 0.012)
        put_wrap(beeps, pan(0.25 * y, -0.6), i * beat)
    beeps = creverb(beeps, r, 1.6, 0.8, damp=5000)
    del t
    mix = 0.35 * nz(hum) + 0.05 * nz(buzz) + 0.35 * nz(vent) + 0.35 * nz(beeps)
    return creverb(mix, r, 1.2, 0.15, damp=6000)


def add_piano(buf, midi, t0, hold, vel, r, jitter=0.008, pan_w=1.0):
    y = piano(midi, hold, vel)
    put_wrap(buf, pan(y * r.uniform(0.9, 1.05), pan_w * (midi - 62) / 36), t0 + r.uniform(-jitter, jitter))


def music_menu(r, L):
    beat = 1.0  # 60 BPM
    buf = np.zeros((2, L))
    pad = np.zeros((2, L))
    prog = [
        ([57, 60, 64], 33, [(0, "A4"), (1.5, "C5"), (3, "E5"), (4, "D5"), (5.5, "C5"), (6, "B4")]),
        ([53, 57, 60], 29, [(0, "A4"), (1.5, "C5"), (3, "F5"), (4, "E5"), (5.5, "C5"), (6, "A4")]),
        ([50, 53, 57], 38, [(0, "F4"), (1.5, "A4"), (3, "D5"), (4, "C5"), (5.5, "A4"), (6, "F4")]),
        ([52, 56, 59], 28, [(0, "G#4"), (1.5, "B4"), (3, "E5"), (4, "D5"), (5.5, "B4"), (6, "E4")]),
    ]
    for cyc in range(2):
        for i, (chord, bass, mel) in enumerate(prog):
            b0 = (cyc * 4 + i) * 8 * beat
            n = ns(8 * beat + 4.0)
            sv = string_voice(r, chord + [chord[0] - 12], n, 750, detune=7, voices=3)
            put_wrap(pad, sv * env_ar(n, 2.5, 3.5), b0 - 0.5)
            add_piano(buf, bass, b0, 6.0, 0.4, r)
            add_piano(buf, bass + 12, b0 + 0.01, 6.0, 0.3, r)
            for j, (bb, nm) in enumerate(mel):
                if cyc == 0 and j in (1, 4):
                    continue  # first pass is sparser
                v = 0.5 if bb in (0, 3) else 0.4
                add_piano(buf, N(nm), b0 + bb * beat, 2.4, v, r)
                if cyc == 1 and bb in (3, 4):
                    add_piano(buf, N(nm) + 12, b0 + (bb + 0.5) * beat, 1.5, 0.2, r)
    mix = nz(buf) + 0.35 * nz(pad)
    return creverb(mix, r, 3.5, 0.45, damp=6000)


def music_tension(r, L):
    beat = 60 / 128
    bar = 4 * beat
    e8 = beat / 2
    per = L / SR
    low = np.zeros((2, L))
    high = np.zeros((2, L))
    perc = np.zeros((2, L))
    prog = [(38, [74, 77, 81, 82]), (34, [70, 74, 77, 78]), (31, [67, 70, 74, 75]), (33, [69, 73, 76, 77])]
    pattern = [0, 0, 12, 0, 0, 12, 0, 12]
    nbars = int(round(per / bar))
    for b in range(nbars):
        cyc = b // 8
        root, upper = prog[(b // 2) % 4]
        for k, iv in enumerate(pattern):
            acc = k in (0, 3, 6)
            n = ns(e8 * 0.95 + 0.08)
            tn = tt(n)
            env = attack(n, 0.008) * (0.3 + 0.7 * np.exp(-tn / 0.1)) * env_ar(n, 0.0, 0.06)
            sv = string_voice(r, [root + iv], n, 1300 if acc else 750, detune=10, voices=3)
            put_wrap(low, sv * env * (1.0 if acc else 0.6), b * bar + k * e8)
        if b % 2 == 0 and cyc >= 1:
            n = ns(2 * bar + 1.0)
            tn = tt(n)
            trem = 0.55 + 0.45 * np.sin(TAU * 7.5 * tn)
            sv = string_voice(r, upper, n, 3500, detune=8, voices=3) * trem * env_ar(n, 0.8, 1.0)
            put_wrap(high, sv * (0.6 if cyc == 1 else 1.0), b * bar)
        n = ns(0.4)
        hb = nz(thump(n, 80, 45, 0.1)) + 0.3 * nz(lp(white(r, n), 200) * expdec(n, 0.05))
        put_wrap(perc, pan(hb, 0), b * bar)
        put_wrap(perc, pan(0.7 * hb, 0), b * bar + 0.35 * beat)
        for q in range(4):
            m = ns(0.08)
            tk = nz(modal(r, m, [(2300, 0.6, 0.01), (3700, 0.4, 0.007), (950, 0.5, 0.015)]))
            put_wrap(perc, pan(0.12 * tk, 0.5 if q % 2 else -0.5), b * bar + q * beat + beat / 2)
        if b % 8 == 7:  # swell into the next phrase
            n = ns(bar)
            tn = tt(n)
            sw = bp(white(r, n, 2), 800, 6000) * (tn / bar) ** 3
            put_wrap(perc, 0.12 * nz(sw), b * bar)
    low = hp(low, 40)
    mix = nz(low) + 0.45 * nz(high) + 0.55 * nz(perc)
    return creverb(mix, r, 2.0, 0.3, damp=6000)


def music_ending(r, L):
    beat = 1.0
    bar = 4 * beat
    buf = np.zeros((2, L))
    pad = np.zeros((2, L))
    arps = [
        [48, 55, 60, 64, 67, 64, 60, 55],
        [47, 55, 59, 62, 67, 62, 59, 55],
        [45, 52, 57, 60, 64, 60, 57, 52],
        [43, 52, 55, 59, 64, 59, 55, 52],
        [41, 48, 53, 57, 60, 57, 53, 48],
        [40, 48, 52, 55, 60, 55, 52, 48],
        [38, 45, 50, 53, 57, 60, 57, 53],
        [43, 50, 55, 60, 62, 60, 59, 55],
    ]
    mel = [
        [(0, "E5", 1.5), (1.5, "D5", 0.5), (2, "C5", 1), (3, "D5", 1)],
        [(0, "D5", 2), (2, "G4", 2)],
        [(0, "C5", 1.5), (1.5, "B4", 0.5), (2, "C5", 1), (3, "E5", 1)],
        [(0, "B4", 3), (3, "G4", 1)],
        [(0, "A4", 1), (1, "C5", 1), (2, "F5", 2)],
        [(0, "E5", 1.5), (1.5, "D5", 0.5), (2, "C5", 2)],
        [(0, "D5", 1), (1, "F5", 1), (2, "E5", 1), (3, "D5", 1)],
        [(0, "D5", 2), (2, "B4", 1), (3, "D5", 1)],
    ]
    for cyc in range(2):
        for i in range(8):
            b0 = (cyc * 8 + i) * bar
            arp = arps[i]
            add_piano(buf, arp[0] - 12, b0, 3.5, 0.3, r, pan_w=0.6)
            for k, m in enumerate(arp):
                add_piano(buf, m, b0 + k * beat / 2, 1.6, 0.3, r, pan_w=0.6)
            for bb, nm, d in mel[i]:
                add_piano(buf, N(nm), b0 + bb * beat, d + 0.4, 0.5 if cyc == 0 else 0.6, r, pan_w=0.4)
                if cyc == 1:
                    add_piano(buf, N(nm) + 12, b0 + bb * beat + 0.012, d + 0.3, 0.2, r, pan_w=0.4)
            n = ns(bar + 3.0)
            chord = sorted(set(arp[1:5]))
            put_wrap(pad, pad_voice(r, chord, n, 1.5, 2.5, bright=0.15), b0 - 0.3)
    mix = nz(buf) + 0.22 * nz(pad)
    return creverb(mix, r, 3.0, 0.4, damp=7000)


LOOPS = {
    "amb_forest": (60.0, amb_forest, AMB_PEAK_DB),
    "amb_house": (60.0, amb_house, AMB_PEAK_DB),
    "amb_attic": (45.0, amb_attic, AMB_PEAK_DB),
    "amb_dungeon": (60.0, amb_dungeon, AMB_PEAK_DB),
    "amb_white": (60.0, amb_white, AMB_PEAK_DB),
    "amb_hospital": (55.0, amb_hospital, AMB_PEAK_DB),
    "music_menu": (64.0, music_menu, MUSIC_PEAK_DB),
    "music_tension": (45.0, music_tension, MUSIC_PEAK_DB),
    "music_ending": (64.0, music_ending, MUSIC_PEAK_DB),
}


def finish_loop(x, peak_db):
    x = fft_shape(np.asarray(x, float), g_hp(25, 2))  # circular: keeps the loop seamless
    assert np.all(np.isfinite(x))
    return nz(x) * 10 ** (peak_db / 20)


# ============================================================================= output

def write_wav(path: Path, x: np.ndarray, sr: int) -> None:
    x = np.asarray(x, float)
    assert np.all(np.isfinite(x)), path
    data = x[:, None] if x.ndim == 1 else x.T
    pcm = np.clip(np.round(data * 32767), -32768, 32767).astype("<i2")
    with wave.open(str(path), "wb") as w:
        w.setnchannels(data.shape[1])
        w.setsampwidth(2)
        w.setframerate(sr)
        w.writeframes(pcm.tobytes())


def pick_encoder() -> str | None:
    ff = shutil.which("ffmpeg")
    if ff:
        out = subprocess.run([ff, "-hide_banner", "-encoders"], capture_output=True, text=True).stdout
        if "libvorbis" in out:
            return "ffmpeg"
    if shutil.which("oggenc"):
        return "oggenc"
    return None


def encode_loop(name: str, x: np.ndarray, encoder: str | None) -> Path:
    MUS_DIR.mkdir(parents=True, exist_ok=True)
    if encoder is None:
        y = signal.resample_poly(x, 1, 2, axis=-1)
        y = nz(y) * np.max(np.abs(x))
        out = MUS_DIR / f"{name}.wav"
        write_wav(out, y, SR // 2)
        (MUS_DIR / f"{name}.ogg").unlink(missing_ok=True)
        return out
    TMP.mkdir(parents=True, exist_ok=True)
    tmp = TMP / f"{name}.wav"
    write_wav(tmp, x, SR)
    out = MUS_DIR / f"{name}.ogg"
    if encoder == "ffmpeg":
        cmd = ["ffmpeg", "-y", "-loglevel", "error", "-i", str(tmp), "-map_metadata", "-1",
               "-c:a", "libvorbis", "-q:a", "4", "-fflags", "+bitexact", "-flags:a", "+bitexact", str(out)]
    else:
        cmd = ["oggenc", "-Q", "-q", "4", "-s", "1", "-o", str(out), str(tmp)]
    subprocess.run(cmd, check=True)
    tmp.unlink(missing_ok=True)
    (MUS_DIR / f"{name}.wav").unlink(missing_ok=True)
    return out


def gen_sfx(name: str) -> None:
    SFX_DIR.mkdir(parents=True, exist_ok=True)
    x = finish_sfx(SFX[name](rng_for(name)))
    write_wav(SFX_DIR / f"{name}.wav", x, SR)


def gen_loop(name: str, encoder: str | None) -> None:
    sec, fn, peak = LOOPS[name]
    L = ns(sec)
    x = fn(rng_for(name), L)
    assert x.shape == (2, L), (name, x.shape)
    encode_loop(name, finish_loop(x, peak), encoder)


# ============================================================================= verification

def read_audio(path: Path):
    if path.suffix == ".wav":
        with wave.open(str(path), "rb") as w:
            sr, ch, sw = w.getframerate(), w.getnchannels(), w.getsampwidth()
            raw = w.readframes(w.getnframes())
        assert sw == 2, f"{path.name}: sample width {sw}"
        x = np.frombuffer(raw, "<i2").astype(float).reshape(-1, ch).T / 32768.0
        return x, sr, ch, "wav16"
    probe = subprocess.run(["ffprobe", "-v", "error", "-select_streams", "a:0", "-show_entries",
                            "stream=sample_rate,channels,codec_name", "-of", "csv=p=0", str(path)],
                           capture_output=True, text=True, check=True).stdout.strip().split(",")
    codec, sr, ch = probe[0], int(probe[1]), int(probe[2])
    raw = subprocess.run(["ffmpeg", "-v", "error", "-i", str(path), "-f", "f32le", "-acodec", "pcm_f32le", "-"],
                         capture_output=True, check=True).stdout
    x = np.frombuffer(raw, "<f4").astype(float).reshape(-1, ch).T
    return x, sr, ch, codec


def seam_stats(x, sr):
    """Loop-point check.

    hf: high-frequency (2nd-difference) energy of a 5 ms window centred on the loop point,
        relative to the 99.5th percentile of all 5 ms windows in the file. A click at the
        seam would stand out (>1); a musical onset landing on the downbeat stays below.
    ddb: RMS difference between the last and first 50 ms (informative for music, which
        restarts on a downbeat; must be small for ambience beds).
    """
    d2 = np.roll(x, -1, axis=-1) - 2 * x + np.roll(x, 1, axis=-1)
    e = np.sum(d2**2, axis=0)
    w = int(0.005 * sr)
    k = len(e) // w
    wins = e[: k * w].reshape(k, w).sum(1)
    hf = (e[-(w // 2):].sum() + e[: w - w // 2].sum()) / (np.percentile(wins, 99.5) + 1e-12)
    w = int(0.05 * sr)
    rms = lambda s: np.sqrt(np.mean(s**2)) + 1e-12  # noqa: E731
    ddb = abs(20 * np.log10(rms(x[:, -w:]) / rms(x[:, :w])))
    return hf, ddb


def verify(names) -> bool:
    ok = True
    rows = []
    for name in names:
        is_loop = name in LOOPS
        cands = [MUS_DIR / f"{name}.ogg", MUS_DIR / f"{name}.wav"] if is_loop else [SFX_DIR / f"{name}.wav"]
        path = next((p for p in cands if p.exists()), None)
        if path is None:
            rows.append((name, "MISSING", "", "", "", "", "", "FAIL"))
            ok = False
            continue
        x, sr, ch, fmt = read_audio(path)
        dur = x.shape[-1] / sr
        peak = np.max(np.abs(x))
        rms_db = 20 * np.log10(np.sqrt(np.mean(x**2)) + 1e-12)
        errs = []
        if not np.all(np.isfinite(x)):
            errs.append("nan")
        if peak >= 0.999:
            errs.append("clip")
        seam = ""
        if is_loop:
            want = LOOPS[name][0]
            if abs(dur - want) > 0.01:
                errs.append(f"dur!={want}")
            hf, ddb = seam_stats(x, sr)
            seam = f"{hf:.2f}/{ddb:.1f}dB"
            if hf > 1.0 or (name.startswith("amb_") and ddb > 3):
                errs.append("seam")
            if ch != 2:
                errs.append("mono")
        else:
            if (sr, ch, fmt) != (SR, 1, "wav16"):
                errs.append("format")
            if abs(20 * np.log10(peak) - SFX_PEAK_DB) > 0.3:
                errs.append("level")
        ok &= not errs
        rows.append((name, path.name, fmt, str(sr), str(ch), f"{dur:6.2f}", f"{20*np.log10(peak):5.1f}/{rms_db:5.1f}",
                     seam + ("  " if seam else "") + ("OK" if not errs else "FAIL " + ",".join(errs))))
    head = ("name", "file", "fmt", "sr", "ch", "dur s", "peak/rms dB", "seam(hf/rmsΔ) status")
    widths = [max(len(str(r[i])) for r in rows + [head]) for i in range(len(head))]
    for r_ in [head] + rows:
        print("  ".join(str(c).ljust(w) for c, w in zip(r_, widths)))
    return ok


# ============================================================================= main

def main() -> int:
    ap = argparse.ArgumentParser(description=__doc__, formatter_class=argparse.RawDescriptionHelpFormatter)
    ap.add_argument("names", nargs="*", help="subset of sounds to (re)generate")
    ap.add_argument("--list", action="store_true")
    ap.add_argument("--verify-only", action="store_true")
    ap.add_argument("--no-verify", action="store_true")
    a = ap.parse_args()
    all_names = list(SFX) + list(LOOPS)
    if a.list:
        print("\n".join(all_names))
        return 0
    names = a.names or all_names
    bad = [n for n in names if n not in SFX and n not in LOOPS]
    if bad:
        print("unknown:", ", ".join(bad), file=sys.stderr)
        return 2
    if not a.verify_only:
        enc = pick_encoder()
        print(f"loop encoder: {enc or 'none (16-bit WAV 22050 Hz)'}")
        for name in names:
            print(f"  {name}", flush=True)
            if name in SFX:
                gen_sfx(name)
            else:
                gen_loop(name, enc)
    if a.no_verify:
        return 0
    return 0 if verify(names) else 1


if __name__ == "__main__":
    sys.exit(main())
