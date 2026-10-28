package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local oldVersion,oldCompiler=love.getVersion,love.graphics.newShader
love.getVersion=function()return 12,0,0 end
local Clip=require('src.render.ClipSpaceCompat')
local manual=[[uniform mat4 vp;vec4 position(mat4 transform_projection,vec4 p){return vp*p;}]]
local standard=[[vec4 position(mat4 transform_projection,vec4 p){return transform_projection*p;}]]
local fixed=Clip.legacyShader(manual)
T.check(fixed:find('clip.y*=-love_ClipSpaceParams.x;',1,true),'old canvas clip coordinates include the native backend correction')
T.eq(Clip.legacyShader(fixed),fixed,'shader normalization is idempotent')
T.eq(Clip.legacyShader(standard),standard,'standard 2D transform is unchanged')
local marked='#define POKEPORT_NATIVE_CLIP_SPACE 1\n'..manual
T.eq(Clip.legacyShader(marked),marked,'explicit native clip contract is preserved')
love.getVersion=function()return 11,5,0 end
T.eq(Clip.legacyShader(manual),manual,'LÖVE 11 retains its historical shader source')
love.getVersion=function()return 12,0,0 end
love.graphics.newShader=function(source)return {source=source}end
for _,api in ipairs({2,3})do
 local run=T.sdk.loadMods({'mods/shader_probe'},{fs=T.sdk.memfs({
  ['mods/shader_probe/manifest.json']=('{"id":"shader_probe","name":"Shader coordinates","version":"1.0.0","api":%d,"entry":"main.lua","affects_link":false}'):format(api),
  ['mods/shader_probe/main.lua']=[[
   local mod=...
   mod.exports.shader=love.graphics.newShader('uniform mat4 vp;vec4 position(mat4 transform_projection,vec4 p){return vp*p;}')
  ]],
 })})
 T.eq(#run.errors,0,'shader probe loads on API '..api)
 local source=run.loader.exports.shader_probe.shader.source
 T.eq(source~=manual,api==2,'only old mod API shader sources are normalized')
 run.release()
end
require('src.mods.LegacyShaderCompat').reset()
love.graphics.newShader=oldCompiler;love.getVersion=oldVersion
T.finish('Legacy mod shader coordinate compatibility')
