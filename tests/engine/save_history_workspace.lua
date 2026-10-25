package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(value,message) assert(value,message);n=n+1 end
local Serializer=require('src.core.SaveSerializer')
local original={version='red',player={name='Original'},meta={resume={schema=1,mods={{id='LOCAL',version='1.0'}}}}}
local bytes=Serializer.encode(original);local restored={};local fail=false;local active='slot1'
local copy={label='cloud sync backup 1',when=1000,ok=true,name='Original',meta={badges=3,timeText='2:00'},read=function() return bytes end}
local deleted={label='deleted slot7',slot='slot7',ok=true,name='Deleted',read=function() return bytes end}
package.loaded['src.core.SaveData']={
 listSlots=function() return {{id='slot1',label='My adventure',exists=true},{id='slot2',unreadable=true}} end,
 deletedSlots=function() return {deleted} end,
 slotBackups=function() return {copy,{ok=false,label='unreadable backup'}} end,
 restoreAsNewSlot=function(_,row)
  if fail then return nil,'injected write failure' end
  restored[#restored+1]=Serializer.decode(row.read());return 'slot'..(#restored+10)
 end,
 setActiveSlot=function() error('History must not select a different save') end,
 restoreBackup=function() error('History must not overwrite an existing save') end,
}
local noop=function() end
local UI={_ui={inside=function(r,x,y) return r and x>=r.x and x<=r.x+r.width and y>=r.y and y<=r.y+r.height end,col=noop},
 _sbCloudRows=noop,_settingsAction=noop,draw=noop,mousepressed=noop,keypressed=noop,touchpressed=noop,
 palette=function() return {ink={},detail={},link={},cardBlue={}} end,
 _chipButton=function(_,x,y,_,opts) return {x=x,y=y,width=opts.w,height=opts.h} end,
 _refreshSlots=function(self) self.refreshed=true end,
 play=function() error('History must not start a game') end}
local function font(size)
 local f=love.graphics.newFont(size);f.getWrap=function(_,text,width)
  local lines={};local chars=math.max(1,math.floor(width/(size*.5)))
  for i=1,#text,chars do lines[#lines+1]=text:sub(i,i+chars-1) end;return width,lines
 end;return f
end
UI.hintFont=font(16);UI.stateFont=font(22)
local W=require('src.import.SaveHistoryWorkspace');W.install(UI)
local function ui() return setmetatable({},{__index=UI}) end
local first=ui();W.open(first)
check(first._saveHistoryOverlay.step=='games' and #restored==0,'opening history does not restore, select or launch a save')
W.action(first,'game:not-a-game');check(first._saveHistoryOverlay.step=='games','unknown game identifiers do not reach storage')
W.action(first,'game:red');local f=first._saveHistoryOverlay
check(f.step=='slots' and #f.slots==3 and f.slots[2].unreadable,'unreadable and deleted slots remain available for recovery')
W.action(first,'slot:1');check(f.step=='copies' and f.rows[1]==copy,'the selected slot exposes cloud-sync and local backup rows')
W.action(first,'copy:2');W.action(first,'recover');check(#restored==0,'an unreadable backup cannot be copied')
W.action(first,'copy:1');first._storageTask={};W.action(first,'recover')
check(#restored==0 and f.chosen==1,'an in-flight sync blocks recovery until it completes')
first._storageTask=nil;fail=true;W.action(first,'recover');fail=false
check(#restored==0 and f.chosen==1 and f.notice:find('injected',1,true),'a write failure keeps the source and selection for retry')
W.action(first,'recover')
check(#restored==1 and f.recovered=='slot11' and not f.chosen and first.refreshed,'recovery makes exactly one new slot and refreshes the library')
check(restored[1].meta.resume.mods[1].id=='LOCAL' and active=='slot1' and original.player.name=='Original','per-save mod requirements, active save and source content are preserved')
W.action(first,'recover');check(#restored==1,'a repeated activation cannot duplicate a completed recovery')
W.action(first,'back');W.action(first,'slot:3');W.action(first,'copy:1');W.action(first,'recover')
check(#restored==2 and f.rows[1]==deleted,'deleted slots recover through the same copy-only path')
W.close(first);check(not first._saveHistoryOverlay,'close leaves all recovered and original saves intact')
local busy=ui();busy._profileApplying=true;W.open(busy)
check(not busy._saveHistoryOverlay,'profile transfers finish before history can open')
local settings=ui();settings:_settingsAction({action='saveHistory'})
check(settings._saveHistoryOverlay,'save history opens directly from native storage settings')
local small=ui();W.open(small);love.graphics.getDimensions=function() return 375,300 end;W.draw(small)
check(small._saveHistoryOverlay.maxScroll>0,'the game list remains scrollable on a short phone display')
small:touchpressed('a',100,180);small:touchmoved('b',100,40)
check(small._saveHistoryOverlay.scroll==0,'a second finger cannot steal the history gesture')
small:touchmoved('a',100,80);small:touchreleased('a',100,80)
check(small._saveHistoryOverlay.scroll>0 and not small._saveHistoryOverlay.touch,'a scroll gesture never activates a restore row')
small:play('red');check(small._saveHistoryOverlay,'play is consumed while history owns input')
print('Save history workspace: '..n..' checks passed')
