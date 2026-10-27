-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- A real native stack modal. Original cartridge rows/art and the existing
-- ListMenu input controller share the game's update and resource lifetime.
local Font=require('src.render.Font')
local Text=require('src.core.game3.rom_text')
local Rich=require('src.render.Gen3HelpText')
local List=require('src.ui.ListMenu')
local Version=require('src.core.GameVersion')
local Native=require('src.compat.gen1.NativeSession')
local H={isOpaque=true};H.__index=H
function H:uiSize()return 240,160 end
function H:wantsFillScale()return true end
function H:wantsEdgeBleed()return false end
function H:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function H:valid()
 if self.closed or Native.game()~=self.game or Version.get()~=self.edition
  or self.game.data~=self.data or self.game.save~=self.save or self.game.stack~=self.stack
  or self.game.mods~=self.loader or self.data.constants.gen3Help~=self.facts then return false end
 if self.owner then
  local mod=self.loader and self.loader.mods and self.loader.mods[self.owner]
  if mod~=self.mod or not mod or mod.failed or mod.enabled==false then return false end
 end
 for _,state in ipairs(self.stack.states)do if state==self then return true end end
 return false
end
function H.new(game,context,owner)
 local facts=game.data and game.data.constants and game.data.constants.gen3Help
 if not(Version.isFRLG()and facts and facts.schema==1 and facts.edition==Version.get()
  and facts.romSha1==Version.info().sha1 and facts.keypad)then return nil,'native Help resources unavailable'end
 if type(context)~='number'or context%1~=0 or context<1 or context>34 then return nil,'native Help context unavailable'end
 local self=setmetatable({game=game,data=game.data,save=game.save,stack=game.stack,loader=game.mods,
  facts=facts,contextId=context,edition=Version.get(),owner=owner,resources={},level='main',layouts={}},H)
 self.mod=owner and self.loader and self.loader.mods and self.loader.mods[owner]
 if owner and(not self.mod or self.mod.enabled==false or self.mod.failed)then return nil,'native Help owner unavailable'end
 self:main();return self
end
function H:layout(key,width)
 local name=key..':'..width
 if not self.layouts[name]then self.layouts[name]=Rich.layout(Text.ir(key),width,self.facts.keypad)end
 return self.layouts[name]
end
function H:list(items)
 local self_=self
 self.menu=List.new(self.game,'',items,{kind='native_help',rows=7,keyRepeat=true,pageJump=true,noSound=true,
  onChoose=function(item)self_:choose(item)end})
 -- A borrowed controller must not pop its owning modal on B.
 self.menu.cancel=function()self_:back()end
