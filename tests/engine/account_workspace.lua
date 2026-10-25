package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local signed=false;local sent;local cancelled=false
local policy={version='policy-v1',terms={title='Terms',text='Service terms.'},privacy={title='Privacy',text='Your account privacy.'},developer={title='Developer',text='Your project rights.'}}
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end,account=function() return 'fixture@example.test' end}
package.loaded['src.cloud.NativeAccount']={policy=function() return policy end,register=function(payload) sent=payload;return {state='email_code',challenge=string.rep('a',64)} end,
  complete=function(challenge,code) sent={challenge=challenge,code=code};signed=true;return {state='connected'} end,
  devices=function() return {devices={}} end}
package.loaded['src.cloud.Task']={new=function(fn) return {poll=function() local a,b=fn();return {kind='done',first=a,second=b} end,cancel=function() cancelled=true end} end}
love.keyboard={setTextInput=function(on) TextInput=on end,isDown=function() return false end}
love.system={getClipboardText=function() return 'fixture' end}
local noop=function() end
local UI={_ui={inside=function(r,x,y) return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end,col=noop},
  draw=noop,update=noop,mousepressed=noop,keypressed=noop,textinput=noop,touchpressed=noop,touchmoved=noop,touchreleased=noop,gamepadpressed=noop,play=noop,
  palette=function() return {ink={},detail={},cardBlue={},link={}} end,
  _chipButton=function(_,x,y,_,opts) return {x=x,y=y,width=opts.w,height=opts.h} end,
  _settings=function(self) self.settings=self.settings or {};return self.settings end,_saveSettings=noop,
  _refreshFind=function(self) self.refreshed=true end,_openDeveloper=function(self) self.developer=true end}
local function font(size)
  local f=love.graphics.newFont(size)
  f.getWrap=function(_,text,width) local lines={};local chars=math.max(1,math.floor(width/(size*.5)));for i=1,#text,chars do lines[#lines+1]=text:sub(i,i+chars-1) end;return width,lines end
  return f
end
UI.hintFont=font(16);UI.stateFont=font(22)
local W=require('src.import.AccountWorkspace');W.install(UI)
W.open(UI,'browse');W.tick(UI);local f=UI._accountOverlay
check(f.mode=='login' and f.policy==policy,'native entry loads the current agreements without opening a browser')
W.action(UI,'register');W.action(UI,'submit');check(not sent and f.notice:find('required',1,true),'signup cannot start without the account agreements')
f.name='Fixture';f.email='fixture@example.test';f.password='fixture-password';f.confirmation=f.password
f.terms=true;f.privacy=true;f.developer=true;f.rights=true;f.repositories={'author/first','author/second'}
W.action(UI,'submit');check(f.password=='' and f.confirmation=='','submitted passwords are cleared from the form immediately')
W.tick(UI);check(f.mode=='email_code' and sent.repositories[2]=='author/second','all supplied projects accompany the email-code registration')
check(not UI.settings,'registration does not upload saves before verification')
f.code='12345678';W.action(UI,'submit');W.tick(UI)
check(not UI._accountOverlay and UI.refreshed and UI.settings.cloudAutoSync==false,'email confirmation links this device and returns to browsing with sync explicitly off')
signed=false;W.open(UI);W.tick(UI);f=UI._accountOverlay
W.action(UI,'field:name');UI:textinput('Jörg');UI:keypressed('backspace');check(f.name=='Jör','backspace preserves valid UTF-8 nickname characters')
W.action(UI,'register');f.developer=true;for i=2,45 do W.action(UI,'addRepo') end
check(#f.repositories==45,'developer signup supports more than one page of project drafts without an account limit')
love.graphics.getDimensions=function() return 375,300 end
W.draw(UI);check(f.maxScroll>0,'long registration forms scroll on small screens')
W.action(UI,'field:password');UI:textinput('private fixture');f.job={cancel=function() cancelled=true end};W.close(UI)
check(cancelled and f.password=='' and not TextInput,'closing cancels pending work and clears the password and keyboard focus')
package.loaded['src.import.BankWorkspace']={open=function(self,mode) self.bankOpened=true;self.bankMode=mode end}
for _,destination in ipairs({'bank','bankDex'}) do
  signed=false;UI.bankOpened=nil
  W.open(UI,destination);W.tick(UI);f=UI._accountOverlay
  f.mode='email_code';f.challenge=string.rep('a',64);f.code='12345678'
  check(not UI.bankOpened,'requesting email verification never opens the Bank early')
  W.action(UI,'submit');W.tick(UI)
  check(UI.bankOpened and not UI._accountOverlay and UI.bankMode==(destination=='bankDex' and 'dex' or nil),'confirmed registration returns directly to the requested Bank page')
end
print('Account workspace: '..n..' checks passed')
