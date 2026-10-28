-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Reference evolution choreography; persistent mutation and learning stay hosted.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3EvolutionState'
local versions={ruby=true,sapphire=true,emerald=true,firered=true,leafgreen=true}
local roles={gText_PkmnIsEvolving='evolving',gText_CongratsPkmnEvolved='congratulations',gText_PkmnStoppedEvolving='stopped'}
function M.available(game,mon,target)
 local v=require('src.core.GameVersion').get();local d=game and game.data;local c=d and d.constants
 local text=c and c.gen3Evolution;local rs=v=='ruby'or v=='sapphire'
 local panel=c and(rs and c.gen3RsBattlePanel or c.gen3BattleTextbox);local bg=c and c.gen3BattleTerrain
 if not(versions[v]and type(text)=='table'and type(panel)=='table'and type(panel.images)=='table'
  and type(panel.images.message)=='string'and type(bg)=='table'and type(bg.images)=='table'
  and bg.evolutionBackground==require('src.import.Gen3EvolutionBackground').PATH and(not rs or panel.version==v))then return false end
 for _,key in pairs(roles)do if type(text[key])~='string'or text[key]==''then return false end end
 return mon and d.pokemon[mon.species]and type(d.pokemon[mon.species].index)=='number'
  and d.pokemon[target]and type(d.pokemon[target].index)=='number'or false
