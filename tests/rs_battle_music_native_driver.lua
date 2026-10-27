-- Native ROM/class/audio acceptance; no story or prepared-party claim.
return function(game)
  local V=require('src.core.GameVersion');local edition=V.get()
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  local J=require('src.link.Json');local Serialize=require('src.core.SaveSerializer')
  local Battle=require('src.battle.BattleState');local Music=require('src.core.Music')
  local policy=require('src.battle.Gen3RsBattleMusic')
  local out=assert(os.getenv('EDITION_QA_OUT'));local before=Serialize.encode(game.save)
  local rng=love.math.getRandomState()
  local report={edition=edition,status='running',nativeMusicAcceptance=true,continuousStory=false,
    trainerRows=0,classCounts={},roles={},victories={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();assert(require('src.import.RomImporter').readyReport(edition).ok)
  assert(policy.ready(game.data.audio))
  -- Independent raw trainer class/name bytes and song-header pointers.
  local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local rom=f:read('*a');f:close()
  local S=require('compat.gen1-rs.Loader').new(edition)('src.import.gba.syms').of(edition)
  local function u32(p)local a,b,c,d=rom:byte(p+1,p+4);return a+b*256+c*65536+d*16777216 end
  local function name(p)return assert(rom:sub(p+1,p+13):match('^(.-)\255'))end
  local wally=name(S.off('BattleText_Wally'))
  local expectedClasses={[2]='aquaMagmaLeader',[49]='aquaMagmaLeader',
    [3]='aquaMagma',[4]='aquaMagma',[50]='aquaMagma',[51]='aquaMagma',
    [25]='gym',[32]='final',[24]='elite'}
  local representatives={}
  for i=0,S.count('gTrainers',40)-1 do
    local p=S.off('gTrainers')+i*40;local class=rom:byte(p+2)
    local id=assert(game.data.constants.trainerOrder[i]);local trainer=assert(game.data.trainers[id])
    assert(trainer.class==class,'Imported class differs from native ROM')
    local expected=expectedClasses[class]or'trainer'
    if class==46 then expected=name(p+4)==wally and'trainer'or'rival'end
    local b=setmetatable({data=game.data,game=game,kind='trainer',trainer=trainer},{__index=Battle})
    assert(b:computeMusicKind()==expected,'Wrong native trainer music '..id)
    assert(b.isGymLeader==(class==25),'Wrong gym identity '..id)
    report.trainerRows=report.trainerRows+1
    local k=tostring(class);report.classCounts[k]=(report.classCounts[k]or 0)+1
    representatives[expected..':'..class]=b
  end
  for _,class in ipairs({2,3,4,24,25,32,46,49,50,51,53})do assert(report.classCounts[tostring(class)])end
  local fanfare=assert(game.data.audio.fanfares.LEVEL_UP)
  local effect=assert(game.data.audio.sfx.Level_Up)
  assert(effect.m4a==367 and effect.song==fanfare.song and effect.fanfare=='LEVEL_UP'and fanfare.frames==80)
  local nativeFanfare=S.off('sFanfares')
  assert(rom:byte(nativeFanfare+1)+rom:byte(nativeFanfare+2)*256==effect.m4a)
  local sound=assert(require('src.core.Sound').play(game.data,'Level_Up'),'Native level-up role was silent')
  assert(sound:isPlaying());sound:stop()
  local synth=require('src.core.M4ASynth').newEngine(game.data,game.data.audio.songs[effect.song],{allowLoops=false})
  local nonzero=false
  for _=1,44100 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then nonzero=true;break end end
  assert(nonzero);report.levelUp={index=effect.m4a,fanfareFrames=fanfare.frames,sourcePlayed=true,nonzeroPCM=true}
  report.commonEffects={}
  for role,id in pairs({Save=55,Run=17,Start_Menu=6,Select=5,Purchase=95})do
    local effect=assert(game.data.audio.sfx[role]);local symbol=assert(policy.effects[role])
    assert(effect.m4a==id and effect.song==('SONG_%03X'):format(id)and not effect.fanfare)
    local song=assert(game.data.audio.songs[effect.song]);assert(song.header==S.off(symbol:lower()))
    assert(u32(S.off('gSongTable')+id*8)-0x08000000==song.header)
    local source=assert(require('src.core.Sound').play(game.data,role),'Silent shared RS effect '..role)
    assert(source:isPlaying());source:stop()
    local synth=require('src.core.M4ASynth').newEngine(game.data,song,{allowLoops=false})
    local nonzero=false
    for _=1,44100 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then nonzero=true;break end end
    assert(nonzero);report.commonEffects[role]={index=id,symbol=symbol,sourcePlayed=true,nonzeroPCM=true}
  end
  -- Match each role to its own native header, then synthesize actual samples.
  local ids=game.data.constants.gen3RsPresentation.songIds
  for role,symbol in pairs(policy.roles)do
    local id=assert(ids[symbol]);local label=assert(game.data.audio.battle[role])
    local song=assert(game.data.audio.songs[label])
    assert(label==('SONG_%03X'):format(id))
    assert(u32(S.off('gSongTable')+id*8)-0x08000000==S.off(symbol:lower()))
    assert(song.header==S.off(symbol:lower()))
    local synth=require('src.core.M4ASynth').newEngine(game.data,song,{allowLoops=false})
    local nonzero=false
    for _=1,44100 do local l,r=synth:sampleStereo();if l~=0 or r~=0 then nonzero=true;break end end
    assert(nonzero,'Silent RS role '..role)
    Music.playBattle(game.data,role);assert(Music.current()==label)
    report.roles[role]={symbol=symbol,index=id,header=song.header,nonzeroPCM=true,selectedByMusic=true}
  end
  for key,b in pairs(representatives)do
    local class=b.trainer.class;local expected='trainer'
    if class==24 or class==32 then expected='final'
    elseif class==25 then expected='gym'
    elseif class==2 or class==3 or class==4 or class==49 or class==50 or class==51 then expected='aquaMagma'end
    b.musicKind=b:computeMusicKind();b:playVictoryMusic()
    local label=assert(game.data.audio.battle[expected..'Win'])
    assert(Music.current()==label,'Wrong native victory '..key)
    report.victories[key]={role=expected,song=label}
  end
  for species,expected in pairs({KYOGRE='weatherTrio',GROUDON='weatherTrio',
    REGIROCK='regi',REGICE='regi',REGISTEEL='regi',RAYQUAZA='wild'})do
    local b=setmetatable({data=game.data,game=game,kind='wild',enemy={mon={species=species}}},{__index=Battle})
    assert(b:computeMusicKind()==expected,'Wrong RS legendary role '..species)
    b.musicKind=expected;b:playVictoryMusic();assert(Music.current()==game.data.audio.battle.wildWin)
  end
  local copy={battle={},songs=game.data.audio.songs,sfx=game.data.audio.sfx,fanfares=game.data.audio.fanfares}
  for k,v in pairs(game.data.audio.battle)do copy.battle[k]=v end
  copy.battle.aquaMagma=nil;assert(not policy.ready(copy),'Old incomplete audio must invalidate readiness')
  copy.battle.aquaMagma=copy.battle.trainer;assert(not policy.ready(copy),'Mislabelled role must invalidate readiness')
  copy.battle.aquaMagma=game.data.audio.battle.aquaMagma;assert(policy.ready(copy))
  copy.sfx={};assert(not policy.ready(copy),'Missing level-up alias must invalidate readiness')
  copy.sfx={};for k,v in pairs(game.data.audio.sfx)do copy.sfx[k]=v end
  copy.sfx.Save=nil;assert(not policy.ready(copy),'Missing shared effect must invalidate readiness')
  assert(before==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Music checks mutated save/RNG')
  report.saveAndRngPreserved=true;report.status='pass';persist()
  print('PASS_RS_NATIVE_BATTLE_MUSIC '..report.trainerRows);love.event.quit()
end
