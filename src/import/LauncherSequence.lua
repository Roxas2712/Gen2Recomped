-- Nonblocking startup and cartridge insertion. The original play method owns
-- the actual boot; it is called once, from update, after the sequence ends.
local Sequence = {}
local Library = require('src.import.LauncherLibrary')
local Strings = require('src.core.Strings')
local Versions = require('src.core.GameVersion')

Sequence.INTRO_DURATION = 14.4
Sequence.PLAY_DURATION = 5.6
Sequence.LATCH_AT = 1.65
Sequence.POWER_AT = 1.98
Sequence.LOGO_AT = 3.0
Sequence.ZOOM_AT = 3.95

local function clamp(value) return math.max(0,math.min(1,value)) end
local function smooth(value) value=clamp(value);return value*value*(3-2*value) end

function Sequence.stages(state)
  local t=state.elapsed
  return {locked=state.kind=='play' and t>=Sequence.LATCH_AT,
    powered=state.kind=='play' and t>=Sequence.POWER_AT,
    logo=state.kind=='play' and smooth((t-Sequence.LOGO_AT)/0.78) or 0,
    zoom=state.kind=='play' and smooth((t-Sequence.ZOOM_AT)/(Sequence.PLAY_DURATION-Sequence.ZOOM_AT)) or 0}
end

function Sequence.new(kind, version)
  return {kind=kind, version=version or 'crystal', elapsed=0,
    duration=kind=='intro' and Sequence.INTRO_DURATION or Sequence.PLAY_DURATION}
end

function Sequence.advance(state, dt)
  state.elapsed = math.min(state.duration, state.elapsed + math.max(0, dt or 0))
  return state.elapsed >= state.duration
end

function Sequence.insertion(state)
  if state.kind~='play' then return 0 end
  local p = clamp((state.elapsed-0.12)/(Sequence.LATCH_AT-0.12))
  return p*p*(3-2*p)
end

function Sequence.motion(state)
  local p=Sequence.insertion(state)
  local align=math.max(0,math.min(1,p/0.68))
  align=align*align*(3-2*align)
  local descend=math.max(0,math.min(1,(p-0.68)/0.32))
  return p,align,descend*descend
end

