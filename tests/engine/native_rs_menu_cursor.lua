-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Cursor=require('src.ui.Gen3RsMenuCursor')
local Public=require('src.ui.game3.rs.menu_cursor')
local Assets=require('src.render.Assets')
local Writer=require('src.import.LuaWriter')
local Version=require('src.core.GameVersion')
local Fx=require('src.core.game3.gba_fx')
local original,version=package.loaded['src.core.Game'],Version.get()
local fs=love.filesystem;local load,exists,image,draw,fxdraw=fs.load,Assets.exists,Assets.image,love.graphics.draw,Fx.draw
-- Compare the independent constant-time strip construction with the pinned
-- public native reference, rather than maintaining a second expected formula.
local golden={
 [1]={{part='left',x=-1},{part='right',x=-6}},
 [8]={{part='left',x=-1},{part='right',x=1}},
 [9]={{part='left',x=-1},{part='middle',x=1},{part='right',x=2}},
 [33]={{part='left',x=-1},{part='wide',x=1},{part='right',x=26}},
 [40]={{part='left',x=-1},{part='wide',x=1},{part='right',x=33}},
 [41]={{part='left',x=-1},{part='wide',x=1},{part='middle',x=33},{part='right',x=34}},
 [42]={{part='left',x=-1},{part='wide',x=1},{part='wide',x=9},{part='right',x=35}},
 [72]={{part='left',x=-1},{part='wide',x=1},{part='wide',x=33},{part='right',x=65}},
}
for width,rows in pairs(golden)do T.same(Cursor.segments(width),rows,'native strip boundary '..width)end
local chunk=loadfile('compat/gen1-rs/reference/src/ui/game3/rs/menu_cursor.lua')
if chunk then
 local environment=setmetatable({require=function()return{}end},{__index=_G});setfenv(chunk,environment)
 local Reference=chunk()
 for width=1,512 do T.same(Cursor.segments(width),Reference.segments(width),'pinned native strip overlap width '..width)end
 T.same(Cursor.segments(4096),Reference.segments(4096))
end
local edited=Cursor.segments(42);edited[1].x=1000;T.eq(Cursor.segments(42)[1].x,-1,'detached segment descriptions')
for _,bad in ipairs{0,-1,4097,1.5,0/0,math.huge,'42',false}do
 T.raises(function()Cursor.segments(bad)end,'invalid native RS cursor width')
end
local manifest,files,reads,paints
fs.load=function(path)
 T.eq(path,'data/generated/gba/rse/common_ui/manifest.lua');reads=reads+1
 return assert(loadstring(Writer.encode(manifest)))
end
Assets.exists=function(path)return files[path]~=nil end
Assets.image=function(path)return files[path]end
for _,edition in ipairs{'ruby','sapphire'}do
 Version.set(edition);Cursor._service.release();reads=0;paints={}
 local game={data={constants={gen3RsBag={format=1,version=edition,common='data/generated/gba/rse/common_ui/manifest.lua'}}}}
 package.loaded['src.core.Game']=game
 manifest={layout='rs',game=edition,menuCursor={}};files={}
 for _,part in ipairs{'left','middle','wide','right'}do
  local width=part=='wide'and 32 or 8
  manifest.menuCursor[part]={png=part,w=width,h=16}
  files[part]={getDimensions=function()return width*2,32 end}
 end
 local calls=0
 Fx.draw=function(fn,options)calls=calls+1;T.eq(options,'borrowed effects');return fn()end
 love.graphics.draw=function(img,x,y,r,sx,sy)paints[#paints+1]={img,x,y,r,sx,sy}end
 local before={love.graphics.getColor()};love.graphics.setColor(.2,.3,.4,.5)
 local borrowed=Cursor.forGame(game)
 T.eq(Public.draw(144,120,42,'borrowed effects'),true);T.eq(reads,1);T.eq(calls,4)
 T.same({love.graphics.getColor()},{.2,.3,.4,.5},'white cursor colour is scoped')
 local rows=golden[42]
 for i,row in ipairs(paints)do
  local ref=rows[#rows-i+1];T.eq(row[1],files[ref.part]);T.same({row[2],row[3],row[4],row[5],row[6]}, {144+ref.x,120,0,.5,.5})
 end
 paints={};T.eq(borrowed.draw(8,120,72,'borrowed effects'),true);T.eq(reads,1,'reuses the native manifest')
 T.eq(#paints,#golden[72])
 Cursor._service.releaseOwner('retired-mod');borrowed.draw(8,120,72,'borrowed effects');T.eq(reads,2)
 Assets.invalidate();borrowed.draw(8,120,72,'borrowed effects');T.eq(reads,3,'asset changes retire manifest data')
 local actualDraw=love.graphics.draw
 love.graphics.draw=function()love.graphics.push();error('native cursor painter failed')end
 T.raises(function()borrowed.draw(1,2,42,'borrowed effects')end,'native cursor painter failed')
 T.same({love.graphics.getColor()},{.2,.3,.4,.5},'failing painter restores graphics state')
 love.graphics.draw=actualDraw
 for _,bad in ipairs{0/0,math.huge,'8',false}do
  T.raises(function()borrowed.draw(bad,1,42,'borrowed effects')end,'invalid native RS cursor position')
  T.raises(function()borrowed.draw(1,bad,42,'borrowed effects')end,'invalid native RS cursor position')
 end
 Cursor._service.release();manifest.game=edition=='ruby'and'sapphire'or'ruby'
 T.raises(function()Public.draw(1,2,42)end,'mixed-edition native RS cursor manifest');manifest.game=edition
 Cursor._service.release();manifest.menuCursor.left.h=15
 T.raises(function()Public.draw(1,2,42)end,'invalid native RS cursor part');manifest.menuCursor.left.h=16
 Cursor._service.release();local saved=files.right;files.right=nil
 T.raises(function()Public.draw(1,2,42)end,'native RS cursor image missing');files.right=saved
 Cursor._service.release();files.right={getDimensions=function()return 8,32 end}
 T.raises(function()Public.draw(1,2,42)end,'invalid native RS cursor image density');files.right=saved
 Cursor._service.release();fs.load=function()return assert(loadstring('return os.execute("invalid cache")'))end
 T.raises(function()Public.draw(1,2,42)end,'os');fs.load=function()reads=reads+1;return assert(loadstring(Writer.encode(manifest)))end
 package.loaded['src.core.Game']={data={constants={}}}
 T.eq(borrowed.draw(1,2,42),false,'retired native game cannot paint')
 T.raises(function()Public.draw(1,2,42)end,'native RS common UI unavailable')
 love.graphics.setColor(unpack(before))
end
for _,edition in ipairs{'firered','leafgreen','emerald','red','crystal'}do
 Version.set(edition);T.eq(Public.draw(1,2,42),false,'other editions retain their own cursor')
end
fs.load,Assets.exists,Assets.image,love.graphics.draw,Fx.draw=load,exists,image,draw,fxdraw
Cursor._service.release();package.loaded['src.core.Game']=original;Version.set(version)
T.finish('native RS cursor composition, high-density images, shared graphics state and owner retirement')
