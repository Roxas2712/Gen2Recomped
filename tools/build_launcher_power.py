"""Synthesize distinct handheld power-on cues; no recordings or ROM samples.

These are short recreations for the illustrated dummy devices, rather than
extracted firmware audio. Regenerate with the Python standard library.
"""
from array import array
import math
from pathlib import Path
import wave

RATE = 22050
# at, frequency, duration, gain: monochrome ping, color sparkle, advance sweep,
# and a soft two-part dual-screen bell. Each completes before logo formation.
CUES = {
    'gb': [(0, 1046.5, .18, .5), (.14, 2093, .62, .42)],
    'gbc': [(0, 1046.5, .16, .35), (.10, 1568, .24, .3), (.20, 2093, .65, .4)],
    'gba': [(0, 523.25, .38, .28), (.10, 783.99, .40, .24),
            (.21, 1046.5, .40, .26), (.31, 1568, .54, .26)],
    'nds': [(0, 1318.51, .60, .34), (.10, 1568, .65, .27), (.20, 2093, .65, .18)],
}

for kind, notes in CUES.items():
    pcm = array('h')
    for i in range(int(RATE * .95)):
        t, value = i / RATE, 0.0
        for at, freq, duration, gain in notes:
            dt = t - at
            if 0 <= dt < duration:
                attack = min(1, dt / .004)
                release = min(1, (duration - dt) / .08)
                envelope = attack * release * math.exp(-dt * (5 if kind == 'gb' else 4))
                phase = 2 * math.pi * freq * dt
                if kind in ('gb', 'gbc'):
                    tone = sum(math.sin(phase * h) / h for h in (1, 3, 5, 7)) * .7
                else:
                    tone = math.sin(phase) + .25 * math.sin(phase * 2.01) * math.exp(-dt * 12)
                value += gain * envelope * tone
        pcm.append(int(math.tanh(value * 1.3) * 28000))
    path = Path(__file__).resolve().parents[1] / f'assets/launcher/power_{kind}.wav'
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), 'wb') as file:
        file.setnchannels(1)
        file.setsampwidth(2)
        file.setframerate(RATE)
        file.writeframes(pcm.tobytes())
    print(path)
