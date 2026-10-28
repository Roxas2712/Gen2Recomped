-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Host=require('src.core.HostShell')
local oldSystem=love.system;love.system=love.system or{}
local osName='UWP';local osGet=love.system.getOS;love.system.getOS=function()return osName end
local oldGame=package.loaded['src.core.Game'];local F=require('src.core.FilePicker')
T.eq(package.loaded['src.core.Game'],oldGame,'import cannot bootstrap Game')
local oldPop,oldHas=Host.popen,Host.hasCommand
local probes,closed={},0
Host.popen=function(cmd)probes[#probes+1]=cmd;return{read=function()return '/usr/bin/zenity\n'end,close=function()closed=closed+1 end}end
for _,os in ipairs{'UWP','NX','Android','iOS','Web','Unknown'}do
 osName=os;T.eq(Host.hasCommand('zenity'),false);T.eq(F.available(),false)
 T.eq(F.commands('Choose',F.IMAGE),nil);T.eq(F.open('Choose',F.IMAGE),nil)
end
T.eq(#probes,0,'unsupported hosts never probe or spawn')
osName='Linux'
for _,name in ipairs{'zenity;touch nope','a b','../tool','-bad','$(bad)','x\nfoo','x%PATH%'}do T.eq(Host.hasCommand(name),false)end
T.eq(#probes,0);T.eq(Host.hasCommand('zenity'),true);T.eq(closed,1)
Host.popen=function()return{read=function()error('owned probe read failure')end,close=function()closed=closed+1 end}end
T.eq(Host.hasCommand('zenity'),false);T.eq(closed,2,'failed probe closes pipe')
local available={zenity=true,kdialog=true};Host.hasCommand=function(n)return available[n]or false end
local kind={label='QA sprite package',exts={'SPRITEPACK','spritepack'}}
local prompt='QA \' " $(do-not-run) `literal` %PATH% ü'
for _,os in ipairs{'OS X','Windows','Linux'}do
 osName=os;T.eq(F.available(),true);local cmds=assert(F.commands(prompt,kind));T.eq(#cmds,1)
 if os=='OS X'then
  T.check(cmds[1]:find('osascript -e ',1,true)==1);T.check(cmds[1]:find("'\\''",1,true)~=nil)
 elseif os=='Windows'then
  T.eq(cmds[1]:find('do-not-run',1,true),nil,'untrusted UTF-8 is data')
  T.check(cmds[1]:find('[Text.Encoding]::UTF8.GetString([byte[]]@(',1,true)~=nil)
  T.check(cmds[1]:find('if($ascii){[Console]::Write($p)}else{',1,true)~=nil,'large ASCII file fast path')
  T.check(cmds[1]:find('[Guid]::NewGuid()',1,true)~=nil,'unique non-ASCII staging')
  T.check(cmds[1]:find('[IO.Path]::GetExtension($p)',1,true)~=nil,
    'non-ASCII staging preserves image/archive extension for the actual importer')
  T.check(cmds[1]:find('-ErrorAction Stop',1,true)~=nil,'failed staging cannot return stale data')
 else T.check(cmds[1]:find('zenity ',1,true)==1)end
end
osName='Linux';available.zenity=false;T.check(F.commands('QA',kind)[1]:find('kdialog ',1,true)==1)
available.kdialog=false;T.eq(F.available(),false);T.eq(F.commands('QA',kind),nil);available.zenity=true
T.eq(F.matches('C:\\QA\\FILE.SPRITEPACK',kind),true);T.eq(F.matches('file.spritepack.exe',kind),false)
T.eq(F.matches('image.JPEG'),true);T.eq(F.basename('C:\\QA\\image.png'),'image.png');T.eq(F.basename('/qa/a.spritepack'),'a.spritepack')
for _,bad in ipairs{{exts={}},{exts={'bad;cmd'}},{exts={'bad"x'}},{exts={'bad x'}},{exts={'png'},label='x|*.sav'}}do
 T.eq(F.commands('QA',bad),nil);T.eq(F.open('QA',bad),nil)
end
T.eq(F.commands('bad\0title',kind),nil);T.eq(F.open(nil,kind),nil);T.eq(F.open(string.rep('x',513),kind),nil)
local mouse,event,timer=love.mouse,love.event,love.timer;local held,pumps,launches=true,0,0
love.mouse={isDown=function()return held end};love.event={pump=function()pumps=pumps+1;held=false end}
love.timer={getTime=function()return 0 end,sleep=function()end}
Host.popen=function()
 T.eq(held,false,'pointer released before native dialog');launches=launches+1
 return{read=function()return ' /owned-qa/a.spritepack\n'end,close=function()closed=closed+1 end}
end
T.eq(F.open('QA pick',kind),'/owned-qa/a.spritepack');T.eq(launches,1);T.eq(pumps,1)
Host.popen=function()launches=launches+1;return{read=function()return ''end,close=function()closed=closed+1 end}end
T.eq(F.open('QA cancel',kind),nil);T.eq(launches,2,'cancel cannot launch another chooser')
local beforeClose=closed
Host.popen=function()return{read=function()error('owned dialog read failure')end,close=function()closed=closed+1 end}end
T.eq(F.open('QA failure',kind),nil);T.eq(closed,beforeClose+1)
love.mouse,love.event,love.timer=mouse,event,timer
local oldOpen=io.open;local reads,closes=0,0
io.open=function(path,mode)
 T.eq(path,'owned-qa-byte-probe');T.eq(mode,'rb')
 return{read=function()reads=reads+1;return '\0binary\255'end,close=function()closes=closes+1 end}
end
T.eq(F.read('owned-qa-byte-probe'),'\0binary\255');T.eq(reads,1);T.eq(closes,1)
io.open=function()return{read=function()error('owned read failure')end,close=function()closes=closes+1 end}end
local bytes,err=F.read('owned-qa-byte-probe');T.eq(bytes,nil);T.check(err:find('owned read failure',1,true)~=nil);T.eq(closes,2)
io.open=oldOpen;Host.popen,Host.hasCommand=oldPop,oldHas;love.system.getOS=osGet;love.system=oldSystem
T.eq(package.loaded['src.core.Game'],oldGame,'no session/save owner introduced')
T.finish('native picker commands, one-backend cancellation, shared pointer release and readonly bytes')
