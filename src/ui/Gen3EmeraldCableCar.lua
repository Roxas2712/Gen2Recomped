-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald's own ride assets with the pinned GBA machine and shared lifecycle.
local Shared=require('src.ui.Gen3RsCableCar')
local M=setmetatable({screenId='Gen3EmeraldCableCar'},{__index=Shared});M.__index=M
function M.available(game)
 return require('src.import.Gen3EmeraldCableCarAssets').valid(game and game.data and game.data.constants
  and game.data.constants.gen3EmeraldCableCar,require('src.core.GameVersion').get())
end
function M.new(game,opts)
 assert(M.available(game));opts=opts or{}
 local self=setmetatable({game=game,opts=opts},M)
 local spec=game.data.constants.gen3EmeraldCableCar;local songs=game.data.constants.gen3EmeraldPresentation.songIds
 local music=require('src.core.Music');local sound=require('src.core.Sound')
 local sheets={};local load
 local audio={fadeOutBgm=music.fadeOutM4a}
 function audio.fadeInBgm(id,speed)
  music.stop();local source=music.play(game.data,('SONG_%03X'):format(id))
  music.dsFade(1,16*math.max(1,speed or 1),0);return source
 end
 function audio.playSe(id)return sound.playId(game.data,id)end
 local context=require('src.ui.Gen3EmeraldSceneContext').new(game,{bindings={
  ['src.core.game3.audio']=audio,
  ['src.core.game3.constants']={of=function(version)
   assert(version=='emerald');return{require=function(_,family,name)
    return assert((family=='songs'and songs or family=='event_objects'and spec.graphics or{})[name])
   end}
  end},
  ['src.ui.game3.rse.ow_sheet']={build=function(id)
   if not sheets[id]then
    local row=assert(spec.actors[id]);sheets[id]={sheet=load('src.ui.game3.rse.gba_machine').sheet(row),
     palette=row.palette,paletteTag=row.paletteTag,w=row.w,h=row.h}
   end
   return sheets[id]
  end},
 }})
 load=context.load;self.load,self.canvas=load,context.canvas
 self.scene=load('src.ui.game3.rse.cable_car').new({goingDown=opts.goingDown,
  female=(game.save.player or{}).gender=='girl',requireAssetLayout='emerald'})
 self.step=load('src.ui.game3.rse.scene_kit').stepper()
 return self
end
return M
