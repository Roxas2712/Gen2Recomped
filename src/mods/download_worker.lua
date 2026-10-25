local job,channel=...
package.path=job.packagePath or package.path
require('love.system');require('love.filesystem');require('love.data');require('love.timer')
local ok,result=pcall(function()
  local Host=require('src.core.HostShell')
  local downloaded,why=Host.httpDownload(job.url,job.absolute,'RetroRecomped-ModCompass/1.0','application/octet-stream',{maxBytes=job.maxBytes})
  if not downloaded then error(why or 'Download failed.',0) end
  local info=love.filesystem.getInfo(job.path)
  if not info or info.size<=0 or info.size>job.maxBytes or job.size and info.size~=job.size then error('The ZIP download is incomplete or exceeds its size limit.',0) end
  local bytes=assert(love.filesystem.read(job.path))
  if bytes:sub(1,2)~='PK' then error('The server did not deliver a ZIP archive.',0) end
  local actual=love.data.encode('string','hex',love.data.hash('sha256',bytes))
  if job.digest then
    if actual~=job.digest then error('The ZIP fingerprint does not match the GitHub release. Nothing was installed.',0) end
  end
  return {kind='done',path=job.path,bytes=info.size,digest=actual,verified=job.digest~=nil}
end)
if not ok then love.filesystem.remove(job.path);result={kind='error',error=tostring(result)} end
channel:push(result)
