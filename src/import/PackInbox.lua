-- Files/iTunes sharing, Android storage and console MTP all reach this same
-- relative inbox. Never move or delete the user's source pack directories.
local Importers=require("src.import.Importers")
local Inbox={ROOT="imports/asset_packs"}
function Inbox.start(fs)
  fs=Importers.fs(fs)
  local queue={}
  for _,desc in ipairs(Importers.all()) do
    for _,pack in ipairs(desc.packs) do
      local root=Inbox.ROOT.."/"..desc.id.."/"..pack.id
      if fs.getInfo(root.."/"..Importers.PACK_FILE,"file") then
        queue[#queue+1]={importer=desc.id,pack=pack.id,root=root}
      end
    end
  end
  return coroutine.create(function()
    local installed,failed={},{}
    for _,item in ipairs(queue) do
      local co=Importers.install(item.importer,item.pack,fs,item.root,fs)
      while true do
        local ok,value=coroutine.resume(co)
        if not ok then
          failed[#failed+1]={importer=item.importer,pack=item.pack,error=tostring(value)}; break
        end
        if coroutine.status(co)=="dead" then installed[#installed+1]=value; break end
        value.importer,value.pack=item.importer,item.pack
        coroutine.yield(value)
      end
    end
    return {installed=installed,failed=failed,found=#queue}
  end)
end
return Inbox
