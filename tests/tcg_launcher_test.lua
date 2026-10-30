-- Launcher ownership/lifetime regression; no cartridge or player save needed.
local notices,opened,closed,forwarded=0,0,0,0
package.loaded['src.import.LauncherBackdrop']={stop=function()end}
package.loaded['src.tcg.Player']={new=function()
 opened=opened+1
 return {update=function(self)self.updates=(self.updates or 0)+1 end,
  close=function()closed=closed+1;return true end,keypressed=function(self,k)if k=='escape'then self.done=true end end}
end}
local M=require('src.import.LauncherTCG')
M.session=function()return {schema=1,ready=true}end
local RI={_ui={}}
RI.new=function()return setmetatable({ready={},tab='gold',section='games'}, {__index=RI})end
for _,name in ipairs{'_sbOpenGame','_sbGames','_sbDrawContent','_sbOwns','play','keypressed','mousepressed','gamepadpressed','_sbMousepressed','update','draw','_sbBack','_sbGo','leave','quit'}do
 RI[name]=function()forwarded=forwarded+1;return 'original'end
end
RI._beginRomScan=function(self,paths)self.scanned=paths;return true end
RI.startPath=function()return 'standard'end
M.install(RI)
local ui=RI.new()
ui:_sbOpenGame('tcggbc');ui:_sbOpenGame('tcggbc')
assert(ui.tab=='tcggbc'and ui.browseConsole=='gbc')
ui:play();ui:play();assert(opened==1,'Repeated play must keep one native owner')
local before=forwarded;ui:mousepressed(1,2,1);ui:gamepadpressed({},'a');assert(forwarded==before,'Guest inputs must not activate the launcher')
ui:update(.02);assert(ui._tcgPlayer.updates==1)
ui:keypressed('escape');ui:update(.02);assert(not ui._tcgPlayer and closed==1)
assert(ui:_sbBack());assert(ui.tab=='gold'and not ui._tcgOldTab)
ui:_sbOpenGame('red');assert(not ui._tcgOpen)
before=forwarded;ui:keypressed('return');assert(forwarded==before+1,'Other games retain their key handler')
ui:_sbOpenGame('tcggbc');ui:play();ui:leave();ui:quit();assert(opened==2 and closed==2,'Leaving and quitting close each guest once')
print('TCG launcher ownership, input isolation and cleanup: PASS')

package.loaded['src.import.LauncherPokemonXY']={versions=function()return{}end,info=function()end}
local external=require('src.import.LauncherExternalGames')
assert(external.info('tcggbc').generation==2 and external.info('tcggbc').external)
assert(external.versions('gbc','pokemon')[1]=='tcggbc')
assert(#external.versions('gb','pokemon')==0 and #external.versions('gbc','hacks')==0)
print('TCG library grouping and external metadata: PASS')

local originalOpen=io.open
io.open=function(path,...)
 if path=='tcg.gbc'then return{seek=function()end,read=function()return'POKECARD'end,close=function()end}end
 return originalOpen(path,...)
end
local picker=RI.new();assert(picker:startPath('red.gb')=='standard');assert(picker:startPath('tcg.gbc')and picker._tcgQueued=='tcg.gbc')
picker._tcgQueued=nil;assert(picker:_beginRomScan({'red.gb','tcg.gbc'}));assert(#picker.scanned==1 and picker.scanned[1]=='red.gb'and picker._tcgQueued=='tcg.gbc')
assert(picker:_beginRomScan({'tcg.gbc'}));assert(picker._tcgQueued=='tcg.gbc')
io.open=originalOpen
print('TCG direct and mixed-batch import routing: PASS')
