-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-import audio integration acceptance; this is not a campaign.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local S=require('src.core.SaveSerializer');local Sound=require('src.core.Sound')
 local V=require('src.core.GameVersion');local edition=V.get();local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 local constants=game.data.constants
 local spec=(edition=='ruby'or edition=='sapphire')and constants.gen3RsPresentation
   or edition=='emerald'and constants.gen3EmeraldPresentation or constants.gen3FrlgHall
 assert(spec and spec.version==edition and spec.songIds)
 local symbols={Level_Up='MUS_LEVEL_UP',Save='SE_SAVE',Run='SE_FLEE',Start_Menu='SE_WIN_OPEN',Select='SE_SELECT',Purchase='SE_SHOP'}
 local report={status='running',edition=edition,continuousStory=false,ownImportReady=true,roles={},failures={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 for _,role in ipairs{'Level_Up','Save','Run','Start_Menu','Select','Purchase'}do
  local index=assert(spec.songIds[symbols[role]]);local row={role=role,index=index,sourceCreated=false}
  local ok,why=pcall(function()
   local definition=assert(game.data.audio.sfx[role],'Missing original engine cue: '..role)
   assert(definition.m4a==index and definition.song==('SONG_%03X'):format(index),'Cue points at another audio program: '..role)
   local before,rng=S.encode(game.save),love.math.getRandomState()
   assert(Sound.play(game.data,role),'Own native sound did not create a source: '..role)
   assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Sound dispatch changed gameplay state')
   row.sourceCreated=true;U.wait(role=='Level_Up'and 120 or 30)
  end)
  if not ok then row.error=tostring(why);report.failures[#report.failures+1]=row.error end
  report.roles[#report.roles+1]=row;persist()
 end
 report.status=#report.failures==0 and'pass'or'fail';report.dispatchPreservesSaveRng=#report.failures==0;persist()
 print((report.status=='pass'and'PASS'or'FAIL')..'_NATIVE_GBA_ENGINE_AUDIO '..edition)
 love.event.quit(report.status=='pass'and 0 or 1)
end
