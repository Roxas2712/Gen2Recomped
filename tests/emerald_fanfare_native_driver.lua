-- Re-run only the original fanfare extraction stage on an own cache clone.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
 local Serialize=require('src.core.SaveSerializer');local M4A=require('src.core.M4ASynth')
 local out=assert(os.getenv('EDITION_QA_OUT'));local version=require('src.core.GameVersion').get()
 assert(version=='emerald'and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 local r={edition=version,status='running',preparedFanfareFixture=true,continuousStory=false,
  captures={},cases={},audio={},measurementErrors={}}
 -- Runtime mounts the cartridge at the virtual root and resets CacheFs.
 -- Reproduce the import stage's explicit write/read prefix instead.
 local runtimePrefix=Fs.prefix
 Fs.prefix=require('src.core.GameVersion').cachePrefix(version)
 assert(Fs.prefix=='emerald/');r.importPrefix=Fs.prefix
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(r));f:close()end
 local function decoded(path)local fn=assert(loadstring(assert(Fs.read(path))));setfenv(fn,{});return assert(fn())end
 local oldAudio=decoded('data/generated/audio.lua');local constants=decoded('data/generated/constants.lua')
 assert(oldAudio.programPrefix==nil,'Import proof must start from serialized data, before Data supplies its prefix')
 local beforeConstants=Writer.encodeSplit(constants);local saveBefore=Serialize.encode(game.save)
 local rng=love.math.getRandomState();local file=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'))
 local bytes=file:read('*a');file:close()
 local rom=require('src.import.RomGba').new(bytes)
 local manifest=J.decode(assert(love.filesystem.read('tools/rom_manifest_emerald.json')))
 local extractor=setmetatable({rom=rom,manifest=manifest,_songs=game.data.audio.songs,_audio=oldAudio,
  _constants=constants,beginStage=function()end},{__index=require('src.import.RomExtractorGen3')})
 local newEngine=M4A.newEngine
 M4A.newEngine=function(data,def,opts)
  local ok,value=pcall(newEngine,data,def,opts)
  if not ok then r.measurementErrors[#r.measurementErrors+1]=tostring(value);persist();error(value,0)end
  return value
 end
 persist();extractor:extractFanfares();M4A.newEngine=newEngine
 assert(#r.measurementErrors==0,'Native import could not read its own music image')
 local fanfares=assert(extractor._constants.gen3Fanfares,'Native Emerald fanfares were discarded')
 assert(fanfares.table==0x5248BC and fanfares.count==18 and fanfares.agreed>=12)
 r.table=fanfares.table;r.count=fanfares.count;r.agreed=fanfares.agreed
 r.cases.nativeTableMeasured=true
 local fresh=decoded('data/generated/audio.lua');assert(fresh.programPrefix==nil)
 local loaded=decoded('data/generated/constants.lua');loaded.gen3Fanfares=nil
 -- The extraction stage may add only its own constants record.
 local fn=assert(loadstring(beforeConstants));setfenv(fn,{});local before=fn();before.gen3Fanfares=nil
 assert(Writer.encode(loaded)==Writer.encode(before),'Fanfare extraction changed unrelated constants')
 assert(Serialize.encode(game.save)==saveBefore and love.math.getRandomState()==rng,'Import proof changed gameplay state')
 fresh.programPrefix=Fs.prefix;fresh.songs=game.data.audio.songs
 Fs.prefix=runtimePrefix
 for i,name in ipairs({
   'LEVEL_UP','OBTAIN_ITEM','EVOLVED','OBTAIN_TMHM','HEAL','OBTAIN_BADGE','MOVE_DELETED','OBTAIN_BERRY',
   'AWAKEN_LEGEND','SLOTS_JACKPOT','SLOTS_WIN','TOO_BAD','POKE_FLUTE','OBTAIN_KEY_ITEM','DEX_RATING',
   'OBTAIN_B_POINTS','OBTAIN_SYMBOL','REGISTER_MATCH_CALL'})do
  local row=assert(fanfares.fanfares[name]);local at=0x5248BC+(i-1)*4
  assert(row.index==rom:u16(at)and row.frames==rom:u16(at+2),'Fanfare metadata differs from original table')
  local synth=newEngine({audio=fresh},assert(fresh.songs[row.song]),{allowLoops=false});local signal=false
  for _=1,88200 do local l,q=synth:sampleStereo();if l~=0 or q~=0 then signal=true;break end end
  assert(signal,'Silent native Emerald fanfare '..name)
  r.audio[name]={index=row.index,frames=row.frames,measured=row.played,nonzeroPcm=true}
 end
 r.cases.allEighteenHaveSignal=true
 assert(fresh.special.heal=='SONG_170'and fresh.sfx.Heal_HP.m4a==368)
 assert(fresh.sfx.Get_Item1.m4a==370 and fresh.sfx.Get_Key_Item.m4a==530)
 local source=require('src.core.Sound').play({audio=fresh},'Heal_HP')
 assert(source and source:isPlaying(),'The restored heal role did not start its native source')
 r.cases.healAndItemRolesRestored=true
 assert(U.shot(game,out..'/native-emerald-fanfare-proof.png'));r.captures={'native-emerald-fanfare-proof'}
 r.cases.saveAndRngPreserved=true;r.status='pass';persist()
 print('PASS_EMERALD_NATIVE_FANFARES');love.event.quit(0)
end
