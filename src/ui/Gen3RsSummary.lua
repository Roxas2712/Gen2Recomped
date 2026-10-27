-- Isolated native RS summary state machine. Host Pokemon/move identities and
-- callbacks remain authoritative; only temporary presentation records use aliases.
local Loader=require('compat.gen1-rs.Loader')
local Assets=require('src.render.Assets')
local Font=require('src.render.Font')
local HostPokemon=require('src.pokemon.Pokemon')
local Growth=require('src.pokemon.Growth')
local Sound=require('src.core.Sound')
local M={};M.__index=M
local GROWTH={'MEDIUM_FAST','ERRATIC','FLUCTUATING','MEDIUM_SLOW','FAST','SLOW'}
local BALL_FOR_ITEM={[1]=4,[2]=3,[3]=1,[4]=0,[5]=2,[6]=5,[7]=6,[8]=7,[9]=8,[10]=9,[11]=10,[12]=11}

function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsSummary
  return (v=='ruby' or v=='sapphire') and type(s)=='table' and s.version==v and s.format==1
    and type(s.locations)=='table' and type(s.eggName)=='string' and type(s.natureNames)=='table' and #s.natureNames==25
end

local function readLua(path)
  local f=assert(love.filesystem.load(path),'Missing native RS summary '..path)
  setfenv(f,{});return f()
