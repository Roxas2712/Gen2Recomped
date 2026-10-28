-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original PC selection over immutable host history; no induction or save IO.
local Base=require('src.ui.Gen3RsHallOfFame')
local M=setmetatable({screenId='Gen3HallPc',isOpaque=true,holdsUIAnchors=true},{__index=Base});M.__index=M
function M.available(game)
 local v=require('src.core.GameVersion').get();local c=game and game.data and game.data.constants
 if not require('src.import.Gen3HallPcAssets').valid(c and c.gen3HallPc,v)then return false end
 local family=v=='emerald'and'Emerald'or(v=='ruby'or v=='sapphire')and'Rs'or'Frlg'
 return require('src.ui.Gen3'..family..'HallOfFame').available(game)
end
function M.new(game,onDone)
 if not M.available(game)then return end
 local version=require('src.core.GameVersion').get();local data,save=game.data,game.save
 local rs=version=='ruby'or version=='sapphire';local spec=data.constants.gen3HallPc
 local self=setmetatable({game=game,onDone=onDone,version=version},M)
 local History=require('src.core.Gen3HallHistory');local teams,why=History.nativeTeams(save,data)
 self.historyError=why
 local session={version=version,hallOfFameTeams=teams or{},gameStats={[10]=History.number(save)}}
 self.session=session
 local species={};for key,def in pairs(data.pokemon)do if def.index then species[def.index]={id=key,def=def}end end
 local function row(n)return assert(species[tonumber(n)],'Unknown native Hall PC species '..tostring(n))end
 local pokemon={name=function(n)return row(n).def.name end,national=function(n)return row(n).def.dex end,
  gender=function(n,pid)
   local g=require('src.pokemon.Pokemon').genderOf(data,{species=row(n).id,personality=pid})
   return g=='male'and'M'or g=='female'and'F'or nil
  end,monFrontPic=function(mon)
   if mon.species==412 then
    if not self.eggImage then
     if rs then
      local f=assert(love.filesystem.load(data.constants.gen3RsSummary.extras));setfenv(f,{})
      -- Assets owns this shared image; release only our canvas and shaders.
      return{image=require('src.render.Assets').image(assert(f().egg))}
     end
     local path=version=='emerald'and require('src.import.Gen3EmeraldHallAssets').ROOT..'egg.rgba'
      or'data/generated/gba/hall_of_fame/egg.rgba'
     local bytes=assert(love.filesystem.read(path));assert(#bytes==64*64*4)
     self.eggImage=love.graphics.newImage(love.image.newImageData(64,64,'rgba8',bytes));self.eggImage:setFilter('nearest','nearest')
    end
    return{image=self.eggImage}
   end
   local path=require('src.pokemon.Sprites').path(data,row(mon.species).id,'front',{mon=mon._hostMon,kind='hof'})
   return path and{image=require('src.render.Assets').image(path)}or nil
  end}
 local bindings={
  ['src.ui.game3.stack']={push=function(id)assert(id=='hall_of_fame_pc')end,pop=function(id)
   assert(id=='hall_of_fame_pc');self:finish()
  end},
  ['src.core.game3.pokemon']=pokemon,
  ['src.import.gba.extract_island1']={CACHE_ROOT='data/generated/gba'},
  ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
  ['src.core.game3.pokedex_data']={isNationalUnlocked=function()return save.nationalDex==true end},
  ['src.core.game3.dex']={regionalNumber=function(n)return(data.constants.gen3HoennDex.numbers or{})[row(n).id]end},
 }
 local text={}
 function text.ir(key)return assert(spec.textIR[key],'Missing native Hall PC label '..key)end
 function text.plain(key,ctx)return self.load('src.core.game3.scripting.text_ir').toAscii(text.ir(key),ctx)end
 bindings['src.core.game3.rom_text']=text
 bindings['src.ui.game3.pokedex_chrome']={drawControlInfo=function(str,right,y)
  local font=self.load('src.ui.game3.frlg_font');local opts={small=not rs}
  font.draw(str,(right or 236)-font.measure(str,opts),y or 146,
   {small=opts.small,colors={fg={1,1,1,1},shadow={98/255,98/255,98/255,1}}})
 end}
 if rs then
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,textIR=spec.textIR})
  self.load,self.canvas=context.load,context.canvas
  local profiles=self.load('src.core.game3.profile');profiles.family=function()return'rse'end
  profiles.of=function()return profiles.forSession(session)end
 elseif version=='emerald'then
  local root=require('src.import.Gen3EmeraldHallAssets').ROOT
  local ui={frames={manifest=data.constants.gen3EmeraldHall.manifest,userCount=20,user=root..'frame_%d.rgba',std='user',sign=false,
   dialogue={path=root..'message_box.rgba',layout='message_box',manifestKey='message_box'},dialogueWindow={left=2,top=15,width=26,height=4}}}
  local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings=bindings,textIR=spec.textIR,ui=ui})
  self.load,self.canvas=context.load,context.canvas
 else
  local common=require('src.ui.Gen3FrlgSceneBindings').new(game,session)
  for key,value in pairs(bindings)do common[key]=value end
  self.load=require('compat.gen1-rs.Loader').new(version,common)
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
 end
 self.load('src.core.game3.audio').stopCry=require('src.core.Sound').stopCry
 self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min((version=='firered'or version=='leafgreen')and 9 or 19,
  ((save.options or{}).gen3Frame or 1)-1)))
 self.scene=self.load('src.ui.game3.hall_of_fame_pc')
 if rs then self.scene.draw=function()self:drawRs()end end
 self.scene.show({session=session})
 return self
