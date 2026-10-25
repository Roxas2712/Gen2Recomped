"""Render the short RetroRecomped guitar intro; no recordings or soundfonts.

The four opening cells follow the IntroBattle motif (Nidorino / Gengar),
arranged for plucked, distorted power chords with original drums and texture.
Requires numpy only to regenerate; the application plays the bundled WAV.
"""
from pathlib import Path
import wave
import numpy as np

RATE = 22050
DURATION = 6.0
rng = np.random.default_rng(2712)
mix = np.zeros((int(RATE * DURATION), 2), dtype=np.float64)


def pluck(midi, seconds, detune=0.0, palm=False):
    freq = 440 * 2 ** ((midi - 69) / 12) * (1 + detune)
    delay = max(2, round(RATE / freq))
    buffer = rng.uniform(-1, 1, delay)
    # Pick position shapes the initial displacement of the string.
    buffer *= np.sin(np.linspace(0, np.pi, delay))
    signal = np.zeros(int(seconds * RATE))
    decay = 0.976 if palm else 0.995
    index = 0
    previous = 0.0
    for i in range(len(signal)):
        current = buffer[index]
        buffer[index] = (current + previous) * 0.5 * decay
        signal[i] = current
        previous = current
        index = (index + 1) % delay
    t = np.arange(len(signal)) / RATE
    attack = np.minimum(1, t / 0.004)
    release = np.minimum(1, (seconds - t) / 0.035)
    signal *= attack * release
    return signal


def add(signal, start, gain, pan=0.0):
    at = int(start * RATE)
    count = min(len(signal), len(mix) - at)
    if count <= 0:
        return
    mix[at:at + count, 0] += signal[:count] * gain * (1 - pan * 0.5)
    mix[at:at + count, 1] += signal[:count] * gain * (1 + pan * 0.5)


start = 0.62
unit = 0.09
# D D A / D D Bb / D D A / D D C#: the recognizable opening figure.
notes = [(38, 2), (38, 2), (45, 4), (38, 2), (38, 2), (46, 4),
         (38, 2), (38, 2), (45, 4), (38, 2), (38, 2), (37, 4)]
for pitch, length in notes:
    duration = unit * length
    for offset, pan, detune in [(0, -0.8, -0.003), (0.012, 0.8, 0.003)]:
        chord = sum(pluck(pitch + interval, duration + 0.12,
                          detune=detune, palm=length == 2) * weight
                    for interval, weight in [(0, 1), (7, 0.65), (12, 0.4)])
        chord = np.tanh(chord * 7.5)
        add(chord, start + offset, 0.15, pan)
    add(pluck(pitch - 12, duration + 0.10), start, 0.13)
    # Lead doubles the original motif an octave above the power-chord root.
    add(np.tanh(pluck(pitch + 12, duration + 0.10) * 4), start, 0.055)
    start += duration

# One resolving D power chord, allowed to ring under the completed logo.
tail = sum(pluck(pitch, 1.8) * weight for pitch, weight in [(38, 1), (45, .7), (50, .5)])
add(np.tanh(tail * 5), start, 0.15)

for beat in range(8):
    at = 0.62 + beat * 0.36
    t = np.arange(int(RATE * 0.25)) / RATE
    kick = np.sin(2 * np.pi * (43 * t + 2.0 * (1 - np.exp(-t * 35)))) * np.exp(-t * 19)
    add(kick, at, 0.26)
    if beat % 2:
        snare = rng.uniform(-1, 1, len(t)) * np.exp(-t * 25)
        add(snare, at, 0.15)
    hat = rng.uniform(-1, 1, int(RATE * .05)) * np.exp(-np.arange(int(RATE * .05)) / RATE * 75)
    add(hat, at + .18, .055, (-1) ** beat * .7)

# Electrical charge and one restrained impact under the lightning animation.
t = np.arange(int(RATE * .58)) / RATE
charge = rng.uniform(-1, 1, len(t)) * (t / .58) ** 2
charge *= np.sin(2 * np.pi * (290 * t + 2300 * t * t))
add(charge, .04, .055)

# Speaker cabinet roll-off and soft limiting keep the high gain listenable.
for channel in range(2):
    low = 0.0
    baseline = 0.0
    for i in range(len(mix)):
        low += .46 * (mix[i, channel] - low)
        baseline += .018 * (low - baseline)
        mix[i, channel] = low - baseline
mix = np.tanh(mix * 1.7)
mix *= .84 / max(.84, float(np.max(np.abs(mix))))
fade = np.minimum(1, np.arange(len(mix)) / (RATE * .01))
fade *= np.minimum(1, (len(mix) - np.arange(len(mix))) / (RATE * .32))
mix *= fade[:, None]
pcm = (mix * 32767).astype('<i2')
path = Path(__file__).resolve().parents[1] / 'assets/launcher/retro_intro_riff.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as file:
    file.setnchannels(2)
    file.setsampwidth(2)
    file.setframerate(RATE)
    file.writeframes(pcm.tobytes())
print(f'{path}: {DURATION}s, peak={np.max(np.abs(mix)):.3f}, RMS={np.sqrt(np.mean(mix ** 2)):.3f}')
