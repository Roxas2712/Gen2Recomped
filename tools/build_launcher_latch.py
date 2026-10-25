"""Generate a short plastic latch/connector click without recorded samples."""
from array import array
import math
from pathlib import Path
import random
import wave

rate = 22050
duration = 0.19
random.seed(2712)
samples = array('h')
for i in range(int(rate * duration)):
    t = i / rate
    value = 0.0
    for at, amplitude, decay in [(0.0, .8, 240), (.017, .48, 190), (.041, .23, 140)]:
        dt = t - at
        if dt >= 0:
            noise = random.uniform(-1, 1) * math.exp(-dt * decay)
            plastic = (math.sin(2 * math.pi * 1580 * dt) + .5 * math.sin(2 * math.pi * 3270 * dt)) * math.exp(-dt * 180)
            value += amplitude * (.6 * noise + .3 * plastic)
    value += .14 * math.sin(2 * math.pi * 225 * t) * math.exp(-t * 65)
    samples.append(int(max(-.8, min(.8, value)) * 32767))
path = Path(__file__).resolve().parents[1] / 'assets/launcher/cartridge_latch.wav'
path.parent.mkdir(parents=True, exist_ok=True)
with wave.open(str(path), 'wb') as file:
    file.setnchannels(1)
    file.setsampwidth(2)
    file.setframerate(rate)
    file.writeframes(samples.tobytes())
print(path)
