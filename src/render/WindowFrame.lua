-- One complete window frame, including world, UI and native overlays.
-- macOS Metal uses an owned final target: captures read its completed pixels,
-- never a late-acquired framebufferOnly drawable. Broken macOS OpenGL system
-- framebuffers use the same target and an explicitly detected Cocoa recovery.
local M = {}
local canvas,bridge,observer,readbackBuffer
local mode="direct"
local frames=0
local function releaseReadback()
  if readbackBuffer then readbackBuffer:release();readbackBuffer=nil end
end
local function readback(target,reuse)
  if love.graphics.readbackTexture then
    if reuse then
      if not readbackBuffer then
        readbackBuffer=love.graphics.readbackTexture(target)
      else
        -- LÖVE 12's synchronous readback destination (argument 8). The Cocoa
        -- presenter copies it before the next frame may overwrite the bytes.
        love.graphics.readbackTexture(target,nil,1,nil,nil,nil,nil,readbackBuffer)
      end
      return readbackBuffer
    end
    return love.graphics.readbackTexture(target)
  end
  return target:newImageData()
end
function M.observe(callback) observer=callback end
function M.info() return {mode=mode,frames=frames} end
function M.shutdown()
  if bridge then bridge:close();bridge=nil end
  releaseReadback()
  if canvas then canvas:release();canvas=nil end
  observer=nil;mode="direct"
end

function M.draw(body,capture)
  local g=love.graphics
  local osName=love.system and love.system.getOS and love.system.getOS()
  local renderer=g.getRendererInfo and g.getRendererInfo() or ""
  if osName=="OS X" and renderer=="OpenGL" and not bridge then
    bridge=require("src.render.MacWindowSurface").createIfUndefined()
    if bridge then
      require("src.core.Logger").warn("OpenGL window framebuffer is undefined; using Cocoa frame presentation")
    end
  end
  local owned=bridge~=nil or (osName=="OS X" and renderer=="Metal")
  if not owned then
    mode="direct"
    -- Request before any clear/draw can acquire the native drawable.
    if capture or observer then
      g.captureScreenshot(function(data)
        if capture then capture(data) end
        if observer then observer(data,M.info()) end
      end)
    end
    body();frames=frames+1
    return
  end
  mode=bridge and "opengl-cocoa-frame" or "metal-frame"
  local ww,wh=g.getDimensions()
  local pw,ph=ww,wh
  if g.getPixelDimensions then pw,ph=g.getPixelDimensions() end
  local dpi=ph/wh
  if not canvas or canvas:getPixelWidth()~=pw or canvas:getPixelHeight()~=ph then
    releaseReadback()
    if canvas then canvas:release() end
    canvas=g.newCanvas(ww,wh,{format="normal",dpiscale=dpi,msaa=0})
    canvas:setFilter("nearest","nearest")
  end
  local setCanvas=g.setCanvas
  -- Scoped exactly like LauncherBackdrop's logical screen. Nested targets,
  -- pushes/pops and render pipelines keep their normal physical resources.
  g.setCanvas=function(target,...)
    if target==nil then return setCanvas({canvas,depthstencil=true}) end
    return setCanvas(target,...)
  end
  g.setCanvas()
  local ok,err=xpcall(body,debug.traceback)
  g.setCanvas=setCanvas
  setCanvas()
  if not ok then error(err,0) end
  frames=frames+1
  local data
  if bridge or capture or observer then data=readback(canvas,bridge and not capture and not observer) end
  local success,reason=xpcall(function()
    if bridge then
      bridge:present(data,ww,wh)
    else
      g.push("all")
      g.origin();g.setShader();g.setScissor();g.setColor(1,1,1,1)
      g.setColorMask(true,true,true,true);g.setStencilTest();g.setDepthMode()
      g.setBlendMode("alpha","premultiplied")
      g.clear(g.getBackgroundColor())
      g.draw(canvas,0,0)
      g.pop()
    end
    if data then
      if capture then capture(data) end
      if observer then observer(data,M.info()) end
    end
  end,debug.traceback)
  if data and data~=readbackBuffer then data:release() end
  if not success then error(reason,0) end
end
return M
