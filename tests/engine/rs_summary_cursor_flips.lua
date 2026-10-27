package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local savedImage=love.image;love.image=love.image or{}
local oldNew=love.image.newImageData
local function image(w,h,values)
  local p={w=w,h=h,values=values or{}}
  function p:getWidth()return self.w end
  function p:getHeight()return self.h end
  function p:getDimensions()return self.w,self.h end
  function p:getPixel(x,y)local v=self.values[y*self.w+x+1]or 0;return v,0,0,v==0 and 0 or 1 end
  function p:setPixel(x,y,v,_,__,alpha)self.values[y*self.w+x+1]=v;T.eq(alpha,v==0 and 0 or 1,'native transparency survives a mirrored frame')end
  function p:paste(src,dx,dy,sx,sy,sw,sh)
    for y=0,sh-1 do for x=0,sw-1 do self.values[(dy+y)*self.w+dx+x+1]=src:getPixel(sx+x,sy+y)end end
  end
  return p
end
love.image.newImageData=image
local Expand=require('src.ui.Gen3RsSummaryCursor')
local entry={frames=2,w=2,h=2,png='unchanged.png',anims={
  {{op='frame',frame=0}},{{op='frame',frame=0,hFlip=true}},
  {{op='frame',frame=0,hFlip=true}},{{op='frame',frame=1,vFlip=true}},
  {{op='frame',frame=0,hFlip=true,vFlip=true}}}}
local source=image(2,4,{0,2,3,4,5,6,7,8})
local out,pixels,changed=Expand.expand(entry,source)
T.check(changed);T.eq(out.frames,5,'repeated animation flags share one baked frame')
T.same(pixels.values,{0,2,3,4,5,6,7,8,2,0,4,3,7,8,5,6,4,3,2,0})
T.eq(out.anims[2][1].frame,2);T.eq(out.anims[3][1].frame,2)
T.eq(out.anims[4][1].frame,3);T.eq(out.anims[5][1].frame,4)
T.eq(out.anims[2][1].hFlip,nil);T.eq(out.anims[4][1].vFlip,nil)
T.eq(entry.frames,2);T.eq(entry.anims[2][1].frame,0);T.eq(entry.anims[2][1].hFlip,true)
T.same(source.values,{0,2,3,4,5,6,7,8},'original sprite pixels remain byte-for-byte equivalent')
local plain={frames=2,w=2,h=2,anims={{{op='frame',frame=1}}}}
local a,b,c=Expand.expand(plain,source);T.eq(a,plain);T.eq(b,source);T.eq(c,false)
love.image.newImageData=oldNew
love.image=savedImage
T.finish('RS summary cursor OAM flips, transparency and immutable cartridge frames')
