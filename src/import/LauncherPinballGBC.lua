-- Separate GBC cartridge backend; integration by Roxas2712.
local M={}
local function exists(path)local f=type(path)=='string'and io.open(path,'rb');if not f then return false end;f:close();return true end
function M.session(locale)
 if locale and locale~='en'then return end
 local root=os.getenv('ASCENDANT_PINBALL_GBC_ROOT')or require('src.pinball.Backend').root()
 if not root then return end
 local f=io.open(root..'/.local/pinball-gbc/library.json','rb');if not f then return end
 local bytes=f:read('*a');f:close()
 local ok,data=pcall(require('src.link.Json').decode,bytes)
 if ok and type(data)=='table'and data.schema==1 and data.ready and data.rom_sha1=='9402014d14969432142abfde728c6f1a10ee4dac'and exists(data.bridge)and exists(data.rom)and type(data.player)=='string'then
  if os.getenv('OA_QA_IDENTITY')then data.player=root..'/.local/pinball-gbc/test-player' end
  return data
 end
end
function M.available()return M.session()~=nil end
return M
