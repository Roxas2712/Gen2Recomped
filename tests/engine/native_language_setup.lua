package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local Json=require('src.link.Json')
local file=assert(io.open('mods/UNI_LANGUAGE_NATIVE/manifest.json','rb'));local raw=Json.decode(file:read('*a'));file:close()
local manifest=require('src.mods.Manifest').validate(raw,'mods/UNI_LANGUAGE_NATIVE')
local Imports=require('src.mods.ModImports');local ready={};local realHave=Imports.have
Imports.have=function(_,entry)return ready[entry.id]==true end
package.loaded['src.mods.LauncherMods']={manifest=function()return manifest end}
local options,writes,fail={},0,false
package.loaded['src.core.SaveData']={loadOptions=function()local o={};for k,v in pairs(options)do o[k]=v end;o.nativeLanguages={};for k,v in pairs(options.nativeLanguages or{})do o.nativeLanguages[k]=v end;return o end,
 saveOptions=function(o)if fail then return nil,'disk full'end;writes=writes+1;options=o;return true end}
local N=require('src.translation.NativeLanguages')
local count=0;local function check(v,m)assert(v,m);count=count+1 end
check(N.canonical('pb')=='pt-BR' and N.canonical('zh')=='zh-Hans','launcher aliases resolve to cartridge profile ids')
for _,entry in ipairs(require('mods.UNI_LANGUAGE_NATIVE.catalog')) do
 local s=N.describe(entry.game,entry.language,manifest)
 check(s.supported and s.source and s.sourceEntry,'every bundled profile has an exact declared source')
 check(s.source.sha1:match('^%x+$') and #s.source.sha1==40 and s.sourceEntry.md5==s.source.md5 and s.sourceEntry.size==s.source.size,'UI prerequisites match the importer identity')
end
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald'}) do
 check(N.describe(v,'de',manifest).supported,v..' German profile')
 check(N.describe(v,'ko',manifest).supported==(v=='gold'or v=='silver'),v..' Korean boundary')
 check(N.describe(v,'ja',manifest).supported==(v=='crystal'),v..' Japanese boundary')
end
check(not N.describe('gold','zh-Hans',manifest).supported,'a font or menu translation does not claim a nonexistent game profile')
check(N.sourceRelevant('gb/profiles/gold_ko/profile.lua','gold') and not N.sourceRelevant('gb/profiles/crystal_ja/profile.lua','gold'),'static checking includes the current edition and its language variants')
check(N.sourceRelevant('gb/compile.lua','gold') and N.sourceRelevant('main.lua','gold'),'static checking never skips shared executable code')
check(N.sourceRelevant('profiles/ruby_ptbr.lua','sapphire') and not N.sourceRelevant('profiles/emerald.lua','sapphire'),'shared Ruby/Sapphire source data is included')
check(not N.select('gold','de') and writes==0,'missing sources cannot activate a language')
ready.gold_de=true;check(N.select('gold','de'),'ready source can activate')
check(options.nativeLanguages.gold=='de' and options.mods[N.ID],'choice and native enable flag persist')
fail=true;check(not N.select('gold','en') and options.nativeLanguages.gold=='de','failed settings writes retain the previous choice');fail=false
ready.emerald_de=true
local gba=N.describe('emerald','de',manifest)
check(not gba.ready and gba.nextEntry.id=='emerald_en','GBA requests the exact English base as well')
local installed
local realInstall=Imports.install;Imports.install=function(_,entry,bytes)installed={entry.id,bytes};ready[entry.id]=true;return true end
check(not N.keepBase('emerald','US ROM','bad') and not installed,'wrong base digest is refused before retention')
check(N.keepBase('emerald','US ROM',gba.requirement.base.sha1) and installed[1]=='emerald_en','successful US import reuses the native atomic import store')
check(N.describe('emerald','de',manifest).ready,'automatic base retention completes GBA prerequisites')
local W=require('src.import.NativeLanguageSetup')
local RI={_ui={inside=function(r,x,y)return r and x>=r.x and y>=r.y and x<r.x+r.width and y<r.y+r.height end},
 play=function(self)self.played=true end,update=function(self)self.updated=true end,draw=function()end,
 mousepressed=function(self)self.leaked=true end,keypressed=function(self)self.leaked=true end,gamepadpressed=function()end,wheelmoved=function()end,
 filedropped=function(self)self.leaked=true end,_modImportEntry=function()end,_installModImport=function(self)self.modNotice={ok=false,text='Wrong ROM'}end,
 _launcherSettingsRows=function()return {}end,_settingsAction=function()end,
 _settings=function()return options end,chooseModImport=function(self,id)self.picked=id end}
RI.__index=RI;W.install(RI)
options={launcherLanguage='de'}
local ui=setmetatable({launcher=true,ready={gold=true},tab='gold'},RI)
ui:play('gold');check(ui._nativeLanguage and not ui.played,'first Play offers the preferred language before the game starts')
check(ui._nativeLanguage.language=='de','German launcher defaults the offer to German')
W.action(ui,'language:ko');check(ui._nativeLanguage.state.nextEntry.id=='gold_ko','Korean offer names only the Korean Gold source')
W.action(ui,'import');local e,row=ui:_modImportEntry(N.ID)
check(ui.picked==N.ID and e.id=='gold_ko' and row.manifestPath==manifest.path,'offer uses the standard cross-platform native picker with the exact entry')
ui:_installModImport(N.ID,'wrong.gbc');check(ui._nativeLanguage.notice=='Wrong ROM' and not options.nativeLanguages,'rejected input stays in setup without changing the game language')
ui:update(.1);check(not ui.updated,'modal blocks hidden launcher updates')
ui:mousepressed(500,500,1);check(not ui.leaked,'modal swallows clicks outside its controls')
ready.gold_ko=true;W.refresh(ui);W.action(ui,'use')
check(options.nativeLanguages.gold=='ko' and ui.played and not ui._nativeLanguage,'confirming a ready profile persists it and resumes Play once')
ui.played=nil;ui:play('gold');check(ui.played and not ui._nativeLanguage,'confirmed choices are not offered again on every launch')
options={launcherLanguage='ja'};ui.played=nil
W.open(ui,'gold');check(not ui._nativeLanguage.state.supported,'unsupported Japanese Gold is honestly described')
W.action(ui,'later');check(options.nativeLanguages.gold=='en' and not ui._nativeLanguage,'English remains playable without another source')
options={launcherLanguage='de'};ui._romQueue={};ui:_nativeLanguageImported('gold','unused',N.requirement('gold').base.sha1)
ui:update(.1);check(not ui._nativeLanguage,'bulk imports finish before offers interrupt')
ui._romQueue=nil;ui:update(.1);check(ui._nativeLanguage,'completed US import opens its language offer')
local Languages=require('src.translation.Languages');local values=Languages.choices();local found={};for _,id in ipairs(values)do found[id]=true end
check(found.ja and found.ko and found.zh and found['zh-Hant'],'all four CJK launcher languages are selectable')
for _,id in ipairs({'ja','ko','zh','zh-Hant'})do check(Languages.bundledFont(id),'each CJK locale has an offline font')end
local builtin=assert(loadfile('mods/UNI_LANGUAGE_NATIVE/main.lua'))()
local installedNative=false
local api={gameVersion='gold',exports={},supports=function()return true end,localization={install=function()installedNative=true end}}
options={translationLanguage='de'};builtin(api)
check(not installedNative and api.exports.status=='machine_translation','existing machine translation remains available until a native choice is made')
options.nativeLanguages={gold='de'};builtin(api)
check(installedNative and api.exports.sessionBoot,'an explicit cartridge choice selects native ownership')
installedNative=false;api.supports=function()return false end;builtin(api)
check(not installedNative and api.exports.status=='unavailable','unprofiled games keep running without native wrappers')
-- Automatic PT-BR uses only an English source; the asynchronous modal owns
-- cancellation and publishes the choice only after verified preparation.
local P=require('src.translation.PtbrPatch');local describe,prepare=P.describe,P.prepare
local base=gba.baseEntry
P.describe=function(version)return{recipe={baseSha1='us'},baseEntry=base,targetEntry={id='gold_ptbr'},baseReady=ready.emerald_en}end
options={launcherLanguage='pb'};ready.gold_ptbr=nil;ui.played=nil
W.open(ui,'gold');check(ui._nativeLanguage.state.automatic and ui._nativeLanguage.state.canPrepare and not ui._nativeLanguage.state.nextEntry,'PT-BR offers generation from retained US without asking for a Portuguese ROM')
P.prepare=function(_,_,progress)progress(1,2,'apply');ready.gold_ptbr=true;return true end
W.action(ui,'use');check(ui._nativeLanguage.job and not options.nativeLanguages,'start does not select unfinished language data')
ui:update(.1);check(ui._nativeLanguage.progress and not options.nativeLanguages,'preparation yields through the modal update')
ui:update(.1);check(not ui._nativeLanguage and options.nativeLanguages.gold=='pt-BR','completed preparation selects Portuguese')
ready.gold_ptbr=nil;options={launcherLanguage='pb'};W.open(ui,'gold');W.action(ui,'use');ui:update(.1);W.action(ui,'later');ui:update(.1)
check(options.nativeLanguages.gold=='en'and not ready.gold_ptbr,'cancelling a suspended preparation does not publish partial data')
options={launcherLanguage='pb'};P.prepare=function()error('corrupt patch')end
W.open(ui,'gold');W.action(ui,'use');ui:update(.1)
check(ui._nativeLanguage and not ui._nativeLanguage.job and ui._nativeLanguage.notice and not options.nativeLanguages,'preparation failure retains the modal and previous selection')
P.describe,P.prepare=describe,prepare
Imports.have=realHave;Imports.install=realInstall
print('Native language setup: '..count..' checks passed')
