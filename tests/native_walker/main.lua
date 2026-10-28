-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Separate native processes, real account-local disk IO and imported species.
local root=assert(os.getenv('NATIVE_WALKER_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
io.stdout:setvbuf('no')
function love.load()
 assert(love.filesystem.getIdentity():match('^gen2recomp%-qa%-walker%-'))
 love.filesystem.setSymlinksEnabled(true);assert(love.filesystem.mountFullPath(root,'','read',true))
 local Saves=require('src.core.SaveData');local S=require('src.core.SaveSerializer')
 local W=require('src.pokewalker.Walker');local L=require('src.pokewalker.WalkerLink')
 local Journal=require('src.pokewalker.WalkerTransfer')
 require('src.core.GameVersion').set('ruby')
 require('src.pokewalker.WalkerArt')._roots={assert(os.getenv('NATIVE_WALKER_IMPORT'))}
 local data=assert(require('src.pokewalker.WalkerDelivery').dataset('ruby'))
 local fs=Saves.persistenceFs();local phase=assert(os.getenv('NATIVE_WALKER_PHASE'))
 local checks=0;local function check(v,m)checks=checks+1;assert(v,m)end
 local slot
 if phase=='send-interrupt'then
  slot=assert(Saves.createSlot('ruby'))
  local save=Saves.newGame{version='ruby',playerName='NATIVE QA',startMap='MAP_G16_N00'}
  local mon=require('src.pokemon.Pokemon').new(data,'TREECKO',5)
  save.boxes={{mons={mon}}};save.box={}
  assert(Saves.writeSlot('ruby',slot,save));assert(fs.write('walker_native_fixture.lua',S.encode{slot=slot}))
  assert(W.save(W.load()))
 else slot=S.decode(assert(fs.read('walker_native_fixture.lua'))).slot end
 local path='saves/ruby/'..slot..'.lua'
 local sourceBefore=assert(fs.read(path))
 if phase=='send-interrupt'or phase=='return-interrupt'then
  local st=W.load();local rawWrite=fs.write;local refused=false
  fs.write=function(p,b)
   if p==W.FILE..'.tmp'and not refused then refused=true;return false,'injected full disk after native source commit'end
   return rawWrite(p,b)
  end
  local ok,why
  if phase=='send-interrupt'then
   local entries=assert(L.boxMons('ruby',slot));check(#entries==1,'native imported Pokémon is in source PC')
   ok,why=L.send(st,entries[1],0)
  else ok,why=L.bringHome(st,false)end
  fs.write=rawWrite
  check(not ok and refused and type(why)=='string','native second-participant refusal reports incomplete transfer')
  check(Journal.pending(fs),'durable journal survives process exit')
  check(not W.check(st),'live stale state cannot repeat native delivery')
  local save=S.decode(assert(fs.read(path)));local walker=S.decode(assert(fs.read(W.FILE)))
  check((save.boxes[1].mons[1]~=nil)==(phase=='return-interrupt'),'native source commit reached disk first')
  check((walker.walking~=nil)==(phase=='return-interrupt'),'prior walker bytes survive the refused write')
 else
  local st=W.load()
  check(not W.transferError,'cold process recovers pending native journal')
  check(not Journal.pending(fs),'cold recovery finalizes its intent')
  check(fs.read(path)==sourceBefore,'cold recovery never replays an already-committed native source')
  local save=S.decode(assert(fs.read(path)))
  local walking=phase=='recover-send'
  check((st.walking~=nil)==walking,'native walker participant recovers intended ownership')
  local count=0
  for _,box in ipairs(save.boxes)do for _,mon in pairs(box.mons or box)do if type(mon)=='table'and mon.species then count=count+1 end end end
  check(count==(walking and 0 or 1),'native source has exactly zero or one prepared Pokémon')
  if not walking then
   check(save.boxes[1].mons[1].species=='TREECKO','actual native delivery retains imported species identity')
  end
 end
 local result={passed=true,checks=checks,phase=phase,preparedNativePokemon=true,
   actualSourceSaveIO=true,realColdProcessRecovery=true,continuousStory=false}
 local file=assert(io.open(assert(os.getenv('NATIVE_WALKER_REPORT')),'wb'))
 file:write(require('src.link.Json').encode(result));file:close()
 print('NATIVE_WALKER_IO_PASS',phase,checks);love.event.quit(0)
end
function love.errorhandler(why)
 print('NATIVE_WALKER_IO_FAIL',debug.traceback(tostring(why)))
 return function()return 1 end
end
