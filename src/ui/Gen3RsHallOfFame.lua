-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Presentation-only reference context; induction, save and completion stay hosted.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true;M.screenId='Gen3RsHallOfFame'
function M.available(game)
  return require('src.import.Gen3RsHallAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsHall,require('src.core.GameVersion').get())
end
function M.new(game,onDone)
  assert(M.available(game))
  local data,save=game.data,game.save;local spec=data.constants.gen3RsHall
  local basic=require('compat.gen1-rs.Loader').new(require('src.core.GameVersion').get())
  local C=require('compat.gen1-rs.Constants').new(basic)
  C.trainer_classes=basic('src.core.game3.constants.ruby.trainer_classes')
  local byNumber={};for id,row in pairs(data.pokemon)do if row.index then byNumber[row.index]={id=id,def=row}end end
  local function row(n)return assert(byNumber[tonumber(n)],'Unknown native Hall of Fame species '..tostring(n))end
  local player=save.player or{}
  local secs=math.floor(require('src.core.SaveData').playSeconds(save))
  local session={version=require('src.core.GameVersion').get(),name=player.name or'',trainerId=player.id or 0,
    gender=(player.gender=='girl'or player.gender=='female'or player.gender==1 or player.female==true)and 1 or 0,
    playtime={hours=math.floor(secs/3600),minutes=math.floor(secs/60)%60,seconds=secs%60},party={}}
  for _,mon in ipairs(save.party or{})do
    local def=data.pokemon[mon.species]
    if def then session.party[#session.party+1]={species=def.index,level=mon.level,nickname=mon.nickname,
      name=def.name,personality=mon.personality or mon.pid or 0,otId=mon.otId or player.id or 0,
      otSecretId=mon.otSecretId or 0,_hostMon=mon}end
  end
  local self
  local bindings={
    ['src.import.gba.extract_island1']={CACHE_ROOT='data/generated/gba'},
    ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.pokedex_data']={isNationalUnlocked=function()return save.nationalDex==true end},
    ['src.core.game3.dex']={regionalNumber=function(n)
      local r=row(n);return(data.constants.gen3HoennDex.numbers or{})[r.id]
    end},
    ['src.core.game3.trainer_pic']={front=function(pic)
      local key=pic==C:require('trainer_classes','TRAINER_PIC_MAY')and'girl'or'boy'
      return{image=require('src.render.Assets').image(spec.trainerPics[key])}
    end},
    ['src.core.game3.pokemon']={national=function(n)return row(n).def.dex end,
      name=function(n)return row(n).def.name end,
      displayName=function(mon)return mon.nickname or mon.name or row(mon.species).def.name end,
      isEgg=function(mon)return mon._hostMon and(mon._hostMon.isEgg or mon._hostMon.egg)or false end,
      gender=function(n,pid)
        local gender=require('src.pokemon.Pokemon').genderOf(data,{species=row(n).id,personality=pid})
        return gender=='male'and'M'or gender=='female'and'F'or nil
      end,
      monFrontPic=function(mon)
        local r=row(mon.species);local path=require('src.pokemon.Sprites').path(data,r.id,'front',{mon=mon._hostMon})
        return path and{image=require('src.render.Assets').image(path)}or nil
      end},
  }
  self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,textIR=spec.textIR}),M)
  self.onDone,self.session=onDone,session
  local profile=self.load('src.core.game3.profile')
  profile.family=function()return'rse'end
  profile.of=function()return profile.forSession(session)end
  self.scene=self.load('src.ui.game3.hall_of_fame')
  -- The existing GameClear owner already records the induction and ribbons.
  -- Never run a second reference save/stat mutation through a numeric view.
  self.scene.start({session=session,dontSave=true,warp=false,credits=false,onDone=function()self:finish()end})
  return self
end
function M:finish()
  if self.closed then return end
  self.closed=true;local cb=self.onDone;self.onDone=nil
  assert(self.game.stack:top()==self,'Hall of Fame lost its host owner')
  self.game.stack:pop()
  local credits=require('src.ui.Gen3Credits').new(self.game,cb)
  if credits then self.game.stack:push(credits)elseif cb then cb()end
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update()
  if self.closed then return end
  self.scene.handleInput(self.game.input);self.scene.update()
  self.phase,self.index=self.scene.phase(),self.scene._currentIndex
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true
  if self.scene then self.scene.reset()end
  if self.load then self.load('src.ui.game3.hall_of_fame_gfx').reset();self.load('src.core.game3.gba_ppu').clearCache()end
  if self.canvas then self.canvas:release();self.canvas=nil end
end
return M
