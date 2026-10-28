-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local before=Version.get()
local Font=require('src.render.Font')
local Menu=require('src.ui.OptionsMenu');local Stack=require('src.core.StateStack')
local Save=require('src.core.SaveData')
local function session(edition,frames)
  Version.set(edition)
  local g={data=T.fixtures.fresh(),save=Save.newGame(),writes=0,input={pressed={}}}
  if frames then g.data.font.imageFrames='frames';g.data.font.frameCount=8 end
  g.stack=setmetatable({},{__index=Stack});g.stack:init()
  g.input.wasPressed=function(self,key)return self.pressed[key]==true end
  g.writeOptions=function(self)self.writes=self.writes+1;self.persisted=Save.encode(self.save)end
  return g
end
local function press(g,key)
  g.input.pressed={[key]=true};g.stack:top():update(1/60);g.input.pressed={}
end
for _,edition in ipairs{'gold','silver','crystal'}do
  local g=session(edition,true);local m=Menu.new(g);g.stack:push(m)
  local p=m:focusRow('frame')
  T.check(p and p~=m,edition..' FRAME opens native GRAPHICS group')
  if p then
    T.eq(p:row().id,'frame')
    press(g,'left');T.eq(g.save.options.frame,8);T.eq(Font.frameIndex(),8,'normal input updates renderer immediately')
    press(g,'right');T.eq(g.save.options.frame,1);T.eq(Font.frameIndex(),1)
    for i=2,8 do press(g,'right');T.eq(g.save.options.frame,i);T.eq(Font.frameIndex(),i)end
    T.eq(g.writes,9,'one native write per real change')
    local saved=assert(Save.decode(g.persisted))
    T.eq(saved.options.frame,8,'normal persistence retains chosen frame')
    -- A boot applies the saved value before the optional font is loaded.
    Font.setFrame(1)
    local Game=require('src.core.Game')
    Game.applyOptions(g,saved.options)
    T.eq(Font.frameIndex(),8,'actual Game option application restores frame')
    press(g,'b');T.eq(g.stack:top(),m,'BACK restores original option page')
  end
end
for _,edition in ipairs{'red','emerald','crystal'}do
  local g=session(edition,false);local m=Menu.new(g)
  for _,r in ipairs(m.rows)do T.check(r.id~='frame',edition..' does not offer an unavailable GSC sheet')end
end
Version.set(before);Font.setFrame(1)
T.finish('GSC FRAME normal input, immediate selection, native save codec and option restoration')
