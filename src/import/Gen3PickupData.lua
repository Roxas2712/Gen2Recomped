-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Import Pickup's item indices and cumulative thresholds from this ROM.
local M={}
function M.extract(rom,manifest,sha1,edition)
 local profile=require('src.import.Gen3PickupProfiles').get(edition,sha1)
 if not(profile and manifest and manifest.romSha1==sha1)then return nil,'unverified Pickup cartridge'end
 local ok,result=pcall(function()
  local function values(at,count,width)
   assert(type(at)=='number'and at>=0 and at+count*width<=rom.size,'Pickup ROM bounds')
   local out={}
   for i=1,count do out[i]=width==2 and rom:u16(at+(i-1)*width)or rom:u8(at+i-1)end
   return out
  end
  local out={schema=1,edition=edition,romSha1=sha1,style=profile.style}
  if profile.style=='fixed'then
   out.items,out.thresholds={},{}
   assert(profile.items+profile.count*4<=rom.size,'Pickup ROM bounds')
   for i=1,profile.count do
    out.items[i]=rom:u16(profile.items+(i-1)*4)
    if i<profile.count then
     local at=profile.items+(i-1)*4+2
     out.thresholds[i]=profile.wide and rom:u16(at)or rom:u8(at)
    end
   end
  else
   out.common=values(profile.common,18,2);out.rare=values(profile.rare,11,2)
   out.thresholds=values(profile.cuts,9,1)
   out.pyramid={level50=values(profile.pyramid50,200,2),open=values(profile.pyramidOpen,200,2),
    thresholds=values(profile.pyramidCuts,10,1)}
  end
  return out
 end)
 if not ok then return nil,tostring(result)end
 return result
end
return M
