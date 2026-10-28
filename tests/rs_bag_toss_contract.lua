love=require('tests.love_stub');love.filesystem.load=loadfile
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local remaining=37;local removed=0
local load=require('compat.gen1-rs.Loader').new('ruby',{
 ['src.ui.game3.rse.scene_kit']={playSe=function()end},
 ['src.ui.game3.frlg_font']={},['src.ui.game3.chrome']={},
 ['src.core.game3.rom_text']={},
 ['src.core.game3.items_data']={toNumericId=function(id)return id end},
 ['src.core.game3.bag']={removeSlot=function(_,pocket,index,qty)
   check(pocket=='ITEMS'and index==1,'Stable original slot')
   remaining=remaining-qty;removed=removed+qty;return true
 end},
})
local R=load('src.ui.game3.rs.bag_menu')
local view={open=true,mode='list',cursor=1,scroll=0,pocketIdx=1,_session={},_bag={},
  _rsBag={pos={},frame=0},list=function()return{{id=13,name='POTION',qty=remaining}}end,
  currentPocket=function()return'ITEMS'end}
local function key(k)
  R.handleInput({wasPressed=function(_,name)return name==k end,isDown=function()return false end},view)
end
local function begin()
  check(R.beforeAction(view,'TOSS',view.list()[1]),'Original TOSS action accepted')
  check(view.tossQty==1 and view.mode=='toss','Original quantity starts at one')
end
begin();key('down');check(view.tossQty==37,'Down wraps to full stack')
key('up');check(view.tossQty==1,'Up wraps to one')
key('right');check(view.tossQty==11,'Right adds ten');key('left');check(view.tossQty==1,'Left subtracts ten')
for _=1,5 do key('right')end;check(view.tossQty==37,'Right clamps at maximum')
key('b');check(view.mode=='list'and removed==0,'Quantity B cancels')
begin();key('a');check(view.mode=='toss_confirm'and view.yesNoCursor==1,'Original YES default')
key('down');key('a');check(view.mode=='list'and removed==0,'NO preserves inventory')
begin();key('up');key('up');key('a');key('b');check(view.mode=='list'and removed==0,'Confirmation B cancels')
begin();key('up');key('up');key('a');key('a')
check(view.mode=='toss_done'and removed==3 and remaining==34,'Only confirmed quantity removed once')
key('right');check(removed==3,'Result state ignores directions')
key('a');check(view.mode=='list'and removed==3,'Acknowledgement does not repeat removal')
begin();key('up')
local held={wasPressed=function()return false end,isDown=function(_,name)return name=='up'end}
for _=1,39 do R.handleInput(held,view)end
check(view.tossQty==2,'Held quantity input waits its original forty frames')
R.handleInput(held,view);check(view.tossQty==3,'First original repeat at forty')
for _=1,5 do R.handleInput(held,view)end
check(view.tossQty==4,'Subsequent original repeat at five')
key('b')
local Gate=require('src.import.Gen3RsBag')
local spec={format=1,version='ruby',tossTextIR={}}
check(not Gate.tossReady(spec,'ruby'),'Old incomplete import rejected')
for _,name in ipairs({'gOtherText_HowManyToToss','gOtherText_OkayToThrowAwayPrompt','gOtherText_ThrewAwayItem','OtherText_Yes','OtherText_No'})do spec.tossTextIR[name]={}end
check(Gate.tossReady(spec,'ruby'),'Matching current text import accepted')
check(not Gate.tossReady(spec,'sapphire'),'Mixed edition rejected')
print('RS_BAG_TOSS_CONTRACT_CHECKS',checks)
