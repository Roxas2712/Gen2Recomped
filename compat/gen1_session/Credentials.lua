-- Portable battle-seat credentials for a Gen1 peer's own profile filesystem.
-- Contributions by Roxas2712; see NOTICE.md. Never reads or edits adventure data.
local Json=require('src.link.Json')
local M={}
local function room(id)return type(id)=='string'and #id==8 and id:match('^[23456789ABCDEFGHJKMNPQRSTUVWXYZ]+$')end
function M.new(fs,scope)
  assert(type(scope)=='string'and #scope>0 and #scope<=256,'stable profile identity required')
  local dir='link/gen1-peer';local self={}
  function self:credentials(id,value)
    if not room(id)then return nil,'invalid room id'end
    local name=dir..'/'..id..'.json'
    if value then
      local out={scope=scope};for key,v in pairs(value)do out[key]=v end
      local bytes=Json.encode(out)
      if #bytes>32768 then return nil,'credential budget exceeded'end
      fs.createDirectory(dir)
      for _,file in ipairs{name..'.tmp',name}do
        local ok,why=fs.write(file,bytes);if not ok or fs.read(file)~=bytes then return nil,why or 'credential write did not verify'end
      end
      return true
    end
    for _,file in ipairs{name..'.tmp',name}do
      local bytes=fs.read(file)
      if bytes then
        if #bytes>32768 then return nil,'invalid credential size'end
        local doc=Json.decode(bytes)
        if type(doc)~='table'or doc.scope~=scope then return nil,'credentials belong to a different profile'end
        return doc
      end
    end
  end
  return self
end
return M
