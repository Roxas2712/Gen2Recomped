-- Rebuild each base atlas with the matching language ROM's tilesets. Keep US
-- metatile IDs/order and map layouts, so scripts, collision and saves agree.
return function(private,rom,profile,base,files)
 local T=private('src.import.gba.tileset')
 local N=private('src.import.gba.native_pack')
 local root='data/generated/gba/native/'
 local manifest=assert(loadstring(assert(base:read(root..'manifest.lua'))))()
 local count=0
 for pair in pairs(manifest.pairs) do
  local specs=assert(profile.pairs[pair],'Language world profile lacks '..pair)
  local pri=T.loadOne(rom,specs.primary)
  local sec=T.loadOne(rom,specs.secondary)
  local bundle={primaryTiles=pri.tiles,secondaryTiles=sec.tiles,
   primaryMt=pri.mt,secondaryMt=sec.mt,primaryAttr=pri.attr,secondaryAttr=sec.attr,
   mapPals=T.mergeMapPalettes(pri.pals,sec.pals)}
  local path=root..pair..'/'
  local original=assert(N.decodeIdx(assert(base:read(path..'mids.idx'))))
  local under,over,middle=N.buildLayeredIdx(bundle,original.midIds)
  files[path..'mids.idx']=N.encodeIdx(under)
  files[path..'mids_over.idx']=N.encodeIdx(over)
  files[path..'mids_mid.idx']=N.encodeIdx(middle)
  files[path..'palettes.bin']=N.encodePalettes(bundle.mapPals)
  count=count+1
 end
 return count
end
