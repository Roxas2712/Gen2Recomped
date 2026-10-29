-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Independent native list presenter; inventory and callbacks stay with the host.
local M={};M.__index=M
local FRAME={ITEM=1,KEY_ITEM=2,BALL=3,TM_HM=4,BERRY=5}
function M.available(owner)
 return not owner.pcList and require('src.core.GameVersion').get()=='emerald'
  and require('src.import.Gen3EmeraldBagAssets').valid(owner.game.data.constants.gen3EmeraldBag,'emerald')
end
function M.new(owner)
 assert(M.available(owner));local self=setmetatable({owner=owner,game=owner.game,images={},quads={}},M)
 local spec=owner.game.data.constants.gen3EmeraldBag
 local raw=assert(require('src.import.CacheFs').read(spec.manifest));local f=assert(loadstring(raw));setfenv(f,{})
 self.manifest=f();assert(self.manifest.game=='emerald'and self.manifest.format==1)
 local root=require('src.import.Gen3EmeraldHallAssets').ROOT
 local ui={frames={manifest=owner.game.data.constants.gen3EmeraldHall.manifest,userCount=20,
  user=root..'frame_%d.rgba',std='user',sign=false,
  dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},
  dialogueWindow={left=2,top=15,width=26,height=4}}}
 local context=require('src.ui.Gen3EmeraldSceneContext').new(owner.game,{ui=ui,bindings={
  ['src.ui.game3.rse.scene_kit']={manifest=function(sub)assert(sub=='rse/bag');return self.manifest end,
   image=function(path)return self:image(path)end}}})
 self.load,self.canvas=context.load,context.canvas
 self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(19,
  ((owner.game.save.options or{}).gen3Frame or 1)-1)))
 return self
end
function M:image(path)
 if not self.images[path]then self.images[path]=require('src.render.Assets').image(path)end
 return self.images[path]
end
function M:quad(path,x,y,w,h,sw,sh)
 local key=path..':'..x..':'..y..':'..w..':'..h
 if not self.quads[key]then self.quads[key]=love.graphics.newQuad(x,y,w,h,sw,sh)end
 return self.quads[key]
end
function M:text(key,vars)
 return self.load('src.core.game3.scripting.text_ir').toAscii(assert(self.manifest.textIR[key]),{stringVars=vars or{}})
end
function M:drawArrow(direction,x,y,tick)
 local spec=assert(self.load('src.ui.game3.rse.bag_chrome').ARROWS[direction])
 local dx,dy=self.load('src.ui.game3.list_menu').bounce(spec.bounce,tick)
 local entry=self.manifest.sprites.arrows;local image=self:image(entry.png)
 local w,h=image:getDimensions()
 local quad=self:quad(entry.png,0,spec.frame*entry.h,entry.w,entry.h,w,h)
 love.graphics.setColor(1,1,1,1)
 love.graphics.draw(image,quad,x+dx,y+dy,0,spec.flipX and -1 or 1,spec.flipY and -1 or 1,entry.w/2,entry.h/2)
