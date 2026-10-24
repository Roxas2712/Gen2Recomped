-- Recovery for macOS OpenGL contexts whose system framebuffer is undefined.
-- The game still renders with OpenGL; only the finished RGBA image is handed
-- to Core Animation. Never selects another application's window or context.
local M = {}
local native
local function api()
  if native then return native end
  local ffi = require("ffi")
  ffi.cdef[[
    typedef struct { double x,y; } G2SurfacePoint;
    typedef struct { double width,height; } G2SurfaceSize;
    typedef struct { G2SurfacePoint origin; G2SurfaceSize size; } G2SurfaceRect;
    void *objc_getClass(const char*); void *sel_registerName(const char*);
    void objc_msgSend(void);
    void glGetIntegerv(unsigned int,int*);
    unsigned int glCheckFramebufferStatus(unsigned int);
    const void *CFDataCreate(const void*,const unsigned char*,long);
    void CFRelease(const void*);
    void *CGColorSpaceCreateDeviceRGB(void); void CGColorSpaceRelease(void*);
    void *CGDataProviderCreateWithCFData(const void*); void CGDataProviderRelease(void*);
    void *CGImageCreate(unsigned long,unsigned long,unsigned long,unsigned long,
      unsigned long,void*,unsigned int,void*,const double*,bool,int);
    void CGImageRelease(void*);
  ]]
  local objc=ffi.load("/usr/lib/libobjc.A.dylib")
  local send=ffi.cast("void*(*)(void*,void*)",objc.objc_msgSend)
  local function msg(object,selector) return send(object,objc.sel_registerName(selector)) end
  local function arg(object,selector,value)
    ffi.cast("void(*)(void*,void*,void*)",objc.objc_msgSend)(object,objc.sel_registerName(selector),value)
  end
  local function rect(object,w,h)
    ffi.cast("void(*)(void*,void*,G2SurfaceRect)",objc.objc_msgSend)(object,
      objc.sel_registerName("setFrame:"),ffi.new("G2SurfaceRect",{{0,0},{w,h}}))
  end
  native={ffi=ffi,objc=objc,msg=msg,arg=arg,rect=rect,
    cg=ffi.load("/System/Library/Frameworks/CoreGraphics.framework/CoreGraphics"),
    cf=ffi.load("/System/Library/Frameworks/CoreFoundation.framework/CoreFoundation"),
    quartz=ffi.load("/System/Library/Frameworks/QuartzCore.framework/QuartzCore"),
    gl=ffi.load("/System/Library/Frameworks/OpenGL.framework/OpenGL")}
  return native
end

function M.windowNumber()
  local a=api()
  local context=a.msg(a.objc.objc_getClass("NSOpenGLContext"),"currentContext")
  local window=a.msg(a.msg(context,"view"),"window")
  local app=a.msg(a.objc.objc_getClass("NSApplication"),"sharedApplication")
  if window==nil then window=a.msg(app,"keyWindow") end
  if window==nil then window=a.msg(app,"mainWindow") end
  if window==nil then
    -- NSApplication.windows contains this process's windows only. SDL need
    -- not designate a main/key window when the test runs in the background.
    local windows=a.msg(app,"windows")
    local number=a.ffi.cast("long(*)(void*,void*)",a.objc.objc_msgSend)
    local count=tonumber(number(windows,a.objc.sel_registerName("count")))
    local at=a.ffi.cast("void*(*)(void*,void*,unsigned long)",a.objc.objc_msgSend)
    for i=0,count-1 do
      local candidate=at(windows,a.objc.sel_registerName("objectAtIndex:"),i)
      if number(candidate,a.objc.sel_registerName("isVisible"))~=0 then window=candidate;break end
    end
  end
  if window==nil then return nil end
  return tonumber(a.ffi.cast("long(*)(void*,void*)",a.objc.objc_msgSend)(window,
    a.objc.sel_registerName("windowNumber")))
end

function M.createIfUndefined()
  local a=api()
  local binding=a.ffi.new("int[1]")
  a.gl.glGetIntegerv(0x8CA6,binding) -- GL_DRAW_FRAMEBUFFER_BINDING
  if binding[0]~=0 or a.gl.glCheckFramebufferStatus(0x8D40)~=0x8219 then return nil end
  local self={reason="GL_FRAMEBUFFER_UNDEFINED",layer=nil,view=nil}
  function self:close()
    if self.layer~=nil then
      a.msg(self.layer,"removeFromSuperlayer");a.msg(self.layer,"release")
      self.layer,self.view=nil,nil
    end
  end
  function self:present(data,ww,wh)
    local context=a.msg(a.objc.objc_getClass("NSOpenGLContext"),"currentContext")
    local view=a.msg(context,"view")
    assert(view~=nil,"OpenGL recovery has no owning view")
    if self.view~=view then
      self:close()
      self.view=view
      self.layer=a.msg(a.msg(a.objc.objc_getClass("CALayer"),"layer"),"retain")
      local string=a.ffi.cast("void*(*)(void*,void*,const char*)",a.objc.objc_msgSend)
      local nearest=string(a.objc.objc_getClass("NSString"),
        a.objc.sel_registerName("stringWithUTF8String:"),"nearest")
      a.arg(self.layer,"setMagnificationFilter:",nearest)
      a.arg(self.layer,"setMinificationFilter:",nearest)
      a.arg(a.msg(view,"layer"),"addSublayer:",self.layer)
    end
    local width,height=data:getDimensions()
    local bytes=data:getString()
    assert(#bytes==width*height*4,"OpenGL recovery requires RGBA8")
    local cfdata=a.cf.CFDataCreate(nil,bytes,#bytes)
    assert(cfdata~=nil,"OpenGL recovery could not allocate frame data")
    local provider=a.cg.CGDataProviderCreateWithCFData(cfdata)
    local space=a.cg.CGColorSpaceCreateDeviceRGB()
    local image=provider~=nil and space~=nil
      and a.cg.CGImageCreate(width,height,8,32,width*4,space,1,provider,nil,false,0) or nil
    if image~=nil then
      local transaction=a.objc.objc_getClass("CATransaction")
      a.msg(transaction,"begin")
      a.ffi.cast("void(*)(void*,void*,bool)",a.objc.objc_msgSend)(transaction,
        a.objc.sel_registerName("setDisableActions:"),true)
      a.rect(self.layer,ww,wh)
      a.arg(self.layer,"setContents:",image)
      a.msg(transaction,"commit");a.msg(transaction,"flush")
      a.cg.CGImageRelease(image)
    end
    if space~=nil then a.cg.CGColorSpaceRelease(space) end
    if provider~=nil then a.cg.CGDataProviderRelease(provider) end
    a.cf.CFRelease(cfdata)
    assert(image~=nil,"OpenGL recovery could not create the window image")
  end
  return self
end
return M
