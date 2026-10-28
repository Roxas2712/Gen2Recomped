package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.harness')
local Check = require('src.update.Check')
local Json = require('src.link.Json')
local Repository = require('src.update.Repository')
T.eq(Check.REPO, 'Roxas2712/Gen2Recomped', 'temporary fork target')
T.eq(Repository.SLUG, Check.REPO, 'news fallback and checker share one repository')
T.eq(Check.apiUrl(), 'https://api.github.com/repos/Roxas2712/Gen2Recomped/releases?per_page=30', 'API includes published previews')
T.eq(Check.releaseUrl(), 'https://github.com/Roxas2712/Gen2Recomped/releases', 'landing page includes previews')

local function metadata(id, version)
  return Json.encode({releaseId=id, engineVersion=version, sourceCommit=string.rep('a',40)})
end
local function preview(id, version)
  local tag='native-preview-'..id
  local url='https://github.com/'..Check.REPO..'/releases/download/'..tag..'/build-manifest.json'
  local body=metadata(id,version)
  return {tag_name=tag,prerelease=true,assets={{name='build-manifest.json',browser_download_url=url,size=#body}}}, url, body
end
local old, oldUrl, oldBody=preview('20261027.5','0.8.52')
local nextRelease, nextUrl, nextBody=preview('20261027.7','0.8.53')
local draft=preview('20261027.8','99.0.0');draft.draft=true
local calls={}
local function fetch(url)
  calls[#calls+1]=url
  return ({[oldUrl]=oldBody,[nextUrl]=nextBody})[url]
end
local rel=assert(Check.parseReleaseFeed(Json.encode({old,draft,nextRelease,{tag_name='ui-hotfix-20261027.2'}}),Json,fetch))
T.eq(#calls,1,'only newest published preview manifest is fetched')
T.eq(calls[1],nextUrl,'manifest request stays in this fork')
T.eq(rel.version,'0.8.53','engine version comes from manifest rather than date tag')
T.eq(rel.releaseId,'20261027.7','preview sequence retained')
T.eq(rel.payload,nil,'preview cannot become a normal sideload payload')
T.eq(rel.apk,nil,'preview cannot enter the regular Android installer path')
local current=assert(Check.previewMetadata(metadata('20261027.6','0.8.53'),Json))
T.eq(Check.compareRelease(rel,'0.8.53',current),1,'same-engine newer preview is detected')
T.eq(Check.compareRelease(rel,'0.8.53',{version='0.8.53',releaseId='20261027.7'}),0,'current preview stays current')
T.eq(Check.compareRelease(rel,'0.8.53',{version='0.8.53',releaseId='20261027.8'}),-1,'older preview never offered')
T.eq(Check.compareRelease(rel,'0.8.54',current),-1,'preview date never causes engine downgrade')
T.eq(Check.compareRelease(rel,'0.8.53',nil),0,'regular same-version build is not treated as an older preview')
T.eq(Check.previewMetadata(nextBody,Json,'20261027.6'),nil,'manifest must match release tag')
T.eq(Check.previewMetadata('{broken',Json),nil,'malformed manifest rejected')
T.eq(Check.previewMetadata(Json.encode({releaseId='20261027.7',engineVersion='20261027.7',sourceCommit=string.rep('a',40)}),Json),nil,'date is not semver')
local stable={tag_name='v0.8.54',assets={}}
local selected=assert(Check.parseReleaseFeed(Json.encode({nextRelease,stable}),Json,fetch))
T.eq(selected.version,'0.8.54','newer stable release remains available')
T.eq(selected.kind,nil,'stable release keeps original protocol')
T.eq(assert(Check.parseReleaseFeed(Json.encode({nextRelease,{tag_name='v0.8.53',assets={}}}),Json,fetch)).kind,'native-preview','preview sequence remains visible beside same-version stable tag')
T.eq(assert(Check.parseReleaseFeed(Json.encode(stable),Json)).version,'0.8.54','old single-release response remains supported')
local invalid=preview('20261027.7','0.8.53');invalid.assets[1].browser_download_url='https://github.com/UNDERdecoded/Gen2Recomped/releases/download/native-preview-20261027.7/build-manifest.json'
local forbidden=0
T.eq(Check.parseReleaseFeed(Json.encode({invalid}),Json,function()forbidden=forbidden+1 end),nil,'foreign manifest rejected')
T.eq(forbidden,0,'foreign repository never fetched')
invalid=preview('20261027.7','0.8.53');invalid.assets[1].size=1024*1024
T.eq(Check.parseReleaseFeed(Json.encode({invalid}),Json,function()forbidden=forbidden+1 end),nil,'oversized manifest rejected')
T.eq(forbidden,0,'oversized manifest never fetched')

-- Execute the actual worker command loop with an in-memory HTTPS transport.
local function worker(remote, url, manifest, version, installedId, expectedRequests, android, appOutdated)
  local savedLove=love
  local names={'love.thread','love.filesystem','love.data','love.timer','love.system',
    'src.update.Check','src.update.Repository','src.update.Semver','src.update.Payload'}
  local loaded,preload={},{ }
  for _,name in ipairs(names)do loaded[name]=package.loaded[name];preload[name]=package.preload[name] end
  local states,requests,channels={},{},{}
  local queue={{cmd='check',android=android,appOutdated=appOutdated},{cmd='quit'}}
  channels.update_check_cmd={demand=function()return table.remove(queue,1)end}
  channels.update_check_state={push=function(_,value)states[#states+1]=value end}
  local shell={transport=function()return 'curl'end,popen=function(command)
    local requested=assert(command:match("'([^']+)'$"));requests[#requests+1]=requested
    local body=requested==Check.apiUrl()and Json.encode({remote})or requested==url and manifest
    assert(body,'unexpected request '..requested)
    return {read=function()return body end,close=function()return true end}
  end}
  love={thread={getChannel=function(name)
    channels[name]=channels[name]or {};return channels[name]
  end},system={getOS=function()return 'OS X'end},data={},timer={},filesystem={
    getSaveDirectory=function()return '/isolated' end,
    load=function(path)
      if path=='src/core/HostShell.lua'then return function()return shell end end
      if path=='src/core/Version.lua'then return function()return {engine=version}end end
      return assert(loadfile(path))
    end,
    read=function(path)if path=='src/preview/release.json'and installedId then return metadata(installedId,version)end end,
    getInfo=function()return nil end,
    remove=function()error('preview must not modify installed files')end}}
  for _,name in ipairs(names)do
    if name:match('^love%.')then package.loaded[name]=nil;package.preload[name]=function()return true end end
  end
  local ok,err=pcall(dofile,'src/update/check_worker.lua')
  love=savedLove
  for _,name in ipairs(names)do package.loaded[name]=loaded[name];package.preload[name]=preload[name]end
  T.check(ok,'actual worker completes: '..tostring(err))
  T.eq(requests[1],Check.apiUrl(),'actual worker queries fork release list')
  T.eq(#requests,expectedRequests or 2,'worker uses only the expected release/manifest requests')
  return states[#states]
end
local state=worker(nextRelease,nextUrl,nextBody,'0.8.53','20261027.6')
T.eq(state.status,'needs_full','actual worker announces new preview without installing')
T.eq(state.latest,'0.8.53 (20261027.7)','banner distinguishes same-engine preview builds')
state=worker(nextRelease,nextUrl,nextBody,'0.8.53','20261027.7')
T.eq(state.status,'uptodate','actual worker recognizes installed preview')
state=worker(old,oldUrl,oldBody,'0.8.53','20261027.6')
T.eq(state.status,'uptodate','actual worker refuses preview downgrade')
state=worker(nextRelease,nextUrl,nextBody,'0.8.53','20261027.7',2,true,true)
T.eq(state.status,'needs_full','older Android shell still needs the current full preview package')
state=worker(old,oldUrl,oldBody,'0.8.53','20261027.6',2,true,true)
T.eq(state.status,'uptodate','older Android shell cannot trigger engine downgrade')
state=worker({tag_name='v0.8.54',assets={
  {name='Gen2Recomped-0.8.54.love',browser_download_url='https://example.test/game.love',size=10},
  {name='sha256sums.txt',browser_download_url='https://example.test/sums',size=10},
}},nil,nil,'0.8.53',nil,1)
T.eq(state.status,'available','actual worker retains regular verified-payload update route')
T.eq(state.latest,'0.8.54','regular version remains semver')

-- A fresh fork check must not keep six-hour-old upstream news from a cache.
local Sidebar=require('src.import.LauncherSidebar')
T.eq(Sidebar.newsUrls().repo,Check.REPO,'sidebar uses fork route')
local savedLove,savedShell=love,package.loaded['src.core.HostShell']
local cache={repo='UNDERdecoded/Gen2Recomped',at=os.time(),items={{title='upstream'}}}
local writes,requests=0,{}
love={filesystem={load=function()return function()return cache end end,write=function()writes=writes+1;return true end}}
package.loaded['src.core.HostShell']={canFetch=function()return true end,httpGet=function(url)
  requests[#requests+1]=url
  if url==Sidebar.newsUrls().feed then return Json.encode({items={{title='fork'}}})end
  return '[]'
end}
local news=Sidebar.fetchNews(false)
T.eq(news.repo,Check.REPO,'replacement cache records source repository')
T.eq(news.items[1].title,'fork','cached upstream entry is not reused')
T.eq(#requests,2,'old upstream cache causes fresh fork requests')
T.eq(writes,1,'only derived news cache is refreshed')
cache={repo=Check.REPO,at=os.time(),items={{title='own cached news'}}}
local before=#requests
news=Sidebar.fetchNews(false)
T.eq(news.items[1].title,'own cached news','same-repository fresh cache remains usable')
T.eq(#requests,before,'same-repository cache avoids network requests')
cache={repo='UNDERdecoded/Gen2Recomped',at=os.time(),items={{title='upstream'}}}
package.loaded['src.core.HostShell'].canFetch=function()return false end
T.eq(#Sidebar.fetchNews(false).items,0,'offline fallback cannot revive upstream cache')
love=savedLove;package.loaded['src.core.HostShell']=savedShell
T.finish('temporary fork update channel and actual worker routing')
