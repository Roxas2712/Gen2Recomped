package.path = './?.lua;./?/init.lua;' .. package.path
local T = require('tests.harness')
local E = require('src.world.Gen2FieldEmotes')
local Registry = require('src.mods.Registry')
local Schemas = require('src.mods.Schemas')
local data = {field={emotes={shock='base-shock.png',heart='base-heart.png',order=E.ORDER}}}
local registry = Registry.new('field', Schemas.REGISTRIES.field)
registry.base = function() return data.field end
registry:patch('emotes', {question='mod-question.png',order={'heart','question'}}, 'probe')
data.field.emotes = registry:get('emotes')
T.eq(#data.field.emotes.order,2,'authored ordering replaces the imported byte map instead of appending')
T.eq(E.kind(data,0),'heart','native byte reads authored order')
T.eq(E.kind(data,1),'question','second authored bubble')
T.eq(E.kind(data,99),'shock','unknown byte retains safe fallback')
T.eq(E.path(data,'shock'),'base-shock.png','partial mod patch retains imported bubbles')
T.eq(E.path(data,'question'),'mod-question.png','renderer selects the authored path')
T.eq(E.path({gen2MenuGfx={emotes={heart='legacy.png'}}},'heart'),'legacy.png','old cache metadata fallback')
local originalLove, assets = love, package.loaded['src.render.Assets']
local loaded, drawn = {}, {}
package.loaded['src.render.Assets']={image=function(path) loaded[#loaded+1]=path;return {path=path} end}
love={graphics={setColor=function()end,draw=function(image,x,y)drawn[#drawn+1]={image.path,x,y}end}}
local cache={}
T.check(E.draw(data,cache,'question',12,34),'native bubble draw succeeds')
T.eq(drawn[1][1],'mod-question.png','actual draw uses mod asset')
T.eq(drawn[1][2],12,'preserve native x anchor')
T.eq(drawn[1][3],34,'preserve native y anchor')
E.draw(data,cache,'question',12,34)
T.eq(#loaded,1,'cache reuses the image')
data.field.emotes.question='replacement.png'
E.draw(data,cache,'question',12,34)
T.eq(drawn[3][1],'replacement.png','new content cannot reuse stale path image')
T.check(not E.draw(data,cache,'missing',0,0),'missing optional art keeps native fallback')
love,package.loaded['src.render.Assets']=originalLove,assets
local Extractor=require('src.import.RomExtractorGen2')
local calls={}
local extractor=setmetatable({},{__index=Extractor})
function extractor:gen2RawSheet(label,w,h,path)
  calls[#calls+1]={label,w,h,path}
  if label~='HeartEmote'then return {path='assets/generated/'..path}end
end
local imported=extractor:gen2FieldEmotes()
T.eq(#calls,8,'extract all eight native emote slots')
T.same(calls[1],{'ShockEmote',2,2,'emotes/shock.png'},'native shock uses its 16x16 row-major sheet')
T.eq(imported.shock,'assets/generated/emotes/shock.png','publish actual written shock path')
T.eq(imported.heart,nil,'missing symbols cannot advertise unwritten art')
T.same(imported.order,{'shock','question','happy','sad','heart','bolt','sleep','fish'},'cartridge byte order is independent of missing optional symbols')
T.finish('Native Gen2 authored field emotes')
