-- Run through the real main.lua POKEPORT_DRIVER path, in a fresh identity.
-- No mod renderer, replacement clock, synthetic map or existing player save.
return function(game)
local U = require("tests.drivers.util")
local Json = require("src.link.Json")
local TR = require("src.render.TileRenderer")
local Tiles = require("src.render.Gen3Tiles")
local Copy = require("src.mods.Merge").deepCopy
local version = assert(os.getenv("POKEPORT_VERSION"))
local out = assert(os.getenv("PALETTE_GPU_OUT"))
local identity = assert(os.getenv("POKEPORT_IDENTITY"))
assert(identity:match("^gen2%-palette%-gpu%-"))
assert(love.filesystem.getIdentity() == identity)
assert(require("src.core.SaveData").portableBaseDir() == nil)
assert(require("src.import.CacheFs").root() == nil)
local renderer, apiVersion, vendor, device = love.graphics.getRendererInfo()
assert(not device:lower():find("software") and not device:lower():find("llvmpipe"))
local report = { game = version, gpu = { renderer = renderer, version = apiVersion,
  vendor = vendor, device = device }, checks = 0, samples = {}, screenshots = {},
  isolation = { freshIdentity = true, legacyMigrationBypassed = true,
    externalCache = false, mods = false }, clock = "unmodified native draw clock" }
local major,minor,revision,codename=love.getVersion()
report.runtime={major=major,minor=minor,revision=revision,codename=codename}
local function writeReport()
  local f = assert(io.open(out .. "/gpu.json", "w"))
  f:write(Json.encode(report)); f:close()
end
local function check(ok, message)
  assert(ok, message); report.checks = report.checks + 1
end
local romFile = assert(io.open(assert(os.getenv("PALETTE_GPU_ROM")), "rb"))
local rom = romFile:read("*a"); romFile:close()
local digest = require("src.import.RomVerification").sha1(rom)
local manifest = Json.decode(assert(love.filesystem.read("tools/rom_manifest_" .. version .. ".json")))
check(digest == manifest.romSha1, "unexpected ROM revision")
report.sha1 = digest
local function u16(at) local a,b = rom:byte(at+1,at+2); return a+b*256 end
local function u32(at) return u16(at)+u16(at+2)*65536 end
local function sourcePalette(ticks)
  local recipe = manifest.terrainPalettePrograms.programs[tostring(0xA1658)]
  local at = u32(recipe.table + math.floor(ticks/4)%4*4) - 0x08000000
  local p = {}
  for c = 0,15 do
    local word = u16(at+c*2)
    p[c+1] = { math.floor(word%32*255/31),
      math.floor(math.floor(word/32)%32*255/31),
      math.floor(math.floor(word/1024)%32*255/31) }
  end
  return p
end
local function readTexture(image)
  local w,h = image:getDimensions()
  local canvas = love.graphics.newCanvas(w,h,{format="rgba8",msaa=0,readable=true,dpiscale=1})
  love.graphics.push("all")
  love.graphics.setCanvas(canvas); love.graphics.origin(); love.graphics.setShader()
  love.graphics.setScissor(); love.graphics.clear(0,0,0,0)
  love.graphics.setColor(1,1,1,1); love.graphics.setBlendMode("replace","premultiplied")
  love.graphics.draw(image)
  love.graphics.pop()
  local data = canvas:newImageData()
  local bytes = data:getString(); data:release(); canvas:release()
  return bytes,w
end
local function metatilePixels(tiles, mid, layer)
  local pixels = {}; for i=1,256 do pixels[i]="\0\0\0\0" end
  tiles:bakeMetatileInto(mid,layer,0,function(x,y,r,g,b)
    pixels[y*16+x+1]=string.char(r,g,b,255)
  end)
  return table.concat(pixels)
