-- Build address-only native language recipes from a matching Gen1 source tree.
-- No cartridge text, graphics, or save data is written to these files.
local modRoot,reference,romDir=assert(arg[1]),assert(arg[2]),assert(arg[3])
package.path=reference..'/?.lua;'..package.path
local W=require('src.import.LuaWriter')
local Versions=require('src.import.gba.versions')
local function write(game,suffix,value)
  local f=assert(io.open('src/translation/rompack/addresses/'..game..suffix..'.lua','w'))
  f:write('-- Address metadata from Gen1Recomp (GPL-3.0); no cartridge payload.\n',W.encode(value));f:close()
end
local roms={ruby='Pokemon - Ruby Version (USA).gba',sapphire='Pokemon - Sapphire Version (USA).gba',leafgreen='Pokemon - LeafGreen Version (USA).gba'}
for _,game in ipairs({'ruby','sapphire','leafgreen'}) do
  require('src.core.GameVersion').set(game)
  Versions.select(game)
  local map={}
  if game=='leafgreen' then
    for label,off in pairs(Versions.NAMED_TEXTS) do map[label]=off end
  else
    local syms=require('src.import.gba.syms').of(game)
    for _,entry in ipairs(dofile(modRoot..'/mod/catalog.lua')) do if entry.game==game then
      for label in pairs(dofile(modRoot..'/mod/'..entry.profile).texts) do
        local ok,off=pcall(syms.off,label)
        if ok and off then map[label]=off end
      end
    end end
  end
  write(game,'',map)
  local source=dofile(modRoot..'/mod/profiles/'..game..'_assets.lua')
  local fields={__symbolOff={}}
  for key in pairs(source.fields) do fields[key]=assert(Versions[key],key) end
  for name in pairs(source.symbols.off or{}) do
    local ok,off=pcall(function() return Versions.SYMS and Versions.SYMS.off(name) or Versions.sym(name) end)
    if ok and off then fields.__symbolOff[name]=off end
  end
  write(game,'_assets',fields)
  local file=assert(io.open(romDir..'/'..roms[game],'rb'));local bytes=file:read('*a');file:close()
  local rom=setmetatable({_raw=bytes,size=#bytes},{__index=require('src.import.gba.rom')})
  local version=assert(Versions.lookup(require('src.core.GameVersion').info().sha1))
  local catalog=require('src.import.gba.map_catalog');catalog.rebuildIndex()
  local census=assert(require('src.import.gba.map_tree').walk(rom,version))
  local order,by=catalog.allOrder(census,{})
  catalog.registerOrder(rom,version,order,by)
  local world={maps={},pairs={}}
  for _,id in ipairs(order) do
    local pair=Versions.MAPS[id].pair;world.maps[id]=pair
    local p=Versions.TILESET_PAIRS[pair]
    world.pairs[pair]={primary=Versions.TILESETS[p.primary],secondary=Versions.TILESETS[p.secondary]}
  end
  write(game,'_world',world)
  print('NATIVE_LANGUAGE_METADATA',game,#order)
end
