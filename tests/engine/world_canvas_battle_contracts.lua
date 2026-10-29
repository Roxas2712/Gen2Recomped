-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Direct staged overrides must prove both published code provenance and the
-- current battle/shot identity. Synthetic records, no ROM or mod source.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.render.WorldCanvasContracts')
local R=require('src.render.Renderer')
local V=require('src.core.GameVersion')
local oldGame,oldVersion=package.loaded['src.core.Game'],V.get()
local backend,major='Metal',12
local oldRenderer,oldLove=love.graphics.getRendererInfo,love.getVersion
love.graphics.getRendererInfo=function()return backend,'test','Apple','fixture'end
love.getVersion=function()return major,0,0 end
V.set('crystal')
T.eq(type(M.canvasOrientation),'function','actual native direct-override contract exists')
if type(M.canvasOrientation)~='function'then T.finish('native direct-override provenance contract absent')end
local hashes={
 ['lib/WorldCanvasOrientation.lua']='bafe05d630481229538f86e05f6361f53acb3171b55ad9e2b0270a5610df4f31',
 ['lib/RendererOrientation.lua']='775e6cb7f2e6b182a014839cec35717216599560aca1b50d602a1d894d08531c',
 ['lib/BattleStage.lua']='09a84485dcaeead5c697aef3990e974ff71156bf8201afb9f5d86b62a2cca879',
 ['lib/BattleScene.lua']='ea537e34c67470acbdd4d25da6ae7bad64ddfe30653b1f94a085a4f5f52f700f',
 ['lib/OverworldBattle.lua']='0eb3ceeac263c8d1df1ed30fb7c1b4b5b43774cd47f940a5df1792268737456b',
 ['lib/Voxel3D.lua']='3e65a6332d89ad164b41c78591293fd9a6819637976b7ab6cbaae5c7be66e3ed',
}
local files={};for name in pairs(hashes)do files['mods/source/'..name]=name end
local manifest={id='source',github='absol89/Gen2Recomped-DramaticShapes',version='2.1.4'}
local loader={loaded={{manifest=manifest,path='mods/source'}},exports={},
 fs={read=function(path)return files[path]end},content={render_pipelines={owners={voxel='source'}}}}
local def={drawWorld=function()end};local data={render_pipelines={voxel=def}}
local battle={letterboxWhite=false};local foreign={}
local canvas=love.graphics.newCanvas(800,720);local other=love.graphics.newCanvas(800,720)
local game={data=data,save={options={}},mods=loader,stack={states={battle},visibleBase=function()return 1 end}}
local ready,surface,staged,returnedBattle=true,true,true,battle
local held,shot=battle,{canvas=canvas}
local scene={battle=function()return held end,shot=function()return shot end}
local exports={battleStage={state=function(expected)
 if expected~=battle then return end
 return {battle=returnedBattle,ready=ready,surfaceOwned=surface,staged=staged}
end},lib={require=function(name)T.eq(name,'OverworldBattle','only the published stage getter is consulted');return scene end}}
loader.exports.source=exports;package.loaded['src.core.Game']=game
local function bind()return M.bind(loader,data,function(bytes)return hashes[bytes]end)end
T.eq(bind(),1,'existing registered producer admission is retained')
T.eq(M.canvasOrientation(canvas),'legacy','exact ready battle shot inherits its verified camera convention')
T.eq(R.mirrorsWorldOverride(nil,canvas),true,'actual direct renderer request resolves the shot convention')
T.eq(R.mirrorsWorldOverride(nil,other),false,'another texture cannot borrow the battle convention')
T.eq(R.mirrorsWorldOverride({worldOrientation='native'},canvas),false,'explicit native override wins over producer provenance')
T.eq(R.mirrorsWorldOverride({worldFormat='renderData.v1'},canvas),false,'portable override keeps native orientation')
T.eq(R.mirrorsWorldOverride({},canvas),false,'an explicit unrelated producer record is not reinterpreted')
R:init();R:beginFrame();R:setWorldOverride(canvas)
T.eq(R.worldOverride,canvas,'native renderer retains the same borrowed canvas')
T.eq(R.worldOverrideMirrored,true,'actual setWorldOverride records the proven convention')
local draw=love.graphics.draw;local flips=0
love.graphics.draw=function(image,x,y,rotation,sx,sy,...)
 if image==canvas then flips=flips+1;T.check(sy<0,'native endFrame applies exactly the vertical correction')end
 return draw(image,x,y,rotation,sx,sy,...)
