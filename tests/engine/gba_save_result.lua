-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Drive the real save callbacks; the writer explicitly returns each result.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local previous=V.get()
local Menu=require('src.ui.Gen3StartMenu');local Sound=require('src.core.Sound')
local originalBox=package.loaded['src.render.TextBox'];local originalPlay=Sound.play
local boxes,sounds
package.loaded['src.render.TextBox']={new=function(_,text,onDone,opts)
  return{text=text,onDone=onDone,opts=opts}
end}
Sound.play=function(_,name)sounds[#sounds+1]=name end
for _,edition in ipairs{'emerald','firered','leafgreen'}do
  V.set(edition)
  for _,result in ipairs{'false','nil','error','true','cancel'}do
    for _,existing in ipairs{'absent','empty','populated'}do
      boxes,sounds={},{}
      local writes=0
      local save={player={name='PROBE'},options={},inventory={KEEP=3}}
      if existing~='absent'then save.gen3Stats=existing=='empty'and{}or{[0]=7,[5]=41}end
      local before=require('src.core.SaveSerializer').encode(save)
      local game={save=save,data={constants={}},stack={push=function(_,box)boxes[#boxes+1]=box end}}
      game.writeSave=function()
        writes=writes+1
        if result=='error'then error('deliberate refused QA write')end
        if result=='nil'then return nil end
        return result=='true'
      end
      local owner=setmetatable({game=game,close=function(self)self.closed=true end},Menu)
      owner:startSave();T.eq(#boxes,1)
      boxes[1].opts.choice(result~='cancel')
      if result=='cancel'then
        T.eq(writes,0);T.eq(require('src.core.SaveSerializer').encode(save),before)
        T.eq(owner.savePanel,false)
      else
        T.eq(#boxes,2);T.eq(writes,0,'write waits for the saving message')
        boxes[2].onDone();T.eq(writes,1)
        local text=boxes[#boxes].text
        if result=='true'then
          T.check(text:find('saved the game',1,true));T.eq(sounds[1],'Save')
          T.eq(save.gen3Stats[0],existing=='populated'and 8 or 1)
          boxes[#boxes].onDone();T.eq(owner.closed,true)
        else
          T.check(text:find('Save failed',1,true),edition..' '..result..' must never claim success')
          T.eq(#sounds,0,edition..' refused write has no success fanfare')
          T.eq(owner.closed,nil,edition..' failure keeps the menu available')
          T.eq(owner.savePanel,false)
          T.eq(require('src.core.SaveSerializer').encode(save),before,
            edition..' '..result..' restores the saved-game counter and unrelated state')
        end
      end
    end
  end
end
package.loaded['src.render.TextBox']=originalBox;Sound.play=originalPlay;V.set(previous)
T.finish('generic GBA SAVE result, counter rollback, cancel and truthful acknowledgement')
