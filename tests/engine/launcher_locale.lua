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