end
R:endFrame();love.graphics.draw=draw
T.eq(flips,1,'actual endFrame consumes the corrected world once')
T.eq(R.worldOverride,nil,'completed frame does not retain the borrowed stage')
ready=false;T.eq(M.canvasOrientation(canvas),nil,'unready stage cannot claim an image');ready=true
surface=false;T.eq(M.canvasOrientation(canvas),nil,'surface ownership can be withdrawn');surface=true
staged=false;T.eq(M.canvasOrientation(canvas),nil,'a non-staged battle cannot claim an image');staged=true
returnedBattle=foreign;T.eq(M.canvasOrientation(canvas),nil,'descriptor must name the actual native stack owner');returnedBattle=battle
held=foreign;T.eq(M.canvasOrientation(canvas),nil,'published getter must still own that battle');held=battle
shot={canvas=other};T.eq(M.canvasOrientation(canvas),nil,'canvas identity must match the current shot');shot={canvas=canvas}
game.stack.states={foreign};T.eq(M.canvasOrientation(canvas),nil,'a departed battle loses canvas admission');game.stack.states={battle}
game.mods={};T.eq(M.canvasOrientation(canvas),nil,'another loader cannot inherit provenance');game.mods=loader
game.data={};T.eq(M.canvasOrientation(canvas),nil,'another dataset cannot inherit provenance');game.data=data
loader.exports.source=nil;T.eq(M.canvasOrientation(canvas),nil,'unloaded exports cannot own a canvas');loader.exports.source=exports
def.worldOrientation='native';T.eq(M.canvasOrientation(canvas),nil,'later explicit producer convention wins');def.worldOrientation=nil
def.worldFormat='renderData.v1';T.eq(M.canvasOrientation(canvas),nil,'later portable producer declaration wins');def.worldFormat=nil
loader.content.render_pipelines.owners.voxel='other';T.eq(M.canvasOrientation(canvas),nil,'changed registry owner revokes the policy');loader.content.render_pipelines.owners.voxel='source'
data.render_pipelines.voxel={};T.eq(M.canvasOrientation(canvas),nil,'replaced native pipeline cannot retain an old binding');data.render_pipelines.voxel=def
for name in pairs(hashes)do
 local key='mods/source/'..name;files[key]='changed';bind()
 T.eq(M.canvasOrientation(canvas),nil,name..' must match its published digest')
 files[key]=name
end
bind();local getter=scene.shot;scene.shot=function()error('stage unavailable')end
T.eq(M.canvasOrientation(canvas),nil,'failing optional stage getter is not an orientation claim');scene.shot=getter
backend='OpenGL';bind();T.eq(M.canvasOrientation(canvas),nil,'desktop OpenGL does not use the Metal staging convention')
backend='Metal';major=11;bind();T.eq(R.mirrorsWorldOverride(nil,canvas),false,'LOVE11 remains unchanged')
major=12;bind();V.set('red');T.eq(M.canvasOrientation(canvas),nil,'Gen1 cannot inherit a Gen2 camera correction')
V.set('crystal');M.reset();T.eq(M.canvasOrientation(canvas),nil,'teardown releases stage provenance')
package.loaded['src.core.Game']=oldGame;V.set(oldVersion)
love.graphics.getRendererInfo,love.getVersion=oldRenderer,oldLove
T.finish('direct staged canvas provenance, actual compositor and native owner lifetime')
