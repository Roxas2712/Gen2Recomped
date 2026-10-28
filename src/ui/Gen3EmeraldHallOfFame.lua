-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original Emerald ceremony, with induction and persistent IDs owned by host.
local Rs=require('src.ui.Gen3RsHallOfFame')
local M=setmetatable({screenId='Gen3EmeraldHallOfFame',isOpaque=true,holdsUIAnchors=true},{__index=Rs});M.__index=M
function M.available(game)
  return require('src.import.Gen3EmeraldHallAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3EmeraldHall,require('src.core.GameVersion').get())
end
function M.new(game,onDone)
  assert(M.available(game))
  local data,save=game.data,game.save;local spec=data.constants.gen3EmeraldHall
  local basic=require('compat.gen1-rs.Loader').new('emerald')
  local trainers=basic('src.core.game3.constants.emerald.trainer_classes').byName
  local flags=basic('src.core.game3.constants.emerald.flags').byName
  local byNumber={};for id,row in pairs(data.pokemon)do if row.index then byNumber[row.index]={id=id,def=row}end end
  local function row(n)return assert(byNumber[tonumber(n)],'Unknown native Emerald Hall species '..tostring(n))end
  local player=save.player or{};local seconds=math.floor(require('src.core.SaveData').playSeconds(save))
  local session={version='emerald',name=player.name or'',trainerId=player.id or 0,
    gender=(player.gender=='girl'or player.gender=='female'or player.gender==1 or player.female==true)and 1 or 0,
    playtime={hours=math.floor(seconds/3600),minutes=math.floor(seconds/60)%60,seconds=seconds%60},party={}}
  for _,mon in ipairs(save.party or{})do
    local def=data.pokemon[mon.species]
    if def then session.party[#session.party+1]={species=def.index,level=mon.level,nickname=mon.nickname,
      name=def.name,personality=mon.personality or mon.pid or 0,otId=mon.otId or player.id or 0,
      otSecretId=mon.otSecretId or 0,_hostMon=mon}end
  end
  local self
  local bindings={
    ['src.core.game3.scripting.flags']={forVersion=function()return{IDS={FLAG_SYS_GAME_CLEAR=assert(flags.FLAG_SYS_GAME_CLEAR)}}end},
    ['src.import.gba.extract_island1']={CACHE_ROOT='data/generated/gba'},
    ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
    ['src.core.game3.constants']={of=function()return{require=function(_,family,name)
      assert(family=='trainer_classes');return assert(trainers[name],'Missing original Emerald trainer '..name)
    end}end},
    ['src.core.game3.pokedex_data']={isNationalUnlocked=function()return save.nationalDex==true end},
    ['src.core.game3.dex']={regionalNumber=function(n)return(data.constants.gen3HoennDex.numbers or{})[row(n).id]end},
    ['src.core.game3.trainer_pic']={front=function(pic)
      assert(pic==trainers.TRAINER_PIC_MAY or pic==trainers.TRAINER_PIC_BRENDAN)
      local path=spec.trainerPics[pic==trainers.TRAINER_PIC_MAY and'girl'or'boy']
      return{image=require('src.render.Assets').image(assert(path,'Emerald trainer portrait missing'))}
    end},
    ['src.core.game3.pokemon']={national=function(n)return row(n).def.dex end,name=function(n)return row(n).def.name end,
      displayName=function(mon)return mon.nickname or mon.name or row(mon.species).def.name end,
      isEgg=function(mon)return mon._hostMon and(mon._hostMon.isEgg or mon._hostMon.egg)or false end,
      gender=function(n,pid)
        local gender=require('src.pokemon.Pokemon').genderOf(data,{species=row(n).id,personality=pid})
        return gender=='male'and'M'or gender=='female'and'F'or nil
      end,
      monFrontPic=function(mon)
        local raw=mon._hostMon;local path
        if raw and(raw.isEgg or raw.egg)then
          if not self.eggImage then
            local bytes=assert(love.filesystem.read(require('src.import.Gen3EmeraldHallAssets').ROOT..'egg.rgba'))
            assert(#bytes==64*64*4,'Emerald egg portrait missing')
            self.eggImage=love.graphics.newImage(love.image.newImageData(64,64,'rgba8',bytes));self.eggImage:setFilter('nearest','nearest')
          end
          return{image=self.eggImage}
        else path=require('src.pokemon.Sprites').path(data,row(mon.species).id,'front',{mon=raw,kind='hof'})end
        return path and{image=require('src.render.Assets').image(path)}or nil
      end},
  }
  local ui={frames={manifest=spec.manifest,userCount=20,user=require('src.import.Gen3EmeraldHallAssets').ROOT..'frame_%d.rgba',std='user',sign=false,
    dialogue={path=require('src.import.Gen3EmeraldHallAssets').ROOT..'message_box.rgba',layout='message_box',manifestKey='message_box'},
    dialogueWindow={left=2,top=15,width=27,height=4}}}
  self=setmetatable(require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings=bindings,textIR=spec.textIR,ui=ui}),M)
  self.onDone,self.session=onDone,session
  self.load('src.ui.game3.chrome').setFrameType(math.max(0,((save.options or{}).gen3Frame or 1)-1))
  self.scene=self.load('src.ui.game3.hall_of_fame')
  -- Only the private presentation session receives native stats/records.
  -- Emerald's atomic ending save/reset is a separate integration step.
  self.scene.start({session=session,dontSave=true,warp=false,credits=false,onDone=function()self:finish()end})
  return self
end
function M:exit()
  Rs.exit(self)
  if self.eggImage then self.eggImage:release();self.eggImage=nil end
end
return M
