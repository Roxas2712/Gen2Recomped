-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Fill missing display metadata in older fork imports. Rules and saves stay
-- native; roof RGB5 pairs are the shared G/S/C cartridge RoofPals table.
local P={}
function P.apply(data,roofColors)
 local field=data.field;if not field or field.gen2Roofs then return 0 end
 local native=field.gen2MapPalettes or{};local sets,rules={},{}
 for k,v in pairs(native.sets or{})do sets[k]=v end
 for i,v in ipairs(native.rules or{})do rules[i]=v end
 local count=0
 for id,map in pairs(data.maps or{})do
  local pair=roofColors[map.group];local ts=data.tilesets and data.tilesets[map.tileset]
  if pair and ts and ts.palMap and(map.environment==1 or map.environment==2)then
   local key='ula-roof:'..map.tileset..':'..map.group
   if not sets[key]then
    local rows={}
    for _,tod in ipairs({'MORN','DAY','NITE'})do
     local base=ts.palColorsByTod and ts.palColorsByTod[tod]or ts.palColors
     if base and base[7]then
      local copy={};for i,pal in ipairs(base)do copy[i]={};for j,color in ipairs(pal)do copy[i][j]=color end end
      for j,color in ipairs(pair[tod=='NITE'and 2 or 1])do
       local rgb={};for c=1,3 do rgb[c]=math.floor(color[c]*255/31+.5)end
       copy[7][j+1]=rgb
      end
      rows[tod]=copy
     end
    end
    sets[key]=rows
   end
   rules[#rules+1]={kind='map',group=map.group,number=map.number,set=key};count=count+1
  end
 end
 field.gen2MapPalettes={sets=sets,rules=rules};return count
end
return P
