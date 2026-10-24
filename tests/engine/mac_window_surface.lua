-- Native-call contract without Cocoa/GPU: direct ImageData bytes must be
-- copied into CF-owned storage before a reusable LÖVE buffer can change.
package.path="./?.lua;./?/init.lua;"..package.path
local T=require("tests.harness")
local eq,check=T.eq,T.check
local view,context={layer={}},{ }
local counts={data=0,provider=0,space=0,image=0,layer=0,ptr=0}
local classes={}
local objc={}
function objc.objc_getClass(name)classes[name]=classes[name] or {class=name};return classes[name]end
function objc.sel_registerName(name)return name end
function objc.objc_msgSend(object,selector,value)
  if selector=="currentContext" then return context end
  if selector=="view" then return view end
  if selector=="layer" then
    if object==view then return view.layer end
    return {kind="layer"}
  end
  if selector=="retain" then counts.layer=counts.layer+1;return object end
  if selector=="release" then counts.layer=counts.layer-1 end
  if selector=="addSublayer:" then object.child=value end
  if selector=="setContents:" then object.image=value end
  if selector=="stringWithUTF8String:" then return value end
end
local cf={}
function cf.CFDataCreate(_,pointer,size)
  eq(size,4,"copy extent matches RGBA storage")
  counts.data=counts.data+1
  return {bytes={unpack(pointer)}}
end
function cf.CFRelease()counts.data=counts.data-1 end
local cg={}
function cg.CGColorSpaceCreateDeviceRGB()counts.space=counts.space+1;return {}end
function cg.CGColorSpaceRelease()counts.space=counts.space-1 end
function cg.CGDataProviderCreateWithCFData(data)counts.provider=counts.provider+1;return data end
function cg.CGDataProviderRelease()counts.provider=counts.provider-1 end
function cg.CGImageCreate(w,h,bits,pixelBits,stride,space,alpha,provider)
  eq(w,1,"image width");eq(h,1,"image height");eq(stride,4,"row stride")
  counts.image=counts.image+1;return {bytes=provider.bytes}
end
function cg.CGImageRelease()counts.image=counts.image-1 end
local ffi={cdef=function()end,cast=function(_,fn)return fn end}
function ffi.new(name,value)return name=="int[1]" and {[0]=0} or value end
function ffi.load(path)
  if path:find("libobjc",1,true) then return objc end
  if path:find("CoreGraphics",1,true) then return cg end
  if path:find("CoreFoundation",1,true) then return cf end
  if path:find("OpenGL",1,true) then
    return {glGetIntegerv=function(_,n)n[0]=0 end,glCheckFramebufferStatus=function()return 0x8219 end}
  end
  return {}
end
package.loaded.ffi=ffi
local Surface=require("src.render.MacWindowSurface")
local bridge=assert(Surface.createIfUndefined())
local pixels={10,20,30,255}
local data={getDimensions=function()return 1,1 end,getSize=function()return 4 end,
  getFormat=function()return "rgba8" end,getFFIPointer=function()counts.ptr=counts.ptr+1;return pixels end,
  getString=function()error("full-frame Lua copy forbidden")end}
for i=1,40 do
  pixels[1]=i;bridge:present(data,100,100)
  eq(view.layer.child.image.bytes[1],i,"current copied frame presented")
  pixels[1]=255
  eq(view.layer.child.image.bytes[1],i,"Core Animation does not borrow mutable readback storage")
  eq(counts.data+counts.provider+counts.space+counts.image,0,"temporary native objects released")
end
eq(counts.ptr,40,"presenter reads native ImageData storage directly")
eq(counts.layer,1,"only one owned layer retained")
data.getFormat=function()return "rgba16f" end
check(not pcall(bridge.present,bridge,data,100,100),"non-RGBA8 buffer refused before native access")
eq(counts.ptr,40,"invalid format never read")
bridge:close();eq(counts.layer,0,"owned layer released at shutdown")
T.finish()
