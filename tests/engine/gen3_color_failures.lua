package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local F = require("tests.terrain_animation.fixture")
local Copy = require("src.mods.Merge").deepCopy
local Renderer = require("src.render.TileRenderer")
for _, version in ipairs({ "emerald", "firered" }) do
  local f = F.new(version,2,true)
  local s,e = f.state,f.exports
  f.records.P.paletteCycles = { { kind = "rotate", first = 17, count = 4, step = 3, direction = -1 } }
  f.records.S.paletteCycles = {}
  local original = Copy(f.records)
  local function reset() for k,v in pairs(original) do f.records[k] = Copy(v) end end
  local function reject(change)
    reset(); change(f.records.P,f.records.S)
    local ok,v,err = pcall(e.colors,1,s.mapId)
    T.eq(ok,true,"invalid color metadata cannot throw")
    T.eq(v,nil,"invalid color metadata declines without partial picture")
    T.eq(err,"palette animation data unavailable","explicit palette failure")
  end
  reject(function(p) p.paletteCycles = nil end)
  reject(function(p,q) q.paletteCycles = nil end)
  reject(function(p) p.paletteCycles = false end)
  reject(function(p) p.paletteCycles = setmetatable({}, { __metatable = false }) end)
  reject(function(p) p.paletteCycles[1] = false end)
  reject(function(p) p.paletteCycles[1] = setmetatable(p.paletteCycles[1],{}) end)
  reject(function(p) p.paletteCycles.extra = 1 end)
  reject(function(p) p.paletteCycles[3] = p.paletteCycles[1] end)
  reject(function(p) for i=2,33 do p.paletteCycles[i] = p.paletteCycles[1] end end)
  reject(function(p,q) for i=1,17 do p.paletteCycles[i] = p.paletteCycles[1];q.paletteCycles[i] = Copy(p.paletteCycles[1]) end end)
  for _, field in ipairs({"first","count","step","phase"}) do
    for _, bad in ipairs({false,"1",-1,0.5,math.huge,0/0}) do
      reject(function(p) p.paletteCycles[1][field] = bad end)
    end
  end
  reject(function(p) p.paletteCycles[1].step = 0 end)
  reject(function(p) p.paletteCycles[1].phase = 65536 end)
  reject(function(p) p.paletteCycles[1].step = 65536 end)
  reject(function(p) p.paletteCycles[1].count = 1 end)
  reject(function(p) p.paletteCycles[1].direction = 0 end)
  reject(function(p) p.paletteCycles[1].kind = "callback" end)
  reject(function(p) p.paletteCycles[1].first = s.game.data.constants.gen3Layout.palettesInPrimary * 16 - 1 end)
  reject(function(p,q) q.paletteCycles = Copy(p.paletteCycles) end)
  reject(function(p) p.paletteCycles[1] = {kind="frames",first=17,count=2,step=1,frames={"short","short"}} end)
  reject(function(p) p.paletteCycles[1] = {kind="frames",first=17,count=1,step=1,frames={"abc"}} end)
  reject(function(p) p.paletteCycles[1] = {kind="frames",first=17,count=1,step=1,frames=setmetatable({"abc","def"},{})} end)
  reject(function(p)
    local frames = {}; for i=1,257 do frames[i]="abc" end
    p.paletteCycles[1] = {kind="frames",first=17,count=1,step=1,frames=frames}
  end)
  reject(function(p)
    local frames={}; for i=1,256 do frames[i]=string.rep("x",48) end
    for i=1,22 do p.paletteCycles[i]={kind="frames",first=16,count=16,step=1,frames=frames} end
  end)
  reset()
  local selected = assert(e.colors(1,s.mapId))
  local step = selected.paletteAnimation.primaryFrames[1]
  local src = f.records.P.palettes[2][step % 4 + 2]
  T.same(selected.primary.palettes[2][2],src,"reverse rotation uses original palette without accumulated drift")
  -- Last run wins; rotations always read source, never earlier runs' output.
  f.records.P.paletteCycles[2] = {kind="frames",first=17,count=1,step=1,frames={"abc","def"}}
  local overlap=assert(e.colors(1,s.mapId))
  local frame=Renderer.animFrame()%2 == 0 and "abc" or "def"
  T.same(overlap.primary.palettes[2][2],{frame:byte(1,3)},"explicit overlap precedence")
  reset()
  local clock=Renderer.animFrame
  for _,bad in ipairs({-1,0.5,"2",false,math.huge,0/0,9007199254740992}) do
    Renderer.animFrame=function() return bad end
    local v,err=e.colors(1,s.mapId)
    T.eq(v,nil,"invalid color clock refused");T.eq(err,"terrain clock unavailable","clock failure")
  end
  Renderer.animFrame=function() return 9007199254740991 end
  f.records.P.paletteCycles[1].phase=65535
  local limit=assert(e.colors(1,s.mapId))
  T.eq(limit.paletteAnimation.primaryFrames[1], math.floor(((9007199254740991%12)+65535)%12/3),"maximum exact tick retains phase precision")
  Renderer.animFrame=clock
  package.loaded["src.render.TileRenderer"]=nil
  T.eq(e.colors(1,s.mapId),nil,"color read never loads a missing clock")
  T.eq(package.loaded["src.render.TileRenderer"],nil,"renderer stays unloaded")
  package.loaded["src.render.TileRenderer"]=Renderer
  reset();f.records.P.paletteCycles={};f.records.S.paletteCycles={}
  local still=assert(e.colors(1,s.mapId))
  T.same(still.primary.palettes,f.records.P.palettes,"explicit static palettes stay unchanged")
  local key=still.contentKey
  for _,p in pairs(f.records) do p.animations={} end
  key=assert(e.colors(1,s.mapId)).contentKey
  for _=1,100 do Renderer.tick(1/60) end
  T.eq(assert(e.colors(1,s.mapId)).contentKey,key,"static content never invalidates just because time passed")
  f.run.release()
end
for _,version in ipairs({"red","gold"}) do
  local f=F.new(version,2,true)
  T.eq(f.exports.supports(1),false,"Gen1/2 color support remains absent")
  T.eq(f.exports.colors(1,f.state.mapId),nil,"unsupported generation declines")
  T.eq(f.exports.weather(1,f.state.mapId),nil,"unsupported weather generation declines")
  f.run.release()
end
T.finish("Color source bounds, legacy-cache fallback and invalid data")
