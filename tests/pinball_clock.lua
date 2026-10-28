-- Repeated bounded stalls must not permanently slow native audio/game time.
package.path='./?.lua;'..package.path
local Clock=require('src.pinball.Clock')
local now,deadline,lost=0,0,0
for frame=1,10000 do
 now=math.max(now,deadline)+.005+(frame%200==0 and .08 or 0)
 local debt;deadline,debt=Clock.advance(deadline,now);lost=lost+debt
end
-- Finish the pending recovery, without skipping guest frames.
for _=1,20 do now=math.max(now,deadline)+.005;deadline=Clock.advance(deadline,now)end
assert(lost==0,'short scheduler stalls must not accumulate discarded audio time')
assert(math.abs(now-10020*Clock.PERIOD)<Clock.PERIOD,'guest steps recover the original real-time deadline')
local nextFrame,discarded=Clock.advance(0,3)
assert(nextFrame==2.75 and discarded>2,'long suspension bounds catch-up instead of running seconds of queued gameplay')
print('Pinball clock: repeated 80 ms stalls preserve game/audio cadence; long suspension remains bounded')