end
function M.new(game,raw,target,onDone,via,evo)
 assert(M.available(game,raw,target));local version=require('src.core.GameVersion').get();local data=game.data
 local self={game=game,raw=raw,target=target,onDone=onDone,via=via,evo=evo,resources={}}
 local source=data.constants[version=='emerald'and'gen3EmeraldPresentation'or(version=='ruby'or version=='sapphire')and'gen3RsPresentation'or'gen3FrlgHall']
 local ids=assert(source and source.songIds);local songs={};local names={}
 for key,id in pairs(ids)do songs[key]=id;names[id]=key end
 function songs.nameOf(id)return names[id]end
 local species={};for key,def in pairs(data.pokemon)do if def.index then species[def.index]={id=key,def=def}end end
 local function row(n)return assert(species[tonumber(n)],'Unknown native evolution species '..tostring(n))end
 local mon={species=data.pokemon[raw.species].index,level=raw.level,nickname=raw.nickname,personality=raw.personality or raw.pid or 0}
 local session={version=version,options=require('src.core.Gen3RsOptionValues').read(game.save.options),party={mon}}
 local runtime={session=session,getSession=function()return session end}
 local audio={};local Music=require('src.core.Music');local Sound=require('src.core.Sound')
 local function number(id)return tonumber(id)or assert(ids[id],'Missing native evolution cue '..tostring(id))end
 function audio.playSong(id,opts)
  id=number(id);if id==0 then return Music.stop()end
  if opts and opts.restart then Music.stop()end
  return Music.play(data,('SONG_%03X'):format(id))
 end
 function audio.playSe(id)return Sound.playId(data,number(id))end
 function audio.playCry(n)return Sound.playCry(data,row(n).id)end
 audio.stopCry=Sound.stopCry;audio.isCryFinished=Sound.isCryFinished
 function audio.playFanfare(id)return Music.nativeFanfare(data,number(id))end
 local previous=Music.current();local hex=type(previous)=='string'and previous:match('^SONG_(%x+)$')
 local saved=hex and tonumber(hex,16)
 audio._mapSong=saved;audio._currentSong={id=saved}
 local text={has=function(key)return roles[key]~=nil end}
 function text.box(key,ctx)
  local template=assert(data.constants.gen3Evolution[assert(roles[key])]);local out={};local pos=1
  local IR=self.load('src.core.game3.scripting.text_ir')
  local function literal(s)for _,token in ipairs(IR.fromAscii(s))do if token.t~='eos'then out[#out+1]=token end end end
  while true do
   local a,b,n=template:find('{VAR([12])}',pos)
   if not a then literal(template:sub(pos));break end
   literal(template:sub(pos,a-1));out[#out+1]={t='text',s=tostring((ctx.stringVars or{})[tonumber(n)]or'')};pos=b+1
  end
  out[#out+1]={t='eos'};return out
 end
 local P=require('src.pokemon.Pokemon');local pokemon={}
 function pokemon.speciesOf(m)return m.species end
 function pokemon.speciesFromName(n)return tonumber(n)end
 function pokemon.name(n)return row(n).def.name end
 function pokemon.displayMonName(m)return m.nickname or row(m.species).def.name end
 function pokemon.picSpecies(n)return n end
 function pokemon.isShiny()return P.isShiny(raw)end
 function pokemon.frontPic(n)
  local path=require('src.pokemon.Sprites').path(data,row(n).id,'front',{mon=raw,kind='evolution'})
  return path and{image=require('src.render.Assets').image(path)}or nil
 end
 local monAnim=require('src.ui.Gen3EvolutionMonAnim').new(game,row,raw)
 local chrome={_installed=true}
 function chrome.drawCleanBg()
  love.graphics.setColor(1,1,1,1);love.graphics.draw(require('src.render.Assets').image(data.constants.gen3BattleTerrain.evolutionBackground),0,0)
 end
 function chrome.drawPanel()
  local rec=(version=='ruby'or version=='sapphire')and data.constants.gen3RsBattlePanel or data.constants.gen3BattleTextbox
  local frame=(game.save.options or{}).gen3Frame or 1
  local path=rec.frameImages and rec.frameImages[frame]and rec.frameImages[frame].message or rec.images.message
  love.graphics.setColor(1,1,1,1);love.graphics.draw(require('src.render.Assets').image(path),0,112)
 end
 local evolution={apply=function(_,n)
  assert(not self.applied and row(n).id==target,'Evolution attempted a second or foreign mutation')
  require('src.pokemon.Evolution').apply(game,raw,target,via,evo);self.applied=true
  mon.species=n;mon.nickname=raw.nickname
 end}
 local bindings={['src.core.game3.audio']=audio,['src.core.game3.song_ids']=songs,['src.core.game3.se_ids']=ids,
  ['src.core.game3.options']={textSpeed=function()return session.options.textSpeed end},
  ['src.core.game3.runtime']=runtime,['src.core.game3.pokemon']=pokemon,['src.core.game3.evolution']=evolution,
  ['src.core.game3.rom_text']=text,['src.ui.game3.battle_chrome']=chrome,['src.core.game3.mon_anim']=monAnim,
  ['src.core.game3.oam']={destroyAll=function()end},
  -- The host owns stable move IDs, Nincada's extra and all learn callbacks.
  ['src.core.game3.battle.learn_move']={movesForLevels=function()return{}end,busy=function()return false end,pump=function()end}}
 local graphics=setmetatable({},{__index=love.graphics})
 for _,key in ipairs{'newImage','newQuad','newShader','newCanvas'}do local create=love.graphics[key]
  graphics[key]=function(...)local object=create(...);self.resources[#self.resources+1]=object;return object end
 end
 local rng=love.math.newRandomGenerator(os.time())
 bindings.__globals={love=setmetatable({graphics=graphics},{__index=love}),
  math=setmetatable({random=function(...)return rng:random(...)end},{__index=math})}
 local opts={bindings=bindings,packageLoaded={['src.core.game3.runtime']=runtime}}
 local context
 if version=='ruby'or version=='sapphire'then context=require('src.ui.Gen3RsSceneContext').new(game,opts)
 elseif version=='emerald'then context=require('src.ui.Gen3EmeraldSceneContext').new(game,opts)
 else
  local common=require('src.ui.Gen3FrlgSceneBindings').new(game,session,runtime)
  for key,value in pairs(bindings)do common[key]=value end
  context={load=require('compat.gen1-rs.Loader').new(version,common),canvas=love.graphics.newCanvas(240,160,{dpiscale=1})}
  context.canvas:setFilter('nearest','nearest')
 end
 for key,value in pairs(context)do self[key]=value end
 self.monAnim=monAnim;self.scene=self.load('src.ui.game3.evolution_scene');self.mon=mon;self.session=session;self.savedSong=saved
 self.postSpecies=data.pokemon[target].index;setmetatable(self,M)
 return self
end
function M:enter()
 if self.began then return end;self.began=true
 assert(self.scene.start(self.mon,self.postSpecies,{canStop=self.via~='TRADE'and self.via~='ITEM',session=self.session,
  savedSong=self.savedSong,via=self.via,onDone=function(result)self:finish(result)end}))
end
function M:finish(result)
 if self.closed then return end
 assert(self.game.stack:top()==self,'Native evolution lost its stack owner')
 local cb=self.onDone;self.onDone=nil;self.closed=true;self.result=result;self.game.stack:pop()
 if result=='evolved'then require('src.pokemon.Evolution').learnEvolutionMoves(self.game,self.raw,cb)
 elseif cb then cb()end
end
function M:update()
 if self.closed then return end
 if not self.began then self:enter()end
 self.monAnim.step();self.scene.handleInput(self.game.input);self.scene.update(1/60)
end
M.uiSize=require('src.ui.Gen3RsCredits').uiSize
M.wantsFillScale=require('src.ui.Gen3RsCredits').wantsFillScale
M.wantsEdgeBleed=require('src.ui.Gen3RsCredits').wantsEdgeBleed
M.sgbPalettes=require('src.ui.Gen3RsCredits').sgbPalettes
M.draw=require('src.ui.Gen3RsCredits').draw
function M:exit()
 self.closed=true
 if self.scene then self.scene.open=false;self.scene._onDone=nil;if self.scene._monAnim then self.monAnim.stop(self.scene._monAnim)end end
 self.monAnim.close()
 for _,object in ipairs(self.resources)do pcall(object.release,object)end;self.resources={}
 if self.canvas then self.canvas:release();self.canvas=nil end
end
return M
