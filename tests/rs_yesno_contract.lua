love=require('tests.love_stub');love.filesystem.load=loadfile
local n=0
local function eq(a,b,why)n=n+1;assert(a==b,(why or'')..': '..tostring(a)..' != '..tostring(b))end
local draws={}
local window={template=function(l,t,w,h)return{l,t,w,h}end,
 stdFrame=function(r)draws.frame=r end,userFrame=function(r)draws.frame=r end,
 printPx=function(label,x,y)draws[#draws+1]={label,x,y}end}
local choice=require('compat.gen1-rs.Loader').new('ruby',{
 ['src.ui.game3.window']=window,['src.core.game3.display']={COLS=30},
 ['src.core.game3.rom_text']={plain=function(k)return k=='gText_Yes'and'YES'or'NO'end},
 ['src.core.game3.se_ids']={SE_SELECT=5},['src.core.game3.audio']={playSe=function()end},
 ['src.core.game3.runtime']={getSession=function()return{options={frameType=3}}end},
 ['src.ui.game3.battle_chrome']={layout=function()return'rs'end},
 ['src.ui.game3.rs.menu_cursor']={draw=function(x,y,w)draws.cursor={x,y,w}end},
})('src.ui.game3.choice')
choice.fieldLayout=function()return'rs'end
local count,result=0
choice.yesNo(function(v)count=count+1;result=v end)
eq(choice.left,20);eq(choice.top,8);eq(choice.cursor,1)
choice.draw();eq(draws.frame[1],21);eq(draws.frame[2],9);eq(draws.frame[3],5);eq(draws.frame[4],4)
eq(draws[1][1],'YES');eq(draws[2][1],'NO');eq(draws[1][2],168);eq(draws[1][3],72)
eq(draws[2][3],88);eq(draws.cursor[3],40)
choice.move(1,0);choice.confirm();eq(result,false);eq(count,1);choice.confirm();eq(count,1)
choice.yesNo(function(v)count=count+1;result=v end,{left=23,top=8})
draws={};choice.draw();eq(draws.frame[1],24);eq(draws.frame[2],9);choice.cancel();eq(result,false);eq(count,2)
choice.yesNo(function(v)count=count+1;result=v end)
choice.style='battle';choice.left,choice.top=24,9;draws={};choice.draw()
eq(draws.frame[1],25);eq(draws.frame[2],9);eq(draws.frame[3],4);eq(draws[1][2],200)
eq(draws[1][3],72);eq(draws[2][3],88);eq(draws.cursor[3],32)
choice.confirm();eq(result,true);eq(count,3)
local Native=require('src.ui.Gen3RsChoice');local Party={};local Battle={}
package.loaded['src.ui.Gen3PartyMenu']=Party;package.loaded['src.battle.BattleState']=Battle
eq(Native.yesNoStyle({stack={states={}}}),'field')
eq(Native.yesNoStyle({stack={states={setmetatable({},Battle),{}}}}),'battle')
eq(Native.yesNoStyle({stack={states={setmetatable({},Battle),setmetatable({},Party),{}}}}),'party')
local old=require('src.ui.ChoiceBox');local called=0
local game={data={constants={}},input={wasPressed=function()return false end},stack={pop=function()end}}
local box=old.new(game,function(v)eq(v,false);called=called+1 end,{defaultNo=true,noSound=true})
eq(getmetatable(box),old,'Datasets without native RS retain the old widget');eq(box.index,2)
box:choose(2)
for _=1,14 do box:update();eq(called,0,'Classic answer hold remains intact')end
box:update();eq(called,1)
print('RS_YESNO_CONTRACT_CHECKS',n)
