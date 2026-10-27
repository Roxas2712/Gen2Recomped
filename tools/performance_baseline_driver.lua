-- Native scene admission, walking and timed FrameProfile baseline cases.
return function(game)
  local U = require("tests.drivers.util")
  local Json = require("src.link.Json")
  local Identity = require("src.core.MapIdentity")
  local Version = require("src.core.GameVersion")
  local spec = Json.decode(assert(os.getenv("PERF_BASELINE_SPEC")))
  assert(spec.inventory == true or spec.measure == true, "explicit probe or measurement mode required")
  assert(love.filesystem.getIdentity():match("^oasc%-gen2recomp%-qa%-perf%-baseline%-"))
  assert(Version.get() == spec.version, "wrong imported cartridge")
  U.freshSave(game)
  local renderer, api, vendor, device = love.graphics.getRendererInfo()
  local major, minor, revision = love.getVersion()
  local report = {
    passed = true, inventoryOnly = not spec.measure, performanceBaseline = spec.measure == true,
    scene = spec.name, edition = Version.get(), runtime = {major, minor, revision},
    gpu = {renderer = renderer, api = api, vendor = vendor, device = device},
    viewport = {love.graphics.getDimensions()}, pixels = {love.graphics.getPixelDimensions()},
    targets = {}, dataKeys = {}, boot = {},
  }
  report.loadedMods={}
  for _,mod in ipairs(game.mods.loaded or {}) do
    report.loadedMods[#report.loadedMods+1]=mod.manifest.id
  end
  table.sort(report.loadedMods)
  if spec.voxel and spec.measure then
    assert(#report.loadedMods==1 and report.loadedMods[1]=='Gen2Recomped-DramaticShapes',
      'voxel measurement requires only DRAMATIC_SHAPE')
  end
  for key in pairs(game.data) do report.dataKeys[#report.dataKeys + 1] = tostring(key) end
  table.sort(report.dataKeys)
  local function scalar(value)
    local kind = type(value)
    return kind == "string" or kind == "number" or kind == "boolean"
  end
  for key, value in pairs(game.data.field and game.data.field.boot or {}) do
    if scalar(value) then report.boot[key] = value end
  end
  local function normalized(value)
    return tostring(value):lower():gsub("[^%w]", ""):gsub("^map", "")
  end
  local targets = {}
  for _, name in ipairs(spec.names or {}) do
    local canonical = name
    if Version.isGen3() then
      canonical = require("src.import.gba.map_catalog").resolve("MAP_" .. name, nil, Version.get())
    end
    targets[#targets + 1] = {name = name, canonical = canonical,
      normalized = normalized(canonical), matches = {}}
  end
  for _, header in ipairs(spec.headers or {}) do
    targets[#targets + 1] = {header = header, matches = {}}
  end
  for _, target in ipairs(targets) do
    local seen = {}
    for id, def in pairs(game.data.maps or {}) do
      if type(def) == "table" and not seen[def] then
        local matched = false
        if target.header then
          matched = tonumber(tostring(id):match("(%d+)$")) == target.header
            or def.header == target.header or def.headerId == target.header
        else
          for _, alias in ipairs(Identity.aliases(game.data, id)) do
            if normalized(alias) == target.normalized then matched = true end
          end
          for _, key in ipairs({"id", "sourceId", "label", "name", "nativeName"}) do
            if def[key] and normalized(def[key]) == target.normalized then matched = true end
          end
        end
        if matched then
          seen[def] = true
          local row = {key = id, runtimeId = Identity.runtimeId(game.data, id), fields = {}, keys = {}}
          for key, value in pairs(def) do
            row.keys[#row.keys + 1] = tostring(key)
          end
          for _, key in ipairs({"id", "sourceId", "label", "name", "nativeName", "generation",
              "header", "headerId", "width", "height", "mapType", "environment"}) do
            if scalar(def[key]) then row.fields[key] = def[key] end
          end
          table.sort(row.keys)
          target.matches[#target.matches + 1] = row
        end
      end
    end
    table.sort(target.matches, function(a, b) return tostring(a.key) < tostring(b.key) end)
    if #target.matches == 0 then report.passed = false end
    report.targets[#report.targets + 1] = target
  end
  if (spec.setupProbe or spec.measure) and report.passed then
    math.randomseed(12345)
    local P=require("src.core.Performance")
    if spec.variant=="idle-off" or spec.variant=="idle-on" then
      local enabled=spec.variant=="idle-on"
      P.idleStream,P.gen4ChunkPrebuild=enabled,enabled
    end
    game.save.options.performance=spec.variant=="adaptive" and "adaptive" or "high"
    game.save.options.fpsCap=spec.fpsCap
    game.save.options.pipelines=game.save.options.pipelines or {}
    game.save.options.pipelines.voxel=spec.voxel and spec.measure and 3 or 0
    game:applyOptions()
    local V=spec.voxel and spec.measure and assert(_G.__DRAMATIC_SHAPE_V,"native mod loader did not admit DRAMATIC_SHAPE")
    local Sections=require("tools.performance_baseline_sections")
    if V then
      local Cap=require("src.core.FrameCap")
      Cap.backgroundPacing=false
      Cap.apply(spec.fpsCap)
      love.window.setVSync(0)
      V.require("Water").setting:sync("full")
      V.require("RenderScale").setting:sync(1)
      V.require("DayNight").setting:sync("day")
      V.require("ChunkMesher").idlePump=spec.variant~="voxel-idle-off"
      Sections.startSetup()
    end
    -- An owned post-starter QA save; game scripts and collision remain native.
    local starters = {red = "BULBASAUR", gold = "CYNDAQUIL", emerald = "TREECKO", platinum = 387}
    game.save.party = {require("src.pokemon.Pokemon").new(game.data, starters[Version.get()], 10)}
    game.save.repelSteps = 10000
    report.preparedState = {partyLevel = 10, repelSteps=10000, kind = "owned post-starter QA save"}
    if Version.isGen3() then
      -- Emerald FLAG_SYS_POKEMON_GET: src/mods/flag_names/emerald.lua.
      local flagKey=require("src.script.Gen3Commands").flagKey
      local flags={82,130,132,301,700,720,723,750,979,2144}
      for _, id in ipairs(flags) do game.save.flags[flagKey(id)]=true end
      report.preparedState.gen3Flags=flags
    elseif Version.get() == "platinum" then
      -- Values reached by the starter/running-shoes story beats in the
      -- existing native Platinum playthrough driver.
      game.save.gen4Vars = {[0x4086] = 2, [0x40A4] = 4}
      game.save.flags.FLAG_G4_00EA = true -- Barry has left his room.
      report.preparedState.gen4Vars = game.save.gen4Vars
      report.preparedState.gen4Flags = {234}
    end
    if spec.hour then
      local Clock=require("src.core.Gen2Clock")
      Clock.setTime(game.save, spec.hour, 0)
      report.clock={hour=Clock.hour(game.save),minute=Clock.minute(game.save)}
    end
    local starts = {
      ["red-pallet"] = {8, 10}, ["red-route1"] = {10, 25},
      ["gold-goldenrod-day"] = {20, 25}, ["gold-goldenrod-night"] = {20, 25},
      ["emerald-route101-103"] = {10, 18}, ["emerald-route119-voxel"] = {10, 10},
      ["platinum-twinleaf-201"] = {15, 10},
    }
    local selected = report.targets[1].matches[1]
    for _, row in ipairs(report.targets[1].matches) do
      if row.key == "T01" then selected = row end
    end
    local cell = assert(starts[spec.name])
    U.teleport(game, selected.runtimeId, cell[1], cell[2], "up")
    local ow = assert(game.overworld)
    if not ow.map:isWalkableCell(cell[1], cell[2]) then
      local best, distance
      for y = 2, ow.map.heightCells - 3 do
        for x = 2, ow.map.widthCells - 3 do
          if ow.map:isWalkableCell(x, y) then
            local occupied = false
            for _, entity in ipairs(ow.entities or {}) do
              if entity ~= ow.player and not entity.passable and entity.cellX == x and entity.cellY == y then
                occupied = true
              end
            end
            local d = (x-cell[1])^2 + (y-cell[2])^2
            if not occupied and (not distance or d < distance) then
              best, distance = {x, y}, d
            end
          end
        end
      end
      assert(best, "scene has no unoccupied native walkable cell")
      U.teleport(game, selected.runtimeId, best[1], best[2], "up")
    end
    local atlasDraws=0
    if spec.atlasBridge then
      assert(Version.isGen3()and not spec.voxel,'atlas bridge requires the Gen-3 field scene')
      local field=require('src.core.game3.field_view')
      local native=field.draw
      -- Use the production replacement boundary, with the native game,
      -- actors, map graph and clock. No alternate simulation is installed.
      field.draw=function(...)
        atlasDraws=atlasDraws+1
        local ok,why=native(...)
        assert(ok,why)
        return ok,why
      end
      report.atlasBridge={enabled=true,kind='production source-field adapter in owned QA host'}
    end
    U.wait(60)
    ow = assert(game.overworld)
    report.setup = {
      map = ow.map.id, width = ow.map.widthCells, height = ow.map.heightCells,
      player = {x = ow.player.cellX, y = ow.player.cellY},
      requested = {x = cell[1], y = cell[2]},
      walkable = ow.map:isWalkableCell(ow.player.cellX, ow.player.cellY),
      worldOnTop = game.stack:top() == ow,
      worldActive = game.stack:active() == ow,
      scriptRunning = ow.runner and ow.runner:isRunning() or false,
      connections = {},
    }
    for dir, conn in pairs(ow.map.def.connections or {}) do
      report.setup.connections[dir] = {map = conn.map, offset = conn.offset}
    end
    report.passed = report.setup.walkable and report.setup.worldActive and not report.setup.scriptRunning
    local function walk()
      local walks={}
      for i=2,#report.targets do
        local row=report.targets[i].matches[1]
        for _, candidate in ipairs(report.targets[i].matches) do
          if candidate.key=="R201" then row=candidate end
        end
        walks[#walks+1]=require("tools.performance_baseline_walk")(game,row.runtimeId)
      end
      return walks
    end
    if spec.walkProbe and report.passed then report.walks=walk() end
    if spec.measure and report.passed then
      if V then
        local mesher=V.require("ChunkMesher")
        local deadline=love.timer.getTime()+480
        repeat
          assert(not mesher.buildFailure(ow.map.id),"native terrain build failed")
          assert(love.timer.getTime()<deadline,"native terrain did not become quiescent")
          U.wait(30)
        until mesher.peek(ow.map,false)
        report.voxelPendingAtReady=mesher.pending()
        local disk=V.require("VoxelDiskCache")
        report.voxelDiskAtReady={hits=disk.hits,misses=disk.misses,errors=disk.errors,bytesLoaded=disk.bytesLoaded}
        report.voxelSetup=Sections.stopSetup()
        report.voxelReadiness="current full mesh published; background jobs may remain"
        if spec.variant=="voxel-warm-disk" then
          local loads=report.voxelSetup.labels["    voxel: VoxelDiskCache.load"] or {}
          assert(loads[ow.map.id] and (loads[ow.map.id].trueReturns or 0)>0,"target map did not load from the warm disk cache")
        end
        Sections.startSetup()
        V.require("Structures").forMap(ow.map)
        V.require("Gen3").prepare(ow.map)
        V.require("TerrainAtlas").forMap(ow.map)
        report.voxelWarmMemory=Sections.stopSetup()
      end
      local Cap=require("src.core.FrameCap")
      Cap.backgroundPacing=false -- owned benchmark keeps its cap outside the foreground
      Cap.apply(spec.fpsCap)
      love.window.setVSync(0)
      U.wait(120)
      report.variant=spec.variant
      report.pacing={fpsCap=Cap.current,vsync=love.window.getVSync(),backgroundPacing=Cap.backgroundPacing}
      report.switches={idleStream=P.idleStream,gen4ChunkPrebuild=P.gen4ChunkPrebuild}
      if V then report.switches.voxelIdlePump=V.require("ChunkMesher").idlePump end
      if spec.variant=="adaptive" then assert(Cap.focused~=false,"adaptive observation requires a focused native window") end
      report.measurement=require("tools.performance_baseline_meter")(game,spec.seconds,#report.targets>1 and walk or nil,
        function()return P.tier,Cap.focused end)
      if V then
        report.voxelPendingAtEnd=V.require("ChunkMesher").pending()
        local disk=V.require("VoxelDiskCache")
        report.voxelDiskAtEnd={hits=disk.hits,misses=disk.misses,errors=disk.errors,bytesLoaded=disk.bytesLoaded}
      end
      if spec.variant=="adaptive" then
        for _, state in ipairs(report.measurement.tierTrace) do
          assert(state.focused~=false,"native window lost focus during adaptive observation")
        end
      end
    end
  end
  local f = assert(io.open(assert(os.getenv("PERF_BASELINE_OUT")), "w"))
  f:write(Json.encode(report));f:close()
  love.event.quit(report.passed and 0 or 1)
end
