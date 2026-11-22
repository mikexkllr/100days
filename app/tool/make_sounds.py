"""Synthesises the app's few sound effects, so they are ours (no licence
question) and tiny. Mono, 22.05 kHz, 16-bit WAV.

    python3 tool/make_sounds.py assets/sounds
"""
import numpy as np, wave, sys
SR = 22050
out = sys.argv[1]

def env(n, attack=0.005, release=0.1):
    t = np.arange(n) / SR
    a = np.clip(t / attack, 0, 1)
    r = np.clip((t[-1] - t) / release, 0, 1)
    return a * r

def save(name, x):
    x = x / (np.max(np.abs(x)) + 1e-9) * 0.85
    data = (x * 32767).astype('<i2').tobytes()
    with wave.open(f'{out}/{name}.wav', 'wb') as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(SR); w.writeframes(data)

rng = np.random.default_rng(7)
def tone(f0, f1, dur, shape='sine'):
    n = int(SR * dur); t = np.arange(n) / SR
    f = np.geomspace(f0, f1, n)
    ph = 2 * np.pi * np.cumsum(f) / SR
    return np.sin(ph) if shape == 'sine' else np.sign(np.sin(ph)) * 0.4 + np.sin(ph) * 0.6

# ignite: a short whoosh (filtered noise rising) and a warm pop
n = int(SR * 0.42)
noise = rng.standard_normal(n)
kernel = np.ones(12) / 12
whoosh = np.convolve(noise, kernel, 'same') * np.linspace(0.2, 1, n) ** 2 * env(n, 0.02, 0.12)
pop = tone(180, 620, 0.42) * np.exp(-np.arange(n) / SR * 9)
save('ignite', whoosh * 0.6 + pop)

# tick: a tiny wooden click
n = int(SR * 0.03)
save('tick', tone(2400, 1800, 0.03) * np.exp(-np.arange(n) / SR * 180))

# thud: a reel stopping
n = int(SR * 0.18)
save('thud', (tone(140, 60, 0.18) + 0.3 * np.convolve(rng.standard_normal(n), np.ones(30) / 30, 'same')) * np.exp(-np.arange(n) / SR * 22))

# gulp: an ember swallowed
n = int(SR * 0.2)
save('gulp', tone(520, 210, 0.2) * env(n, 0.01, 0.08) * np.exp(-np.arange(n) / SR * 6))

# poke: a soft boing
n = int(SR * 0.26)
t = np.arange(n) / SR
save('poke', np.sin(2 * np.pi * (330 + 90 * np.sin(2 * np.pi * 18 * t)) * t) * np.exp(-t * 11))

# jackpot: a bright arpeggio with shimmer
notes = [523.25, 659.25, 783.99, 1046.5, 1318.5]
parts = []
for i, f in enumerate(notes):
    n = int(SR * 0.16)
    t = np.arange(n) / SR
    parts.append((np.sin(2 * np.pi * f * t) + 0.35 * np.sin(2 * np.pi * 2 * f * t)) * np.exp(-t * 7))
tail_n = int(SR * 0.55); t = np.arange(tail_n) / SR
tail = sum(np.sin(2 * np.pi * f * t) for f in notes[2:]) * np.exp(-t * 4.5)
save('jackpot', np.concatenate(parts + [tail]))
print('ok')
