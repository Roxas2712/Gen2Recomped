-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Music=require('src.core.Music')
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 for _,speed in ipairs{4,10}do
  local f=dofile('tests/enemy_actions/assist.lua').fixture('.','gen2',edition)
  local h=dofile('tests/native_bgm/streams.lua').install('.','gen2',edition,f)
  -- The title uses Music.play/fadeOutM4a after the field has established
  -- the native sequencer. Use a real owned M4A stream, not a file Source.
  Music.play(f.data,('SONG_%03X'):format(h.ids[2]),true)
  h.update();T.check(Music.current()~=nil,'title owns the native M4A stream')
  Music.fadeOutM4a(speed)
  for _=1,16*speed-1 do h.update()end
  T.check(Music.current()~=nil,'native title song survives until its last fade tick')
  h.update()
  T.eq(Music.current(),nil,edition..': native title fade releases its actual song')
  T.eq(Music.nativeSnapshot().song,nil,'logical native owner ends with its output')
  local queues=h.state().queues
  T.eq(queues[#queues].playing,false,'the actual native queue stops')
  T.eq(queues[#queues].queued,0,'the completed fade retains no PCM')
  h.close()
 end
end
T.finish('Title M4A fade after an existing native field music session, all five GBA editions')
