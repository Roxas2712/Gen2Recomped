package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local T=require('src.translation.Service');T.setLauncher({launcherLanguage='de'})
local catalog=require('src.translation.LauncherCatalog').de
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local W=require('src.import.FirstRun')
for _,page in ipairs(W.pages) do
 check(catalog[page.title] and catalog[page.body] and catalog[page.tag],'every setup title, tag and explanation has reviewed German text')
 for _,tip in ipairs(page.tips or {}) do check(catalog[tip],'every setup help card is translated') end
end
check(T.launcherLookup('Saved on this device')=='Auf diesem Gerät gesichert','sync feedback is translated without a model download')
T.launcherCatalog={['SIGN IN']='Bad cached translation'}
check(T.launcherLookup('SIGN IN')=='ANMELDEN','reviewed navigation overrides machine-generated cached text')
check(not T.launcherLookup(W.pages[3].tips[1]):find('→',1,true),'guide navigation uses glyphs available in the bundled launcher font')
check(T.launcherLookup('PlayerName#1234')=='PlayerName#1234','unknown user-provided names remain unchanged')
T.setLauncher({launcherLanguage='en'});check(T.launcherLookup('SIGN IN')=='SIGN IN','language changes do not retain the previous catalog')
print('Launcher locale: '..n..' checks passed')
-- Dynamic templates are localized before private values are inserted.
T.setLauncher({launcherLanguage='de'})
check(T.launcherFormat('GAME · %s','SIGN IN#1234')=='SPIEL · SIGN IN#1234','friend names and tags are never translated as UI labels')
check(T.launcherCount(1,'%d NEW FRIEND REQUEST','%d NEW FRIEND REQUESTS')=='1 NEUE FREUNDSCHAFTSANFRAGE','singular request')
check(T.launcherCount(0,'%d NEW FRIEND REQUEST','%d NEW FRIEND REQUESTS')=='0 NEUE FREUNDSCHAFTSANFRAGEN','zero uses plural')
check(T.launcherCount(30,'%d NEW FRIEND REQUEST','%d NEW FRIEND REQUESTS')=='30 NEUE FREUNDSCHAFTSANFRAGEN','plural request')
T.launcherCatalog['Unreviewed %s']='Broken %d %d'
check(T.launcherFormat('Unreviewed %s','Name#1234')=='Unreviewed Name#1234','malformed cached formats fall back safely')
local extra=require('src.translation.CommunityCatalog').de
local function signature(value)
 local out={};for kind in value:gmatch('%%[-+ #0]*%d*%.?%d*([cdeEfgGiouXxsq%%])')do if kind~='%'then out[#out+1]=kind end end
 return table.concat(out)
end
for source,target in pairs(extra)do
 if source:find('%%[dsf]')then check(signature(source)==signature(target),'reviewed template substitutions retain types and order: '..source)end
end
check(T.launcherLookup('TAKE OVER RUNNING BATTLE ON THIS DEVICE')=='KAMPF HIER FORTSETZEN','short actionable German takeover label')
check(T.launcherLookup('The independent legality checker is not available yet.'):find('Prüfdienst',1,true),'disabled private checker has a clear localized explanation')
-- Render the actual origin page: both normal and failed-check paths, no ROM.
local shown={};local oldPrint=love.graphics.printf
love.graphics.printf=function(value)shown[#shown+1]=tostring(value)end
local entry={id=string.rep('a',64),source={version='red',slot=1},mon={nickname='SIGN IN',species='PIKACHU',level=30,otId=2712}}
local ui={hintFont={getWrap=function(_,value)return 700,{value}end,getHeight=function()return 12 end}}
local f={mode='details',inspected={entry=entry},bankCheck={bank_digest=entry.id,current=true,state='illegal',report={moves={{valid=false}},provenance={receipt='unattested',notice='Imported history is self-reported. A legal encounter does not prove that this particular Pokémon was caught legitimately.'}}}}
local function output(value)shown[#shown+1]=T.launcherLookup(value)end
require('src.import.BankPages').draw(ui,f,0,0,700,1500,1,output,output,function()end)
love.graphics.printf=oldPrint
local rendered=table.concat(shown,'\n')
check(rendered:find('SIGN IN',1,true)and not rendered:find('ANMELDEN',1,true),'stored nickname survives real Bank drawing')
check(rendered:find('SPIEL · ',1,true)and rendered:find('Attacke 1',1,true),'actual origin and failed move detail are translated')
check(rendered:find('STANDARDREGELN',1,true)and rendered:find('Selbstauskünfte',1,true),'legality status and provenance notice are localized')
T.setLauncher({launcherLanguage='en'})
check(T.launcherFormat('GAME · %s','SIGN IN#1234')=='GAME · SIGN IN#1234','English remains the unmodified default')
print('Community locale: '..n..' checks passed')

T.setLauncher({launcherLanguage='de'})
local sidebar=require('src.import.LauncherSidebar')
check(sidebar.nameOf('red')=='Pokémon Rot','library edition titles use the selected launcher language')
check(sidebar.metaText({badges=8,timeText='24:00',dexCount=45})=='8 Orden - 24:00 - 45 gefangen','actual library save summary is localized')
for _,category in ipairs(require('src.import.LauncherWorkspace').CATEGORIES)do
 check(T.launcherLookup(category.note)~=category.note,'workspace category help has reviewed German: '..category.id)
end
T.setLauncher({launcherLanguage='en'})
check(sidebar.nameOf('red')=='Pokemon Red','English library title remains unchanged')
print('Library locale: '..n..' checks passed')
