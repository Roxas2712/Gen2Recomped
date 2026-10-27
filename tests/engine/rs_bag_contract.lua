package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
love.filesystem.load=loadfile
local T=require('tests.harness')
local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter')
local Import=require('src.import.Gen3RsBag')
local oldRead,oldExists=Fs.read,Fs.exists
local bodies,files={},{}
local toss={}
for _,key in ipairs({'gOtherText_HowManyToToss','gOtherText_OkayToThrowAwayPrompt',
  'gOtherText_ThrewAwayItem','OtherText_Yes','OtherText_No'})do toss[key]={}end
bodies['data/generated/constants.lua']=Writer.encode({gen3RsBag={format=1,version='ruby',tossTextIR=toss}})
for _,sub in ipairs({'bag','common_ui','bag_chrome'}) do
  local file='data/generated/gba/rse/'..sub..'/test.png'
  bodies['data/generated/gba/rse/'..sub..'/manifest.lua']=Writer.encode({layout='rs',game='ruby',files={file}})
  files[file]=true
end
Fs.read=function(p)return bodies[p]end
Fs.exists=function(p)return files[p]end
T.eq(#Import.missing('ruby'),0,'all native bag resources are ready')
T.eq(#Import.missing('sapphire'),4,'Ruby assets and text cannot satisfy Sapphire')
files['data/generated/gba/rse/bag/test.png']=nil
T.eq(#Import.missing('ruby'),1,'missing bag graphics invalidate the cache')
bodies['data/generated/gba/rse/common_ui/manifest.lua']='return {layout="rs",game="ruby",files={}}'
T.eq(#Import.missing('ruby'),2,'interrupted empty cursor manifest fails readiness')
bodies['data/generated/gba/rse/bag_chrome/manifest.lua']='broken lua'
T.eq(#Import.missing('ruby'),3,'broken window manifest fails readiness')
Fs.read,Fs.exists=oldRead,oldExists

local V=require('src.core.GameVersion')
local old=V.get()
V.set('ruby')
local Bag=require('src.ui.Gen3BagMenu')
local Action=require('src.ui.Gen3ItemMenu')
local Native=require('src.ui.Gen3RsBagInput')
local game={data={constants={gen3RsBag={format=1,version='ruby'}},items={}},
  save={inventory={},bagOrder={},options={}},stack={pop=function()end}}
for i=1,12 do
  local id='ITEM_'..i
  game.data.items[id]={id=id,name=id,pocket='ITEM',index=i}
  game.save.inventory[id]=i
  game.save.bagOrder[i]=id
end
game.data.items.BALL={id='BALL',name='BALL',pocket='BALL',index=20}
game.save.inventory.BALL=2;game.save.bagOrder[13]='BALL'
local bag=Bag.new(game)
T.check(bag.rs,'new matching RS metadata enables native bag')
T.eq(bag:listRows(),8,'RS displays eight rows')
T.eq(select(1,bag:uiSize()),240,'native bag keeps its own width')
local input={pressed={}}
function input:wasPressed(key)return self.pressed[key]end
function input:isDown()return false end
local function press(key)input.pressed={[key]=true};bag.tick=(bag.tick or 0)+1;Native.update(bag,input)end
for _=1,16 do press('')end
press('up');T.eq(bag.index,1,'native list clamps at top')
for _=1,8 do press('down')end
T.eq(bag.index,9,'ninth item remains reachable')
T.eq(bag.top,2,'ninth item scrolls one native row')
press('right')
for _=1,16 do press('')end
T.eq(bag.pocket,2,'next pocket uses host pocket identity')
press('left')
for _=1,16 do press('')end
T.eq(bag.index,9,'return to pocket restores native selection')
T.eq(bag.top,2,'return to pocket restores native scroll')
local inv=Writer.encode(game.save.inventory)
press('select');press('down');press('select')
T.eq(game.save.bagOrder[9],'ITEM_10','SELECT swaps real inventory order')
T.eq(game.save.bagOrder[10],'ITEM_9','swap retains both original IDs')
T.eq(Writer.encode(game.save.inventory),inv,'reordering preserves quantities')
for _=1,30 do press('down')end
T.check(bag:selected().close,'close row remains selectable after long scrolling')
press('select');T.eq(bag.rsSwap,nil,'close row never becomes a reorder item')
local replacement=Bag.new(game)
Native.restore(replacement)
T.eq(replacement.index,bag.index,'reopening restores selection without save writes')
local parent={sgbPalettes=function()return {{native=true}}end}
local action=Action.new(game,{rsBag=parent,columns=2,entries={
  {label='USE',kind='use'},{label='REGISTER',kind='register'},
  {label='',kind='blank'},{label='CANCEL',kind='cancel'}}})
action:step('up');T.eq(action.index,1,'RS actions clamp at top')
action:step('down');T.eq(action.index,1,'RS actions do not cross deliberate holes')
action:step('right');T.eq(action.index,2,'RS right selects second column')
action:step('down');T.eq(action.index,4,'RS down selects cancel')
action:step('right');T.eq(action.index,4,'RS actions clamp at right')
T.check(action.isOpaque,'native actions redraw the complete native bag')
T.check(action:sgbPalettes()[1].native,'native actions keep bag palette zones')
local legacy=Action.new(game,{entries={{label='A',kind='use'},{label='B',kind='cancel'}}})
legacy:step('left');T.eq(legacy.index,2,'other-edition action wrapping is unchanged')
T.eq(legacy.sgbPalettes,nil,'other editions still inherit underlying palette owner')
V.set('leafgreen')
T.check(not Bag.new(game).rs,'RS metadata cannot enable native bag on LeafGreen')
V.set(old)
T.finish('RS bag cache, eight-row input, cancel, reorder and return contracts')
