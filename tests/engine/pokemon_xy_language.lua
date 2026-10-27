package.path='./?.lua;'..package.path
local Language=require('src.import.PokemonXYLanguage');local Json=require('src.link.Json')
local checks=0;local function check(v,m)assert(v,m);checks=checks+1 end
-- A memory filesystem proves preferences stay separate from save data.
local bytes,events={},{}
io.open=function(path,mode)
 if mode=='rb'then if not bytes[path]then return end;return {read=function()return bytes[path]end,close=function()end}end
 return {write=function(_,s)bytes[path]=s;return true end,close=function()return true end}
end
os.rename=function(a,b)bytes[b]=bytes[a];bytes[a]=nil;return true end
local session={data='/private/player',edition='y'}
local language=Language.new(session,function(event)events[#events+1]=event end)
check(language:buttons(0,1,1)==1 and not language.remembered,'ordinary gameplay A is never a language choice')
language:buttons(1,0,150);language:buttons(1,1,151);language:buttons(5,1,152)
check(not bytes[Language.path(session)],'held selection A cannot also confirm the language')
language:buttons(5,0,153);language:buttons(5,1,154)
check(Json.decode(bytes[Language.path(session)]).language=='german','confirmed choice persists immediately per edition')
local emitted=0;language=Language.new(session,function()emitted=emitted+1 end)
local downEdges,aEdges,last=0,0,0
for n=1,80 do
 local stage=n<24 and 1 or 5;local b=language:buttons(stage,0,n)
 if b==128 and last~=128 then downEdges=downEdges+1 end
 if b==1 and last~=1 then aEdges=aEdges+1 end
 last=b
end
check(downEdges==3 and aEdges==2 and emitted==1,'remembered German selects three rows then separately confirms once')
check(not language.active,'automation stops after the verified startup prompts')
language=Language.new(session,function()end)
for n=1,80 do language:buttons(n<24 and 1 or 2,0,n)end
check(language.active and not language.plan,'mismatched confirmation stays manual instead of accepting the wrong language')
language:reset();check(not bytes[Language.path(session)] and bytes[Language.path(session)..'.previous'],'reset parks only the preference')
local x=Language.new({data='/private/player',edition='x'},function()end)
check(not x.remembered,'X/Y language choices stay independent')
local open=io.open;io.open=function()return nil,'read only'end
local failed=Language.new(session,function(event)events[#events+1]=event end)
check(failed:remember('german')==false and not failed.remembered,'failed preference writes cannot report success')
check(events[#events].message:find('nicht gespeichert',1,true),'write failure reaches the player')
io.open=open
print('3DS language preference: '..checks..' checks passed')
