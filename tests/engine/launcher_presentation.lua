package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local now=0;love.timer.getTime=function() return now end
local wall=1000;os.time=function() return wall end
local P=require('src.import.LauncherPresentation')
local checks=0
local function check(v,m) assert(v,m);checks=checks+1 end
local doc={schema_version=1,week_enabled=true,promotions_enabled=true,week={catalogue_id='featured'},items={
 {kind='promotion',title='A clearly labelled promotion',description='The operator announcement.',url='https://pokexpert.de/projects/example',image='https://pokexpert.de/assets/example.png'},
}}
local state=assert(P.parse(doc))
check(state.week.catalogue_id=='featured' and #state.items==1,'enabled public placements retain the selected week and campaign')
check(state.items[1].thumbnail=='https://pokexpert.de/assets/example.png','owned image previews are allowed')
doc.items[1].image='https://external.test/tracker.png';state=assert(P.parse(doc))
check(state.items[1].thumbnail==nil,'campaign images never trigger external tracking hosts')
doc.items[1].url='https://name:password@pokexpert.de/private'
check(not P.parse(doc),'credential-bearing links are rejected')
doc.items[1].url='javascript:alert(1)'
check(not P.parse(doc),'script destinations are rejected')
doc.items[1].url='https://pokexpert.de/';doc.items[1].title=string.rep('x',321)
check(not P.parse(doc),'oversized labels cannot enter the interface')
doc.items[1].title='Safe';doc.week_enabled=false;doc.promotions_enabled=false
state=assert(P.parse(doc));check(not state.week and #state.items==0,'disabled settings never retain the formerly published content')
local response=require('src.link.Json').encode(doc)
local requests,cancelled=0,0
package.loaded['src.cloud.Http']={request=function(method,url,opts)
 check(method=='GET' and url==P.URL and not opts.headers.Authorization,'public refresh uses no account credentials')
 requests=requests+1;return 200,response
end}
package.loaded['src.cloud.Task']={new=function(fn) return {poll=function() return {kind='done',first=fn()} end,cancel=function() cancelled=cancelled+1 end} end}
local enabled=true
local ui={section='mods',_settings=function() return {modCompassEnabled=enabled} end}
P.update(ui);P.update(ui)
check(requests==1 and P.current(ui)~=nil and P.week(ui)==nil,'first catalogue visit receives fresh disabled controls')
doc.week_enabled=true;doc.promotions_enabled=true;response=require('src.link.Json').encode(doc)
now=59;P.update(ui);check(requests==1,'ordinary frames do not flood the server')
now=60;P.update(ui);P.update(ui)
check(requests==2 and P.week(ui).catalogue_id=='featured' and #P.items(ui)==1,'new published contents appear at the next refresh')
now=179;check(P.current(ui)~=nil,'fresh placements remain for less than two minutes')
now=180;check(P.current(ui)==nil and #P.items(ui)==0,'stale campaigns and weekly highlights expire without needing another successful request')
P.update(ui);ui.section='library';P.update(ui)
check(cancelled==1,'leaving Mods cancels the outstanding request')
ui.section='mods';now=200;ui._presentationNext=0;P.update(ui);P.update(ui)
check(#P.items(ui)==1,'a fresh response restores currently published content')
wall=1200
check(P.current(ui)==nil,'device sleep expires campaigns even if the performance clock was paused')
P.update(ui)
check(ui._presentationJob~=nil,'resuming with expired content triggers a fresh request immediately')
ui.section='mods';enabled=false;P.update(ui)
check(not ui._presentation and not ui._presentationAt,'disabling ModCompass drops all public placements')
print('Launcher presentation: '..checks..' checks passed')
