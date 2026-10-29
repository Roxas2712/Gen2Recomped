-- Contributions by Roxas2712. Engine interfaces, no third-party mod code.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');Version.set('crystal')
local Game=require('src.core.Game');local Stack=require('src.core.StateStack')
local Input=require('src.core.Input');local Tilt=require('src.render.Tilt')
local Pipelines=require('src.render.Pipelines')
Input:init()
local stack=setmetatable({}, {__index=Stack});stack:init()
local idle=true;local world={isOverworld=true,map={id='ELMS_LAB'},acceptsMenuInput=function()return idle end}
local writes=0
local game=setmetatable({stack=stack,overworld=world,save={options={}},writeOptions=function()writes=writes+1 end}, {__index=Game})
stack:setWorldOwner(game);stack:push(world)
local top,owner=game:pipelineGate()
T.eq(top,world,'empty native overlay stack exposes live field');T.eq(owner,world,'gate retains native world identity')
idle=false;top,owner=game:pipelineGate();T.eq(top,nil,'busy world denies pipeline toggle');T.eq(owner,world,'busy gate retains world identity')
idle=true;local menu={};stack:push(menu);top,owner=game:pipelineGate();T.eq(top,menu,'native menu remains top owner');T.eq(owner,world,'menu does not replace world');stack:pop()
local inner=Game.hotkey;local claims=0
Game.hotkey=function(self,key)
 local current,ow=self:pipelineGate()
 if key=='3'and current==ow and current and current:acceptsMenuInput()then claims=claims+1;return true end
 return inner(self,key)
end
Tilt.setLevel(0);game:keypressed('3')
T.eq(claims,1,'published source-shaped hotkey override receives normal key event')
T.eq(Tilt.level,0,'claimed voxel key never also cycles native tilt');T.eq(writes,0,'claimed key never writes unrelated native options')
Game.hotkey=inner;game:keypressed('3');T.check(Tilt.level>0,'unmodified native tilt fallback is retained');T.eq(writes,1,'native display change persists once')
T.eq(game:hotkey('up'),false,'ordinary game button not claimed');game:keypressed('up');T.eq(Input:isDown('up'),true,'ordinary native input still reaches input owner');game:keyreleased('up')
T.eq(Input:isDown('up'),false,'native release still works')
local sceneKeys=0;stack:push({onKeyPressed=function(_,key)sceneKeys=sceneKeys+1;T.eq(key,'3','screen receives same key')end})
game:keypressed('3');T.eq(sceneKeys,1,'direct screen keyboard ownership precedes display seam');T.eq(writes,1,'screen-owned key never changes display')
stack:pop();Tilt.setLevel(0)
T.finish('native display hotkey and persistent-world gate')
