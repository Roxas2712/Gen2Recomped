-- FR/LG main-menu geometry/data view, verified against the pinned boot.lua.
-- Native reference provenance/license: compat/gen1-frlg/README.md.
-- The host retains OPTION/EXIT, mod rows and every action/save callback.
local Font=require('src.render.Font')
local M={}
M.BG={139/255,148/255,1,1}
M.INK={98/255,98/255,98/255,1}
M.SHADOW={213/255,213/255,205/255,1}
M.BOY={4/31,16/31,1,1};M.GIRL={1,3/31,21/31,1}

function M.snapshot(game,save)
  if type(save)~='table'then return nil end
  local data=game.data;local flags=save.flags or {}
  local constants=data.constants or {};local menu=constants.gen3StartMenu or {}
  local hasDex=flags[menu.pokedexFlag or 'FLAG_G3_0829']==true
  if not hasDex then hasDex=require('src.script.Flags').hasPokedex(save)end
  local national=save.nationalDex==true or flags.FLAG_G3_0840==true
  local maximum=national and 386 or 151
  local indices={};for _,def in pairs(data.pokemon or {})do if def.index then indices[def.index]=def end end
  local counted={};local count=0
  local function owned(n)
    n=tonumber(n)
    if n and n>=1 and n<=maximum and not counted[n]then counted[n]=true;count=count+1 end
  end
  local dex=save.pokedex or {}
  for _,key in ipairs({'owned','caught'})do
    for id,on in pairs(dex[key]or {})do
      if on and on~=0 then
        local def=(data.pokemon or {})[id]or indices[tonumber(id)]
        if def then owned(def.dex)end
      end
    end
  end
  local imported=save.modData and save.modData.cartImport
  for _,n in ipairs(imported and imported.dexOwned or {})do owned(n)end
  local seconds=math.floor(require('src.core.SaveData').playSeconds(save))
  local player=save.player or {}
  local frame=math.max(1,math.min(10,math.floor(tonumber((save.options or {}).gen3Frame)or 1)))
  return {name=player.name or '',girl=player.gender=='girl',hasDex=hasDex==true,
    dexCount=count,badges=require('src.inventory.Badges').count(data,save),
    time=('%d:%02d'):format(math.floor(seconds/3600),math.floor(seconds/60)%60),frame=frame}
end

function M.windows(items,index,scroll)
  local wins={step=16};local top=1
  for i,item in ipairs(items)do
    local h=item.key=='continue'and 10 or 2
    wins[i]={tx=3,ty=top,tw=24,th=h};top=top+h+2
  end
  scroll=math.max(0,math.floor(tonumber(scroll)or 0))
  local selected=wins[index]
  if selected then
    if items[index].key=='continue'or index==1 then scroll=0
    elseif selected.ty+selected.th+1-scroll>20 then scroll=selected.ty+selected.th+1-20
    elseif selected.ty-1-scroll<0 then scroll=selected.ty-1 end
  end
  wins.scroll=scroll
  for _,w in ipairs(wins)do w.ty=w.ty-scroll end
  return wins
end

local function text(value,x,y,ink,maxWidth,maxChars)
  Font.pushStyle({text=ink,shadow=M.SHADOW})
  local ok,why=pcall(function()
    local width=0
    for i,code in ipairs(Font.encode(tostring(value or '')))do
      if maxChars and i>maxChars then break end
      local w=Font.advanceOf(code)
      if width+w>(maxWidth or 192)then break end
      Font.drawCode(code,x+width,y);width=width+w
    end
  end)
  Font.popStyle();if not ok then error(why,0)end
end

function M.arrow(game)
  local spec=(game.data.constants or {}).gen3FRLGMainMenu
  if not spec then return nil end
  local Assets=require('src.render.Assets');local path=assert(spec.images.downArrow)
  assert(Assets.exists(path),'Missing native FR/LG main-menu arrow')
  return {image=Assets.image(path),bounce=spec.bounce}
end

function M.drawArrow(menu,cx,cy,t)
  local g=love.graphics;g.setColor(1,1,1,1)
  local art=menu.frlgArrow
  if art then
    local b=art.bounce;local pos=(math.floor(t)*b.frequency)%256
    local sine=math.sin(pos*math.pi*2/256)*256
    sine=sine<0 and math.ceil(sine-.5)or math.floor(sine+.5)
    local v=sine*b.multiplier/256;v=v<0 and math.ceil(v)or math.floor(v)
    g.draw(art.image,cx-8+(b.bounceDir~=1 and v or 0),cy-8+(b.bounceDir==1 and v or 0))
  else
    local dy=math.floor(math.sin((t%256)*math.pi*2/32)*2+.5)
    Font.pushStyle({text=M.INK,shadow=M.SHADOW})
    local ok,why=pcall(Font.drawCode,0x7A,cx-4,cy-4+dy)
    Font.popStyle();if not ok then error(why,0)end
  end
end

function M.draw(menu)
  local g=love.graphics;local width=select(1,menu:uiSize())
  local wins=M.windows(menu.items,menu.index,menu.frlgScroll)
  local saved=menu.frlgSummary
  g.setColor(M.BG);g.rectangle('fill',0,0,width,160)
  for i,item in ipairs(menu.items)do
    local w=wins[i];local x,y=w.tx*8,w.ty*8
    if y+w.th*8+8>0 and y-8<160 then
      Font.drawBox(w.tx-1,w.ty-1,w.tw+2,w.th+2,menu.frlgFrame or (saved and saved.frame)or 1)
      text(item.label,x+2,y+2,M.INK)
      if item.key=='continue'and saved then
        local rows=menu.frlgLabels;local ink=saved.girl and M.GIRL or M.BOY
        text(rows[1][1],x+2,y+18,ink);text(saved.name,x+62,y+18,ink,130,7)
        text(rows[4][1],x+2,y+34,ink);text(saved.time,x+62,y+34,ink)
        if saved.hasDex then
          text(rows[3][1],x+2,y+50,ink);text(saved.dexCount,x+62,y+50,ink)
        end
        text(rows[2][1],x+2,y+66,ink);text(saved.badges,x+62,y+66,ink)
      end
    end
  end
  local sel=wins[menu.index]
  if sel then
    local top=math.max(0,(sel.ty-1)*8+2);local bottom=math.min(160,(sel.ty+sel.th+1)*8-2)
    g.setColor(0,0,0,7/16)
    g.rectangle('fill',0,0,width,top);g.rectangle('fill',0,bottom,width,160-bottom)
    g.rectangle('fill',0,top,18,bottom-top);g.rectangle('fill',222,top,width-222,bottom-top)
  end
  if wins[#menu.items]and (wins[#menu.items].ty+wins[#menu.items].th+1)*8>160 then
    M.drawArrow(menu,width/2,152,menu.frlgTick or 0)
  end
  local fade=menu.frlgFade or 0
  if fade>0 then
    local c=menu.frlgLeaving and 0 or 1;g.setColor(c,c,c,fade/16);g.rectangle('fill',0,0,width,160)
  end
  g.setColor(1,1,1,1)
end
return M
