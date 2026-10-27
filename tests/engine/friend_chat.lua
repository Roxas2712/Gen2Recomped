package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local account='1';local clock=0;local reply;local sent;local cancelled=0
love.system={getOS=function()return 'iOS'end};love.keyboard={setTextInput=function(v)love.ime=v end,isDown=function()return false end}
love.timer.getTime=function()return clock end;love.math.random=function()return .4 end
love.data={hash=function()return string.rep('a',64)end,encode=function(_,_,b)return b end}
package.loaded['src.cloud.RetroCloud']={signedIn=function()return account~=nil end,accountId=function()return account end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()local a,b=fn();return {kind='done',first=a,second=b}end,cancel=function()cancelled=cancelled+1 end}end}
package.loaded['src.cloud.Play']={request=function(method,path,payload)sent={method=method,path=path,payload=payload};if reply==false then return nil,'Offline'end;return reply end}
local C=require('src.ui.FriendChat');local K=require('src.ui.TextComposer');local O={}
C.open(O,'2');reply={account_id='1',friend_id='2',enabled=true,messages={}}
C.tick(O);C.tick(O);T.eq(sent.path,'friends/2/chat','friend window requests only its selected conversation')
C.action(O,'chatCompose');T.check(love.ime and not O.composer.grid,'iPhone composer arms the native IME without forcing a desktop keyboard')
K.text(O,'Jörg 👋');K.key(O,'backspace');K.key(O,'return');T.eq(O.chatDraft,'Jörg ','native keyboard edits Unicode codepoints and keeps the draft')
C.action(O,'chatSend');reply=false;C.tick(O);local first=sent.payload.id
T.check(O.chatSend and O.chatDraft=='Jörg ','offline sending retains both message identity and the draft')
C.action(O,'chatSend');reply={account_id='1',friend_id='2',enabled=true,messages={{id=first,sender='1',body='Jörg ',created_at='2026-10-26 12:00:00'}}};C.tick(O)
T.check(sent.payload.id==first and O.chatDraft==''and not O.chatSend,'retry reuses one identity and clears only after acknowledgement')
K.open(O,'',function(value)O.value=value end,4);K.pad(O,'a');K.pad(O,'dpright');K.pad(O,'a');K.pad(O,'start');T.eq(O.value,'ab','controller keyboard selects letters with A and finishes with Start')
K.open(O,'',function()end,2);K.text(O,'é😀x');T.eq(O.composer.value,'é😀','message limits count Unicode characters without splitting UTF-8')
account='3';C.tick(O);T.check(not O.chat and not O.composer and O.chatDoc==nil,'account switch clears conversation, private draft and system keyboard')
T.finish('Native friend chat and keyboard')
