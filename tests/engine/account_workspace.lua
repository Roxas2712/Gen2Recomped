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
check(not UI.settings.cloudAutoSync,'registration does not enable upload before verification')
f.code='12345678';W.action(UI,'submit');W.tick(UI)
check(not UI._accountOverlay and UI.refreshed and UI.settings.cloudAutoSync==true,'email confirmation links this device and returns to browsing with automatic account sync')
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
signed=false
local SaveData=require('src.core.SaveData')
local previousLoad,previousSave=SaveData.loadOptions,SaveData.saveOptions
local options={cloudAutoSync=true};local writes=0
SaveData.loadOptions=function() return options end
SaveData.saveOptions=function(value) writes=writes+1;options=value;return true end
W.open(UI,{kind='play',version='red',storagePrompt=true});f=UI._accountOverlay
check(f.mode=='storage_choice' and not f.job,'first guest play offers local saves without making an account request')
local storage=require('src.storage.AccountStorage');local previousResume=storage.resume;local resumed
storage.resume=function(_,after) resumed=after.version end
f.password='private fixture';f.job={cancel=function() cancelled=true end};cancelled=false
W.action(UI,'local')
check(cancelled and not UI._accountOverlay and f.password=='' and resumed=='red',
  'local play cancels pending networking, clears credentials and resumes the requested game')
check(writes==1 and options.launcherSaveStorageChoice=='local' and options.cloudAutoSync==false,
  'declining cloud persists a local-only choice without enabling uploads')
storage.resume=previousResume;SaveData.loadOptions,SaveData.saveOptions=previousLoad,previousSave
signed=true
local auth=package.loaded['src.cloud.RetroCloud'];auth.accountId=function() return '17' end
local native=package.loaded['src.cloud.NativeAccount']
native.profile=function(payload)
  if payload then sent=payload end
  return {account_id='17',name=payload and payload.name or 'Fixture',friend_tag='Fixture#4821',avatar_preset='leaf',avatar_color='forest'}
end
native.request=function()return {account_id='17',friends={},incoming={},outgoing={}}end
native.friends=function() return {account_id='17',friends={},incoming={},outgoing={}} end
native.findPlayer=function(tag) sent=tag;return {friend_tag=tag,account_id='18'} end
native.createGift=function(payload) sent=payload;return {id='11111111-1111-4111-8111-111111111111',code='TEST-CODE-1234-5678'} end
native.gifts=function() return {receipts={},campaigns={},manage=true} end
W.open(UI);W.tick(UI);f=UI._accountOverlay
check(f.nickname=='Fixture' and f.friendTag=='Fixture#4821','the native account displays the shared ModCompass nickname and friend tag')
W.action(UI,'transferGuide');W.draw(UI)
check(f.mode=='transferGuide','the device-switch guide is available inside the native account')
local restoreMode;UI._storageSync=function(_,_,_,_,mode)restoreMode=mode end
W.action(UI,'restoreGames')
check(not UI._accountOverlay and restoreMode=='restore','the guide starts an explicit account restore without enabling uploads')
W.open(UI);W.tick(UI);f=UI._accountOverlay
f.profileName='UpdatedFixture';W.action(UI,'saveProfile');W.tick(UI)
check(sent.name=='UpdatedFixture','nickname changes use the shared profile endpoint')
W.action(UI,'friends');W.tick(UI);f.friendQuery='Other#4821';W.action(UI,'findFriend');W.tick(UI)
check(sent=='Other#4821' and f.foundFriend.friend_tag=='Other#4821','exact friend tags can be searched inside the launcher')
W.action(UI,'gifts');W.tick(UI);W.action(UI,'newGift');f.giftTitle='Flying companion';f.giftMoves='FLY';f.giftSelected={red=true}
W.action(UI,'createGift');W.tick(UI)
check(sent.editions[1]=='red' and sent.moves[1]=='FLY' and not sent.egg and not sent.shiny,'Gen 1 event gift creation sends the chosen edition and special move without egg or shiny defaults')
check(f.createdGift.code=='TEST-CODE-1234-5678','the generated code is shown in the creation result')
W.draw(UI);f.rolePassword='private-role-confirmation';W.close(UI)
check(not f.createdGift and f.rolePassword=='','closing clears generated codes and the role confirmation password')
W.open(UI);W.tick(UI);f=UI._accountOverlay;f.mode='friends'
local pinId='pinball:accept:11111111-1111-4111-8111-111111111111';local pinAction
UI._pinFriends={rows=function(_,peer)return peer and {}or{{id=pinId,label='PINBALL ANNEHMEN',note='QA invitation'}}end,
 action=function(_,id)if id:match('^pinball:')then pinAction=id;return true end;return false end}
for _,mode in ipairs({'friends','inbox'})do
 f.mode=mode;W.draw(UI);local found=false
 for _,rect in ipairs(f.rects)do if rect.id==pinId then found=true end end
 check(found,'Pinball invitation has a native actionable row in '..mode)
end
W.action(UI,pinId);check(pinAction==pinId,'account actions route Pinball to its adapter')
UI._pinFriends=nil;W.close(UI)
W.open(UI);f=UI._accountOverlay;if f.job then f.job:cancel();f.job=nil end
f.mode='login';f.cloudSync=true
local T=require('src.translation.Service');T.setLauncher({launcherLanguage='de'})
local printed={};local printf=love.graphics.printf;love.graphics.printf=function(value)printed[#printed+1]=tostring(value)end
W.draw(UI);love.graphics.printf=printf
check(table.concat(printed,'\n'):find('[x] Meine Spielstände automatisch',1,true),'the real checked cloud label is translated before its checkbox marker is added')
T.setLauncher({launcherLanguage='en'});W.close(UI)
print('Account workspace: '..n..' checks passed')
