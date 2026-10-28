-- Isolated RS map/popup services. Runtime aliases are temporary read views.
local Loader=require('compat.gen1-rs.Loader')
local Assets=require('src.render.Assets')
local Font=require('src.render.Font')
local M={}
M.TYPES={TOWN=1,CITY=2,ROUTE=3,UNDERGROUND=4,UNDERWATER=5,OCEAN_ROUTE=6,UNKNOWN=7,INDOOR=8,SECRET_BASE=9}
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsMap
  return (v=='ruby' or v=='sapphire')and type(s)=='table'and s.version==v and s.format==1
end
function M.new(game)
  local self={game=game,manifests={},quads={}}
  local spec=assert(game.data.constants.gen3RsMap)
  local basic=Loader.new(spec.version)
  local C=require('compat.gen1-rs.Constants').new(basic);self.constants=C
  local function read(path)
    local chunk=assert(love.filesystem.load(path),'Missing native RS map '..path);setfenv(chunk,{});return chunk()
  end
  function self:manifest()
    if not self.man then
      self.man=read(spec.map);assert(self.man.game==spec.version and self.man.assetLayout=='rs','Mixed native RS map cache')
    end
    return self.man
  end
  local function image(path)assert(Assets.exists(path),'Missing native RS map image '..tostring(path));return Assets.image(path)end
  local colors={[0]={0,0,0,0}}
  for i,w in ipairs(assert(game.data.constants.gen3RsBag).palette)do
    if i>1 then
    colors[i-1]={w%32/31,math.floor(w/32)%32/31,math.floor(w/1024)%32/31,1}
    end
  end
  local normal={fg=colors[1],shadow=colors[8],bg=colors[0]}
  local function drawText(str,x,y,opts)
    opts=opts or {};local c=opts.colors or normal
    Font.pushStyle({text=c.fg,shadow=c.shadow})
    local ok,why=pcall(function()
      for line in (tostring(str or '')..'\n'):gmatch('(.-)\n')do
        local pen=0
        for _,code in ipairs(Font.encode(line))do
          local width=Font.advanceOf(code)
          if pen+width<=(opts.maxWidth or 240)then Font.drawCode(code,x+pen,y)end
          pen=pen+width
        end
        y=y+(opts.linePitch or 16)
      end
    end)
    Font.popStyle();if not ok then error(why,0)end
  end
  local function frame(style,tx,ty,tw,th,fill)
    local path='data/generated/gba/rse/bag_chrome/manifest.lua'
    self.frames=self.frames or read(path)
    assert(self.frames.game==spec.version)
    local index=math.max(0,math.min(19,math.floor(tonumber(style)or 0)))
    local img=image(self.frames.frames[index+1]);local q=self.quads
    if not q[0]then local w,h=img:getDimensions()
      for i=0,8 do q[i]=love.graphics.newQuad(i%3*8,math.floor(i/3)*8,8,8,w,h)end
    end
    love.graphics.setColor(1,1,1,1)
    for row=-1,th do for col=-1,tw do
      local tile
      if row==-1 then tile=col==-1 and 0 or col==tw and 2 or 1
      elseif row==th then tile=col==-1 and 6 or col==tw and 8 or 7
      elseif col==-1 then tile=3 elseif col==tw then tile=5 else tile=4 end
      if tile then love.graphics.draw(img,q[tile],(tx+col)*8,(ty+row)*8)end
    end end
    if fill then love.graphics.setColor(fill);love.graphics.rectangle('fill',tx*8,ty*8,tw*8,th*8)end
    love.graphics.setColor(1,1,1,1)
  end
  local function mapView(raw)
    if not raw then return nil end
    local out={};for k,v in pairs(raw)do out[k]=v end
    out.regionMapSectionId=raw.regionMapSectionId or raw.regionMapSection
    out.mapType=tonumber(raw.mapType)or M.TYPES[raw.mapType]or M.TYPES.UNKNOWN
    return out
  end
  self.mapView=mapView
  local maps=setmetatable({},{__index=function(_,id)return mapView(game.data.maps[id])end})
  local function mapId(group,num)return ('MAP_G%02d_N%02d'):format(group,num)end
  local function warp(raw)
    if type(raw)~='table'then return nil end
    local out={map=raw.map or raw.id,x=raw.x,y=raw.y,warpId=raw.warpId or raw.warp}
    local id=tonumber(out.warpId);local def=game.data.maps[out.map]
    local event=id and id>=0 and id<255 and def and (def.warps or {})[id+1]
    if event then out.x,out.y=event.x,event.y end
    return out
  end
  local flags=setmetatable({},{__index=function(_,id)
    local saved=game.save.flags or {};local v=saved[('FLAG_G3_%04X'):format(id)]
    if v==true or v==1 or saved[id]==true or saved[id]==1 then return true end
    if self.visitedFlags and self.visitedFlags[id]then return true end
    return false
  end})
  local session=setmetatable({flags=flags,vars=setmetatable({},{__index=function(_,id)return (game.save.gen3Vars or {})[id]or 0 end})},
    {__index=function(_,key)
      local ow=game.overworld
      if key=='map'then return ow and ow.map and ow.map.id or game.save.map end
      if key=='x'then return ow and ow.player and ow.player.cellX or 0 end
      if key=='y'then return ow and ow.player and ow.player.cellY or 0 end
      if key=='gender'or key=='playerGender'then
        local g=(game.save.player or {}).gender
        return (g=='girl'or g=='female'or g=='F'or g==1)and 'female'or 'male'
      end
      if key=='escapeWarp'then
        local def=ow and ow.map and ow.map.def
        local cave=def and (def.mapType=='UNDERGROUND'or def.mapType==4)
        return warp(game.save.gen3EscapeWarp or (cave and game.save.digWarp)or game.save.lastOutdoor or game.save.digWarp)
      end
      if key=='dynamicWarp'then return warp(game.save.gen3DynamicWarp)end
    end})
  self.session=session
  local loaded=setmetatable({
    ['src.core.game3.scripting.space']=false,['src.core.game3.scripting.flags']=false,
    ['src.core.game3.runtime']={_game={data={maps=maps}},getSession=function()return session end},
    ['src.core.game3.map']={currentDef=function()return maps[session.map]end},
    ['src.core.game3.player']=setmetatable({},{__index=function(_,key)return key=='cellX' and session.x or key=='cellY' and session.y or nil end}),
  },{__index=package.loaded})
  self.load=Loader.new(spec.version,{
    __package=setmetatable({loaded=loaded},{__index=package}),
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.profile']={forSession=function()return {id=spec.version}end},
    ['src.core.game3.field_moves']={MAP_TYPES=M.TYPES},
    ['src.core.game3.rse.init']={mapGroupNum=function(id)
      local d=game.data.maps[id];if d then return d.group,d.number end
    end,system=function()end},
    ['src.import.gba.map_catalog']={mapIdFor=mapId},
    ['src.core.game3.heal_locations']={get=function(index)return (game.data.constants.gen3HealLocations or {})[index]end},
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
    ['src.ui.game3.rse.mapsec']={entry=function(id)return self:manifest().sections[id]end,name=function(id)
      local e=self:manifest().sections[id];return e and require('src.core.Strings')(e.name)or ''
    end},
    ['src.core.game3.rom_text']={key=function(k,i)return k..':'..i end,has=function()return false end,
      plain=function(key)
        local alias={gText_Hoenn='gOtherText_Hoenn',gText_FlyToWhere='gOtherText_FlyToWhere'}
        local v=assert(spec.text[alias[key]or key],'Missing native RS map text '..key);return v
      end},
    ['src.ui.game3.frlg_font']={draw=drawText,measure=function(s)return Font.width(s)end,COLOR={NORMAL=normal}},
    ['src.ui.game3.chrome']={userFrame=frame,_frameType=math.max(0,(tonumber((game.save.options or {}).gen3Frame)or 1)-1)},
    ['src.core.game3.gba_fx']={active=function(fx)return fx and fx.y>0 end},
    ['src.ui.game3.rse.scene_kit']={loadLua=read,image=image,messageColors=function()return normal end,
      userFrame=function(tx,ty,tw,th,style,fill)return frame(style,tx,ty,tw,th,fill)end,
      playSe=function(id)require('src.core.Sound').play(game.data,id)end,
      drawFade=function(pal)
        local s=pal.slots[0];if s and s.y>0 then
          love.graphics.setColor(s.color[1]/31,s.color[2]/31,s.color[3]/31,s.y/16)
          love.graphics.rectangle('fill',0,0,240,160)
        end
      end},
  })
  return self
end
return M
