-- Legacy GSC slot queries use the native weighted-table selector. Walking
-- still owns its rate roll, repel and water-level adjustment.
local Native=require('src.world.Encounter')
local E={}
local function rng(random)
  if not random then return nil end
  return function(lo,hi) return lo+random(hi-lo+1) end
end
function E.grassSlot(enc,map,tod,random)
  local row=enc and enc.grass and enc.grass[map]
  if not row then return nil end
  local slots=row.slots
  if type(slots)=='table' and #slots==0 then slots=slots[tod or 'DAY'] end
  return slots and Native.chooseTable({slots=slots,buckets=row.buckets,bucketSpan=row.bucketSpan},rng(random))
end
function E.waterSlot(enc,map,random)
  local row=enc and enc.water and enc.water[map]
  return row and Native.chooseTable(row,rng(random))
end
return E