end
function H:main()
 self.level='main';self.topic=nil
 local rows={}
 for _,i in ipairs(self.facts.topicOrder)do
  local topic=self.facts.topics[i]
  if self.facts.topicFlags[self.contextId][i]then rows[#rows+1]={label=Text.plain(topic.label),key=topic.label,topic=i}end
 end
 self:list(rows)
 self.menu.index=math.min(self.mainIndex or 1,#rows)
end
function H:choose(item)
 if self.level=='main'then
  if item.topic==6 then return self:close()end
  self.mainIndex=self.menu.index;self.topic=item.topic;self.level='questions'
  local rows={}
  for _,id in ipairs(self.facts.contexts[self.contextId][self.topic])do
   local entry=self.facts.entries[self.topic][id]
   rows[#rows+1]={label=Text.plain(entry.question),key=entry.question,id=id}
  end
  rows[#rows+1]={label=Text.plain(self.facts.cancel),key=self.facts.cancel,cancel=true}
  self:list(rows)
 elseif item.cancel then self:main()
 else
  self.level='answer';self.article=self.facts.entries[self.topic][item.id];self.articleScroll=0
 end
end
function H:back()
 if self.level=='main'then return self:close()end
 if self.level=='answer'then self.level='questions';self.article=nil else self:main()end
end
function H:close()if not self.closed then self.stack:removeAll({self})end end
function H:exit()
 if self.closed then return end;self.closed=true
 for _,resource in ipairs(self.resources)do resource:release()end
 self.resources={};self.layouts={}
 self.game,self.data,self.save,self.stack,self.loader,self.mod,self.facts,self.menu=nil,nil,nil,nil,nil,nil,nil,nil
 self.tiles,self.icons,self.palette,self.article=nil,nil,nil,nil
end
function H:update(dt)
 if not self:valid()then return self:close()end
 if (self.stack.active and self.stack:active()or self.stack:top())~=self then return end
 local input=self.game.input
 if input:wasPressed('l')or input:wasPressed('r')then return self:close()end
 if self.level=='answer'then
  if input:wasPressed('a')or input:wasPressed('b')then return self:back()end
  local lines=math.max(0,math.ceil(self:layout(self.article.answer,208).height/15)-6)
  if input:wasPressed('down')then self.articleScroll=math.min(lines,self.articleScroll+1)
  elseif input:wasPressed('up')then self.articleScroll=math.max(0,self.articleScroll-1)end
 elseif input:wasPressed('b')then return self:back()
 else self.menu:update(dt)end
end
function H:art()
 if self.tiles then return end
 local Rom=require('src.import.RomGba');local palette={}
 for i,value in ipairs(self.facts.frame.palette)do
  local r,g,b=Rom.bgr555(value);palette[i]={r/255,g/255,b/255,1}
 end
 self.palette=palette
 local function image(raw,start,width,height,columns,transparent)
  local data=love.image.newImageData(width,height)
  for y=0,height-1 do for x=0,width-1 do
   local tile=start+math.floor(y/8)*columns+math.floor(x/8)
   local value=assert(raw[tile*32+(y%8)*4+math.floor(x%8/2)+1],'native Help artwork truncated')
   local index=math.floor(value/(x%2==0 and 1 or 16))%16
   local c=assert(palette[index+1]);data:setPixel(x,y,c[1],c[2],c[3],transparent and index==0 and 0 or 1)
  end end
  local ok,result=pcall(love.graphics.newImage,data);data:release()
  if not ok then error(result,0)end
  self.resources[#self.resources+1]=result;result:setFilter('nearest','nearest');return result
 end
 local tiles,icons={},{}
 local ok,why=pcall(function()
  for i=0,8 do tiles[i+1]=image(self.facts.frame.tiles,i,8,8,1,false)end
  for i,region in ipairs(self.facts.keypad.regions)do
   icons[i]=image(self.facts.keypad.tiles,region.tile,region.width,region.height,16,true)
  end
 end)
 if not ok then
  for _,resource in ipairs(self.resources)do resource:release()end
  self.resources={};self.palette=nil;error(why,0)
 end
 self.tiles,self.icons=tiles,icons
end
function H:paint()
 self:art();local G=love.graphics;G.setColor(1,1,1,1)
 local function tile(id,x,y,w,h)G.draw(self.tiles[id+1],x,y,0,w/8,h/8)end
 -- help_system_util.c's original 0x1F7..0x1FF decoration tiles.
 tile(8,0,0,240,160);tile(2,0,0,8,160);tile(2,232,0,8,160)
 local answer=self.level=='answer'
 if answer then tile(3,8,24,224,136)end
 tile(answer and 4 or 0,8,16,224,8);tile(answer and 5 or 1,8,152,224,8)
 local function text(key,x,y,width,scroll)Rich.draw(self:layout(key,width),x,y,self.palette,self.icons,scroll)end
 text('gString_Help',14,1,58)
 local control=answer and'gText_HelpSystemControls_AorBtoCancel'
  or self.level=='main'and'gText_HelpSystemControls_PickOkEnd'or'gText_HelpSystemControls_PickOkCancel'
 text(control,80,1,152)
 G.setScissor(16,24,208,128)
 if answer then
  text(self.article.question,16,24,208);tile(5,8,40,224,8)
  G.setScissor(16,48,208,104);text(self.article.answer,16,48,208,self.articleScroll)
 else
  local top=self.level=='main'and 24 or 45
  if self.topic then text(self.facts.topics[self.topic].label,16,24,208)end
  for i=self.menu.scroll+1,math.min(#self.menu.items,self.menu.scroll+self.menu.rows)do
   local y=top+(i-self.menu.scroll-1)*15
   text(self.menu.items[i].key,24,y,200)
   if i==self.menu.index then Font.drawCode(256+3,16,y)end
  end
  if self.level=='main'then
   G.setScissor(16,120,208,32)
   text(self.facts.topics[self.menu.items[self.menu.index].topic].description,16,120,208)
  end
 end
end
function H:draw()
 if not self:valid()then return end
 local facade=require('src.ui.game3.help_system')
 return facade._nativeDraw(self,function()return self:paint()end)
end
return H
