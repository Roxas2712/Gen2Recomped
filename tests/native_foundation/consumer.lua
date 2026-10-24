-- A real mod entry: no engine imports, native objects or backend adapters.
local mod = ...
local r = assert(mod.renderData)
mod.exports.renderData = r
function mod.exports.observe(mapId, query)
  local terrain, err = r:surface(1, mapId, query)
  if not terrain then return nil, err end
  local actors, why = r:actors(1, mapId)
  if not actors then return nil, why end
  local effects, reason = r:fieldEffects(1, mapId)
  if not effects then return nil, reason end
  local mounts, problem = r:surfMounts(1, mapId)
  if not mounts then return nil, problem end
  return { terrain = terrain, actors = actors, effects = effects, mounts = mounts }
end
mod.content.render_pipelines:register("native_foundation", {
  label = "Foundation contract probe",
  levels = { "OFF", "ON" },
  worldFormat = "renderData.v1",
  drawWorld = function(frame)
    -- Returning nil deliberately keeps the native renderer. This tests the
    -- real world callback as a consumer without pretending to draw Origami.
    mod.exports.lastFrame = frame
    mod.exports.lastScene, mod.exports.lastError = mod.exports.observe(frame.mapId)
  end,
})
