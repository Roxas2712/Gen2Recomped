local job,channel=...
package.path=job.packagePath or package.path
require('love.system');require('love.filesystem')
local ok,why=pcall(function()
  assert(job.url:match('^https://archives%.bulbagarden%.net/media/upload/')
    or job.url:match('^https://pokexpert%.de/launcher/cartridges/v1/[%w_%-]+%.png$')
    or job.preview and (job.url:match('^https://pokexpert%.de/') or job.url:match('^https://i%.ytimg%.com/')), 'Invalid artwork source.')
  local saved,reason=require('src.core.HostShell').httpDownload(job.url,job.absolute,'RetroRecomped/1.0','image/png',{maxBytes=8*1024*1024})
  if not saved then error(reason or 'The source could not provide the image.',0) end
end)
if not ok then love.filesystem.remove(job.path) end
channel:push(ok and {kind='done'} or {kind='error',error=tostring(why)})