end
local function readSlot(bytes,width,slot)
  local x,y=slot%Tiles.SHEET_COLS*16,math.floor(slot/Tiles.SHEET_COLS)*16
  local rows={}
  for row=0,15 do local at=((y+row)*width+x)*4;rows[#rows+1]=bytes:sub(at+1,at+64) end
  return table.concat(rows)
end
local function pixelsEqual(actual,expected)
  if actual==expected then return true end
  for at=1,math.min(#actual,#expected) do
    if actual:byte(at)~=expected:byte(at) then
      print("[palette-gpu] first mismatch",at,actual:byte(at),expected:byte(at),#actual,#expected)
      break
    end
  end
  return false
end
local sceneProbe
local function sample(world, tag)
  local r=world.map.renderer
  local record=assert(r.gen3,"real map has no GPU sheets")
  local ticks=assert(record.paletteTicks)
  check(ticks==TR.animFrame(),"native texture did not follow the draw clock")
  local p,s=record.tiles.primary,record.tiles.secondary
  local expectedS=Copy(s)
  if version=="emerald" and s.paletteProgram.id=="battle-dome-floor" then
    expectedS.palettes[9]=sourcePalette(ticks)
  end
  local expected=Tiles.new({primary=p,secondary=expectedS},game.data.constants.gen3Layout)
  local mids,seen={},{}
  local function add(mid) if not seen[mid] then seen[mid]=true;mids[#mids+1]=mid end end
  for mid=0,math.min(15,p.metatileCount-1) do add(mid) end
  for mid=0,math.min(15,s.metatileCount-1) do add(expected.metatilesInPrimary+mid) end
  local paletteMetatiles=0
  local paletteIds={}
  if version=="emerald" and s.paletteProgram.id=="battle-dome-floor" then
    for mid=0,expected:metatileCount()-1 do
      for _,entry in ipairs(expected:entries(mid)) do
        if entry.palette==8 then add(mid);paletteIds[mid]=true;paletteMetatiles=paletteMetatiles+1;break end
      end
    end
  end
  local movers=expected:animatedMetatiles()
  for i=1,math.min(16,#movers) do add(movers[i]) end
  local count, packed = 0, {}
  for layer,image in ipairs({record.bottom,record.top}) do
    local bytes,width=readTexture(image)
    expected:setAnimFrame(0)
    for _,mid in ipairs(mids) do
      local actual=readSlot(bytes,width,mid)
      check(pixelsEqual(actual,metatilePixels(expected,mid,layer)),"GPU/base mismatch "..mid.." layer "..layer)
      count=count+256;packed[#packed+1]=actual
    end
    for i=1,math.min(16,#movers) do
      local mid=movers[i]
      for f=2,record.animFrames do
        expected:setAnimFrame(f-1)
        local actual=readSlot(bytes,width,record.animSlots[mid][f])
        check(actual==metatilePixels(expected,mid,layer),"GPU/animation mismatch "..mid.." frame "..f)
        count=count+256
      end
    end
  end
  local coverPixels=0
  if record.cover then
    local bytes,width=readTexture(record.cover)
    for mid,quads in pairs(record.coverQuads) do
      for frame,quad in ipairs(quads) do
        expected:setAnimFrame(frame-1)
        local want={};for i=1,256 do want[i]="\0\0\0\0" end
        expected:drawLayer(mid,2,0,0,function(x,y,rr,gg,bb)
          want[y*16+x+1]=string.char(rr,gg,bb,255)
        end)
        local x,y=quad:getViewport()
        local slot=y/16*Tiles.SHEET_COLS+x/16
        check(pixelsEqual(readSlot(bytes,width,slot),table.concat(want)),
          "GPU/reflection-cover mismatch "..mid.." frame "..frame)
        coverPixels=coverPixels+256
      end
    end
    count=count+coverPixels
  end
  local pixels=table.concat(packed)
  local paletteCells=0
  local blocks=world.map.def.blocks
  if type(blocks)=="string" then
    for at=1,#blocks,2 do
      local lo,hi=blocks:byte(at,at+1)
      if paletteIds[(lo+hi*256)%1024] then paletteCells=paletteCells+1 end
    end
  end
  local hash=love.data.encode("string","hex",love.data.hash("sha256",pixels))
  local item={tag=tag,map=world.map.id,tileset=world.map.tileset.id,ticks=ticks,
    palettePhase=version=="emerald" and math.floor(ticks/4)%4 or 0,
    tileFrame=r:gen3AnimFrame(),paletteRevision=record.paletteRevision or 0,
    paletteMetatiles=paletteMetatiles,paletteCells=paletteCells,rgbaPixels=count,
    coverRgbaPixels=coverPixels,baseHash=hash}
  if version=="emerald" then check(paletteCells>0,"test map does not display the imported palette cycle") end
  if version=="emerald" then
    -- A clear retail floor cell, beyond the player/NPC sprites. Checking the
    -- live world canvas catches a correct atlas that never reaches the map.
    local data=game.renderer.worldCanvas:newImageData()
    local bytes=data:getString();local width,height=data:getDimensions()
    local function wanted(mid,tick)
      expectedS.palettes[9]=sourcePalette(tick)
      expected:setAnimFrame(r:gen3AnimFrame() or 0)
      local want={};for i=1,256 do want[i]="\0\0\0\0" end
      expected:draw(mid,0,0,function(px,py,red,green,blue)
        want[py*16+px+1]=string.char(red,green,blue,255)
      end)
      return table.concat(want)
    end
    local function crop(cx,cy)
      local x,y=cx*16-math.floor(world.camera.x),cy*16-math.floor(world.camera.y)
      if x<0 or y<0 or x+16>width or y+16>height then return nil end
      local rows={}
      for row=0,15 do local at=((y+row)*width+x)*4;rows[#rows+1]=bytes:sub(at+1,at+64) end
      return table.concat(rows)
    end
    if not sceneProbe then
      -- Pick a visible, unobstructed cell whose actual source colours differ
      -- in ALL four phases. Merely using palette 8 is insufficient: much of
      -- the court uses entries that are identical in every frame.
      for cy=0,world.map.def.height-1 do for cx=0,world.map.def.width-1 do
        local mid=world.map:blockAt(cx,cy)
        local actual=paletteIds[mid] and crop(cx,cy)
        if actual and not sceneProbe then
          local variants={}
          for phase=0,3 do variants[wanted(mid,phase*4)]=true end
          local n=0;for _ in pairs(variants) do n=n+1 end
          if n==4 and actual==wanted(mid,ticks) then sceneProbe={x=cx,y=cy,mid=mid} end
        end
      end end
      check(sceneProbe~=nil,"no visible floor cell changes across all source phases")
      report.sceneProbe=sceneProbe
    end
    local cx,cy=sceneProbe.x,sceneProbe.y
    local mid=world.map:blockAt(cx,cy)
    check(mid==sceneProbe.mid and paletteIds[mid],"live scene probe changed geometry")
    local x,y=cx*16-math.floor(world.camera.x),cy*16-math.floor(world.camera.y)
    check(x>=0 and y>=0 and x+16<=width and y+16<=height,"scene probe outside viewport")
    local actual=crop(cx,cy)
    check(pixelsEqual(actual,wanted(mid,ticks)),"live floor pixels differ from ROM palette")
    item.scenePixels=256
    item.sceneHash=love.data.encode("string","hex",love.data.hash("sha256",actual))
    data:release()
  end
  report.samples[#report.samples+1]=item
  writeReport()
  print("[palette-gpu] "..tag.." map="..item.map.." tick="..ticks.." pixels="..count)
  return item
end
local function shot(tag)
  local name=version.."-"..tag..".png"
  for attempt=1,30 do
    check(U.shot(game,out.."/"..name),"screenshot failed")
    local f=assert(io.open(out.."/"..name,"rb"));local bytes=f:read("*a");f:close()
    local data=love.image.newImageData(love.filesystem.newFileData(bytes,name))
    local pixels=data:getString();local width,height=data:getDimensions()
    local colours,count={},0
    -- Ignore letterboxing and the runtime's bottom-edge deprecation overlay:
    -- warning text on an otherwise black window is not visible gameplay.
    for y=math.floor(height*.2),math.floor(height*.7),math.max(1,math.floor(height/100)) do
      for x=math.floor(width*.2),math.floor(width*.8),math.max(1,math.floor(width/100)) do
        local at=(y*width+x)*4
        local rgb=pixels:sub(at+1,at+3)
        if not colours[rgb] then colours[rgb]=true;count=count+1 end
      end
    end
    data:release()
    if count>=16 then
      report.screenshots[#report.screenshots+1]=name
      report.captureAttempts=report.captureAttempts or {}
      report.captureAttempts[name]=attempt
      check(true,"visible world screenshot")
      return
    end
    print("[palette-gpu] blank window capture; retry",tag,attempt,
      "fade",tostring(game.renderer.worldFadeAlpha),"veil",tostring(game.renderer.screenVeil))
    U.wait(5)
  end
  error("window captures lack visible gameplay; texture checks alone are insufficient")
end

local summary=assert(game.data.map_tilesets._romInfo.palettePrograms)
check(summary.unavailable==0,"full import left unknown palette programs")
check(summary.animated==(version=="emerald" and 1 or 0),"unexpected animated bank count")
report.import=summary
local target=version=="emerald" and "TILESET_03DF884_03DFCC4" or "TILESET_02D4A94_02D4AAC"
local candidates={}
for id,def in pairs(game.data.maps) do if def.tileset==target then candidates[#candidates+1]=id end end
table.sort(candidates)
report.candidates=candidates
check(#candidates>0,"no real map uses the imported target pair")
writeReport()
-- Target positions are supplied by the launcher after discovery of the
-- imported retail map. They affect only this new, unsaved test game.
local mapId=assert(os.getenv("PALETTE_GPU_MAP"))
local x,y=assert(tonumber(os.getenv("PALETTE_GPU_X"))),assert(tonumber(os.getenv("PALETTE_GPU_Y")))
check(game.data.maps[mapId].tileset==target,"target map uses wrong tileset")
U.teleport(game,mapId,x,y,"down")
U.wait(15)
local world=assert(game.overworld)
check(world.map.id==mapId,"teleport failed")
check(game.stack.states[game.stack:visibleBase()]==world,"native world is not visible")
report.entryOverlay=game.stack:top()~=world and require("src.core.StateStack").describe(game.stack:top()) or false
local record=assert(world.map.renderer.gen3)
local bottom,top,cover=record.bottom,record.top,record.cover
local phases,frames,hashes={},{},{}
local sceneHashes={}
local firstTick=TR.animFrame()
local start=love.timer.getTime()
while love.timer.getTime()-start<20 do
  U.wait(1)
  local phase=version=="emerald" and math.floor(TR.animFrame()/4)%4 or 0
  local frame=world.map.renderer:gen3AnimFrame()
  frames[frame]=true
  if not phases[phase] then
    local item=sample(world,"phase-"..phase)
    phases[phase]=true;hashes[item.baseHash]=true
    if item.sceneHash then sceneHashes[item.sceneHash]=true end
    -- Capture each real palette phase at the current draw; screenshot
    -- handling remains in main.lua and never reads other app windows.
    if version=="emerald" then shot("phase-"..phase) end
  end
  local n=0;for _ in pairs(phases) do n=n+1 end
  local f=0;for _ in pairs(frames) do f=f+1 end
  if n==(version=="emerald" and 4 or 1) and f>=record.animFrames
    and TR.animFrame()-firstTick>=120 then break end
end
local n=0;for _ in pairs(phases) do n=n+1 end
check(n==(version=="emerald" and 4 or 1),"palette phases did not all render")
local frameCount=0;for _ in pairs(frames) do frameCount=frameCount+1 end
check(frameCount==record.animFrames,"native tile animation stopped")
check(TR.animFrame()>firstTick,"native clock did not advance")
check(record.bottom==bottom and record.top==top and record.cover==cover,"palette cycling replaced retained textures")
if version=="emerald" then
  local distinct=0;for _ in pairs(hashes) do distinct=distinct+1 end
  check(distinct==4,"four source palette phases did not change GPU pixels")
  local scenes=0;for _ in pairs(sceneHashes) do scenes=scenes+1 end
  check(scenes==4,"four palette phases did not reach the live map")
  check((record.paletteRevision or 0)>0,"live palette upload did not occur")
else
  local last=sample(world,"static-after-animation")
  check(last.baseHash==report.samples[1].baseHash,"static palette atlas changed")
  check((record.paletteRevision or 0)==0,"static palette unnecessarily uploaded")
  shot("outdoor")
end
report.tileFramesObserved=frameCount
report.nativeTicksElapsed=TR.animFrame()-firstTick
-- Exercise a real second map and return, with the shared GPU pair retained.
local other=version=="emerald" and "MAP_G26_N18" or "MAP_G04_N01"
U.teleport(game,other,version=="emerald" and 11 or 6,version=="emerald" and 10 or 6,"down")
U.wait(15)
check(world.map.id==other,"second retail map did not load")
shot("second-map")
if version=="firered" then
  local px,py=world.player.px,world.player.py
  U.hold(game,"left",20);U.wait(5)
  check(world.player.px~=px or world.player.py~=py,"native indoor movement failed")
  report.indoorMovement=true
end
U.teleport(game,mapId,x,y,"down");U.wait(15)
check(world.map.id==mapId,"return to target failed")
check(world.map.renderer.gen3==record,"return failed to retain the shared GPU sheets")
sample(world,"after-map-return")
shot("map-return")
report.mapReturn=true
if TR.gen3PaletteCacheStats then
  report.paletteCache=TR.gen3PaletteCacheStats()
  check(report.paletteCache.bytes<=report.paletteCache.budget,"palette cache exceeded CPU byte budget")
  check(report.paletteCache.entries==(version=="emerald" and 4 or 0),
    "unexpected native palette picture population")
end
report.pass=true
writeReport()
print("[palette-gpu] PASS "..version.." "..report.checks.." checks")
end
