-- Prepared native cinematic qualification; never ordinary campaign progress.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json');local S=require('src.core.SaveSerializer')
 local A=require('src.import.Gen3EmeraldRaySceneAssets');local Native=require('src.ui.Gen3EmeraldRayScene')
 local out=assert(os.getenv('EDITION_QA_OUT'));assert(require('src.core.GameVersion').get()=='emerald')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-emerald%-'))
 assert(Native.available(game)and #A.missing()==0)
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset();U.freshSave(game);U.teleport(game,'MAP_G19_N00',6,7,'up');U.wait(90)
 local report={status='running',edition='emerald',preparedCinematicFixture=true,continuousStory=false,
  fullStoryTested=false,captures={},cases={},audio={},drawSaveAndRngPreserved=true}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function stableSave()
  local copy={};for k,v in pairs(game.save)do if k~='playTime'then copy[k]=v end end
  return S.encode(copy)
 end
 -- Independent host decoder versus the new indexed reference extractor.
 local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local raw=f:read('*a');f:close()
 local rom=require('src.import.RomGba').new(raw);local X=require('src.import.RomExtractorGen3')
 local symbols=require('compat.gen1-rs.Loader').new('emerald')('src.import.gba.syms').of('emerald')
 local function lz(symbol)local ok,bytes=X.lz77ok(rom,assert(symbols.off(symbol)));assert(ok);return bytes end
 local function pixels(key,gfxName,mapName,size,affine,clear)
  local gfx,map=lz(gfxName),lz(mapName)
  local image=love.image.newImageData(A.ROOT..key..'_idx.png')
  local w,h=image:getDimensions();assert(w==size and h==size)
  local count=0
  for y=0,size-1 do for x=0,size-1 do
   local cell=math.floor(y/8)*(size/8)+math.floor(x/8)
   local entry=affine and map[cell+1]or(map[cell*2+1]+map[cell*2+2]*256)
   if clear and cell>=0x100/2 and cell<(0x100+0x340)/2 then entry=0 end
   local px,py=x%8,y%8
   if not affine then
    if math.floor(entry/1024)%2==1 then px=7-px end
    if math.floor(entry/2048)%2==1 then py=7-py end
   end
   local tile=affine and entry or entry%1024;local index
   if affine then index=gfx[tile*64+py*8+px+1]
   else local byte=gfx[tile*32+py*4+math.floor(px/2)+1]
    index=px%2==0 and byte%16 or math.floor(byte/16)
    if index~=0 then index=index+math.floor(entry/4096)*16 end
   end
   assert(index~=nil and math.floor(image:getPixel(x,y)*255+.5)==index,key..': native index mismatch')
   count=count+1
  end end
  image:release();return count
 end
 report.independentRomPixels=pixels('tf_rayquaza','gRaySceneTakesFlight_Rayquaza_Gfx','gRaySceneTakesFlight_Rayquaza_Tilemap',256,true)
  +pixels('ca_ring','gRaySceneChasesAway_Ring_Gfx','gRaySceneChasesAway_Ring_Tilemap',128,true)
  +pixels('de_bg_top','gRaySceneDescends_Bg_Gfx','gRaySceneDescends_Bg_Tilemap',256,false,true)
 local music=require('src.core.Music');local sound=require('src.core.Sound')
 local song=assert(game.data.constants.gen3EmeraldRayScene.song);local label=('SONG_%03X'):format(song)
 local engine=require('src.core.M4ASynth').newEngine(game.data,assert(game.data.audio.songs[label]),{allowLoops=false})
 for _=1,88200 do local l,r=engine:sampleStereo();if l~=0 or r~=0 then report.audio.nonzeroPCM=true;break end end
 assert(report.audio.nonzeroPCM,'Silent native Rayquaza music')
 local oldPlay,oldSe,oldCry=music.play,sound.playId,sound.playCry
 music.play=function(data,key,...)
  local source=oldPlay(data,key,...)
  if data==game.data and key==label then
   assert(source and music.current()==label);report.audio.rayquazaPlays=(report.audio.rayquazaPlays or 0)+1
  end
  return source
 end
 sound.playId=function(data,id,...)
  local result=oldSe(data,id,...);if data==game.data then report.audio[tostring(id)]=(report.audio[tostring(id)]or 0)+1 end
  return result
 end
 sound.playCry=function(data,species,...)
  local result=oldCry(data,species,...)
  if data==game.data and species=='RAYQUAZA'then report.audio.rayquazaCries=(report.audio.rayquazaCries or 0)+1 end
  return result
 end
 local function shot(screen,name)
  local save=S.encode(game.save);local rng=love.math.getRandomState();local private=screen.load('src.core.game3.rng')
  local r1,r2,wild=private._value,private._value2,private._wild
  assert(require('src.render.GraphicsScope').call(function()screen:draw()end))
  assert(save==S.encode(game.save)and rng==love.math.getRandomState(),'Native cinematic draw changed SAVE/host RNG')
  assert(r1==private._value and r2==private._value2 and wild==private._wild,'Native cinematic draw advanced private RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
 end
 local world=game.overworld;local Commands=require('src.script.Gen3Commands')
 for _,part in ipairs{0,1}do
  game.save.gen3Vars=game.save.gen3Vars or{};game.save.gen3Vars[0x8004]=part
  local before=stableSave();local yields,resumes=0,0
  local runner={yield=function()yields=yields+1 end,resume=function()resumes=resumes+1 end}
  Commands.SPECIALS[part==0 and 470 or 508]({game=game,save=game.save,overworld=world,runner=runner})
  local screen=game.stack:top();assert(getmetatable(screen)==Native and yields==1)
  local scene=screen.scene;local phase,start=scene.animId,scene.frames
  local captures={};local visited={}
  -- Original scene ignores B/START; hold them to rule out the old skip path.
  game.input:overlayPressed('b');game.input:overlayPressed('start')
  for _=1,12000 do
   visited[scene.animId]=true
   if scene.animId~=phase then phase,start=scene.animId,scene.frames end
   local at=scene.frames-start
   if at>=150 and not captures[phase]and phase<6 then
    shot(screen,('ray-part%d-phase%d-original'):format(part,phase));captures[phase]=true
   elseif phase==5 and at>=420 and not captures.finale then
    shot(screen,'ray-original-finale-trio-and-ring');captures.finale=true
   end
   if scene.done then break end
   U.wait(1)
  end
  game.input:overlayReleased('b');game.input:overlayReleased('start');U.wait(5)
  assert(scene.done and resumes==1 and game.stack:top()==world,'Original cinematic failed its one-shot field return')
  assert(before==stableSave(),'Prepared native cinematic changed gameplay SAVE beyond normal play time')
  assert(scene.frames>328,'Native scene was replaced by a short hold')
  if part==0 then assert(not visited[1])else for phase=1,6 do assert(visited[phase])end end
  report.cases[tostring(part)]={frames=scene.frames,visited=visited,callbackOnce=true,nativeSpecial=part==0 and 470 or 508}
  persist()
 end
 assert(report.audio.rayquazaPlays==1 and report.audio.rayquazaCries==1)
 music.play,sound.playId,sound.playCry=oldPlay,oldSe,oldCry
 report.status='pass';persist();print('PASS_EMERALD_NATIVE_RAYQUAZA_SCENE');love.event.quit(0)
end
