-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Compatibility defaults for published producers which predate the explicit
-- worldOrientation contract. Never infer orientation from a mod ID alone.
local Version=require('src.core.GameVersion')
local M={}
local policies=setmetatable({},{__mode='k'})
local legacyTarget=false
local staged
local known={
 ['absol89/gen2recomped-dramaticshapes@2.1.4']={
  ['lib/WorldCanvasOrientation.lua']='bafe05d630481229538f86e05f6361f53acb3171b55ad9e2b0270a5610df4f31',
  ['lib/RendererOrientation.lua']='775e6cb7f2e6b182a014839cec35717216599560aca1b50d602a1d894d08531c',
 },
}
-- The direct battle override bypasses the registered world pipeline. Its
-- camera deliberately retains Metal's opposite clip-Y convention, so bind
-- that additional contract only for the exact published staging/projection
-- helpers as well. A matching mod ID or a ready canvas alone proves nothing.
local battleFiles={
 ['absol89/gen2recomped-dramaticshapes@2.1.4']={
  ['lib/BattleStage.lua']='09a84485dcaeead5c697aef3990e974ff71156bf8201afb9f5d86b62a2cca879',
  ['lib/BattleScene.lua']='ea537e34c67470acbdd4d25da6ae7bad64ddfe30653b1f94a085a4f5f52f700f',
  ['lib/OverworldBattle.lua']='0eb3ceeac263c8d1df1ed30fb7c1b4b5b43774cd47f940a5df1792268737456b',
  ['lib/Voxel3D.lua']='3e65a6332d89ad164b41c78591293fd9a6819637976b7ab6cbaae5c7be66e3ed',
 },
}
local function sha256(bytes)
 local d=love and love.data
 if not(d and d.hash and d.encode)then return nil end
 local ok,raw=pcall(d.hash,'string','sha256',bytes)
 if not ok then ok,raw=pcall(d.hash,'sha256',bytes)end
 if not ok then return nil end
 if type(raw)=='userdata'and raw.getString then raw=raw:getString()end
 if type(raw)~='string'or #raw~=32 then return nil end
 local encoded,value=pcall(d.encode,'string','hex',raw)
 return encoded and value or nil
end
local function affectedTarget()
 if not(love and love.getVersion and love.getVersion()>=12
  and love.graphics and love.graphics.getRendererInfo)then return false end
 local ok,a,b,c,d=pcall(love.graphics.getRendererInfo)
 if not ok then return false end
 local renderer=table.concat({tostring(a),tostring(b),tostring(c),tostring(d)},' '):lower()
 return renderer:find('metal',1,true)~=nil or(renderer:find('apple',1,true)~=nil and renderer:find('opengl es',1,true)~=nil)
end
function M.reset()policies=setmetatable({},{__mode='k'});legacyTarget=false;staged=nil end
-- The digest seam lets ROM-free contracts inspect policy independently of
-- graphics/runtime availability. Actual Loader calls always use native SHA256.
function M.bind(loader,data,digest)
 M.reset();digest=digest or sha256
 local defs=data and data.render_pipelines
 local registry=loader and loader.content and loader.content.render_pipelines
 local fs=loader and loader.fs
 if type(defs)~='table'or not registry or not(fs and fs.read)then return 0 end
 local producers,staging={},{}
 for _,mod in ipairs(loader.loaded or{})do
  local manifest=mod.manifest or{}
  local repo=manifest.github
  local key=type(repo)=='string'and(repo:lower()..'@'..tostring(manifest.version))
  local files=key and known[key]
  local valid=type(files)=='table'and type(mod.path)=='string'
  if valid then for relative,expected in pairs(files)do
   local read,bytes=pcall(fs.read,mod.path..'/'..relative)
   if not read or type(bytes)~='string'or #bytes>65536 or digest(bytes)~=expected then valid=false;break end
  end end
  if valid then
   producers[manifest.id]=key
   local stageFiles=battleFiles[key];local stageValid=type(stageFiles)=='table'
   if stageValid then for relative,expected in pairs(stageFiles)do
    local read,bytes=pcall(fs.read,mod.path..'/'..relative)
    if not read or type(bytes)~='string'or #bytes>131072 or digest(bytes)~=expected then stageValid=false;break end
   end end
   if stageValid then staging[manifest.id]=true end
  end
 end
 local count=0
 for id,def in pairs(defs)do
  local owner=registry.owners and registry.owners[id]
  if type(def)=='table'and def.drawWorld and def.worldOrientation==nil
   and def.worldFormat~='renderData.v1'and producers[owner]then
   policies[def]=producers[owner];count=count+1
   if staging[owner]then
    staged=staged or {loader=loader,data=data,registry=registry,defs=setmetatable({},{__mode='k'})}
    staged.defs[def]={id=id,owner=owner}
   end
  end
 end
 if count>0 then legacyTarget=affectedTarget()end
 return count
end
function M.orientation(def)
 if policies[def]and legacyTarget and Version.isGen2()then return 'legacy'end
end
-- Resolve only a current native battle's exact ready shot, belonging to the
-- verified producer above. No arbitrary override, UI texture, saved frame,
-- unloaded mod or later dataset inherits this canvas convention.
function M.canvasOrientation(canvas)
 if not (canvas and staged and legacyTarget and Version.isGen2())then return end
 local game=package.loaded['src.core.Game']
 local bound=staged
 if not (type(game)=='table'and game.mods==bound.loader and game.data==bound.data
     and type(game.stack)=='table'and type(game.stack.states)=='table')then return end
 local stack,save=game.stack,game.save
 for def,record in pairs(bound.defs)do
  if policies[def]and def.worldOrientation==nil and def.worldFormat~='renderData.v1'
      and bound.loader.content and bound.loader.content.render_pipelines==bound.registry
      and bound.registry.owners and bound.registry.owners[record.id]==record.owner
      and bound.data.render_pipelines and bound.data.render_pipelines[record.id]==def then
   local exports=bound.loader.exports and bound.loader.exports[record.owner]
   local stage=type(exports)=='table'and exports.battleStage
   local lib=type(exports)=='table'and exports.lib
   if type(stage)=='table'and type(stage.state)=='function'
       and type(lib)=='table'and type(lib.require)=='function'then
    for i=#stack.states,1,-1 do
     local battle=stack.states[i]
     local ok,state=pcall(stage.state,battle)
     if ok and type(state)=='table'and state.battle==battle and state.staged==true
         and state.ready==true and state.surfaceOwned==true then
      local loaded,owner=pcall(lib.require,'OverworldBattle')
      if loaded and type(owner)=='table'and type(owner.battle)=='function'and type(owner.shot)=='function'then
       local current,held=pcall(owner.battle)
       local shown,shot=pcall(owner.shot)
       if current and held==battle and shown and type(shot)=='table'and shot.canvas==canvas
           and staged==bound and game.mods==bound.loader and game.data==bound.data
           and game.stack==stack and stack.states[i]==battle and game.save==save then return 'legacy'end
      end
     end
    end
   end
  end
 end
end
return M
