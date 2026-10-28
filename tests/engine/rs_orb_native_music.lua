-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Music,V=require('src.core.Music'),require('src.core.GameVersion')
local before=V.get()
require('src.script.Gen3Commands')
for _,edition in ipairs{'ruby','sapphire'}do
  for _,shared in ipairs{false,true}do
    local f=dofile('tests/enemy_actions/assist.lua').fixture('.','gen2',edition)
    local h=dofile('tests/native_bgm/streams.lua').install('.','gen2',edition,f,{initialShared=shared})
    h.update()
    T.check(Music.current()~=nil,'prepared music owns a song')
    local runner=require('src.script.ScriptRunner').new(f.game,{map={id='OWNED_NATIVE_BGM_MAP'}})
    runner:run({{'g3_special',0x114C},{'g3_wait_state'}})
    T.check(runner:isRunning(),'original RS special parks the actual VM')
    T.eq(Music.nativeSnapshot().fadeOut.dur,64/60,'RS fade uses the serviced native clock')
    for _=1,63 do h.update();runner:update();T.check(runner:isRunning(),'VM waits for music completion')end
    T.check(Music.current()~=nil,'song survives until final fade tick')
    h.update();runner:update()
    T.eq(Music.current(),nil,'actual music owner stops at tick64')
    T.eq(runner:isRunning(),false,'music completion releases the actual VM')
    T.eq(Music.nativeSnapshot().song,nil,'native logical song is cleared')
    if not shared then
      T.eq(h.state().queues[1].playing,false,'actual native queue stops')
      T.eq(h.state().queues[1].queued,0,'native fade leaves no pending PCM')
    end
    h.close()
  end
end
V.set(before)
T.finish('RS legendary music wait with actual native sequencer and shared override')
