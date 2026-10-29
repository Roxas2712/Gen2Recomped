-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Compatibility defaults for published producers which predate the explicit
-- worldOrientation contract. Never infer orientation from a mod ID alone.
local Version=require('src.core.GameVersion')
local M={}
local policies=setmetatable({},{__mode='k'})
local legacyTarget=false
local known={
 ['absol89/gen2recomped-dramaticshapes@2.1.4']={
  ['lib/WorldCanvasOrientation.lua']='bafe05d630481229538f86e05f6361f53acb3171b55ad9e2b0270a5610df4f31',
  ['lib/RendererOrientation.lua']='775e6cb7f2e6b182a014839cec35717216599560aca1b50d602a1d894d08531c',
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
function M.reset()policies=setmetatable({},{__mode='k'});legacyTarget=false end
-- The digest seam lets ROM-free contracts inspect policy independently of
-- graphics/runtime availability. Actual Loader calls always use native SHA256.
function M.bind(loader,data,digest)
 M.reset();digest=digest or sha256
 local defs=data and data.render_pipelines
 local registry=loader and loader.content and loader.content.render_pipelines
 local fs=loader and loader.fs
 if type(defs)~='table'or not registry or not(fs and fs.read)then return 0 end
 local producers={}
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
  if valid then producers[manifest.id]=key end
 end
 local count=0
 for id,def in pairs(defs)do
  local owner=registry.owners and registry.owners[id]
  if type(def)=='table'and def.drawWorld and def.worldOrientation==nil
   and def.worldFormat~='renderData.v1'and producers[owner]then
   policies[def]=producers[owner];count=count+1
  end
 end
 if count>0 then legacyTarget=affectedTarget()end
 return count
end
function M.orientation(def)
 if policies[def]and legacyTarget and Version.isGen2()then return 'legacy'end
end
return M