function Sequence.install(RI)
  local U = RI._ui
  local col = U.col
  local new = RI.new
  RI.new = function(...)
    local self = new(...)
    if self.launcher and self.sidebarMode and not self.workState and not self.forceImport
      and self:_settings().launcherAnimations ~= false then
      self._launcherSequence = Sequence.new('intro')
    end
    return self
  end

  local play = RI.play
  RI.play = function(self, version, ...)
    if self._launcherSequence or self._handedOff then return end
    if self.workState=='working' or not self.ready[version] then return end
    if not self.sidebarMode or self:_settings().launcherAnimations == false then
      return play(self, version, ...)
    end
    self._padDir = {}
    self._padAxis = {leftx=0,lefty=0,righty=0}
    self._launcherSequence = Sequence.new('play', version)
  end

  local update = RI.update
  RI.update = function(self, dt, ...)
    self._sequenceInputGuard = math.max(0, (self._sequenceInputGuard or 0) - dt)
    local state = self._launcherSequence
    if state then
      require('src.import.LauncherBackdrop').setPaused(true)
      if state.kind=='intro' and not state.soundStarted then
        state.soundStarted=true
        if love.audio and love.audio.newSource then
          local ok,source=pcall(love.audio.newSource,'assets/launcher/retro_intro_riff.wav','static')
          if ok and source then
            self._introSound=source
            source:setVolume(math.max(0,math.min(1,(tonumber(self:_settings().musicVol) or 5)/7))*0.65)
            source:play()
          end
        end
      end
      self.pulse = (self.pulse or 0) + dt
      local done=not state.cancelled and Sequence.advance(state, dt)
      if state.kind=='play' and not state.cancelled and not done and not state.latchStarted and Sequence.insertion(state)>=1 then
        state.latchStarted=true
        if love.audio and love.audio.newSource then
          local ok,source=pcall(love.audio.newSource,'assets/launcher/cartridge_latch.wav','static')
          if ok and source then
            self._latchSound=source
            source:setVolume(math.max(0,math.min(1,(tonumber(self:_settings().sfxVol) or 5)/7))*0.7)
            source:play()
          end
        end
      end
      if state.kind=='play' and not state.cancelled and not done and not state.powerStarted and state.elapsed>=Sequence.POWER_AT then
        state.powerStarted=true
        if love.audio and love.audio.newSource then
          local kind=require('src.import.LauncherHardware').kind(state.version)
          local ok,source=pcall(love.audio.newSource,'assets/launcher/power_'..kind..'.wav','static')
          if ok and source then
            self._powerSound=source
            source:setVolume(clamp((tonumber(self:_settings().sfxVol) or 5)/7)*0.7)
            source:play()
          end
        end
      end
      if state.cancelled or done then
        self._launcherSequence = nil
        if self._introSound then self._introSound:stop();self._introSound=nil end
        if self._latchSound then self._latchSound:stop();self._latchSound=nil end
        if self._powerSound then self._powerSound:stop();self._powerSound=nil end
        self._sequenceInputGuard = 0.15
        if state.kind=='play' and not state.cancelled then return play(self, state.version) end
      end
      return
    end
    return update(self, dt, ...)
  end

  local function input(self, cancel)
    local state = self._launcherSequence
    if not state then return (self._sequenceInputGuard or 0)>0 end
    if cancel and state.kind=='play' then state.cancelled=true
    else state.elapsed=state.duration end
    return true
  end
  for _,method in ipairs({'mousepressed','touchpressed','touchreleased','keypressed','gamepadpressed'}) do
    local original = RI[method]
    if original then
      RI[method] = function(self, ...)
        local a,b = ...
        local cancel = (method=='keypressed' and a=='escape')
          or (method=='gamepadpressed' and require('src.core.GamepadMap').mapGamepadButton(b)=='b')
        if input(self,cancel) then return end
        return original(self,...)
      end
    end
  end
  -- Scrolling, drags and text input must not change the hidden page either.
  for _,method in ipairs({'wheelmoved','touchmoved','mousereleased','textinput','gamepadaxis','gamepadreleased','joystickhat'}) do
    local original=RI[method]
    if original then RI[method]=function(self,...)
      if self._launcherSequence or (self._sequenceInputGuard or 0)>0 then return end
      return original(self,...)
    end end
  end

  local function lightning(cx,cy,w,h,s,elapsed,phase)
    if phase>0.62 then return end
    local g=love.graphics
    local fade=math.min(1,elapsed*2)*math.min(1,(0.62-phase)*7)
    local targets={{0.03,0.12},{0.94,0.06},{0.01,0.72},{0.98,0.80},{0.30,0.02},{0.78,0.98}}
    for i,origin in ipairs(targets) do
      local travel=(elapsed*1.1+i*0.17)%1
      local sx,sy=origin[1]*w,origin[2]*h
      local points={}
      for segment=0,11 do
        local q=segment/11
        local along=math.min(1,travel*1.4+q*0.28)
        local jag=math.sin(segment*17.31+i*2.9+math.floor(elapsed*17))*18*s*(1-q)
        points[#points+1]=sx+(cx-sx)*along+jag
        points[#points+1]=sy+(cy-sy)*along-jag*0.6
      end
      local rgb=i%2==0 and {112,220,255} or {180,105,255}
      col(rgb,fade*0.09);g.setLineWidth(10*s);g.line(points)
      col(rgb,fade*0.35);g.setLineWidth(4*s);g.line(points)
      col({221,245,255},fade*0.9);g.setLineWidth(math.max(1,1.2*s));g.line(points)
    end
    for i=1,18 do
      local angle=i*2.39996+elapsed*0.3
      local radius=(1-((elapsed*0.5+i/18)%1))*210*s
      col(i%2==0 and {136,227,255} or {196,141,255},fade*0.7)
      g.circle('fill',cx+math.cos(angle)*radius,cy+math.sin(angle)*radius*0.38,1.6*s)
    end
    g.setLineWidth(1)
  end

  local function screenLightning(sx,sy,tx,ty,progress,s)
    if progress<=0 or progress>=1 then return end
    local g=love.graphics
    local strength=math.sin(progress*math.pi)
    for ray=1,5 do
      local targetX=tx+(ray-3)*48*s
      local targetY=ty+math.sin(ray*1.7)*18*s
      local points={sx,sy}
      for i=1,8 do
        local t=i/8
        local jitter=math.sin(ray*13+i*8+math.floor(progress*26))*13*s*math.sin(t*math.pi)
        points[#points+1]=sx+(targetX-sx)*t+jitter
        points[#points+1]=sy+(targetY-sy)*t-jitter
      end
      col(ray%2==0 and {189,121,255} or {112,224,255},strength*0.15)
      g.setLineWidth(8*s);g.line(points)
      col({216,246,255},strength*0.9);g.setLineWidth(1.3*s);g.line(points)
    end
    g.setLineWidth(1)
  end

  function RI:_drawLauncherSequence()
    local state = self._launcherSequence
    if not state then return end
    local g,P = love.graphics,RI.palette()
    local ox,oy,w,h = require('src.core.SafeArea').rect()
    local s=math.min(w/680,h/640,1.4)
    local cx,cy=ox+w/2,oy+h/2
    local intro=state.kind=='intro'
    local phase=state.elapsed/state.duration
    local accent=Library.edition(state.version)
    local logo=self.gen2Logo or self.logo
    local stage=Sequence.stages(state)
    local dock=intro and smooth((phase-0.93)/0.07) or 0
    self._sequenceFadeShader=self._sequenceFadeShader or g.newShader([[
      extern number opacity;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pos) {
        return Texel(tex, uv) * color * vec4(1.0,1.0,1.0,opacity);
      }
    ]])
    g.push('all');g.origin();g.setScissor()
    self._sequenceFadeShader:send('opacity',1-dock)
    g.setShader(self._sequenceFadeShader)
    col(P.bgBot);g.rectangle('fill',0,0,g.getWidth(),g.getHeight())

    if intro then
      -- Application identity only: no game, cartridge or device in this intro.
      local logoY=oy+h*0.44
      col(accent,0.04);g.circle('fill',cx,logoY,230*s)
      col(accent,0.09);g.circle('line',cx,logoY,230*s)
      lightning(cx,logoY,w,h,s,state.elapsed,phase)
      g.setFont(self.labelFont);col(accent,1-dock)
      g.printf(Strings('YOUR NEXT CHAPTER'),ox,oy+h*0.22,w,'center')
      if logo then
        local lw,lh=logo:getDimensions()
        local logoW=math.min(w*0.80,460*s)
        local mainS=self._s or 1
        local endScale=math.min(218*mainS/lw,62*mainS/lh,(w-40*mainS)/lw)
        local sc=logoW/lw*(1-dock)+endScale*dock
        local left=(cx-lw*sc/2)*(1-dock)+(ox+20*mainS)*dock
        local top=(logoY-lh*sc/2)*(1-dock)+(oy+(80*mainS-lh*sc)/2)*dock
        local reveal=smooth((state.elapsed-0.72)/7.0)
        g.setShader()
        g.setScissor(math.floor(left),math.floor(top),math.ceil(lw*sc*reveal),math.ceil(lh*sc))
        g.setColor(1,1,1,clamp(state.elapsed/0.3));g.draw(logo,left,top,0,sc,sc)
        g.setScissor()
      end
      g.setFont(self.hintFont);col(P.warning,1-dock)
      g.printf(Strings('Tap or press any key to skip'),ox,oy+h-44*s,w,'center')
    else
      local Hardware=require('src.import.LauncherHardware')
      local p,align,descent=Sequence.motion(state)
      local device=Hardware.deviceGeometry(state.version,cx,oy+h*0.43,s)
      local screenX,screenY,screenW,screenH=Hardware.screenPoint(device)
      local rectX,rectY=Hardware.screenRect(device)
      -- Exponential camera travel keeps the last part from accelerating abruptly.
      -- Focus and scale both settle on the lit display, filling the actual window.
      local finalScale=math.max(w/(screenW-8*s),h/(screenH-8*s))*1.03
      local cameraScale=math.exp(math.log(math.max(1,finalScale))*stage.zoom)
      local focusX=cx+(screenX-cx)*stage.zoom
      local focusY=cy+(screenY-cy)*stage.zoom
      g.push('all');g.translate(cx,cy);g.scale(cameraScale);g.translate(-focusX,-focusY)
      col(accent,0.035);g.circle('fill',cx,cy,230*s)
      col(accent,0.09);g.circle('line',cx,cy,230*s)
      local cartH=(142*(1-align)+(device.kind=='gba' and 66 or device.kind=='nds' and 82 or 100)*align)*s
      local startX=cx-250*s
      local cartX=startX+(device.slotX-startX)*align
      local cartY=device.slotY-24*s-36*s*align-65*s*math.sin(align*math.pi)+100*s*descent
      local cw,ch=Hardware.cartSize(state.version)
      Hardware.cartridge(self,state.version,cartX,cartY,cartH*cw/ch,cartH,-0.46*(1-align))
      Hardware.device(self,state.version,device,stage.locked,{powered=stage.powered,logo=false})
      if stage.powered then
        -- Keep electricity and the wordmark inside the physical display aperture.
        local clipX,clipY=g.transformPoint(rectX+3*s,rectY+3*s)
        local clipW,clipH=(screenW-6*s)*cameraScale,(screenH-6*s)*cameraScale
        local x1,y1=math.max(0,clipX),math.max(0,clipY)
        local x2,y2=math.min(g.getWidth(),clipX+clipW),math.min(g.getHeight(),clipY+clipH)
        g.setScissor(math.floor(x1),math.floor(y1),math.max(0,math.ceil(x2-x1)),math.max(0,math.ceil(y2-y1)))
        local power=clamp((state.elapsed-Sequence.POWER_AT)/0.65)
        col(accent,0.10+0.12*math.sin(power*math.pi))
        g.rectangle('fill',rectX,rectY,screenW,screenH)
        if state.elapsed<Sequence.LOGO_AT then
          col({221,245,255},0.3*(1-power))
          g.rectangle('fill',rectX,rectY+screenH*power,screenW,1.5*s)
        end
        local electric=clamp((state.elapsed-Sequence.LOGO_AT)/0.9)
        screenLightning(screenX,screenY+screenH*0.35,screenX,screenY,electric,screenW/260)
        if logo and stage.logo>0 then
          local lw,lh=logo:getDimensions()
          local sc=math.min(screenW*0.84/lw,screenH*0.60/lh)
          local left,top=screenX-lw*sc/2,screenY-lh*sc/2
          local lx,ly=g.transformPoint(left,top)
          -- The lightning draws the logo across the display before the camera moves.
          g.setScissor(math.max(0,math.floor(lx)),math.max(0,math.floor(ly)),
            math.max(0,math.ceil(lw*sc*cameraScale*stage.logo)),math.max(0,math.ceil(lh*sc*cameraScale)))
          g.setColor(1,1,1,stage.logo);g.draw(logo,left,top,0,sc,sc)
        end
        g.setScissor()
      end
      g.pop()
      local hud=1-smooth(stage.zoom/0.45)
      g.setFont(self.labelFont);col(accent,hud)
      g.printf(Strings('ONE MORE ADVENTURE'),ox,oy+32*s,w,'center')
      g.setFont(self.gameNameFont);col(P.ink,hud)
      local title=Versions.info(state.version).displayName
      local ts=math.min(1.15,w*0.85/math.max(1,self.gameNameFont:getWidth(title)))
      g.print(title,cx-self.gameNameFont:getWidth(title)*ts/2,oy+76*s,0,ts,ts)
      local status=not stage.locked and 'INSERTING CARTRIDGE'
        or not stage.powered and 'CARTRIDGE LOCKED'
        or state.elapsed<Sequence.LOGO_AT and 'POWER ON'
        or stage.zoom>0 and 'ENTERING YOUR NEXT CHAPTER' or 'FORMING YOUR NEXT CHAPTER'
      local statusY=math.min(oy+h-150*s,device.y+device.h+28*s)
      g.setFont(self.labelFont);col(accent,hud);g.printf(Strings(status),ox,statusY,w,'center')
      -- Native framebuffer and current drawable size, independent of camera magnification.
      local nativeW,nativeH,screens=Hardware.nativeResolution(state.version)
      local targetW,targetH=g.getDimensions()
      local resolution=('%d × %d%s  >  %d × %d'):format(nativeW,nativeH,screens==2 and ' · 2 SCREENS' or '',targetW,targetH)
      g.setFont(self.hintFont)
      local rw=self.hintFont:getWidth(resolution)+32*s
      col({6,12,20},0.88);g.rectangle('fill',cx-rw/2,oy+h-94*s,rw,30*s,8*s,8*s)
      col({173,218,232});g.printf(resolution,ox,oy+h-87*s,w,'center')
      col(P.warning,1-stage.zoom)
      g.printf(Strings('Tap / Enter to start now   ·   Esc / B to cancel'),ox,oy+h-44*s,w,'center')
    end
    g.pop()
  end

  local draw=RI.draw
  RI.draw=function(self,...)
    -- The first normal draw creates the responsive fonts used by the sequence.
    local state=self._launcherSequence
    if not state or not self.gameNameFont or (state.kind=='intro' and state.elapsed/state.duration>0.93) then draw(self,...) end
    if self._launcherSequence then self:_drawLauncherSequence() end
  end

  local rows=RI._settingsRows
  RI._settingsRows=function(self,...)
    local result=rows(self,...)
    if self.settingsPage=='launcher' then
      result[#result+1]={kind='option',scope='launcher',label='STARTUP & CARTRIDGE ANIMATION',
        note='A short intro and cartridge insertion when starting a game.',
        row={id='launcherAnimations',values={true,false},labels={[true]='ON',[false]='OFF'}}}
    end
    return result
  end
end

return Sequence
