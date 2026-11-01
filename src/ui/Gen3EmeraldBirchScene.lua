-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Emerald-specific rules over the pinned RSE scene's public TASKS interface.
-- The reused Gen1Recomp controller retains its GPLv3/Section7 licence and
-- BOIS CLUB GAMES, LLC credit under compat/gen1-rs/reference/LICENSE.MD.
local M={}
function M.new(context,spec,options)
  local load=context.load
  local Kit=load('src.ui.game3.rse.scene_kit')
  local Chrome=load('src.ui.game3.chrome')
  local Pal=load('src.core.game3.pal_fade')
  local Rng=load('src.core.game3.rng')
  local Audio=load('src.core.game3.audio')
  local Base=load('src.ui.game3.rs.birch_speech')
  local manifest=assert(Kit.loadLua(spec.manifest))
  assert(manifest.game=='emerald'and manifest.layout=='emerald'
    and manifest.pics.lotad.species==spec.lotadSpecies,'Wrong Emerald professor assets')
  local view={};for key,value in pairs(manifest)do view[key]=value end
  view.pics={};for key,value in pairs(manifest.pics)do view.pics[key]=value end
  -- The shared controller's internal slot is Azurill on RS. This private
  -- view supplies only Emerald's independently decoded Lotad resource.
  view.pics.azurill=manifest.pics.lotad
  local oldManifest=Kit.manifest
  Kit.manifest=function(name)return name=='birch'and view or oldManifest(name)end
  local textWindow=spec.windows.dialogue
  local frame,userFrame=Chrome.stdFrame,Chrome.userFrame
  Chrome.stdFrame=function(x,y,w,h,...)
    if x==3 and y==14 and w==24 and h==4 then
      return Chrome.dialogueFrame()
    end
    return frame(x,y,w,h,...)
  end
  Chrome.userFrame=function(x,y,w,h,...)
    if x==3 and y==5 and w==5 and h==4 then w=spec.windows.gender.width end
    return userFrame(x,y,w,h,...)
  end
  local rgbaImage=Kit.rgbaImage
  Kit.rgbaImage=function(path,...)
    if path=='data/generated/gba/chrome/fonts/down_arrow.rgba'then path=spec.arrow end
    return rgbaImage(path,...)
  end
  local printer=Kit.printer
  Kit.printer=function(...)
    local p=printer(...);local draw=p.draw
    p.draw=function(self,x,y,opts)
      if x==24 and y==112 then
        x,y=textWindow.left*8,textWindow.top*8
        local copy={};for key,value in pairs(opts or{})do copy[key]=value end
        copy.maxWidth=textWindow.width*8
        copy.clip={x,y,textWindow.width*8,textWindow.height*8};opts=copy
      end
      return draw(self,x,y,opts)
    end
    return p
  end
  local F=assert(Base.TASKS,'Pinned RSE controller has no public task adapter')
  -- Emerald starts its independent release task when the native printer
  -- reaches PAUSE, while the message printer continues on the main task.
  F.ThisIsAPokemon=function(self,m,input)
    if self.pal:fadeActive()or self:printersActive(input)then return end
    self.startedBallTask=false
    self:print('gBirchSpeech_ThisIsPokemon',function()
      if self.startedBallTask then return end
      self.startedBallTask=true
      local mon=self.sprites.azurill
      mon.x,mon.y,mon.invisible=100,75,false
      self:createReleaseBall(mon,112,58,32)
      self:event('ball_created')
      self:createTask(function(scene,task)
        task.data.clock=task.data.clock+1
        if task.data.clock==32 then
          Audio.playCry(scene.azurillSpecies,0,0);scene:event('azurill_cry')
        end
        if mon.callback=='dummy'then
          task.data.settled=task.data.settled+1
          if task.data.settled>=96 then task.alive=false end
        end
      end,{clock=0,settled=0})
    end)
    m.func='MainSpeech'
  end
  F.WaitForWhatsYourNameToPrint=function(self,m,input)
    if not self:printersActive(input)then m.func='EmeraldWaitPressBeforeName'end
  end
  F.EmeraldWaitPressBeforeName=function(self,m,input)
    if input.new.a or input.new.b then
      self.pal:beginFade(Pal.ALL,0,0,16,Pal.BLACK);m.func='StartNamingScreen'
    end
  end
  F.StartNamingScreen=function(self,m)
    if self.pal:fadeActive()then return end
    local names=self:presetNames()
    assert(#names==20,'Emerald requires its own20 default names')
    self.playerName=names[Rng.Random()%20+1]
    self.nameMenu,self.showDialogue,self.printer=nil,false,nil
    self:enterNaming();m.func='Naming'
  end
  F.CreateNameYesNo=function(self,m,input)
    if self:printersActive(input)then return end
    self.yesNo=Kit.yesNo(2,1,{frameType=self.frameType});m.func='ProcessNameYesNoMenu'
  end
  local reshow=F.ReshowBirchAzurill
  F.ReshowBirchAzurill=function(self,m)
    local ready=m.doneFading
    reshow(self,m)
    if ready then
      self.sprites.birch.x,self.sprites.birch.y=136,60
      self.sprites.azurill.x,self.sprites.azurill.y=100,75
    end
  end
  local returned=Base.returnFromNaming
  Base.returnFromNaming=function(self)
    returned(self)
    self.gradState=1;self.main.timer=5
    self.showDialogue=false;self.main.func='ReturnFromNamingScreenShowTextbox'
  end
  local event=Base.event
  Base.event=function(self,name)return event(self,(name:gsub('azurill','lotad')))end
  local scene=Base.new(options)
  scene.sprites.azurill.x,scene.sprites.azurill.y=100,75
  return scene
end
return M