end
-- Keep the original horizontal-column controls in numbered TM/berry names.
function M:numbered(key,a,b)
 local out={};local vars={a,b}
 for _,node in ipairs(assert(self.manifest.textIR[key]))do
  if node.t=='text'then out[#out+1]=node.s
  elseif node.t=='strvar'then out[#out+1]=vars[node.n]or''
  elseif node.t=='ext'and(node.cmd==0x11 or node.cmd==0x13)then
   out[#out+1]=string.char(0xFC,node.cmd,node.args and node.args[1]or 0)
  end
 end
 return table.concat(out)
end
function M:label(row,pocket)
 if row.close then return self:text('close')end
 local def=self.game.data.items[row.id]or{}
 if row.label and def.name and row.label~=def.name then return row.label end
 local machine=def.machine
 if pocket=='TM_HM'and machine then
  local move=self.game.data.moves[machine.move];local label=move and move.name or row.label
  local n=tonumber(machine.number)or 0;local hm=machine.kind=='HM'
  return self:numbered(hm and'hmNumber'or'number',hm and tostring(n)or('%02d'):format(n),label),hm
 elseif pocket=='BERRY'and type(def.index)=='number'and def.index>=133 and def.index<=175 then
  return self:numbered('number',('%02d'):format(def.index-132),row.label)
 end
 return row.label or def.name or row.id
end
function M:drawMoveInfo(row)
 local def=row and self.game.data.items[row.id];local machine=def and def.machine
 local move=machine and self.game.data.moves[machine.move];local info=self.manifest.moveInfo
 if not(move and info)then return false end
 local image=self:image(info.image);local sw,sh=image:getDimensions()
 local function icon(id,x,y)
  local r=assert(info.rects[id+1]);love.graphics.setColor(1,1,1,1)
  love.graphics.draw(image,self:quad(info.image,r.x,r.y,r.w,r.h,sw,sh),x,y)
 end
 for i=0,3 do icon(19+i,8,104+i*12)end
 local typeId
 for i,id in ipairs(self.game.data.constants.typeOrder or{})do if id==move.type then typeId=i;break end end
 if typeId then icon(typeId,56,104)end
 local K=self.load('src.import.gba.rse.boot_gfx')
 local function color(i)local r,g,b=K.rgb8(info.palette[i+1]);return{r/255,g/255,b/255,1}end
 local style={colors={fg=color(14),shadow=color(10),bg={0,0,0,0}}}
 local font=self.load('src.ui.game3.frlg_font')
 local power,accuracy=tonumber(move.power)or 0,tonumber(move.accuracy)or 0
 font.draw(power<=1 and'---'or('%3d'):format(power),63,116,style)
 font.draw(accuracy==0 and'---'or('%3d'):format(accuracy),63,128,style)
 font.draw(('%3d'):format(tonumber(move.pp)or 0),63,140,style)
 return true
end
function M:drawActions(menu)
 local cols,n=menu.columns,#menu.entries;local rows=math.ceil(n/cols)
 local x,y,w,h
 if cols==1 then x,w,h=22,7,n*2;y=19-h
 else x,y,w,h=15,rows<=2 and 15 or 13,14,rows<=2 and 4 or 6 end
 local window=self.load('src.ui.game3.window');local font=self.load('src.ui.game3.frlg_font')
 window.stdFrame(window.template(x,y,w,h))
 for i,entry in ipairs(menu.entries)do
  if menu:pickable(i)then
   local px=x*8+8+(i-1)%cols*56;local py=y*8+1+math.floor((i-1)/cols)*16
   font.draw(entry.label,px,py,{font='narrow',colors=font.COLOR.NORMAL})
   if i==menu.index then window.cursorPx(px-8,py)end
  end
 end
end
function M:drawNative(action)
 local owner,man=self.owner,self.manifest;local g=love.graphics
 local font=self.load('src.ui.game3.frlg_font');local K=self.load('src.import.gba.rse.boot_gfx')
 local female=(self.game.save.player or{}).gender=='girl'
 local palette=man.palettes[female and'female'or'male']
 local function color(index)local r,gg,b=K.rgb8(palette[index+1]);return{r/255,gg/255,b/255,1}end
 local normal={fg=color(17),shadow=color(19),bg={0,0,0,0}}
 local narrow={font='narrow',colors=normal}
 local bg=female and man.background.variants.female or man.background.png
 g.setColor(1,1,1,1);g.draw(self:image(bg),0,0)
 local ind=man.indicator;local path=female and ind.variants.female or ind.png;local image=self:image(path)
 local iw,ih=image:getDimensions()
 for i=1,#owner.pockets do
  g.draw(image,self:quad(path,i==owner.pocket and 8 or 0,0,8,8,iw,ih),(i-1+5)*8,24)
 end
 local pocket=owner.pockets[owner.pocket];local label=pocket.name or''
 font.draw(label,32+math.floor((64-font.measure(label))/2),9,
  {colors={fg=color(17),shadow=color(20),bg={0,0,0,0}}})
 local bag=man.sprites[female and'female'or'male'];path=bag.png;image=self:image(path);iw,ih=image:getDimensions()
 g.setColor(1,1,1,1);g.draw(image,self:quad(path,0,(FRAME[pocket.key]or 1)*64,64,64,iw,ih),36,34)
 local selected=self.game.stack:top()~=owner
 for i=0,7 do
  local row=owner.rows[owner.top+i];if not row then break end
  local y=17+i*16
  if owner.top+i==owner.index then
   font.drawGlyph(font.CHAR_SELECTOR_ARROW,112,y,{colors=selected
    and{fg=color(19),shadow=color(22),bg={0,0,0,0}}or normal})
  end
  local text,hm=self:label(row,pocket.key)
  if hm then g.setColor(1,1,1,1);g.draw(self:image(require('src.import.Gen3EmeraldBagAssets').ROOT..'hm.png'),120,y-1)end
  font.draw(text,120,y,narrow)
  if not row.close then
   if pocket.key=='BERRY'or(pocket.key~='KEY_ITEM'and not row.important)then
    local digits=pocket.key=='BERRY'and 3 or 2
    local count=self:text('count',{string.format('%'..digits..'d',row.qty or 1)})
    font.draw(count,231-font.measure(count,{font='narrow'}),y,narrow)
   elseif row.id==self.game.save.registeredItem then
    g.setColor(1,1,1,1);g.draw(self:image(require('src.import.Gen3EmeraldBagAssets').ROOT..'select.png'),208,y-1)
   end
  end
 end
 local row=owner:selected();local count=(self.game.data.constants.gen3ItemIcons or{}).count
 local icon,quad=owner:itemIcon(row and row.id or nil,row and row.close and count and count-1 or nil)
 if icon then g.setColor(1,1,1,1);g.draw(icon,quad,8,72)end
 local desc=owner.message or(row and row.description)
 if action and row and not row.close then desc=self:text('selected',{row.label})end
 if row and row.close and not desc then
  local loc=owner.battle and 1 or owner.sell and 3 or owner.store=='deposit'and 6 or 0
  local destination=self.load('src.core.game3.scripting.text_ir').toAscii(assert(man.returnToIR[loc]))
  desc=self:text('returnTo',{destination})
 end
 if not(action and pocket.key=='TM_HM'and self:drawMoveInfo(row))and desc then
  font.draw(desc,3,105,{colors=normal,maxWidth=109})
 end
 if action then self:drawActions(action)end
 if not selected then
  local tick=owner.tick or 0
  if not owner.lockPocket then self:drawArrow('left',28,16,tick);self:drawArrow('right',100,16,tick)end
  if owner.top>1 then self:drawArrow('up',172,12,tick)end
  if owner.top+7<#owner.rows then self:drawArrow('down',172,148,tick)end
 end
end
function M:draw(action)
 local g=love.graphics;local ok,why=require('src.render.GraphicsScope').call(function()
  g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0);self:drawNative(action)
 end)
 if not ok then error(why,0)end
 g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
 if self.canvas then self.canvas:release();self.canvas=nil end
 for _,quad in pairs(self.quads)do quad:release()end
 self.quads,self.images,self.load={},nil,nil
end
return M
