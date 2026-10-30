-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local images,paths=0,{}
local original=love.graphics.newImage
love.graphics.newImage=function(path)images=images+1;paths[#paths+1]=path;return{path=path}end
local run=T.sdk.loadMods({'mods/image_probe'},{data=T.fixtures.fresh(),fs=T.sdk.memfs({
  ['mods/image_probe/manifest.json']=[[{"id":"image_probe","name":"Image probe","version":"1.0.0","api":2,"entry":"main.lua","optional_imports":[{"id":"portrait","file":"portrait.png"}]}]],
  ['mods/image_probe/baseroms/portrait.png']='synthetic image seam',
  ['mods/image_probe/main.lua']=[[
    local mod=...
    mod.exports.image=function(path)return mod.assets:image(path)end
  ]],
})})
T.eq(#run.errors,0,'native API2 mod loads unchanged')
local image=run.loader.exports.image_probe.image
local first=image('./portraits/front.png')
T.eq(first.path,'mods/image_probe/portraits/front.png','image uses normalized mod path')
T.eq(image('portraits/front.png'),first,'equivalent relative spellings share image identity')
T.eq(images,1,'second relative spelling does not allocate another image')
for _,path in ipairs({'../other/portrait.png','/absolute.png','C:/absolute.png','C:relative.png','folder\\image.png','','bad\0.png'})do
  T.eq(pcall(image,path),false,'invalid image path refused before graphics access')
end
T.eq(pcall(image,{}),false,'non-string image path refused')
T.eq(images,1,'invalid names never reach graphics')
local imported=image('portrait.png')
T.eq(imported.path,'mods/image_probe/baseroms/portrait.png','portable import uses its declared canonical location')
T.eq(image('baseroms/portrait.png'),imported,'legacy and canonical import spellings share image identity')
T.eq(images,2,'import alias is cached once')
run.release();love.graphics.newImage=original
T.finish('native mod image path boundary')