end
-- Ruby/Sapphire have no Emerald/FRLG hint bar. Their original PC prints at
-- tiles (0,0), (4,15), (9,15), (7,17), (13,17), and dims other mons pink.
-- Facts: pret/pokeruby f6e2a590, src/hall_of_fame.c: HallOfFame_PrintMonInfo.
function M:drawRs()
 local scene=self.scene;local g=love.graphics;local font=self.load('src.ui.game3.frlg_font')
 local gfx=self.load('src.ui.game3.hall_of_fame_gfx');gfx.drawStripes();gfx.drawBands(16,7)
 local text=self.load('src.core.game3.rom_text');local white={fg=font.STDPAL[1],shadow=font.STDPAL[2],bg=font.STDPAL[0]}
 if scene._corrupted then
  local window=self.load('src.ui.game3.window');window.stdFrame(window.template(3,15,24,4))
  font.draw(text.plain('gText_HOFCorrupted'),24,120,{colors=white});return
 end
 local team=scene._teams[scene._team];local positions=#team>3 and{{120,40},{56,40},{184,40},{120,88},{200,88},{40,88}}
  or{{120,64},{56,64},{184,64}}
 if not self.dimShader then self.dimShader=g.newShader([[
  vec4 effect(vec4 color, Image tex, vec2 uv, vec2 sc) {
   vec4 p=Texel(tex,uv);return vec4(mix(p.rgb,vec3(1.0,26.0/31.0,28.0/31.0),12.0/16.0),p.a)*color;
  }]])end
 local pokemon=self.load('src.core.game3.pokemon')
 for i,mon in ipairs(team)do
  local pic=pokemon.monFrontPic(mon);local p=positions[i]
  if pic and pic.image and p then
   g.setShader(i~=scene._mon and self.dimShader or nil);g.setColor(1,1,1,1);g.draw(pic.image,p[1]-32,p[2]-32);g.setShader()
  end
 end
 font.draw(text.plain('gText_HOFNumber')..tostring(scene._number),0,0,{colors=white})
 local mon=team[scene._mon];if not mon then return end
 local egg=mon.species==412
 if not egg then
  local n=scene._national and pokemon.national(mon.species)or self.load('src.core.game3.dex').regionalNumber(mon.species)
  font.draw(text.plain('gText_Number')..(n and('%03d'):format(n)or'???'),32,120,{colors=white})
 end
 font.draw(mon.nickname,72,120,{colors=white})
 if egg then return end
 local sex='';if mon.species~=29 and mon.species~=32 then
  local gender=pokemon.gender(mon.species,mon.personality);sex=gender=='M'and'♂'or gender=='F'and'♀'or''
 end
 font.draw('/'..pokemon.name(mon.species)..' '..sex,134,120,{colors=white})
 font.draw(text.plain('gText_Level')..tostring(mon.level),56,136,{colors=white})
 font.draw(text.plain('gText_IDNumber')..('%05d'):format((tonumber(mon.trainerId)or 0)%65536),104,136,{colors=white})
end
function M:finish()
 if self.closed then return end;self.closed=true
 assert(self.game.stack:top()==self,'Hall PC lost its stack owner')
 local cb=self.onDone;self.onDone=nil;self.game.stack:pop();if cb then cb()end
end
function M:update()
 if not self.closed then self.scene.handleInput(self.game.input)end
end
M.draw=require('src.ui.Gen3RsCredits').draw
function M:exit()
 self.closed=true;self.onDone=nil
 if self.scene then self.scene.reset()end
 require('src.core.Sound').stopCry()
 if self.load then self.load('src.ui.game3.hall_of_fame_gfx').reset();self.load('src.core.game3.gba_ppu').clearCache()end
 for _,key in ipairs{'canvas','eggImage','dimShader'}do if self[key]then self[key]:release();self[key]=nil end end
end
return M
