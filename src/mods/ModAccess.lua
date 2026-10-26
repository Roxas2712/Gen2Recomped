-- Guest updates are scoped to a real installed manifest and its recorded
-- original repository. This exception never authorizes a new remote mod.
local M={}
local Manifest=require('src.mods.Manifest')
local Semver=require('src.mods.Semver')
function M.repository(mod,options)
 local source=options and options.modInstallSources and options.modInstallSources[mod.id]
 local candidate=mod.github or source and source.version==mod.version and source.repo
 local ok,repo=pcall(Manifest.parseGithub,candidate)
 return ok and repo or nil
end
function M.updateAllowed(id,release,repo,installed,options)
 local current
 for _,mod in ipairs(installed or {}) do if mod.id==id then current=mod;break end end
 if not current then return nil,'Sign in to download a new mod. Manual ZIP imports and local play do not need an account.' end
 if current.updateCheck==false then return nil,'This installed mod has disabled repository updates.' end
 local original=M.repository(current,options)
 local ok,requested=pcall(Manifest.parseGithub,repo)
 if not original or not ok or not requested or original:lower()~=requested:lower() then return nil,'The update repository does not match the installed mod.' end
 local url=release and release.zip and release.zip.url
 local prefix='https://github.com/'..original..'/releases/download/'
 if type(url)~='string' or url:sub(1,#prefix):lower()~=prefix:lower() or url:find('..',1,true) or url:find('[?#]') or not url:lower():match('%.zip$') then
  return nil,'Updates must use a release ZIP from the installed mod’s original repository.'
 end
 local comparison=Semver.compare(release.version,current.version)
 if not comparison or comparison<=0 then return nil,'Guest updates require a newer version of the installed mod.' end
 return true
end
function M.checkUpdate(id,release,repo)
 return M.updateAllowed(id,release,repo,require('src.mods.LauncherMods').list(),require('src.core.SaveData').loadOptions())
end
return M
