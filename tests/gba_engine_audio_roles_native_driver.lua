-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-import audio integration acceptance; this is not a campaign.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local S=require('src.core.SaveSerializer');local Sound=require('src.core.Sound')
 local V=require('src.core.GameVersion');local edition=V.get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 local proof=assert(game.data.constants.gen3EngineAudioRoles);assert(proof.edition==edition and proof.format==1)
 local report={status='running',edition=edition,continuousStory=false,freshOwnImport=true,roles={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 for _,role in ipairs{'Level_Up','Save','Run','Start_Menu','Select','Purchase'}do
  local expected=assert(proof.roles[role]);local definition=assert(game.data.audio.sfx[role])
  assert(definition.m4a==expected.index and definition.song==expected.song)
  local before,rng=S.encode(game.save),love.math.getRandomState()
  local source=assert(Sound.play(game.data,role),'Own native sound did not create a source: '..role)
  assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Sound dispatch changed gameplay state')
  report.roles[#report.roles+1]={role=role,index=expected.index,sourceCreated=true};persist()
  U.wait(role=='Level_Up'and 120 or 30)
 end
 report.status='pass';report.dispatchPreservesSaveRng=true;persist()
 print('PASS_NATIVE_GBA_ENGINE_AUDIO '..edition);love.event.quit(0)
end
