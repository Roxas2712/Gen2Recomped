-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
return function(game)
 local U=require('tests.drivers.util');local Json=require('src.link.Json')
 local Runtime=require('src.mods.Runtime');local Palette=require('src.render.PaletteFX')
 local Theme=require('src.ui.Theme');local Choice=require('src.ui.ChoiceBox')
 local out=assert(os.getenv('CHOICE_QA_OUT'))
 game.save=require("src.core.SaveData").newGame()
 game.save.options.colors='gbc';game.save.options.tilt=0;game.save.options.gbcfx=0
 game.save.options.zoom=0;game.save.options.performance='high';game.save.options.textSpeed=1
 game:applyOptions()
 local _,_,flags=love.window.getMode();flags.highdpi=false;flags.vsync=0;flags.resizable=false
 assert(love.window.setMode(640,576,flags));U.wait(5)
 while game.stack:top()do game.stack:pop()end
 local backdrop={isOpaque=true,shaderPresetBypass=true}
 function backdrop:draw()love.graphics.setColor(1,1,1,1);love.graphics.rectangle('fill',0,0,160,144)end
 function backdrop:sgbPalettes(g)return Palette.wholeNamed(g.data,'MEWMON')end
 game.stack:push(backdrop)
 if not Runtime.hooks or not Runtime.hooks.wrap then Runtime.install(Runtime.events,require('src.mods.Hooks').new(),Runtime.errors)end
 local captured,viewport
 Runtime.hooks:wrap('render.output_enabled',function()return true end,10000,'choice_qa')
 Runtime.hooks:wrap('render.output',function(_,ctx)
  captured=ctx.canvas;viewport={x=ctx.gameX,y=ctx.gameY,width=ctx.gameWidth,height=ctx.gameHeight,scale=ctx.scale,dpiX=ctx.dpiX,dpiY=ctx.dpiY}
  return false
 end,10000,'choice_qa')
 local function write(name,bytes)local f=assert(io.open(out..'/'..name,'wb'));f:write(bytes);f:close()end
 local report={passed=false,edition='red',language='English',realImportedContent=true,syntheticBackdrop=true,
  source=assert(os.getenv('CHOICE_QA_SOURCE')),playerProfilesUsed=false,frames={},events={}}
 local optionsBefore=Json.encode(game.save.options)
 local function add(opts)
  local box=Choice.new(game,function(yes)report.events[#report.events+1]=yes end,opts)
  game.stack:push(box);return box
 end
 local function capture(name,box)
  U.wait(2);captured=nil;local saveBefore=Json.encode(game.save)
  love.graphics.push('all');love.graphics.setCanvas();game:draw();love.graphics.pop()
  assert(captured,'actual final renderer did not publish a Canvas')
  assert(Json.encode(game.save)==saveBefore,'drawing mutated the save')
  local data=captured:newImageData();local w,h=data:getDimensions()
  write(name..'.rgba',data:getString());write(name..'.png',data:encode('png'):getString());data:release()
  report.frames[name]={width=w,height=h,viewport=viewport,selection=box.index,
   box={tx=box.tx,ty=box.ty,tw=box.tw,th=box.th},drawSaveUnchanged=true}
 end
 local box=add();capture('yes',box)
 U.tap(game,'down');assert(box.index==2,'native Down did not select NO');capture('no',box)
 U.tap(game,'a');U.wait(20)
 assert(#report.events==1 and report.events[1]==false and game.stack:top()==backdrop,'NO did not return exactly once')
 add();U.tap(game,'b');U.wait(20)
 assert(#report.events==2 and report.events[2]==false and game.stack:top()==backdrop,'B did not cancel exactly once')
 add();U.tap(game,'a');U.wait(20)
 assert(#report.events==3 and report.events[3]==true and game.stack:top()==backdrop,'YES did not return exactly once')
 assert(Json.encode(game.save.options)==optionsBefore,'choice input rewrote saved options')
 report.passed=true;report.inputReturnPaths=true;report.drawSaveUnchanged=true
 write('report.json',Json.encode(report));love.event.quit(0)
end
