"""Bell and haunted arrangements, synthesized without samples or soundfonts."""
from pathlib import Path
import json
import wave
import numpy as np

ROOT = Path(__file__).resolve().parents[1]
SCORE = json.loads((ROOT / 'assets/launcher/intro_score.json').read_text())
RATE = 22050
NOTES = [(38,2),(38,2),(45,4),(38,2),(38,2),(46,4),
         (38,2),(38,2),(45,4),(38,2),(38,2),(37,4),
         (38,2),(38,2),(45,4),(38,2),(38,2),(49,4),
         (50,8),(38,8),(48,8),(36,8),
         (38,2),(38,2),(45,4),(38,2),(38,2),(46,4),
         (38,2),(38,2),(48,4),(38,2),(38,2),(49,4),(50,16),(62,16)]

def render(season):
    mix = np.zeros((round(RATE*SCORE['duration']), 2))
    rng = np.random.default_rng(2712)
    def add(signal, at, gain, pan=0):
        start = round(at*RATE)
        count = min(len(signal), len(mix)-start)
        if count > 0:
            mix[start:start+count] += signal[:count,None] * np.array([1-pan*.4,1+pan*.4]) * gain
    def bell(pitch, seconds=1.8, haunted=False):
        t = np.arange(round(RATE*seconds))/RATE
        frequency = 440*2**((pitch-69)/12)
        if haunted:
            wave = sum(np.sin(2*np.pi*frequency*ratio*t + .018*np.sin(t*9))*weight*np.exp(-t*decay)
                       for ratio,weight,decay in [(1,1,2.4),(2,.22,4.5),(3,.09,6),(1.003,.24,2.5)])
        else:
            wave = sum(np.sin(2*np.pi*frequency*ratio*t)*weight*np.exp(-t*decay)
                       for ratio,weight,decay in [(1,1,2.9),(2.76,.26,6.4),(5.4,.10,10),(8.93,.04,14)])
        return wave*np.minimum(1,t/.007)*np.minimum(1,(seconds-t)/.15)
    if season == 'winter':
        at = SCORE['musicStart']
        for pitch,length in NOTES:
            add(bell(pitch+24, max(1.3,length*SCORE['noteUnit']+.5)), at, .24, np.sin(at)*.7)
            add(bell(pitch+12,1.6), at, .07, -.4)
            at += length*SCORE['noteUnit']
        for i in range(36):
            t = np.arange(round(RATE*.16))/RATE
            noise = rng.uniform(-1,1,len(t))
            hiss = np.concatenate(([0],np.diff(noise)))*np.exp(-t*38)
            chime = np.sin(2*np.pi*4700*t)*np.exp(-t*30)
            add((hiss*.25+chime*.5),.72+i*.36,.035,(-1)**i*.7)
        closing = [50,57,62]
    else:
        # Lavender Town's exposed C-G-B-F# figure (pokered Ch2), with an
        # original soft organ bed and a restrained minor closing cadence.
        for i in range(36):
            at = SCORE['musicStart']+i*.36
            add(bell([72,79,83,78][i%4],2.1,True),at,.16,np.sin(i*.8)*.75)
            if i%4 == 0:
                add(bell([52,50,48,52][(i//4)%4],2.3,True),at,.13)
        t = np.arange(len(mix))/RATE
        bed = sum(np.sin(2*np.pi*f*t+.03*np.sin(t*2))*g for f,g in [(82.4,.028),(123.47,.015),(164.81,.011)])
        bed *= np.minimum(1,t/2)*np.clip((SCORE['catch']-t)/1.5,0,1)
        add(bed,0,1)
        closing = [40,47,52]
    for hit in SCORE['closing']:
        for pitch in closing:
            add(bell(pitch,hit['length']+.5,season=='autumn'),hit['at'],.10)
    mix = np.tanh(mix*1.3)
    mix *= .74/max(.74,float(np.max(np.abs(mix))))
    t = np.arange(len(mix))/RATE
    mix *= (1-np.clip((t-(SCORE['catch']-.09))/.09,0,1)*(1-SCORE['closingLevel']))[:,None]
    mix *= np.minimum(1,(SCORE['duration']-t)/.45)[:,None]
    path = ROOT/f'assets/launcher/retro_intro_{season}.wav'
    with wave.open(str(path),'wb') as out:
        out.setnchannels(2);out.setsampwidth(2);out.setframerate(RATE)
        out.writeframes((mix*32767).astype('<i2').tobytes())
    print(path.name, 'peak',round(float(np.max(np.abs(mix))),3))

if __name__ == '__main__':
    render('winter')
    render('autumn')
