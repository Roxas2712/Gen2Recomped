-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original FR/LG controller/font/windows, over host-owned Pokémon identities.
local Base=require('src.ui.Gen3RsHallOfFame')
local M=setmetatable({screenId='Gen3FrlgHallOfFame',isOpaque=true,holdsUIAnchors=true},{__index=Base});M.__index=M
function M.available(game)
  return require('src.import.Gen3FrlgHallAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3FrlgHall,require('src.core.GameVersion').get())
end
function M.new(game,onDone,opts)
  assert(M.available(game))
  local data,save=game.data,game.save;local spec=data.constants.gen3FrlgHall;local version=spec.version
  local player=save.player or{};local seconds=math.floor(require('src.core.SaveData').playSeconds(save))
  local session={version=version,name=player.name or'',trainerId=player.id or 0,
    gender=(player.gender=='girl'or player.gender=='female'or player.gender==1 or player.female==true)and 1 or 0,
    playtime={hours=math.floor(seconds/3600),minutes=math.floor(seconds/60)%60,seconds=seconds%60},party={}}
  for _,mon in ipairs(save.party or{})do
    local def=data.pokemon[mon.species]
    if def then session.party[#session.party+1]={species=def.index,level=mon.level,nickname=mon.nickname,name=def.name,
      personality=mon.personality or mon.pid or 0,otId=mon.otId or player.id or 0,otSecretId=mon.otSecretId or 0,_hostMon=mon}end
  end
  local self;local saveEnding=opts and opts.saveEnding==true
  local runtime={session=session,_game={saveGame=function()return self:writeEnding()end}}
  local bindings,audio,row=require('src.ui.Gen3FrlgSceneBindings').new(game,session,runtime)
  local songs=spec.songIds
  -- The cart continues with a hardware backup-memory check. Host IO retries
  -- use its first sentence, within the original two-line saving window.
  local failureIR={spec.textIR.gText_SaveFailedCheckingBackup[1],{t='eos'}}
  local text={ir=function(key)
    if self and self.saveFailure and key=='gText_SavingDontTurnOffThePower2'then return failureIR end
    return assert(spec.textIR[key],'Missing original FR/LG Hall text '..key)
  end}
  function text.plain(key,ctx)return self.load('src.core.game3.scripting.text_ir').toAscii(text.ir(key),ctx)end
  local specific={
    ['src.core.game3.scripting.flags']={forVersion=function()return{IDS={FLAG_SYS_GAME_CLEAR=0x82c}}end},
    ['src.core.game3.rom_text']=text,
    ['src.core.game3.pokedex_data']={isNationalUnlocked=function()return save.nationalDex==true end},
    ['src.core.game3.dex']={regionalNumber=function(n)local dex=row(n).def.dex;return dex and dex<=151 and dex or nil end},
    ['src.core.game3.trainer_pic']={front=function(pic)
      assert(pic==135 or pic==136,'Foreign FR/LG Hall portrait')
      return{image=require('src.render.Assets').image(spec.trainerPics[pic==136 and'girl'or'boy'])}
    end},
    ['src.core.game3.pokemon']={national=function(n)return row(n).def.dex end,name=function(n)return row(n).def.name end,
      displayName=function(mon)return mon.nickname or mon.name or row(mon.species).def.name end,
      isEgg=function(mon)return mon._hostMon and(mon._hostMon.isEgg or mon._hostMon.egg)or false end,
      gender=function(n,pid)
        local raw={species=row(n).id,personality=pid}
        for _,mon in ipairs(session.party)do if mon.species==n and mon.personality==pid then raw=mon._hostMon;break end end
        local sex=require('src.pokemon.Pokemon').genderOf(data,raw);return sex=='male'and'M'or sex=='female'and'F'or nil
      end,
      monFrontPic=function(mon)
        local raw=mon._hostMon
        if raw and(raw.isEgg or raw.egg)then
          if not self.eggImage then
            local bytes=assert(love.filesystem.read('data/generated/gba/hall_of_fame/egg.rgba'));assert(#bytes==64*64*4)
            self.eggImage=love.graphics.newImage(love.image.newImageData(64,64,'rgba8',bytes));self.eggImage:setFilter('nearest','nearest')
          end
          return{image=self.eggImage}
        end
        local path=require('src.pokemon.Sprites').path(data,row(mon.species).id,'front',{mon=raw,kind='hof'})
        return path and{image=require('src.render.Assets').image(path)}or nil
      end},
  }
  for key,value in pairs(specific)do bindings[key]=value end
  self=setmetatable({game=game,version=version,session=session,onDone=onDone,
    saveEnding=saveEnding,endingResult={nativeFrlgSaved=true},saveSound=assert(songs.SE_SAVE)},M)
  local playSe=audio.playSe
  audio.playSe=function(id,...)
    if saveEnding and id==self.saveSound and not self.saved then return end
    return playSe(id,...)
  end
  self.load=require('compat.gen1-rs.Loader').new(version,bindings)
  self.load('src.core.game3.rng').SeedRng(os.time()%65536)
  self.load('src.ui.game3.chrome').setFrameType(math.max(0,math.min(9,((save.options or{}).gen3Frame or 1)-1)))
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
  self.scene=self.load('src.ui.game3.hall_of_fame')
  self.scene.start({session=session,dontSave=not saveEnding,warp=false,credits=false,onDone=function()self:finish()end})
  return self
end
function M:writeEnding()
  assert(self.saveEnding and self.savingDrawn,'League saving must render before IO')
  if self.saved then return true end
  require('src.core.Gen3HallHistory').recordScene(self)
  self.saved,self.saveError=require('src.core.Gen3FrlgEndingSave').write(self.game)
  self.saveFailure=not self.saved
  return self.saved
end
function M:exit()
  Base.exit(self)
  if self.eggImage then self.eggImage:release();self.eggImage=nil end
end
return M
