package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local save={version='red',player={name='Original'},meta={}}
local slots={slot1=save};local active='slot1';local creates=0;local launches=0;local match=false;local signed=true
local options={mods={}};local installed={}
local blocked=false;local failCopy=false
package.loaded['src.core.SaveData']={activeSlot=function() return active end,peekSlot=function(_,id) return slots[id] end,
 loadOptions=function() return options end,restoreAsNewSlot=function(_,row,label)
  if failCopy then return nil,'injected write failure' end
  creates=creates+1;local id='slot'..(creates+1);slots[id]=S.decode(row.read());return id
 end,setActiveSlot=function(_,id) active=id;return true end}
package.loaded['src.storage.SaveResume']={fingerprint=S.encode,assess=function()
 return {needsReview=not match,blocked=blocked,problems={},rows={},plan=not blocked and {downloads={},resume={generation=1,required={}}} or nil}
end}
package.loaded['src.mods.ModProfiles']={fingerprint=function() return 'local-stack' end}
package.loaded['src.mods.LauncherMods']={list=function() return installed end}
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end}
local noop=function() end
local UI={_ui={inside=function(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end,col=noop},
 draw=noop,update=noop,mousepressed=noop,keypressed=noop,textinput=noop,touchpressed=noop,touchmoved=noop,touchreleased=noop,gamepadpressed=noop,
 play=function() launches=launches+1 end,palette=function() return {ink={},detail={},cardBlue={},link={}} end,
 _chipButton=function(_,x,y,_,opts) return {x=x,y=y,width=opts.w,height=opts.h} end,
 _refreshMods=noop,_refreshSlots=noop,_sbGo=function(self,section) self.section=section end,
 _openAccount=function(self) self.accountOpened=true end,
 _communityApplyProfile=function(self,plan,manual) self.applied=plan;self.manual=manual;self._profileApplying=true end}
local function font(size)
 local f=love.graphics.newFont(size);f.getWrap=function(_,text,width)
  local lines={};local chars=math.max(1,math.floor(width/(size*.5)));for i=1,#text,chars do lines[#lines+1]=text:sub(i,i+chars-1) end;return width,lines
 end;return f
end
UI.hintFont=font(16);UI.stateFont=font(22)
local W=require('src.import.ResumeWorkspace');W.install(UI)
local function ui() return setmetatable({launcher=true,ready={red=true}},{__index=UI}) end
local first=ui();first:play('red')
check(first._resumeOverlay and launches==0 and creates==0,'a mismatched save is reviewed before launching or changing any save')
W.action(first,'close');check(not first._resumeOverlay and slots.slot1==save,'closing leaves the original untouched')
first:play('red');W.action(first,'copy')
check(launches==1 and creates==1 and active=='slot2','explicit current-mod continuation selects a new slot and launches once')
check(slots.slot1==save and slots.slot2.player.name=='Original','the original save remains intact after creating a playable copy')
check(not first._resumeBypass,'the copy launch bypass is consumed once')
active='slot1';local failed=ui();failed:play('red');failCopy=true;W.action(failed,'copy');failCopy=false
check(launches==1 and active=='slot1' and failed._resumeOverlay,'a copy write failure cannot discard or launch over the original')
W.close(failed);local stale=ui();stale:play('red');slots.slot1={version='red',player={name='Updated'}};W.action(stale,'copy')
check(stale._resumeOverlay.stale and creates==1,'a save changed during review cannot be copied or restored using stale approval')
slots.slot1=save;local switching=ui();switching:play('red');active='slot2';W.action(switching,'restore')
check(switching._resumeOverlay.stale and not switching.applied,'changing the active slot invalidates the selected restore')
active='slot1';local restore=ui();restore:play('red');W.action(restore,'restore')
check(restore.applied and restore.manual and restore._resumeRestore and not restore._resumeOverlay,'reviewed requirements use the existing staged package transaction')
W.tick(restore);check(launches==1,'a partially applied mod set cannot launch')
restore._profileApplying=nil;match=true;W.tick(restore)
check(launches==2 and not restore._resumeRestore,'successful restoration is checked again before the original save can launch')
match=false;local unresolved=ui();unresolved:play('red');W.action(unresolved,'restore');unresolved._profileApplying=nil;W.tick(unresolved)
check(unresolved._resumeOverlay and launches==2,'an incomplete or failed restore returns to review without launching')
blocked=true;local newer=ui();newer:play('red');W.action(newer,'copy')
check(newer._resumeOverlay and creates==1 and launches==2,'an incompatible save format cannot bypass the check by making a copy')
blocked=false;local uploading=ui();uploading._storageTask={};uploading:play('red')
check(not uploading._resumeOverlay and launches==2,'an in-flight cloud transfer finishes before a save is selected for play')
local settings=ui();settings:play('red');W.action(settings,'mods');check(settings.section=='mods' and not settings._resumeOverlay,'the mod manager opens natively from save review')
local small=ui();small:play('red');love.graphics.getDimensions=function() return 375,300 end;W.draw(small)
check(small._resumeOverlay.maxScroll>0,'the review remains scrollable on a short phone display')
local f=small._resumeOverlay;small:touchpressed('a',100,180);small:touchmoved('b',100,40);check(f.scroll==0,'a second finger cannot steal the active review gesture')
small:touchmoved('a',100,80);small:touchreleased('a',100,80);check(f.scroll>0 and not f.touch,'touch scrolling never activates a restore button accidentally')
print('Resume workspace: '..n..' checks passed')
