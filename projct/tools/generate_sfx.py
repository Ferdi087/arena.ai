#!/usr/bin/env python3
"""Prozeduraler SFX-Generator für Möbel-Rambo (kein externes Asset nötig).

Erzeugt bewusst kurze, synthetische Sounds (Rauschbursten + Resonatoren +
abgestimmte Sinus-Ketten), die als Platzhalter-NICHT gemeint sind: sie sind
die spielbare Default-Bank; echte Samples können später 1:1 unter demselben
Namen in audio/sfx/ abgelegt werden (audio_manager sucht zuerst .wav dann .ogg).

Aufruf:  python3 tools/generate_sfx.py [out_dir]   (Default: projct/audio/sfx)
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.abspath(os.environ.get("SFX_OUT", os.path.join(os.path.dirname(__file__), "..", "audio", "sfx")))

random.seed(20260921)


def write_wav(name: str, samples):
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        frames = b"".join(struct.pack("<h", int(max(-1.0, min(1.0, s)) * 32767)) for s in samples)
        w.writeframes(frames)


def noise_env(n, decay=8.0, hp=0.0):
    """Gegrauster White-Noise mit Lowpass via Differentiator (hp>0 = weniger Bass)."""
    out = []
    prev = 0.0
    for i in range(n):
        x = random.uniform(-1.0, 1.0)
        y = x - hp * prev
        prev = x
        out.append(y * math.exp(-decay * i / n))
    return out


def resonator(noise, freq, q=8.0, mix=1.0):
    """2-Pol-Resonanzfilter (Bandpass) – Körper aus Rauschen formen."""
    w = 2.0 * math.pi * freq / SR
    alpha = math.sin(w) / (2.0 * q)
    b0, b1, b2 = alpha, 0.0, -alpha
    a0 = 1.0 + alpha
    a1, a2 = -2.0 * math.cos(w) / a0, (1.0 - alpha) / a0
    x1 = x2 = y1 = y2 = 0.0
    out = []
    for x in noise:
        y = (b0 * x + b1 * x1 + b2 * x2 - a1 * y1 - a2 * y2) / a0
        x2, x1 = x1, x
        y2, y1 = y1, y
        out.append(y * mix)
    return out


def tone(dur, freq_fn, decay=6.0, vol=0.6, hum=0.0):
    n = int(dur * SR)
    out = []
    for i in range(n):
        t = i / SR
        f = freq_fn(t)
        s = math.sin(2.0 * math.pi * f * t) * (1.0 - hum) + hum * math.sin(2.0 * math.pi * f * 2.01 * t + 1.3)
        out.append(s * math.exp(-decay * t) * vol)
    return out


def mix(*layers, norm=0.85):
    n = max(len(l) for l in layers)
    out = [0.0] * n
    peak = 1e-6
    for l in layers:
        for i, v in enumerate(l):
            out[i] += v
        peak = max(peak, max((abs(v) for v in l), default=0.0))
    scale = norm / peak
    return [v * scale for v in out]


def thump(dur=0.18, f0=140.0, f1=40.0, decay=16.0):
    return tone(dur, lambda t: f0 + (f1 - f0) * min(1.0, t / dur), decay=decay, vol=0.9)


def click(freq=2600.0, dur=0.05):
    n = int(dur * SR)
    out = []
    for i in range(n):
        out.append(math.sin(2 * math.pi * freq * i / SR) * math.exp(-70.0 * i / n))
    return out


# ------------------------------------------------------------- Material-Set --


def material_impact(base_freq, body="thump", crackle=0.0, ring=0.0, dur=0.3):
    layers = []
    layers.append(thump(dur * 0.6, base_freq * 1.4, base_freq * 0.35, decay=18.0))
    n = noise_env(int(dur * SR), decay=14.0, hp=0.6)
    layers.append(resonator(n, base_freq * 3.0, q=6.0, mix=1.0 + crackle))
    if ring > 0.0:
        layers.append(tone(dur * 2.2, lambda t: base_freq * ring, decay=4.0, vol=0.5))
    return mix(*layers)


SETS = {
    # set: (base_freq, crackle, ring_mult, dur)
    "wood": (240.0, 1.2, 2.2, 0.28),
    "metal": (420.0, 0.5, 4.1, 0.5),
    "glass": (900.0, 2.0, 5.3, 0.55),
    "plastic": (520.0, 1.0, 1.6, 0.2),
    "soft": (110.0, 0.2, 0.0, 0.22),
    "ceramic": (700.0, 1.6, 3.4, 0.4),
    "stone": (160.0, 0.9, 0.0, 0.3),
    "cardboard": (300.0, 1.6, 0.0, 0.15),
    "electronic": (600.0, 0.8, 2.0, 0.3),
}
VARIANTS = {"soft": (0.55, 0.8), "mid": (1.0, 1.0), "heavy": (1.7, 1.35)}


def gen_materials():
    for name, (f, cr, ring, dur) in SETS.items():
        for vname, (vol, length) in VARIANTS.items():
            random.seed(hash((name, vname)) & 0xFFFF)
            layers = [thump(dur * 0.6 * length, f * 1.35, f * 0.3, decay=16.0 / length)]
            n = noise_env(int(dur * SR * length), decay=12.0 / length, hp=0.6)
            layers.append(resonator(n, f * (3.0 + cr), q=5.0 + cr * 2.0, mix=1.0 + cr))
            if ring > 0.0:
                layers.append(tone(dur * 2.0 * length, lambda t: f * ring, decay=3.5 / length, vol=0.6))
            snd = mix(*layers, norm=0.85 * vol)
            write_wav(f"{name}_{vname}", snd)


def gen_events():
    # Einzel-Keys aus dem Spiel (play_world/one_shot) – Namen MÜSSEN matchen.
    # Holzsplittern-Knistern fürs Möbel-Brechen
    random.seed(11)
    n = noise_env(int(0.5 * SR), decay=5.0, hp=0.2)
    write_wav("wood_crack", mix(
        resonator(n, 700.0, 3.0, 1.6),
        thump(0.35, 200.0, 55.0, decay=10.0),
        tone(0.3, lambda t: 90.0 - 40.0 * t, decay=9.0, vol=0.8),
    ))
    # Hammer auf Holz im Baumodus
    random.seed(12)
    write_wav("build_hammer", mix(
        thump(0.12, 320.0, 90.0, decay=26.0),
        resonator(noise_env(int(0.16 * SR), 26.0, 0.5), 1100.0, 4.0, 1.2),
        click(2100.0, 0.03),
    ))
    # Cargo-Verriegelung: Doppelklicken + Auskling-Sumsen
    random.seed(13)
    l1 = click(1500.0, 0.04)
    l2 = click(1100.0, 0.05)
    body = tone(0.18, lambda t: 180.0, decay=10.0, vol=0.7)
    d = int(0.06 * SR)
    write_wav("cargo_lock", mix(l1, [0.0] * d + l2, [0.0] * 300 + body))
    # Spukhaus: Luftzug + Dissonanz-Schwebung
    random.seed(14)
    whoosh = noise_env(int(1.3 * SR), decay=2.2, hp=0.15)
    disson = tone(1.3, lambda t: 133.0 + 9.0 * math.sin(2 * math.pi * 0.7 * t), decay=1.6, vol=0.55, hum=0.6)
    write_wav("ghost_whoosh", mix(
        resonator(whoosh, 260.0, 1.6, 1.0),
        [v * 0.6 for v in noise_env(int(1.3 * SR), 2.6, 0.3)],
        disson,
    ))
    # Donner: tiefes Rumpeln mit zwei Peaks
    random.seed(15)
    dur = 2.2
    n = noise_env(int(dur * SR), decay=1.5, hp=0.05)
    rumble = resonator(n, 60.0, 1.2, 1.0)
    crack = resonator(noise_env(int(0.12 * SR), 40.0, 0.7), 1600.0, 2.0, 1.4)
    thunder = [v * math.exp(-1.1 * i / len(rumble)) * (1.0 + 0.6 * math.exp(-12.0 * abs(i / SR - 0.05))) for i, v in enumerate(rumble)]
    write_wav("thunder", mix(thunder, crack + [0.0] * (len(thunder) - len(crack))))
    # UI
    write_wav("ui_click", click(1900.0, 0.05) + [0.0] * 400)
    up = tone(0.16, lambda t: 660.0 + 220.0 * min(1.0, t / 0.06), decay=14.0, vol=0.5)
    write_wav("ui_confirm", mix(up, click(2400.0, 0.03)))
    # Hupen: drei Charaktere
    write_wav("horn_truck", mix(
        tone(0.7, lambda t: 138.0, decay=2.4, vol=0.8, hum=0.5),
        tone(0.7, lambda t: 207.0, decay=2.4, vol=0.5),
    ))
    write_wav("horn_air", tone(0.55, lambda t: 415.0 + 12.0 * math.sin(9.0 * t), decay=3.0, vol=0.8, hum=0.7))
    organ = mix(
        tone(0.9, lambda t: 294.0, decay=2.0, vol=0.6),
        tone(0.9, lambda t: 370.0, decay=2.0, vol=0.5),
        tone(0.9, lambda t: 440.0, decay=2.0, vol=0.55),
        tone(0.9, lambda t: 588.0, decay=2.0, vol=0.4),
    )
    write_wav("horn_organ", organ)


def main():
    os.makedirs(OUT, exist_ok=True)
    gen_materials()
    gen_events()
    files = sorted(os.listdir(OUT))
    print(f"{len(files)} Dateien in {OUT}")
    total = sum(os.path.getsize(os.path.join(OUT, f)) for f in files)
    print(f"Gesamtgröße: {total / 1024.0:.0f} KB")


if __name__ == "__main__":
    main()
