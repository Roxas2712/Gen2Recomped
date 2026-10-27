-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Record known facts at native creation. Never fill a transferred monster's
-- missing history with the destination game's identity.
local O={}
local GBA={sapphire=1,ruby=2,emerald=3,firered=4,leafgreen=5}
local DS={platinum=12,heartgold=7,soulsilver=8,white=20,black=21}
function O.stamp(save,mon,met,fresh)
 if not fresh or not met then return end
 local version=save.version or require('src.core.GameVersion').get()
 if GBA[version]then
  mon.gen3MetGame=mon.gen3MetGame or mon.metGame or GBA[version]
  mon.metGame=mon.metGame or mon.gen3MetGame
  if mon.gen3OtFemale==nil then mon.gen3OtFemale=save.player.gender=='girl'or save.player.gender=='female'or save.player.gender==1 end
  if mon.otGender==nil then mon.otGender=mon.gen3OtFemale and 1 or 0 end
 elseif DS[version]then
  mon.ndsGame=mon.ndsGame or DS[version]
 end
end
return O
