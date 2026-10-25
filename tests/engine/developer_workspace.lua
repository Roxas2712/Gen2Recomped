package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local signed=false;local calls={};local opened={};local profile={id=1,repository='author/mod',verified=true}
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end,account=function() return 'author@example.invalid' end}
package.loaded['src.cloud.DeveloperProjects']={list=function(page) calls[#calls+1]='list';return {repositories={profile},page=page,total=1} end,
  prepare=function(repo) calls[#calls+1]=repo;return profile end,verify=function() return profile end,proofUrl=function() return 'https://github.com/author/mod/new/HEAD' end}
package.loaded['src.cloud.Task']={new=function(fn) return {poll=function() return {kind='done',first=fn()} end,cancel=function() calls[#calls+1]='cancel' end} end}
love.system={openURL=function(url) opened[#opened+1]=url end}
love.keyboard={setTextInput=function(on) TextInput=on end,isDown=function() return false end}
local W=require('src.import.DeveloperWorkspace')
local noop=function() end
local UI={_ui={inside=function(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end,col=noop},
  draw=noop,update=noop,mousepressed=noop,keypressed=noop,textinput=noop,touchpressed=noop,touchmoved=noop,touchreleased=noop,gamepadpressed=noop,play=noop,
  palette=function() return {ink={},detail={},cardBlue={},link={}} end,
  _chipButton=function(_,x,y,_,opts) return {x=x,y=y,width=opts.w,height=opts.h} end,
  _refreshFind=function(self) self.refreshed=true end, _openAccount=function(self,mode) self.accountMode=mode end}
W.install(UI)
local function font(size)
  local f=love.graphics.newFont(size)
  f.getWrap=function(_,text,width)
    local lines={};local chars=math.max(1,math.floor(width/(size*.5)))
    for i=1,#text,chars do lines[#lines+1]=text:sub(i,i+chars-1) end
    return width,lines
  end
  return f
end
UI.hintFont=font(16);UI.stateFont=font(22)
W.open(UI,'browse')
check(#calls==0 and #opened==0 and UI.accountMode=='browse','signed-out browsing opens native account entry without starting linkage or opening a browser')
signed=true
W.open(UI,'browse');W.tick(UI)
W.action(UI,'browse');check(not UI._developerOverlay and UI.refreshed,'the linked device can enter the native browser')
W.open(UI,'developer');W.tick(UI)
check(UI._developerOverlay.projects[1]==profile,'the developer corner loads all linked repositories')
W.action(UI,'select:1')
check(UI._developerOverlay.repository=='author/mod','selecting a project loads its own control status')
W.action(UI,'save');check(calls[#calls]=='list','preparing a new proof requires explicit rights confirmation')
love.graphics.getDimensions=function() return 375,300 end
W.draw(UI)
local f=UI._developerOverlay
check(f.maxScroll>0,'the developer profile scrolls when the window is short')
W.scroll(UI,-100);check(f.scroll==f.maxScroll,'scrolling cannot escape the content bounds')
W.draw(UI);f.padIndex=#f.rects;W.navigate(UI,1)
check(f.padIndex==1 and f.padActive,'keyboard and controller selection wrap to the fixed Close action')
W.navigate(UI,1);check(f.padIndex==2 and f.scroll>=0,'moving to the repository scrolls it back into view')
W.action(UI,'repository');check(f.focus and TextInput,'the repository can receive text with a controller or keyboard')
UI:textinput('author/new');check(f.repository=='author/modauthor/new','text input is routed to the repository field')
W.navigate(UI,1);check(not f.focus and not TextInput,'leaving the field releases the system keyboard')
W.draw(UI);f.scroll=0
UI:touchpressed('first',100,200);UI:touchmoved('second',100,50)
check(f.scroll==0,'another finger cannot take over an active gesture')
UI:touchmoved('first',100,80);UI:touchreleased('first',100,80)
check(f.scroll>0 and not f.touch,'a vertical gesture scrolls instead of activating a button')
local pending={cancel=function() calls[#calls+1]='cancel' end};f.job=pending
W.close(UI);check(not UI._developerOverlay and calls[#calls]=='cancel' and not TextInput,'closing cancels pending account work and releases text input')
print('Developer workspace: '..n..' checks passed')
