-- Nonblocking startup and cartridge insertion. The original play method owns
-- the actual boot; it is called once, from update, after the sequence ends.
local Sequence = {}
local Library = require('src.import.LauncherLibrary')
local Strings = require('src.core.Strings')
local Versions = require('src.core.GameVersion')

Sequence.INTRO_DURATION = 6.0
Sequence.PLAY_DURATION = 2.4

function Sequence.new(kind, version)
  return {kind=kind, version=version or 'crystal', elapsed=0,
    duration=kind=='intro' and Sequence.INTRO_DURATION or Sequence.PLAY_DURATION}
end

function Sequence.advance(state, dt)
  state.elapsed = math.min(state.duration, state.elapsed + math.max(0, dt or 0))
  return state.elapsed >= state.duration
end

function Sequence.insertion(state)
  local start=state.kind=='intro' and 0.55 or 0.07
  local span=state.kind=='intro' and 0.24 or 0.42
  local p = math.max(0, math.min(1, (state.elapsed/state.duration - start)/span))
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
      if not state.cancelled and not done and not state.latchStarted and Sequence.insertion(state)>=1 then
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
      if state.cancelled or done then
        self._launcherSequence = nil
        if self._introSound then self._introSound:stop();self._introSound=nil end
        if self._latchSound then self._latchSound:stop();self._latchSound=nil end
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
    local cx,cy=ox+w/2,oy+h*(state.kind=='intro' and 0.50 or 0.47)
    local accent=Library.edition(state.version)
    local p,align,descent=Sequence.motion(state)
    local intro=state.kind=='intro'
    local phase=state.elapsed/state.duration
    local dock=intro and math.max(0,math.min(1,(phase-0.90)/0.10)) or 0
    local burst=math.max(0,math.min(1,(phase-(intro and 0.79 or 0.49))/(intro and 0.11 or 0.31)))
    local ending=not intro and math.max(0,math.min(1,(phase-0.94)/0.06)) or 0
    dock=dock*dock*(3-2*dock)
    self._sequenceFadeShader=self._sequenceFadeShader or g.newShader([[
      extern number opacity;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 pos) {
        return Texel(tex, uv) * color * vec4(1.0,1.0,1.0,opacity);
      }
    ]])
    g.push('all'); g.origin(); g.setScissor()
    self._sequenceFadeShader:send('opacity',(1-dock)*(1-ending))
    g.setShader(self._sequenceFadeShader)
    col(P.bgBot);g.rectangle('fill',0,0,g.getWidth(),g.getHeight())
    col(accent,0.035);g.circle('fill',cx,cy,230*s)
    col(accent,0.09);g.setLineWidth(1)
    g.circle('line',cx,cy,230*s);g.circle('line',cx,cy,198*s)
    if intro then lightning(cx,oy+125*s,w,h,s,state.elapsed,phase) end
    g.setFont(self.labelFont);col(accent)
    g.printf(Strings(intro and 'YOUR NEXT CHAPTER' or 'ONE MORE ADVENTURE'),ox,oy+32*s,w,'center')
    local title=intro and '' or (Versions.info(state.version).displayName)
    g.setFont(self.gameNameFont);col(P.ink,math.max(0,1-burst*5))
    local font=self.gameNameFont
    local ts=math.min(1.35,w*0.85/math.max(1,font:getWidth(title)))
    g.print(title,cx-font:getWidth(title)*ts/2,oy+83*s,0,ts,ts)
    -- A turning cartridge arcs into the top slot of its own handheld family.
    local Hardware=require('src.import.LauncherHardware')
    local device=Hardware.deviceGeometry(state.version,cx,cy,s)
    local cartH=(142*(1-align)+(device.kind=='gba' and 66 or device.kind=='nds' and 82 or 100)*align)*s
    local startX=cx-250*s
    local cartX=startX+(device.slotX-startX)*align
    local cartY=device.slotY-24*s-36*s*align-65*s*math.sin(align*math.pi)+100*s*descent
    local cw,ch=Hardware.cartSize(state.version)
    Hardware.cartridge(self,state.version,cartX,cartY,cartH*cw/ch,cartH,-0.46*(1-align))
    Hardware.device(self,state.version,device,p>=1)
    local screenX,screenY,screenW=Hardware.screenPoint(device)
    screenLightning(screenX,screenY,cx,oy+125*s,burst,s)
    local statusY=math.min(oy+h-112*s,device.y+device.h+28*s)
    g.setFont(self.labelFont);col(accent)
    local status=intro and phase<0.53 and 'CHARGING THE NEXT CHAPTER'
      or p<1 and 'INSERTING CARTRIDGE' or burst<0.35 and 'CARTRIDGE LOCKED'
      or intro and 'WELCOME HOME' or 'POWERING YOUR NEXT CHAPTER'
    g.printf(Strings(status),ox,statusY,w,'center')
    local barW=220*s
    col(P.cardBorder,0.2);g.rectangle('fill',cx-barW/2,statusY+32*s,barW,3*s,1,1)
    col(accent);g.rectangle('fill',cx-barW/2,statusY+32*s,barW*state.elapsed/state.duration,3*s,1,1)
    g.setFont(self.hintFont);col(P.warning)
    g.printf(Strings(intro and 'Tap or press any key to skip' or 'Tap / Enter to start now   ·   Esc / B to cancel'),ox,oy+h-44*s,w,'center')
    -- The actual RetroRecomped wordmark powers on, then docks into the header.
    g.setShader()
    local logo=self.gen2Logo or self.logo
    if logo then
      local lw,lh=logo:getDimensions()
      local mainS=self._s
      local startW=math.min(w*0.78,(intro and 380 or 140)*s)
      local targetW=math.min(w*0.78,380*s)
      local rise=1-(1-burst)^3
      local secondLogo=burst>0
      local logoW=secondLogo and (screenW*0.8*(1-rise)+targetW*rise) or startW
      local endScale=math.min(218*mainS/lw,62*mainS/lh,(w-40*mainS)/lw)
      local scale=logoW/lw*(1-dock)+endScale*dock
      local logoCX=secondLogo and (screenX*(1-rise)+cx*rise) or cx
      local targetTop=oy+60*s
      local startLeft=secondLogo and logoCX-lw*scale/2 or intro and cx-lw*scale/2 or ox+24*s
      local startTop=secondLogo and (screenY-lh*scale/2)*(1-rise)+targetTop*rise or oy+(intro and 60 or 16)*s
      local left=startLeft*(1-dock)+(ox+20*mainS)*dock
      local top=startTop*(1-dock)+(oy+(80*mainS-lh*scale)/2)*dock
      local reveal=secondLogo and 1 or intro and math.max(0,math.min(1,(state.elapsed-0.8)/1.4)) or math.min(1,state.elapsed/0.32)
      local opacity=secondLogo and math.min(1,burst*5) or intro and (1-math.max(0,math.min(1,(phase-0.58)/0.16))) or 1
      g.setScissor(math.floor(left),math.floor(top),math.ceil(lw*scale*reveal),math.ceil(lh*scale))
      g.setColor(1,1,1,math.min(1,state.elapsed/0.2)*opacity*(1-ending))
      g.draw(logo,left,top,0,scale,scale)
      g.setScissor()
    end
    g.pop()
  end

  local draw=RI.draw
  RI.draw=function(self,...)
    -- The first normal draw creates the responsive fonts used by the sequence.
    local state=self._launcherSequence
    if not state or not self.gameNameFont or (state.kind=='intro' and state.elapsed/state.duration>0.90) then draw(self,...) end
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