end
local function codes(str)
  local out,pos={},1
  str=tostring(str or '')
  while pos<=#str do
    local a,b=str:find('{LV}',pos,true)
    for _,code in ipairs(Font.encode(str:sub(pos,a and a-1 or #str)))do out[#out+1]=code end
    if not a then break end
    out[#out+1]=0x34;pos=b+1
  end
  return out
end
local function measure(str)
  local max=0
  for line in (tostring(str or '')..'\n'):gmatch('(.-)\n')do
    local w=0;for _,code in ipairs(codes(line))do w=w+Font.advanceOf(code)end
    max=math.max(max,w)
  end
  return max
end
local function drawText(str,x,y,opts)
  local colors=assert(opts.colors)
  Font.pushStyle({text=colors.fg,shadow=colors.shadow})
  local ok,why=pcall(function()
    for line in (tostring(str or '')..'\n'):gmatch('(.-)\n')do
      local pen=0
      for _,code in ipairs(codes(line))do
        local w=Font.advanceOf(code)
        if pen+w<=(opts.maxWidth or 240) or pen==0 then Font.drawCode(code,x+pen,y);pen=pen+w end
      end
      y=y+(opts.linePitch or 16)
    end
  end)
  Font.popStyle();if not ok then error(why,0)end
end
local function copy(t)local out={};for k,v in pairs(t or {})do out[k]=v end;return out end
local function stats(t)
  local out=copy(t)
  out.maxHp=out.maxHp or out.hp;out.spAtk=out.spAtk or out.spatk;out.spDef=out.spDef or out.spdef
  return out
end

function M.new(host,opts)
  opts=opts or {}
  local self=setmetatable({host=host,views=setmetatable({},{__mode='k'}),manifests={},quads={},pics={}},M)
  local game,data=host.game,host.game.data
  local spec=assert(data.constants.gen3RsSummary)
  local species,moves,abilities,items={},{},{},{}
  for id,def in pairs(data.pokemon or {})do if def.index then species[def.index]={id=id,def=def}end end
  for id,def in pairs(data.moves or {})do if def.index then moves[def.index]={id=id,def=def}end end
  for id,def in pairs(data.constants.abilities or {})do if def.index then abilities[def.index]={id=id,def=def}end end
  for id,def in pairs(data.items or {})do if def.index then items[def.index]={id=id,def=def}end end
  local function speciesRow(id)return assert(species[tonumber(id)],'Unknown native summary species '..tostring(id))end
  local function moveRow(id)return assert(moves[tonumber(id)],'Unknown native summary move '..tostring(id))end
  local function speciesId(mon)return assert(data.pokemon[mon.species]).index end
  local function moveId(id)return type(id)=='number' and id or id and assert(data.moves[id],'Unknown host move '..tostring(id)).index or 0 end
  local function abilityId(id)
    return type(id)=='number' and id or id and assert(data.constants.abilities[id],'Unknown host ability '..tostring(id)).index or 0
  end
  local function typeId(id)
    if type(id)=='number'then return id end
    return assert(data.type_chart.types[id],'Unknown host type '..tostring(id)).index
  end
  local function itemId(id)return tonumber(id) or id and data.items[id] and data.items[id].index or 0 end
  local function manifest(sub)
    if not self.manifests[sub]then
      local man=readLua('data/generated/gba/'..sub..'/manifest.lua')
      assert(man.layout=='rs' and man.game==spec.version,'Mixed native RS summary cache')
      self.manifests[sub]=man
    end
    return self.manifests[sub]
  end
  local function image(path)
    assert(Assets.exists(path),'Missing native RS summary image '..tostring(path))
    return Assets.image(path)
  end
  local function view(raw)
    if not raw then return nil end
    local v=self.views[raw]
    if not v then v={};self.views[raw]=v end
    for k in pairs(v)do v[k]=nil end
    for k,value in pairs(raw)do v[k]=value end
    local calculated=raw.stats
    if not calculated then
      local nature=raw.nature or data.constants.natureOrder[(raw.personality or 0)%25+1]
      calculated=require('src.pokemon.Stats').calc(data.pokemon[raw.species],raw.level or 1,raw.ivs,nil,raw.evs,nature)
    end
    v._host=raw;v.stats=stats(calculated);v.maxHp=raw.maxHp or raw.maxHP or v.stats.maxHp
    v.isEgg=raw.isEgg==true or raw.egg==true
    local gender=HostPokemon.genderOf(data,raw)
    v.gender=gender=='male' and 'M' or gender=='female' and 'F' or ''
    v.otName=raw.otName or raw.gen3OtName or raw.ot or raw.originalTrainer
    v.otSecretId=raw.otSecretId or raw.secretId
    v.markings=raw.markings or raw.gen3Markings
    v.pokerus=raw.pokerus or raw.gen3Pokerus
    v.language=raw.language or raw.gen3Language
    v.status=raw.status or raw.statusWord
    v.pokeball=raw.pokeball or raw.ball
    v.metGame=raw.metGame or raw.gen3MetGame
    v.friendship=raw.friendship or raw.happiness
    v.abilityNum=raw.abilityNum or raw.abilitySlot and raw.abilitySlot-1
    v.ppBonuses={}
    for i,slot in ipairs(raw.moves or {})do v.ppBonuses[i]=type(slot)=='table' and slot.ppUps or 0 end
    return v
  end
  self.view=view
  local function actual(v)return v and (v._host or v)end
  local function portrait(v)
    local raw=actual(v)
    if v.isEgg then return {image=image(assert(manifest('rse/summary_extras').egg))}end
    local path=require('src.pokemon.Sprites').path(data,raw.species,'front',{mon=v,kind='summary'})
    return path and {image=image(path)} or nil
  end
  local pokemon={
    speciesOf=speciesId,isEgg=function(v)return v.isEgg==true end,
    isShiny=function(v)return HostPokemon.isShiny(v)end,
    displayName=function(v)return v.isEgg and assert(spec.eggName) or v.nickname or data.pokemon[v.species].name end,
    name=function(id)return speciesRow(id).def.name end,national=function(id)return speciesRow(id).def.dex end,
    monFrontPic=portrait,
    types=function(id)local d=speciesRow(id).def;return {typeId(d.type1 or d.types[1]),typeId(d.type2 or d.types[2] or d.type1 or d.types[1])}end,
    abilities=function(id)local out={};for i,a in ipairs(speciesRow(id).def.abilities or {})do out[i]=abilityId(a)end;return out end,
    abilityId=function(id,pid)local a=speciesRow(id).def.abilities or {};return abilityId(a[(pid or 0)%2+1] or a[1])end,
    abilityName=function(id)return assert(abilities[id],'Unknown summary ability '..tostring(id)).def.name end,
    gender=function(id,pid)
      local row=speciesRow(id);local g=HostPokemon.genderOf(data,{species=row.id,personality=pid})
      return g=='male' and 'M' or g=='female' and 'F' or ''
    end,
    growthRate=function(id)
      local key=speciesRow(id).def.growthRate
      for i,name in ipairs(GROWTH)do if key==name then return i-1 end end
      error('Unknown RS growth '..tostring(key))
    end,
    calcStats=function(id,level,ivs,evs,pid)
      local nature=data.constants.natureOrder[(pid or 0)%25+1]
      return stats(require('src.pokemon.Stats').calc(speciesRow(id).def,level,ivs,nil,evs,nature))
    end,
    moveIdAt=function(v,i)local m=v.moves and v.moves[i];return moveId(type(m)=='table' and m.id or m)end,
    moveName=function(id)return moveRow(id).def.name end,movePp=function(id)return moveRow(id).def.pp end,
    battleMove=function(id)local d=copy(moveRow(id).def);d.type=typeId(d.type);return d end,
    isHmMove=function(id)
      for _,m in pairs(data.constants.machines or {})do if m.kind=='HM' and moveId(m.move)==id then return true end end
      return false
    end,
    swapMoves=function(v,a,b)
      local raw=actual(v);raw.moves[a],raw.moves[b]=raw.moves[b],raw.moves[a]
      v.ppBonuses[a],v.ppBonuses[b]=v.ppBonuses[b],v.ppBonuses[a]
    end,
  }
  local contestPack={moves={},effects={}}
  for number,row in pairs(moves)do
    local d=row.def
    local cat=({COOL=0,BEAUTY=1,CUTE=2,SMART=3,TOUGH=4})[d.contestCategory]
    if cat~=nil then
      contestPack.moves[number]={category=cat,effect=number}
      contestPack.effects[number]={appeal=d.contestAppeal or 0,jam=d.contestJam or 0,description=d.contestDescription or ''}
    end
  end
  local hoenn={toHoenn={}}
  for native,row in pairs(species)do hoenn.toHoenn[native]=(data.constants.gen3HoennDex.numbers or {})[row.id]end
  local session=copy(game.save)
  local player=game.save.player or {}
  session.version=spec.version;session.game=game
  session.playerName=player.name;session.trainerId=player.id
  session.options=copy(game.save.options);session.options.buttonMode=(session.options.gen3ButtonMode or 1)-1
  local audio={
    playCry=function(id)self.cry=Sound.playCry(data,speciesRow(id).id)end,
    stopCry=function()if self.cry then self.cry:stop();self.cry=nil end end,
  }
  local kit={manifest=manifest,image=image,
    rgb555=function(w)w=tonumber(w) or 0;return w%32/31,math.floor(w/32)%32/31,math.floor(w/1024)%32/31 end,
    playSe=function(name)Sound.play(data,name)end,
    loadLua=function(path)
      if path=='data/generated/gba/pokemon/hoenn.lua'then return hoenn end
      if path=='data/generated/gba/pokemon/contest_moves.lua'then return contestPack end
      error('Unexpected RS summary data '..tostring(path))
    end,
    drawFade=function(pal)
      local s=pal and pal.slots[0]
      if s and s.y>0 then
        love.graphics.setColor(s.color[1]/31,s.color[2]/31,s.color[3]/31,s.y/16)
        love.graphics.rectangle('fill',0,0,240,160);love.graphics.setColor(1,1,1,1)
      end
    end,
  }
  self.load=Loader.new(spec.version,{
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
    ['src.ui.game3.rse.scene_kit']=kit,
    ['src.ui.game3.frlg_font']={measure=measure,draw=drawText},
    ['src.core.game3.pokemon']=pokemon,
    ['src.core.game3.rom_text']={plain=function(key)
      -- assert returns all arguments in Lua 5.1. Return one string: an error
      -- message as a second value would become memo()'s optional color id.
      local value=assert(spec.text[key],'Missing native summary text '..key)
      return value
    end,
      at=function(key,i)assert(key=='gNatureNames');return assert(spec.natureNames[i+1])end},
    ['src.core.game3.audio']=audio,
    ['src.core.game3.gba_fx']={active=function(fx)return fx and (fx.y>0 or fx.gray or fx.base~=nil)end},
    ['src.import.CacheBlob']={readFs=function(path)return love.filesystem.read(path)end},
    ['src.core.Strings']=require('src.core.Strings'),
    ['src.core.GameVersion']=require('src.core.GameVersion'),
    ['src.core.game3.progression']={growthKey=function(id)return id end,growthCurve=function(id)
      return function(level)return Growth.expForLevel(assert(GROWTH[id+1]),level,data.growth_rates)end
    end},
    ['src.core.game3.dex']={nationalEnabled=function()return game.save.nationalDex==true end},
    ['src.core.game3.items_data']={toNumericId=itemId,displayName=function(id)return assert(items[id]).def.name end},
    ['src.core.game3.rse.ribbons']={count=function(v)return require('src.pokemon.Contest').ribbonCount(actual(v))end},
    ['src.core.game3.constants']={active=function()return {require=function(_,family,name)
      assert(family=='region_map_sections');return assert(self.load('src.core.game3.constants.ruby.region_map_sections').byName[name])
    end}end},
    ['src.ui.game3.rse.mapsec']={name=function(id)return spec.locations[id] or '' end},
    ['src.ui.LevelDisplay']={visible=function(v,where)return require('src.ui.LevelDisplay').visible(actual(v),where,game)end},
    ['src.core.game3.battle.ball_open']={ballIdForItem=function(item)return BALL_FOR_ITEM[itemId(item)] or 0 end},
    ['src.core.game3.battle.ui']={ballQuad=function(id)
      local path=assert(manifest('rse/summary_extras').balls[id+1]);local img=image(path)
      self.quads[path]=self.quads[path] or love.graphics.newQuad(0,0,16,16,img:getDimensions())
      return img,self.quads[path]
    end},
  })
  local summaryData=self.load('src.core.game3.summary_data')
  summaryData.abilityDescription=function(id)return assert(abilities[id]).def.description or '' end
  summaryData.moveDescription=function(id)return moveRow(id).def.description or '' end
  summaryData.contestEffectDescription=function(effect)return effect.description or '' end
  self.scene=self.load('src.ui.game3.rs.summary_menu')
  local party=host.party or {host.mon};self.party={}
  local lastSlot=0
  for index,raw in pairs(party)do
    if type(index)=='number' and raw then self.party[index]=view(raw);lastSlot=math.max(lastSlot,index)end
  end
  local nativeOpts={session=session,owner=session,bridge={},
    context=opts.context,disableMoveOrderEditing=opts.disableMoveOrderEditing,
    maxMonIndex=opts.maxMonIndex or (opts.context=='box' and lastSlot-1 or nil),
    onClose=function(index)
      self:sync()
      if not host.choose then host:close()end
    end,
    onSelectMove=host.choose and function(index)host:answer(index)end or nil,
  }
  if host.choose then nativeOpts.mode='select_move';nativeOpts.moveToLearn=moveId(host.choose.move);nativeOpts.forgetMove=host.choose.forgetMove end
  self.scene.openMenu(self.party,host.partyIndex or 1,nativeOpts)
  self:sync()
  return self
end

function M:sync()
  local s,h=self.scene,self.host
  local raw=self.party[s._cursor] and self.party[s._cursor]._host
  if raw and raw~=h.mon then
    h.mon=raw;h.partyIndex=s._cursor;h.def=h.game.data.pokemon[raw.species]
    if h.onMonChange then h.onMonChange(s._cursor,raw)end
  end
  h.page=s._page+1;h.moveIndex=s._selected+1
  h.moveSelect=s._state=='detail' or s._state=='swap'
  h.moveSwapFrom=s._state=='swap' and s._selected+1 or nil
end
function M:update()
  if self.closed then return end
  for _,v in pairs(self.party)do self.view(v._host)end
  self.scene.update()
  if self.closed then return end
  self.scene.handleInput(self.host.game.input)
  if not self.closed then self:sync()end
end
function M:draw()
  love.graphics.push('all')
  local ok,why=pcall(self.scene.draw)
  love.graphics.pop();if not ok then error(why,0)end
end
function M:exit()
  self.closed=true
  if self.cry then self.cry:stop();self.cry=nil end
  if self.scene then self.scene.reset()end
end
return M
