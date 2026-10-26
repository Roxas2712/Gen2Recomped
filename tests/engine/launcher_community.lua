-- Catalogue metadata may enrich a card, but must never select another repo's ZIP.
package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local checks=0
local function check(v,why) assert(v,why);checks=checks+1 end
local options={}
local saved=0
local signedIn=true
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signedIn end,accessToken=function() return 'test-device-token' end}
package.loaded['src.core.SaveData']={loadOptions=function() return options end,saveOptions=function(o) options=o;saved=saved+1 end}
local requests=0
local requestUrls={}
local response
package.loaded['src.cloud.Http']={request=function(_,url)
  if url=='https://pokexpert.de/api/launcher/presentation.json' then return 200,'{"schema_version":1,"week_enabled":false,"promotions_enabled":false,"items":[]}' end
  requests=requests+1;requestUrls[url]=(requestUrls[url] or 0)+1;return 200,response
end}
package.loaded['src.cloud.Task']={new=function(fn)
  return {cancel=function() end,poll=function() local a,b=fn();return {kind='done',first=a,second=b} end}
end}
local C=require('src.import.LauncherCommunity')
local Json=require('src.link.Json')
local Index=require('src.mods.ModIndex')
local function release(version,repo,pre)
  return {version=version,prerelease=pre,zip={name='original-'..version..'.zip',url='https://github.com/'..(repo or 'author/mod')..'/releases/download/v'..version..'/mod.zip'}}
