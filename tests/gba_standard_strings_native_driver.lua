-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real cartridge import/dispatch acceptance; no campaign progress is claimed.
return function(game)
 local V=require('src.core.GameVersion');local edition=V.get()
 local M=require('src.import.Gen3StandardStrings');local J=require('src.link.Json')
 local S=require('src.core.SaveSerializer');local C=require('src.script.Commands')
 require('src.script.Gen3Commands')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 assert(require('src.import.RomImporter').readyReport(edition).ok)
 local record=game.data.constants.gen3StandardStrings
 assert(M.valid(record,edition)and record.romSha1==V.info(edition).sha1)
 local before,rng=S.encode(game.save),love.math.getRandomState()
 local oldBuffers=game.stringBuffers;local rows={}
 for i=0,record.count-1 do
  C.g3_buffer({game=game,save=game.save},0,'std',i)
  assert(game.stringBuffers[1]==record.strings[i]and game.stringBuffers[1]~='')
  rows[#rows+1]={index=i,text=game.stringBuffers[1]}
 end
 if edition=='firered'or edition=='leafgreen'then
  for i,badge in ipairs(game.data.constants.badges)do
   assert(record.strings[14+i]==(badge.name or badge.id),'Original badge and standard-string names disagree')
  end
 end
 C.g3_buffer({game=game,save=game.save},0,'std',record.count)
 assert(game.stringBuffers[1]=='','Invalid standard ID retained stale text')
 game.stringBuffers=oldBuffers
 assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Buffer dispatch changed save/RNG')
 local report={status='pass',edition=edition,continuousStory=false,standardStringsOnly=true,
  ownImportReady=true,tableAddress=record.tableAddress,count=record.count,romSha1=record.romSha1,
  dispatchPreservesSaveRng=true,rows=rows}
 local f=assert(io.open(assert(os.getenv('EDITION_QA_OUT'))..'/result.json','w'));f:write(J.encode(report));f:close()
 print('PASS_NATIVE_GBA_STANDARD_STRINGS '..edition)
 love.event.quit(0)
end
