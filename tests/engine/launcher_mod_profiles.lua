package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(value,why) assert(value,why);n=n+1 end
local options={mods={old=true},modInstallSources={}}
local installed={{id='old',version='1.0.0',github='author/old'}}
local sequence,removed={},{}
local failId,changed,recovered,accepted
local function event(name) sequence[#sequence+1]=name end
package.loaded['src.core.SaveData']={persistenceFs=function() return {read=function() end} end,loadOptions=function() return options end,saveOptions=function(value) options=value;return true end}
package.loaded['src.mods.ModProfiles']={
  plan=function(profile,_,resume) return {profile=profile,downloads=profile.mods,flags={},hash='remote',resume=resume} end,
  unchanged=function() return not changed end,
  accept=function() event('accept');accepted=true;return true end,
}
local packages={list=function() return installed end,
  backupProfile=function(ids) event('backup');return {ids=ids,mods={old=true}} end,
  installFromRelease=function(id,release,path)
    event('install:'..id)
    if failId==id then return nil,'injected write failure' end
    return true,release.version
  end,
  restoreProfile=function() event('restore');recovered=true;return true end,
  finishProfile=function() event('finish');return true end,
}
package.loaded['src.mods.LauncherMods']=packages
package.loaded['src.mods.ModDownload']={start=function(release)
  event('download:'..release.tag)
  return {cancel=function() event('cancel') end,poll=function() return {kind='done',path='temporary-'..release.tag,digest=string.rep('a',64)} end}
end}
package.loaded['src.cloud.Task']={new=function(fn)
  return {cancel=function() end,poll=function() local a,b=fn();return {kind='done',first=a,second=b} end}
end}
local requested={}
local docs={}
package.loaded['src.cloud.Http']={form=function(q) return 'version='..q.version..'&tag='..q.tag end,
  request=function(_,url) requested[#requested+1]=url;return 200,docs[url] end}
package.loaded['src.link.Json']={decode=function(doc) return doc end}
package.loaded['src.import.LauncherCommunity']={resolve=function(entry,doc) if not doc then return nil end;entry.id=doc.id;return true end}
love.filesystem.remove=function(path) removed[path]=true;return true end
local UI={_ui={inside=function(rect,x) return rect and rect.x==x end},_settingsAction=function() end,
  mousepressed=function() end,play=function(self) self.played=true end,_sbBackdropWant=function() return true end,
  _drawModsPanel=function() end,_drawFindPanel=function() end,_sbGames=function() end,update=function() end,
  new=function() return {} end,_refreshMods=function(self) self.refreshed=true end,_ensureFind=function() end,
}
local M=require('src.import.LauncherModProfiles');M.install(UI)
local wanted={}
for i=1,2 do
  local id='mod'..i;local repo='author/'..id;local url='https://pokexpert.de/api/launcher/mods/'..id
  wanted[i]={id=id,repo=repo,version='1.0.0',tag='v1.0.0'}
  docs[url..'/latest?version=1.0.0&tag=v1.0.0']={id=id,releases={{version='1.0.0',tag='v1.0.0',zip={url='https://github.com/'..repo..'/releases/download/v1.0.0/mod.zip'}}}}
end
local function ui()
  local value=setmetatable({findLoaded=true,findIndex={mods={}}},{__index=UI})
  for _,m in ipairs(wanted) do value.findIndex.mods[#value.findIndex.mods+1]={github=m.repo,catalogueId=m.id,resolveUrl='https://pokexpert.de/api/launcher/mods/'..m.id} end
  return value
end
local function drain(value)
  for _=1,30 do if not value._profileApplying then return end;value:update(0) end
  error('profile did not terminate')
end
local plan={kind='apply',profile={mods=wanted},hash='remote',scope='account'}
local first=ui();first:_communityApplyProfile(plan);drain(first)
check(accepted and not first._profileApplying,'a complete profile commits after all package installs')
local stages=table.concat(sequence,',')
check(stages:find('download:v1.0.0,download:v1.0.0,backup,install:mod1,install:mod2,accept,finish',1,true),'all packages are staged before any installed mod changes')
check(options.modInstallSources.mod2.repo=='author/mod2' and #options.modInstallSources.mod2.sha256==64,'actual verified package provenance is retained')
check(requested[1]:find('/latest?version=1.0.0&tag=v1.0.0',1,true),'profile restore requests the pinned tag, not the newest release')
sequence={};accepted=false;recovered=false;failId='mod2'
local failing=ui();failing:_communityApplyProfile(plan);drain(failing)
check(recovered and not accepted and not failing._profileApplying,'a second package failure restores the whole previous profile')
check(table.concat(sequence,','):find('install:mod1,install:mod2,restore',1,true),'an earlier successful package is included in rollback')
sequence={};failId=nil;changed=true
local stale=ui();stale:_communityApplyProfile(plan)
check(not stale._profileApplying and #sequence==0,'a local edit since sync prevents automatic replacement')
changed=false;local editing=ui();editing:_communityApplyProfile(plan)
for _=1,10 do if editing._profileApplying.stage=='backup' then break end;editing:update(0) end
changed=true;sequence={};editing:update(0)
check(not editing._profileApplying and #sequence==0,'a local edit during download is checked again before preserving or replacing files')
changed=false;local conflict=ui();plan.kind='conflict';conflict:_communityApplyProfile(plan)
check(not conflict._profileApplying and conflict._modProfilePlan==plan,'conflicting devices require explicit review even with auto-download enabled')
plan.kind='apply';local playing=ui();playing:_communityApplyProfile(plan);playing:play()
check(not playing.played,'game launch cannot load a partly applied mod stack')
playing._profileApplying=nil;playing._profileRecoveryBlocked=true;playing:play()
check(not playing.played,'an unfinished recovery also blocks game hand-off')
local save={fingerprint='approved'}
package.loaded['src.core.SaveData'].peekSlot=function() return save end
package.loaded['src.core.SaveData'].activeSlot=function() return 'slot1' end
package.loaded['src.storage.SaveResume']={fingerprint=function(value) return value.fingerprint end}
plan.resume={generation=1,required={'mod1','mod2'}}
local changedSave=ui();changedSave._resumeRestore={version='red',slot='slot1',fingerprint='approved'}
changedSave:_communityApplyProfile(plan,true)
check(changedSave._profileApplying.plan.resume.generation==1,'the save generation survives the fresh package plan')
for _=1,30 do if changedSave._profileApplying.stage=='backup' then break end;changedSave:update(0) end
save.fingerprint='changed';sequence={};accepted=false;changedSave:update(0)
check(not changedSave._profileApplying and #sequence==0 and not accepted,'a save changed during download is refused before any mod backup or replacement')
print('Launcher mod profiles: '..n..' checks passed')
