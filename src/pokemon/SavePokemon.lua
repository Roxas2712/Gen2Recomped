-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Walk real save slots only; arbitrary mod data is never a Pokemon registry.
local M={}
function M.each(save,visit,source)
  if type(save)~='table' or type(visit)~='function' then return end
  local function slots(values)
    if type(values)~='table' then return end
    local iterator=source and ipairs or pairs
    for _,mon in iterator(values)do visit(mon)end
  end
  slots(save.party)
  for _,box in pairs(save.boxes or{})do
    if type(box)=='table' then slots(box.mons or box)end
  end
  local dc=save.dayCare
  if type(dc)=='table' then
    for _,side in ipairs{'man','lady'}do
      if type(dc[side])=='table' and dc[side].mon then visit(dc[side].mon)end
    end
    if dc.egg then visit(dc.egg)end
  end
  dc=save.daycare
  if type(dc)=='table' then
    if dc.mon then visit(dc.mon)end
    local breed=dc.breed
    if type(breed)=='table' then
      for _,side in ipairs{1,2}do
        if type(breed[side])=='table' and breed[side].mon then visit(breed[side].mon)end
      end
      if breed.egg then visit(breed.egg)end
    end
  end
end
return M
