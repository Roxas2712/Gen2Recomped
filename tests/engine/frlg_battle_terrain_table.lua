package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local E=require('src.import.RomExtractorGen3')
local Json=require('src.link.Json')
for _,version in ipairs({'firered','leafgreen'})do
  local f=assert(io.open('tools/rom_manifest_'..version..'.json','rb'))
  local manifest=Json.decode(f:read('*a'));f:close()
  local first=manifest.symbols.sBattleTerrainTable
  local pointers,blobs={},{}
  for row=0,19 do
    for _,offset in ipairs({0,4,16})do
      local target=10000+row*300+offset*10
      pointers[first+row*20+offset]=target
      blobs[target]=offset==16 and{0,0}or{row+1}
    end
  end
  local rom={size=0x1000000}
  function rom:pointer(at)return pointers[at]end
  function rom:lz77(at)return blobs[at]end
  local images={};local decoded=0
  local x=setmetatable({version=version,manifest=manifest,symbols=manifest.symbols,rom=rom},E)
  function x:beginStage()end
  function x:battleBackgroundImage(tiles,map,palette)
    decoded=decoded+1;T.eq(tiles[1],decoded,'terrain order follows the edition table')
    T.eq(map[1],decoded);T.check(palette[33]~=nil)
    return{row=decoded}
  end
  function x:saveImage(image,path)images[path]=image.row end
  function x:write()end
  x:extractBattleBackgrounds()
  T.eq(decoded,20,'both editions compose every terrain')
  T.eq(images['battle/bg/grass.png'],1)
  T.eq(images['battle/bg/plain.png'],10)
  T.eq(images['battle/bg/champion.png'],20)
  T.eq(x._constants.gen3BattleTerrain.tableAt,first)
end
T.finish('FRLG edition-specific battle terrain table and all 20 scene rows')
