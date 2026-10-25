-- Companion to check_gen3_palette_programs.py. Python authenticates stdin's
-- exact bytes before this process runs. Data stages write only to local tables;
-- no source ROM/cache/save/image or installed runtime is created/modified.
package.path="./?.lua;./?/init.lua;"..package.path
require("tests.modkit")
local Json=require("src.link.Json")
local game,digest=assert(arg[1]),assert(arg[2])
local data=io.read("*a")
local file=assert(io.open("tools/rom_manifest_"..game..".json","rb"))
local manifest=Json.decode(file:read("*a"));file:close()
assert(digest==manifest.romSha1,"unsupported ROM digest")
local Version=require("src.core.GameVersion");Version.set(game)
local Extractor=require("src.import.RomExtractorGen3")
local Verify=require("src.import.RomVerification")
Verify.sha1=function(bytes) assert(bytes==data,"digest/input mismatch");return digest end
local stage=Extractor.new(data,Version.VERSIONS[game],manifest)
local captured={}
stage.write=function(_,name,value) captured[name]=value end
stage.tilesetSheet=function() return {} end;stage.saveImage=function() end
-- Map/script behaviour discovery is unrelated to this focused source test.
-- The real source-header, tile/frame and palette-program stages run below.
for _,name in ipairs({"counterBehaviour","pcBehaviour","wallBehaviours","warpBehaviours","diveTerrain",
  "waterfallTerrain","iceBehaviours","bikeBehaviours","escalatorBehaviours","currentBehaviours",
  "forcedMovementBehaviours","lavaridgeWarps","noRunBehaviours","checkBehaviourNames"}) do
  stage[name]=function() end
end
stage:extractMapLayouts();stage:extractTilesets();stage:extractTilesetAnimations();stage:extractTilesetPalettePrograms()
local report={game=game,sha1=digest,summary=stage._tilesets._romInfo.palettePrograms,
  pixelChecks=0,consumerApis={},paletteMetatiles=0,visiblePaletteChange=false}
assert(report.summary.unavailable==0,"some real ROM programs were not recognized")
assert(report.summary.animated==(game=="emerald" and 1 or 0),"unexpected real-ROM palette program count")
local selected
local keys={};for key in pairs(captured.tilesets) do if key~="_romInfo" then keys[#keys+1]=key end end;table.sort(keys)
for _,key in ipairs(keys) do
  local pair=captured.tilesets[key]
  local p,s=stage._tilesets[pair.primaryKey],stage._tilesets[pair.secondaryKey]
  if p and s and ((game=="emerald" and s.paletteProgram.status=="animated")
    or (game=="firered" and p.paletteProgram.id=="general")) then selected=pair;break end
end
assert(selected,"no representative real tileset pair")
local Tiles=require("src.render.Gen3Tiles")
local Copy=require("src.mods.Merge").deepCopy
local p,s=stage._tilesets[selected.primaryKey],stage._tilesets[selected.secondaryKey]
local layout=stage._constants.gen3Layout
local decoder=Tiles.new({primary=p,secondary=s},layout)
local mids,seen={},{}
local function add(mid) if not seen[mid] then mids[#mids+1]=mid;seen[mid]=true end end
if game=="emerald" then
  for mid=0,decoder:metatileCount()-1 do
    for _,entry in ipairs(decoder:entries(mid)) do
      if entry.palette==8 then add(mid);break end
    end
  end
  report.paletteMetatiles=#mids;assert(#mids>0,"floor palette must actually be used by terrain")
end
for mid=0,math.min(15,p.metatileCount-1) do add(mid) end
for mid=0,math.min(15,s.metatileCount-1) do add(layout.metatilesInPrimary+mid) end
for i,mid in ipairs(decoder:animatedMetatiles()) do if i<=16 then add(mid) end end
local function pixels(tiles,mid,layer)
  local out={};for i=1,256 do out[i]="\0\0\0\0" end
  tiles:drawLayer(mid,layer,0,0,function(x,y,r,g,b) out[y*16+x+1]=string.char(r,g,b,255) end)
  return table.concat(out)
end
local Renderer=require("src.render.TileRenderer")
local originalClock=Renderer.animFrame
for _,api in ipairs({1,2}) do
  local f=require("tests.terrain_animation.fixture").new(game,api,true)
  local state,e=f.state,f.exports
  state.game.data.map_tilesets=stage._tilesets
  state.game.data.constants.gen3Layout=layout
  state.map.tileset.primaryKey,state.map.tileset.secondaryKey=selected.primaryKey,selected.secondaryKey
  local expectedS=Copy(s)
  local expected=Tiles.new({primary=p,secondary=expectedS},layout)
  local native=Tiles.new({primary=p,secondary=s},layout)
  local firstPixels,firstTileFrame
  for tick=0,31 do
    Renderer.animFrame=function() return tick end
    local graphics,why=e.colors(1,state.mapId);assert(graphics,why)
    if game=="emerald" then
      -- Independent expected colours read directly from the raw source words,
      -- rather than the imported RGB strings or the shared palette sampler.
      local recipe=manifest.terrainPalettePrograms.programs[tostring(0xA1658)]
      local frame=math.floor(tick/4)%4
      local at=stage.rom:u32(recipe.table+frame*4)-0x08000000
      local pal={}
      for c=0,15 do
        local word=stage.rom:u16(at+c*2)
        pal[c+1]={math.floor((word%32)*255/31),math.floor((math.floor(word/32)%32)*255/31),
          math.floor((math.floor(word/1024)%32)*255/31)}
      end
      expectedS.palettes[9]=pal
    end
    expected:setAnimFrame(graphics.animation.frame)
    native:setAnimFrame(graphics.animation.frame);native:setPaletteTicks(tick)
    local selectedPixels={}
    for _,mid in ipairs(mids) do for layer=1,2 do
      local want=pixels(expected,mid,layer)
      assert(e.layer(graphics,mid,layer)==want,"public real-ROM RGBA mismatch")
      assert(pixels(native,mid,layer)==want,"native real-ROM RGBA mismatch")
      report.pixelChecks=report.pixelChecks+2
      if tick==0 or tick==4 then selectedPixels[#selectedPixels+1]=want end
    end end
    if tick==0 then firstPixels=table.concat(selectedPixels);firstTileFrame=graphics.animation.frame end
    if tick==4 and game=="emerald" then
      -- Compare at the same tile-animation picture. A changed picture here
      -- must come from the imported palette, not a coincident tile frame.
      assert(graphics.animation.frame==firstTileFrame,"palette visibility test requires identical tile picture")
      assert(table.concat(selectedPixels)~=firstPixels,"ROM palette cycle has no visible terrain effect")
      report.visiblePaletteChange=true
    end
  end
  report.consumerApis[#report.consumerApis+1]=api
  f.run.release()
end
Renderer.animFrame=originalClock
report.metatilesChecked=#mids;report.pair=selected.id
print("PALETTE_ROM_RESULT "..Json.encode(report))
