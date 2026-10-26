-- Run from the repository root with LuaJIT. No ROM assets or GPU required.
local function read(path)local f=assert(io.open(path));local s=f:read('*a');f:close();return s end
local source=read('src/battle/Gen3Battle.lua')
local function between(first,last)
 local a=assert(source:find(first,1,true));local z=assert(source:find(last,a+#first,true));return source:sub(a,z-1)
end
local frlg=true;local Version={isFRLG=function()return frlg end}
local G={WIDTH=240,HEIGHT=160,STRIP_TOP=14,STRIP_ROWS=6}
G.extra=function()return 0 end
local pass=function(x)return x end
local frames=between('local function frameOf(win, fallback)','-- THE ORDER THE FOUR CELLS SELECT IN.')
assert(loadstring('local Gen3Battle,GameVersion,spanBox,shiftBox,STRIP_FALLBACK=...\n'..frames))(G,Version,pass,pass,{textX=8,row1=120,row2=136})
local function window(left,top,width,height)return{left=left,top=top,width=width,height=height}end
local b={data={constants={gen3MessageWindow=window(1,15,28,4),gen3BattleWindows={
 message=window(1,15,28,4),prompt=window(1,15,14,4),action=window(17,15,12,4),
 moves={window(2,15,8,2),window(11,15,8,2),window(2,17,8,2),window(11,17,8,2)}}},moves={}}}
local w=G.windows(b);assert(w.prompt.textX==10 and w.action.textX==136)
for i,p in ipairs{{16,122},{88,122},{16,138},{88,138}}do assert(w.moves[i].textX==p[1]and w.moves[i].row1==p[2])end
assert(G.strip(b).textX==10 and G.strip(b).row1==122)
frlg=false;w=G.windows(b);assert(w.prompt.textX==8 and w.moves[1].row1==120,'Non-FRLG windows changed');frlg=true
-- Use the real Font.fit/face stack with distinct variable-width font records.
local assets={register=function()end}
package.loaded['src.render.Assets']=assets
package.preload['src.render.Assets']=function()return assets end
love={graphics={newQuad=function()return{}end}}
local Font=assert(loadfile('src/render/Font.lua'))()
local function widths(n)local t={};for i=0,255 do t[i]=n end;return t end
local defs={normal={image='normal',base=0,glyphWidth=8,glyphHeight=14,glyphsPerRow=16,widths=widths(7)},
 small={image='small',base=0,glyphWidth=8,glyphHeight=13,glyphsPerRow=16,widths=widths(4)}}
function assets.image(path)local p=assert(defs[path]);return{getDimensions=function()return 128,p.glyphHeight*16 end}end
local charmap={};for i=32,126 do charmap[#charmap+1]={seq=string.char(i),code=i}end
Font.load{font={pages={normal=defs.normal},faces={small=defs.small},charmap=charmap}}
local normalWidth=Font.width('BULLET SEED');assert(normalWidth>64 and Font.fit('BULLET SEED',64)~='BULLET SEED')
local draws,arrows={},{};local fault
Font.draw=function(text,x,y)if fault and text=='BULLET SEED'then error('injected glyph failure')end;draws[#draws+1]={text=text,x=x,y=y,width=Font.width(text)}end
Font.drawCode=function(code,x,y)arrows[#arrows+1]={code=code,x=x,y=y}end
local arrow=between('local function drawArrow(battle, x, y)','local function drawMessageBox')
local A=assert(loadstring('local Font,GameVersion,Gen3Battle,Assets,love,Theme=...\n'..arrow..'\nreturn drawArrow'))(Font,Version,G,{image=function()error('Opaque cursor image used')end},love,{cursor=47})
local shadowed=function(_,_,fn)return fn(0,0)end
local detailCode=between('local function drawMoveDetails(battle, move, panelDrawn)','local function drawMoveGrid')
local D=assert(loadstring('local Gen3Battle,Font,GameVersion,shadowed,TypeChart,fitName=...\n'..detailCode..'\nreturn drawMoveDetails'))(G,Font,Version,shadowed,{displayName=function()return'FIRE'end},Font.fit)
local gridCode=between('local function drawMoveGrid(battle, moves, selected)','local function drawMoveMenu')
local grid=assert(loadstring('local Gen3Battle,Font,GameVersion,drawPanel,shadowed,fitName,drawArrow,drawMoveDetails,love=...\n'..gridCode..'\nreturn drawMoveGrid'))(G,Font,Version,function()return true end,shadowed,Font.fit,A,D,love)
local moves={};for i,name in ipairs{'BULLET SEED','FLAMETHROWER','THUNDERBOLT','SELFDESTRUCT'}do b.data.moves[i]={name=name,pp=25,type='FIRE'};moves[i]={id=i,pp=25}end
for i=1,4 do draws={};arrows={};grid(b,moves,i)
 assert(draws[1].text=='BULLET SEED'and draws[1].width==44,'Move measured/drawn in the wrong face')
 assert(draws[1].x==16 and draws[1].y==122 and draws[2].x==88 and draws[3].y==138)
 assert(arrows[1].code==0xEF and arrows[1].x==(i%2==1 and 8 or 80)and arrows[1].y==(i<=2 and 122 or 138),'Wrong selector source or position')
 assert(draws[5].text=='PP'and draws[5].x==168 and draws[6].x==202,'PP printers merged/misaligned')
 assert(Font.width('BULLET SEED')==normalWidth,'Small face leaked')
end
fault=true;assert(not pcall(grid,b,moves,1));assert(Font.width('BULLET SEED')==normalWidth,'Glyph error leaked small face')
print('PASS_NATIVE_FRLG_BATTLE_UI_CONTRACT four move slots, real face-aware fitting, transparent selector source, printer offsets, PP columns, non-FRLG guard and error unwind; CPU only')
