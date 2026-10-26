-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
return function(mod,version,own,apply)
 local Runtime=require('src.mods.Runtime');local bus=Runtime.events
 local prefs=own('preferences.lua')(mod);local locales=own('locales.lua');local labels=own('session_locales.lua')
 local self={version=version,uiLanguage=prefs:read('preferences/ui-language.txt') or 'en',page='home',index=1,opened=false}
 if not locales[self.uiLanguage]then self.uiLanguage='en'end
 local function live()return Runtime.events==bus and Runtime.wants('ula.fork.session')end
 mod.events:on('ula.fork.session',function()end)
 function self:text(key)
  local startup=mod.exports.startup
  if startup and locales[startup.uiLanguage]then self.uiLanguage=startup.uiLanguage end
  return (labels[self.uiLanguage] or labels.en)[key] or labels.en[key] or key
 end
 function self:choices()
  local base,sources
  for _,row in ipairs(own('rom_requirements.lua'))do if row.game==version then base=row.base;sources=row.sources end end
  local out={{id='en',name=locales.en.native,available=true,supported=true,sha1=base and base.sha1,revision=base and base.version,rom=base and base.name}}
  for _,lang in ipairs({'de','pt-BR','es','fr','it','ja','ko','zh-Hans','zh-Hant'})do
   local row={id=lang,name=locales[lang].native,available=false,supported=false}
   for _,entry in ipairs(own('catalog.lua'))do if entry.game==version and entry.language==lang then
    row.supported=true;row.importId=entry.sourceId or entry.id;row.available=mod.imports:info(row.importId)~=nil
    for _,source in ipairs(sources or {})do if source.language==lang then row.sha1=source.sha1;row.revision=source.version;row.rom=source.name end end
   end end
   out[#out+1]=row
  end
  return out
 end
 function self:menuLanguage(id)
  if not locales[id]then return nil,'Unknown language'end
  prefs=own('preferences.lua')(mod)
  local ok,err=prefs:write('preferences/ui-language.txt',id)
  if ok then self.uiLanguage=id;if mod.exports.startup then mod.exports.startup.uiLanguage=id end end
  return ok,err
 end
 function self:canSwitch()
  local game=self.game;local top=game and game.stack and (game.stack:top()or game.stack.worldState)
  if top and top.screenId=='TitleState'then return true end
  if not top or not top.isOverworld or game.arena or game.unionPresence or game.linkSession
   or game.retroArena or game.linkNet and not game.linkNet.closed then return nil,self:text('busy')end
  local world=game.overworld
  if not world or world.transitioning or world.pendingWarp or world.player and (world.player.moving or world.player.jumping or world.player.inputLocked) then return nil,self:text('busy')end
  local script=world.script or world.runner
  if script and script.isRunning and script:isRunning()then return nil,self:text('busy')end
  if world.busy and world:busy()then return nil,self:text('busy')end
  return true
 end
 function self:close()
  self.opened=false;self.pending=nil;self.error=nil
  if self.game and self.game.input and self.game.input.reset then self.game.input:reset()end
 end
 function self:open(game)
  self.game=game or self.game
  if self.game.input and self.game.input.reset then self.game.input:reset()end
  self.opened=true;self.page='home';self.index=1;self.error=nil;return true
 end
 function self:request(id)
  local ok,why=self:canSwitch();if not ok then return nil,why end
  local found=false;for _,row in ipairs(self:choices())do if row.id==id and row.available then found=true end end
  if not found then return nil,self:text('needsRom')end
  self.pending=id;return true
 end
 function self:importBytes(bytes)
  local id,err=mod.imports:import(bytes,version)
  if not id then self.error=err;return nil,err end
  self.notice=self:text('imported')..' '..id;self.error=nil;return true
 end
 function self:pick()
  local path=require('src.import.RomImporter').chooseFileByExt({'gb','gbc','gba'},'language ROM')
  if not path then return end
  local file,err=io.open(path,'rb');if not file then self.error=err;return end
  local size=file:seek('end');file:seek('set',0)
  if not size or size>32*1024*1024 then file:close();self.error='Invalid language ROM size';return end
  local bytes=file:read('*a');file:close();return self:importBytes(bytes)
 end
 function self:update()
  if not self.pending then return end
  local id=self.pending;self.pending=nil
  local ok,why=apply(id,true)
  if ok then
   local top=self.game.stack:top()
   if top and top.screenId=='TitleState'then self.game.stack:pop();self.game.stack:push(self.game:makeTitleState())end
   self:close()
  else self.error=why end
 end
 own('session_menu.lua')(mod,self,own,live)
 -- The fork reuses one Game singleton. Keep a single set of callbacks and
 -- point it at the current service, instead of retaining old session trees
 -- every time the launcher opens another game.
 local Service=require('src.translation.Service')
 Service.__ulaUI=Service.__ulaUI or {games=setmetatable({},{__mode='k'})}
 local ui=Service.__ulaUI;ui.current=self;ui.live=live
 function self:attach(game)
  local state=ui.games[game]
  if state then return end
  state={};ui.games[game]=state
  local function active()return ui.current and ui.live() and ui.current.opened end
  local update,draw=game.update,game.draw
  game.update=function(g,dt,...)if active()then return ui.current:update(dt)end;return update(g,dt,...)end
  game.draw=function(g,...)if active()then return ui.current:draw()end;return draw(g,...)end
  -- This fork does not dispatch the upstream input.key/input.gamepad hooks.
  -- Intercept its Game callbacks before TitleState or Input consumes them.
  local press,release=game.keypressed,game.keyreleased
  game.keypressed=function(g,key,...)
   if ui.live()and key=='f8'then if active()then ui.current:close()else ui.current:open(g)end;return end
   if active()then return ui.current:key(key)end
   return press(g,key,...)
  end
  game.keyreleased=function(g,key,...)if active()then return end;if release then return release(g,key,...)end end
  local pad,padRelease,axis=game.gamepadpressed,game.gamepadreleased,game.gamepadaxis
  game.gamepadpressed=function(g,joystick,button,...)
   if active()then return ui.current:key(({dpup='up',dpdown='down',a='z',b='x',start='return'})[button]or button)end
   if pad then return pad(g,joystick,button,...)end
  end
  game.gamepadreleased=function(g,...)if active()then return end;if padRelease then return padRelease(g,...)end end
  game.gamepadaxis=function(g,...)if active()then return end;if axis then return axis(g,...)end end
  local click=game.mousepressed
  game.mousepressed=function(g,x,y,button,...)
   if active()then
    local s=ui.current
    if button==1 and not s.pending then
     local w,h=love.graphics.getDimensions();local scale=math.min(w/960,h/650)
     x=(x-(w-960*scale)/2)/scale;y=(y-(h-650*scale)/2)/scale
     for _,r in ipairs(s.hitboxes or {})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then
      if r.action then r.action()else s.index=r.index;s:key('return')end;break
     end end
    end
    return
   end
   if click then return click(g,x,y,button,...)end
  end
  local wheel=game.wheelmoved
  game.wheelmoved=function(g,dx,dy,...)if active()then return ui.current:key(dy>0 and 'up' or 'down')end;if wheel then return wheel(g,dx,dy,...)end end
  local touch=game.touchpressed
  game.touchpressed=function(g,id,x,y,...)if active()then return g:mousepressed(x,y,1)end;if touch then return touch(g,id,x,y,...)end end
  local pointer=game.hasPointerScreen
  game.hasPointerScreen=function(g,...)if active()then return true end;if pointer then return pointer(g,...)end;return false end
 end
 if not ui.dropped then
  ui.dropped=true;local original=love.filedropped
  love.filedropped=function(file)
   if ui.current and ui.live() and ui.current.opened then
    local ok,err=pcall(function()
     assert(file:open('r'));assert(file:getSize()<=32*1024*1024,'Invalid language ROM size')
     local bytes=assert(file:read());file:close();ui.current:importBytes(bytes)
    end)
    if not ok then pcall(file.close,file);ui.current.error=tostring(err)end
    return
   end
   if original then return original(file)end
  end
 end
 mod.hooks:wrap('input.key',function(nextFn,game,event)
  if live() and event.phase=='pressed' and event.key=='f8'then self:open(game);return end
  return nextFn(game,event)
 end,2100)
 return self
end
