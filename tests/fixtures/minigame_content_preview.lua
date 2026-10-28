-- Actual LÖVE ZIP/PNG, profile persistence, setup and five-game smoke test.
-- Contributions by Roxas2712. No external game graphics or network.
local hub,frame,phase= nil,0,'setup'
local checks=0;local basicImages=0;local realImage
local profile,changeProfile
local function check(v,m)assert(v,m);checks=checks+1 end
local function capture(name,nextPhase)
 local output=assert(os.getenv('WALKER_PREVIEW_CAPTURE')):gsub('%.png$','-'..name..'.png')
 phase='capture'
 love.graphics.captureScreenshot(function(data)
  local f=assert(io.open(output,'wb'));f:write(data:encode('png'):getString());f:close();phase=nextPhase;frame=0
 end)
end
function love.load()
 require('src.translation.Service').setLauncher({launcherLanguage='de'})
 local S=require('src.core.SaveSerializer');love.filesystem.write('storage_account.lua',S.encode({schema=1,accountId='17'}))
 local F=require('src.storage.ProfileFs');local active=F.wrap(love.filesystem,'29')
 profile=active;changeProfile=function(id)active=F.wrap(love.filesystem,id)end
 require('src.core.SaveData').persistenceFs=function()return active end
 local H=require('src.ui.WalkerMinigames');local E=require('src.pokewalker.minigames.Enrollment')
 assert(E.accept(active,E.VERSION,H.GAME_MODULES))
 hub=H.new(nil,require('src.pokewalker.Walker').newState())
 check(hub.settingContent and not hub.session,'notices lead to content setup')
 -- No game-media load can silently occur in basic mode.
 realImage=love.graphics.newImage
 love.graphics.newImage=function(...)
  if phase=='basic'then basicImages=basicImages+1;error('Basic mode must not load external image files')end
  return realImage(...)
 end
end
function love.update(dt)
 frame=frame+1
 if phase=='chooseBasic'then hub.contentFocus=1;hub:action('a');check(not hub.settingContent,'basic mode enters catalogue');phase='basic';frame=0
 elseif phase=='basic'then
  local i=math.floor(frame/4)+1
  if i<=5 then
   if hub.sel~=i or not hub.session then hub:play(i,true)end
   hub:update(.016)
  else
   check(basicImages==0,'all five games use zero external images in basic mode')
   hub.session=nil;hub.view='list'
   require('src.pokewalker.minigames.ContentSetup').open(hub)
   local f=assert(io.open(assert(os.getenv('WALKER_PREVIEW_PACK')),'rb'));local bytes=f:read('*a');f:close()
   require('src.pokewalker.minigames.ContentSetup').archive(hub,bytes)
   check(hub.contentReview and not hub.contentChecked,'real ZIP enters unchecked review')
   hub.contentFocus=2;hub:action('a');check(not hub.contentJob,'unchecked content cannot install')
   phase='review';frame=0
  end
 elseif phase=='install'then
  if not hub.contentJob then
   if not hub.contentRead then hub:action('right');return end
   hub.contentFocus=1;hub:action('a');hub.contentFocus=2;hub:action('a')
   check(hub.contentJob,'explicit checked acceptance starts install')
  end
  hub:update(dt)
  if not hub.settingContent then
   local C=require('src.pokewalker.minigames.Content')
   check(C.current().mode=='pack','real filesystem publishes completed pack')
   check(love.filesystem.getInfo('profiles/29/'..C.FILE),'profile-scoped selection has correct physical path')
   check(not love.filesystem.getInfo(C.FILE),'profile does not leak selection to shared root')
   local A=assert(C.provider());local img=assert(A.front(25));check(img:getWidth()==16 and img:getHeight()==32,'real PNG decoded from installed immutable object')
   local H=require('src.ui.WalkerMinigames');local again=H.new(nil,hub.st)
   check(not again.settingContent and not again.enrolling,'restart directly reuses the accepted installed pack')
   hub=again;phase='pack';frame=0
  end
 end
end
function love.draw()
 if phase=='capture'then return end
 hub:drawFull()
 if phase=='setup'and frame>=3 then
  local l=hub.contentLayout;check(l.descriptionBottom<=l.controlsTop,'setup description fits above controls')
  local w,h=love.graphics.getDimensions()
  for _,r in ipairs(hub.hits.list)do check(r.x>=0 and r.y>=0 and r.x+r.w<=w and r.y+r.h<=h,'setup control inside viewport')end
  capture('setup','chooseBasic')
 elseif phase=='review'and frame>=3 then capture('review','install')
 elseif phase=='basic'and hub.session then check(hub.session.phase=='play','actual game starts after content choice')
 elseif phase=='pack'then
  require('src.pokewalker.minigames.Gfx').portrait(25,30,40,100,'Fixture')
  if frame>=3 then capture('installed','finish')end
 elseif phase=='finish'then
  -- Actual imported-cache reader and byte-export path, using only our pixels.
  local C=require('src.pokewalker.minigames.Content');local Data=require('src.import.PackData')
  local current=assert(C.current());local entry=current.manifest.entries[1]
  local bytes=assert(Data.read(profile,C.ROOT..'/objects/'..entry.md5..'.png'))
  local prefix='fixture-import/'..require('src.core.GameVersion').cachePrefix('crystal')
  love.filesystem.createDirectory(prefix..'data/generated');love.filesystem.createDirectory(prefix..'assets/generated')
  love.filesystem.write(prefix..'assets/generated/shape.png',bytes)
  love.filesystem.write(prefix..'data/generated/pokemon.lua','return {[25]={dex=25,id=25,name="Independent fixture",spriteFront="assets/generated/shape.png"}}')
  love.filesystem.write(prefix..'data/generated/icons.lua','return {bySpecies={[25]={image="assets/generated/shape.png",frameHeight=16}}}')
  local Art=require('src.pokewalker.WalkerArt');Art._roots={love.filesystem.getSaveDirectory()..'/fixture-import'};Art.forget()
  local co=C.prepare('crystal');local prepared
  while coroutine.status(co)~='dead'do local ok,v=coroutine.resume(co);assert(ok,v);prepared=v end
  check(#prepared.manifest.entries==2,'real imported-cache reader prepares portrait and walking sheet')
  co=C.install(prepared,true)
  while coroutine.status(co)~='dead'do local ok,v=coroutine.resume(co);assert(ok,v)end
  check(C.current().digest==prepared.digest,'real local import publishes its exact reviewed snapshot')
  local provider=assert(C.provider());local walk,fw,fh=provider.walk(25)
  check(walk and fw==16 and fh==16,'real prepared animation frames remain usable')
  changeProfile('33')
  check(not C.current()and not provider.front(25),'profile change retires cached optional images')
  check(not C.basic(profile),'stale content UI cannot write after actual profile change')
  print('Actual content ZIP/PNG + profile filesystem + five-game basic smoke: '..checks..' checks passed')
  local f=assert(io.open(assert(os.getenv('WALKER_PREVIEW_CAPTURE')):gsub('%.png$','.passed'),'wb'));f:write('passed');f:close();love.event.quit(0)
 end
end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());return function()return 1 end end
