-- Both animation and audio generation read this same cue sheet.
local path='assets/launcher/intro_score.json'
local raw=love and love.filesystem and love.filesystem.read(path)
if not raw then
  local file=io.open(path,'rb')
  if file then raw=file:read('*a');file:close() end
end
return assert(require('src.link.Json').decode(assert(raw,'Missing intro cue sheet')))
