love=require('tests.love_stub');love.filesystem.load=loadfile
local VM=require('src.script.Gen3ScriptVM')
local n=0
local function eq(a,b,why)n=n+1;assert(a==b,(why or '')..': '..tostring(a)..' != '..tostring(b))end
local rows={
  {{'multichoice',17,4,20,1},20,1,0,17,4,1},
  {{'multichoicedefault',6,3,42,2,0},42,0,2,6,3,1},
  {{'multichoicegrid',2,5,18,3,1},18,1,0,2,5,3},
}
for _,case in ipairs(rows)do
  local s={out={}};VM.LOWERING[case[1][1]](case[1],s)
  local out=s.out[1];eq(#s.out,1);eq(#out,5);eq(out[1],'g3_multichoice')
  eq(out[2],case[2]);eq(out[3],case[3]);eq(out[4],case[4]);eq(out[5].left,case[5]);eq(out[5].top,case[6]);eq(out[5].cols,case[7])
end
-- Run the pinned input controller, independently of GPU and adapter code.
local choice=require('compat.gen1-rs.Loader').new('ruby',{
  ['src.ui.game3.window']={},['src.core.game3.display']={COLS=30},
  ['src.core.game3.rom_text']={},['src.core.game3.se_ids']={SE_SELECT=5},
  ['src.ui.game3.frlg_font']={measure=function(s)return #s*6 end},
  ['src.core.game3.audio']={playSe=function()end},
})('src.ui.game3.choice')
local calls,result=0
local function open(labels,default,layout)
  choice.multi(labels,default,function(value)calls=calls+1;result=value end,layout)
end
open({'PETALBURG','SLATEPORT','CANCEL'},1,{left=1,top=1})
eq(choice.cursor,2);choice.confirm();eq(result,1);eq(calls,1);choice.confirm();eq(calls,1)
open({'A','B','C'},0,{ignoreBPress=true});choice.cancel();eq(choice.active,true);eq(calls,1)
choice.move(1,0);choice.confirm();eq(result,1);eq(calls,2)
open({'A','B','C'},0);choice.cancel();eq(result,127);eq(calls,3)
open({'A','B','C','D','E'},0,{cols=2});choice.move(0,1);eq(choice.cursor,2)
choice.move(1,0);eq(choice.cursor,4);choice.move(1,0);eq(choice.cursor,5)
choice.move(-1,0);eq(choice.cursor,3);choice.confirm();eq(result,2)
open({'A','B'},99);eq(choice.cursor,1)
local g=choice.rsMultiGeometry({'PETALBURG','SLATEPORT','CANCEL'},1,1,1)
eq(g.frame[1],1);eq(g.frame[2],1);eq(g.frame[3],7);eq(g.frame[4],6)
eq(g.cells[2].x,8);eq(g.cells[2].y,24);eq(g.barWidth,56)
g=choice.rsMultiGeometry({'ABCDEFGHIJ'},27,2,1);eq(g.frame[1],21);eq(g.frame[3],8)
g=choice.rsMultiGeometry({'A','B','C','D','E'},2,3,2)
eq(g.frame[3],3);eq(g.frame[4],6);eq(g.cells[4].x,32);eq(g.cells[4].y,40)
choice.reset();eq(choice.active,false)
print('RS_CHOICE_CONTRACT_CHECKS',n)