end
local entry={id='catalogue-slug',github='author/mod',summary='Short',description='Full details',games={'red','blue'},sourceChecked='2026-10-25'}
check(C.resolve(entry,{id='REAL_ID',releases={release('1.0.0'),release('2.0.0'),release('3.0.0','author/mod',true)}}),'original releases resolve')
check(entry.id=='REAL_ID' and entry.latest.version=='2.0.0','manifest ID and newest stable release win')
local before=entry.latest
check(not C.resolve(entry,{id='FORGED',releases={release('5.0.0','attacker/mod')}}),'another repository is refused')
check(entry.id=='REAL_ID' and entry.latest==before,'a rejected response cannot mutate the card')
check(not C.resolve(entry,{id='../wrong',releases={}}),'invalid manifest ID is refused')
check(not C.resolve(entry,{id='real'}),'malformed release response is refused')
check(not C.resolve(entry,{id='real',releases={{version='not semver',zip={}}}}),'malformed release is refused')
check(C.resolve(entry,{id='REAL_ID',releases={}}) and entry.update_check=='no installable release','a source-only mod never invents an install URL')
local body=C.describe(entry)
check(body:find('Full details',1,true) and body:find('red, blue',1,true) and body:find('author/mod',1,true),'details preserve curated text, games and origin')
local document={schema_version=1,mods={{id='catalogue-slug',catalogue_id='slug',github='author/mod',summary=string.rep('Long description. ',100),description='Full curated details',games={'red'},project_url='https://pokexpert.de/projects/slug',resolve_url='https://pokexpert.de/api/launcher/mods/slug'}}}
local parsed=assert(Index.parse(Json.encode(document)))
check(parsed.mods[1].description=='Full curated details' and parsed.mods[1].games[1]=='red','feed parser preserves detail metadata')
local RI={_ui={inside=function() return false end}}
function RI:_settings() return options end
function RI:_refreshFindSources() self.findSources={{feed='https://custom.test/index.json',label='Custom'}} end
function RI:_removeIndex() self.customRemoved=true end
function RI:_refreshMods() self.mods={{id='REAL_ID',github='AUTHOR/MOD',description='Original manifest'}};self:_syncModUpdateInfo() end
function RI:_findShowDetails() self.customDetails=true end
function RI:_findThumb() end
function RI:_drawFindPanel() return 100 end
function RI:_drawModsPanel() return 100 end
function RI:_sbMousepressed() end
function RI:update() self.updated=true end
function RI:play() self.launched=true end
function RI:_ensureFind() self:_refreshFind() end
C.install(RI)
local ui=setmetatable({section='mods',tab='find'},{__index=RI})
ui:_refreshFindSources()
check(ui.findSources[1].feed==C.FEED and #ui.findSources==2,'ModCompass is available by default beside custom feeds')
ui:_removeIndex(C.FEED)
ui:_refreshFindSources()
check(options.modCompassEnabled==false and #ui.findSources==1,'built-in feed can be removed persistently')
ui:_removeIndex('custom');check(ui.customRemoved,'custom feed removal is preserved')
options.modCompassEnabled=true
-- Cache avoids network when still fresh, while the card keeps its full detail text.
local oldRead,oldWrite=Index.readCache,Index.writeCache
Index.readCache=function(feed) return feed==C.FEED and parsed or {mods={},categories={}} end
parsed.cachedAt=os.time()
local oldFresh=Index.cacheFresh;Index.cacheFresh=function() return true end
ui:_refreshFind();ui:update(0)
check(requests==0 and #ui.findIndex.mods==1,'fresh cached catalogue works offline without requests')
local card=ui.findIndex.mods[1]
check(#card.summary<230 and card.description=='Full curated details','card preview is bounded without losing full details')
ui:_refreshMods()
check(ui.mods[1].description:find('ModCompass:',1,true),'refreshing installed mods restores curated metadata')
C.enrich(ui)
local _,count=ui.mods[1].description:gsub('ModCompass:','')
check(count==1 and ui.mods[1].description:find('Original manifest',1,true),'enrichment does not duplicate itself or erase manifest information')
ui:_findShowDetails(card)
check(ui._findDetails.body:find('Full curated details',1,true),'details show full description')
ui:_findShowDetails({id='custom'})
check(ui.customDetails,'custom feed detail behavior remains supported')
ui:_findThumb(card);ui:_findThumb(card)
check(#ui._communityResolveQueue==1,'visible cards queue one repository check')
response=Json.encode({id='REAL_ID',releases={release('1.2.3')}})
ui:update(0);ui:update(0)
check(card.id=='REAL_ID' and card.latest.version=='1.2.3','background resolver enables the original release on its card')
check(requestUrls[card.resolveUrl]==1 and saved>=2,'repository result is fetched once and cached')
local forged={id='bad',catalogueId='bad',resolveUrl='https://evil.test/api/launcher/mods/bad'}
ui:_findThumb(forged)
check(#ui._communityResolveQueue==0,'custom feeds cannot enqueue foreign endpoints as ModCompass')
local compatible={_communityResolved=true,api=2,game_version='>=0.3.0 <2.0.0',latest=release('1.0.0')}
check(C.weekCompatible(compatible),'weekly highlight requires a resolved release compatible with this engine and API')
compatible.api=99;check(not C.weekCompatible(compatible),'future mod APIs cannot become the weekly highlight')
compatible.api=2;compatible.game_version='>=9.0.0';check(not C.weekCompatible(compatible),'a mod for another engine version stays out of the highlight')
check(C.videoUrl({id='1zapYKShrtQ',url='https://attacker.test'})=='https://www.youtube.com/watch?v=1zapYKShrtQ','video links use canonical YouTube IDs rather than arbitrary catalogue URLs')
check(not C.videoUrl({id='../bad'}),'invalid video IDs never become external links')
signedIn=false;local beforeRequests=requests;ui:_refreshFind(true)
ui:update(0)
check(ui._findNeedsLogin and ui.findIndex and #ui.findIndex.mods==0 and requests==beforeRequests,'guest browsing is gated before cached metadata or network requests are used')
local account=false;ui._openAccount=function() account=true end
ui:_findConfirmInstall(card)
check(account and not ui._communityLatestJob,'installing still requires the native account login before a download begins')
check(C.compatibility({_communityResolved=true,api=99,game_version='>=0.1.0'})=='INCOMPATIBLE','future APIs receive an explicit incompatibility status')
check(C.compatibility({})=='NOT VERIFIED','missing information never claims verified gameplay compatibility')
check(C.compatibility({game_version='Not documented'})=='NOT VERIFIED','missing version documentation is not reported as a proven incompatibility')
Index.readCache,Index.writeCache,Index.cacheFresh=oldRead,oldWrite,oldFresh
ui.mods={{id='first',github='Author/Shared',version='1.0.0'},{id='second',github='author/shared',version='1.0.0'}}
ui:_syncModUpdateInfo(true)
check(#ui._communityUpdateQueue==1,'startup checks each repository once even when several mods share it')
response=Json.encode({{tag_name='v2.0.0',assets={{name='first-2.0.0.zip',browser_download_url='https://github.com/Author/Shared/releases/download/v2.0.0/first-2.0.0.zip'},
  {name='second-2.0.0.zip',browser_download_url='https://github.com/Author/Shared/releases/download/v2.0.0/second-2.0.0.zip'}}}})
C.backgroundUpdates()
local pending=ui._communityUpdateJob
ui:play('red')
check(ui.launched and ui._communityUpdateJob==pending,'starting a game preserves the public repository check')
C.backgroundUpdates()
check(ui.modUpdateInfo.first.status=='available' and ui.modUpdateInfo.second.status=='available','background completion updates every installed mod from the same repository')
check(ui.modUpdateInfo.first.best.zip.name=='first-2.0.0.zip' and ui.modUpdateInfo.second.best.zip.name=='second-2.0.0.zip','a shared repository still selects and caches the correct ZIP for each individual mod')
check(not C._updateOwner,'completed startup checks release their old launcher instance')
local L=require('src.mods.LauncherMods');local oldList,oldInstall=L.list,L.installFromRelease
local installed={{id='first',github='Author/Shared',version='1.0.0'}}
local sourceScans=0
L.list=function() sourceScans=sourceScans+1;return installed end
local D=require('src.mods.ModDownload');local oldStart=D.start;local starts,cancelled,installs=0,0,0
D.start=function() starts=starts+1;return {cancel=function() cancelled=cancelled+1 end,poll=function() return {kind='progress',bytes=0} end} end
L.installFromRelease=function() installs=installs+1;return true,'2.0.0' end
ui.mods=installed;signedIn=false;account=false
ui:_confirmModUpdate('first',release('2.0.0','Author/Shared'))
check(ui._communityDownload and starts==1 and not account,'guest update buttons start a direct download for a real installed mod without opening login')
ui:update(0);ui:update(0)
check(sourceScans==1,'guest downloads do not scan every installed manifest on every progress frame')
installed[1].github='Other/Project';ui._communityDownload.phase='install';ui._communityDownload.path='downloads/fixture.zip';ui:update(0)
check(not ui._communityDownload and cancelled==1 and installs==0,'repository identity is checked again before replacement and a changed source cancels safely')
signedIn=true;ui:_communityStartDownload('new-mod',release('2.0.0','Author/Shared'),'New mod','Author/Shared')
signedIn=false;ui:update(0)
check(not ui._communityDownload and installs==0,'a new online install cannot finish after sign-out through the guest update exception')
D.start=oldStart;L.list=oldList;L.installFromRelease=oldInstall
print('Launcher community: '..checks..' checks passed')

-- A Task timeout terminates the coroutine before its HTTP fallback can run.
-- The last valid metadata must already be visible before the worker starts.
signedIn=true;options.modCompassEnabled=true
Index.writeCache(C.FEED,parsed);ui.findIndex=nil
local Tasks=require('src.cloud.Task');local taskNew=Tasks.new
Tasks.new=function()return {cancel=function()end,poll=function()return {kind='error',error='Fixture timeout'}end}end
ui:_refreshFind(true)
check(#ui.findIndex.mods==1 and ui.findIndex.mods[1].title==parsed.mods[1].title,'cached mod cards are immediately available while a forced refresh is pending')
ui:update(0)
check(#ui.findIndex.mods==1 and not ui.findNotice.ok and ui.findNotice.text:find('saved catalogue',1,true),'worker timeouts retain catalogue cards and explain retry instead of reporting an empty search')
Tasks.new=taskNew
print('Catalogue timeout recovery: 2 checks passed')
