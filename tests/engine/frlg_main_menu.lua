package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');love.filesystem.load=loadfile
local T=require('tests.harness');local V=require('src.core.GameVersion');V.set('leafgreen')
local trace,style={},nil
local function record(kind,value)trace[kind]=trace[kind]or {};trace[kind][#trace[kind]+1]=value end
local F={encode=function(s)local r={};for i=1,#s do r[i]=s:byte(i)end;return r end,
 advanceOf=function()return 6 end,pushStyle=function(s)style=s end,popStyle=function()style=nil end,
 drawCode=function(c,x,y)record('text',{c,x,y,style and style.text,style and style.shadow})end,
 drawBox=function(...)record('frames',{...})end}
package.loaded['src.render.Font']=F
package.loaded['src.ui.Gen3Wide']={uiSize=function()return 240,160 end}
package.loaded['src.ui.Theme']={cursor=1}
package.loaded['src.core.Strings']=function(s)return s end
local extra
package.loaded['src.mods.Runtime']={call=function(_,_,_,items)return extra or items end}
local pushes={}
package.loaded['src.ui.Screens']={push=function(_,id,opts)pushes[#pushes+1]={id=id,opts=opts}end}
package.loaded['src.core.Sound']={play=function()end}
local saved,loads
package.loaded['src.core.SaveData']={saveFilename=function(v)return v..'.save'end,
 load=function(v)assert(v=='leafgreen');loads=loads+1;return saved end,
 playSeconds=function(s)return s.playTime or 0 end}
love.filesystem.getInfo=function()return saved and {}or nil end
local G=love.graphics;local color
G.setColor=function(...)local a={...};color=type(a[1])=='table'and a[1]or a end
G.rectangle=function(mode,x,y,w,h)if color[4]==7/16 then record('dim',{x,y,w,h})end end
local M=require('src.ui.Gen3FrlgMainMenu');local Menu=require('src.ui.Gen3MainMenu')
local game={data={constants={gen3StartMenu={pokedexFlag='FLAG_G3_0829'}},pokemon={
 BULBASAUR={index=1,dex=1},MEW={index=151,dex=151},TREECKO={index=277,dex=252},EGG={index=412,dex=0}}},
 save={options={gen3Frame=1}},input={keys={}},stack={pop=function()end}}
function game.input:wasPressed(k)return self.keys[k]end
local function make()loads=0;return Menu.new(game,{onNewGame=function()record('action',{'newGame'})end,
 onContinue=function()record('action',{'continue'})end,onCancel=function()record('action',{'cancel'})end})end
saved={player={name='LONGERNAME',gender='girl'},options={gen3Frame=7},flags={},playTime=3723,
 pokedex={owned={BULBASAUR=true,MEW=false,TREECKO=true,EGG=true},caught={BULBASAUR=true,MEW=0}}}
local s=M.snapshot(game,saved)
T.eq(s.hasDex,false,'save summary hides Pokedex before actual receipt flag')
T.eq(s.dexCount,1,'regional count excludes foreign, false, zero, duplicate and egg rows')
T.eq(s.time,'1:02','saved play-time clock supplies native hours/minutes')
T.eq(s.frame,7,'continue preview uses saved frame rather than new-session frame')
T.eq(s.girl,true,'saved gender selects native girl palette')
saved.flags.FLAG_G3_0829=true;T.eq(M.snapshot(game,saved).hasDex,true,'native receipt flag enables Pokedex summary')
saved.flags.FLAG_G3_0840=true;T.eq(M.snapshot(game,saved).dexCount,2,'national flag enables foreign species in count')
saved.modData={cartImport={dexOwned={1,151,252,0,387}}}
T.eq(M.snapshot(game,saved).dexCount,3,'native imported ownership merges without duplicate counts')
saved.flags.FLAG_G3_0840=nil
T.eq(M.snapshot(game,saved).dexCount,2,'regional imported ownership remains Kanto-bounded')
local menu=make();T.eq(loads,1,'menu takes one explicit-edition save snapshot before drawing')
T.eq(menu.items[1].key,'continue','continue remains the actual host action')
menu.frlgPalette:resetFade();menu.frlgFade=0;menu:draw();menu:draw();T.eq(loads,1,'drawing never loads or recovers a save')
T.eq(saved.player.name,'LONGERNAME','display truncation never rewrites saved custom name')
local wins=menu:frlgWindows()
T.eq(wins[1].th,10,'continue retains native ten-row content height')
T.eq(wins.step,16,'native sixteen-pixel stat pitch remains uncompressed')
T.eq(wins[2].ty,13,'new-game window stays at native row thirteen')
menu.index=4;wins=menu:frlgWindows();T.eq(wins.scroll,4,'fourth host row scrolls by native four tiles')
T.eq(wins[4].ty,17,'fourth selected row fits above screen edge')
menu.frlgScroll=4;menu.index=3;T.eq(menu:frlgWindows().scroll,4,'moving up preserves native scroll until continue')
menu.index=1;T.eq(menu:frlgWindows().scroll,0,'continue restores full native panel')
local function key(k,frames)
 game.input.keys=k and {[k]=true}or {};menu:update(1/60);game.input.keys={}
 for _=2,frames or 1 do menu:update(1/60)end
end
key('up');T.eq(menu.index,1,'UP clamps at top as original FRLG menu')
menu.index=#menu.items;key('down');T.eq(menu.index,#menu.items,'DOWN clamps at last host row')
menu.index=2;trace={};key('a');T.eq(trace.action,nil,'selection callback waits for native departure fade')
local fade=menu.frlgPalette;local steps=0
while fade:fadeActive()do fade:updateFade();steps=steps+1 end
menu:frlgBeginFade(true,'choose')
menu.index=3 -- external UI changes cannot redirect the pending native choice
key(nil,steps);T.eq(trace.action,nil,'callback does not run before native fade completion')
key(nil,1);T.eq(trace.action[1][1],'newGame','departure invokes original host new-game callback once')
local custom={key='custom',label='CUSTOM',onSelect=function()record('action',{'custom'})end}
extra={};for i=1,9 do extra[i]=i==9 and custom or {key='option',label='OPTION '..i}end
menu=make();menu.frlgPalette:resetFade();menu.frlgFade=0;menu.index=9;wins=menu:frlgWindows()
T.eq(wins[9].ty+wins[9].th+1,20,'extra mod rows stay selectable and fully visible')
trace={};key('a',30);T.eq(trace.action[1][1],'custom','custom row retains its own action and identity')
T.eq(extra[9],custom,'layout never substitutes the mod row object')
extra=nil;menu=make();menu.frlgPalette:resetFade();menu.frlgFade=0;menu.index=3
key('a',30);game.save.options.gen3Frame=4;pushes[#pushes].opts.onCancel()
T.eq(menu.frlgFrame,4,'return from actual options callback applies selected frame without a save reload')
T.eq(loads,1,'options return never reloads or recovers the save snapshot')
saved=nil;menu=make();T.eq(loads,0,'no-save menu does not probe save recovery')
T.eq(menu.items[1].key,'newGame','no-save menu begins with real new-game callback')
T.eq(menu:frlgWindows()[3].ty,9,'host option/exit extensions use full native pitch without compression')
menu.frlgPalette:resetFade();menu.frlgFade=0;trace={};key('b',30);T.eq(trace.action[1][1],'cancel','B returns through host title callback after fade')
-- Same controller/action boundary for other generations keeps original wrap.
V.set('sapphire');menu=make();menu.index=1;key('up');T.eq(menu.index,#menu.items,'RS host input policy remains unchanged')
T.finish('FRLG main-menu geometry, read-only summary and host callbacks')
