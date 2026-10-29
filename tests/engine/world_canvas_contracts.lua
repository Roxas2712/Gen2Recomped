-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.render.WorldCanvasContracts');local Renderer=require('src.render.Renderer')
local Version=require('src.core.GameVersion');local previous=Version.get()
local graphics,version=love.graphics.getRendererInfo,love.getVersion
local backend,major='Metal',12
love.getVersion=function()return major,0,0 end
love.graphics.getRendererInfo=function()return backend,'test','Apple','fixture'end
Version.set('crystal')
local hashes={world='bafe05d630481229538f86e05f6361f53acb3171b55ad9e2b0270a5610df4f31',renderer='775e6cb7f2e6b182a014839cec35717216599560aca1b50d602a1d894d08531c'}
-- Synthetic digest inputs test binding/ownership, not cryptographic bytes.
-- The real published helpers are verified separately by actual native runs.
local function digest(bytes)return hashes[bytes]end
local manifest={id='source',github='absol89/Gen2Recomped-DramaticShapes',version='2.1.4'}
local owner={manifest=manifest,path='mods/source'}
local files={['mods/source/lib/WorldCanvasOrientation.lua']='world',['mods/source/lib/RendererOrientation.lua']='renderer'}
local loader={loaded={owner,{manifest={id='native'},path='mods/native'}},fs={read=function(path)return files[path]end},content={render_pipelines={owners={voxel='source',other='native',explicit='source',portable='source'}}}}
local data={render_pipelines={voxel={drawWorld=function()end},other={drawWorld=function()end},explicit={drawWorld=function()end,worldOrientation='native'},portable={drawWorld=function()end,worldFormat='renderData.v1'}}}
local def=data.render_pipelines.voxel
T.eq(M.bind(loader,data,digest),1,'only verified producer world pipeline receives a compatibility default')
T.eq(M.orientation(def),'legacy','known Gen2 Metal preflip is retained as explicit compositor contract')
T.eq(Renderer.mirrorsWorldOverride(def),true,'actual native compositor consumes the verified contract')
T.eq(Renderer.mirrorsWorldOverride(data.render_pipelines.other),false,'native Gen2 mod default unchanged')
T.eq(Renderer.mirrorsWorldOverride(data.render_pipelines.explicit),false,'explicit native convention wins')
T.eq(Renderer.mirrorsWorldOverride(data.render_pipelines.portable),false,'portable renderer remains native')
T.eq(def.worldOrientation,nil,'authored definition is never rewritten')
backend='OpenGL';M.bind(loader,data,digest);T.eq(M.orientation(def),nil,'desktop OpenGL has no published preflip')
backend='OpenGL ES';M.bind(loader,data,digest);T.eq(M.orientation(def),'legacy','the verified Apple ES helper branch matches')
major=11;M.bind(loader,data,digest);T.eq(Renderer.mirrorsWorldOverride(def),false,'LOVE11 keeps existing canvas convention')
major=12;backend='Metal';M.bind(loader,data,digest);Version.set('red');T.eq(M.orientation(def),nil,'Gen1 never inherits a Gen2 compositor correction');Version.set('crystal')
for _,change in ipairs{'version','repo','world','renderer','owner','unloaded','oversize'}do
 manifest.version,manifest.github='2.1.4','absol89/Gen2Recomped-DramaticShapes'
 files['mods/source/lib/WorldCanvasOrientation.lua']='world';files['mods/source/lib/RendererOrientation.lua']='renderer'
 loader.loaded={owner};loader.content.render_pipelines.owners.voxel='source'
 if change=='version'then manifest.version='2.1.5'
 elseif change=='repo'then manifest.github='other/repo'
 elseif change=='world'then files['mods/source/lib/WorldCanvasOrientation.lua']='changed'
 elseif change=='renderer'then files['mods/source/lib/RendererOrientation.lua']='changed'
 elseif change=='owner'then loader.content.render_pipelines.owners.voxel='native'
 elseif change=='unloaded'then loader.loaded={}
 else files['mods/source/lib/WorldCanvasOrientation.lua']=string.rep('x',65537)end
 T.eq(M.bind(loader,data,digest),0,change..' cannot receive an unproven canvas policy')
 T.eq(M.orientation(def),nil,change..' clears old session policy')
end
manifest.version,manifest.github='2.1.4','absol89/Gen2Recomped-DramaticShapes';loader.loaded={owner};loader.content.render_pipelines.owners.voxel='source'
files['mods/source/lib/WorldCanvasOrientation.lua']='world';files['mods/source/lib/RendererOrientation.lua']='renderer'
T.eq(M.bind(loader,data,digest),1,'valid later reload binds again');M.reset();T.eq(M.orientation(def),nil,'teardown sheds retained producer policy')
T.eq(M.bind({},data,digest),0,'no loader content is a no-op')
love.graphics.getRendererInfo,love.getVersion=graphics,version;Version.set(previous)
T.finish('verified published world canvas contracts')
