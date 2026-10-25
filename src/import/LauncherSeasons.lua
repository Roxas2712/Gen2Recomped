-- Seasonal choreography. Autumn/winter use credited Cobblemon models;
-- spring/summer and the renderer fallback remain code-drawn mascots.
local Seasons = {}
local Score=require('src.import.LauncherIntroScore')
Seasons.VALUES={'auto','lightning','spring','summer','autumn','winter'}
Seasons.LABELS={auto='AUTOMATIC',lightning='LIGHTNING',spring='SPRING · BRANCHLING',
  summer='SUMMER · SPARK DRAKE',autumn='AUTUMN · GEIST',winter='WINTER · COURIER'}
local function clamp(v) return math.max(0,math.min(1,v)) end
local function ease(v) v=clamp(v);return v*v*(3-2*v) end

function Seasons.audio(kind)
  if kind=='winter' then return 'assets/launcher/retro_intro_winter.wav' end
  if kind=='autumn' then return 'assets/launcher/retro_intro_autumn.wav' end
  return 'assets/launcher/retro_intro_riff.wav'
end

function Seasons.resolve(choice,month)
  if choice and choice~='auto' and Seasons.LABELS[choice] then return choice end
  month=tonumber(month) or tonumber(os.date('%m')) or 1
  if month==12 or month<=2 then return 'winter' end
  if month<=5 then return 'spring' end
  if month<=8 then return 'summer' end
  return 'autumn'
end

function Seasons.pose(kind,t,cx,cy,s)
  if kind=='autumn' then
    local appear=ease((t-Score.ghostAppear)/(Score.ghostReady-Score.ghostAppear))
    local approach=ease((t-Score.ghostReady)/(Score.orbitStart-Score.ghostReady))
    local orbit=ease((t-Score.orbitStart)/(Score.orbitEnd-Score.orbitStart))
    local angle=orbit*math.pi*2
    local radius=math.min(292*s,math.max(70*s,cx-80*s))
    local size=math.min(1,cx/(450*s))
    local x=cx-210*s+(210*s+radius)*approach
    local y=cy+135*s*(1-approach)+math.sin(approach*math.pi)*80*s
    if t>=Score.orbitStart then x,y=cx+math.cos(angle)*radius,cy+math.sin(angle)*110*s end
    local grasp=ease((t-Score.orbitEnd)/(Score.catch-Score.orbitEnd))
    local exit=ease((t-Score.place-0.15)/(Score.duration-Score.place-0.35))
    return {x=x,y=y,alpha=appear*(1-exit),size=size*(.86+.14*math.sin(angle)),
      action=grasp,release=Score.logoReveal,travel=ease((t-Score.logoReveal)/(Score.logoLock-Score.logoReveal)),
      logoX=cx,logoY=cy,logoScale=1,logoAlpha=ease((t-Score.logoReveal)/(Score.logoLock-Score.logoReveal)),
      rotation=0,behind=t>=Score.orbitStart and t<Score.orbitEnd and math.sin(angle)<0,
      holding=t>=Score.catch,grasp=grasp}
  end
  local release=({autumn=3.2,winter=3.8,spring=3.4,summer=3.0})[kind] or 0.72
  local entry=ease((t-0.65)/1.5)
  local action=math.sin(clamp((t-release+0.8)/1.6)*math.pi)
  local exit=ease((t-9.2)/1.5)
  local x=cx-160*s-(1-entry)*230*s
  local y=cy+192*s
  if kind=='winter' then y=y-math.abs(math.sin((t-0.65)*6))*18*s*(1-exit)
  elseif kind=='autumn' then y=y-math.sin(entry*math.pi)*85*s+math.sin(t*2)*5*s
  elseif kind=='spring' then x=x+math.sin(t*26)*action*6*s
  else y=y+math.sin(t*3)*8*s end
  local originX=x+(kind=='winter' and 67 or kind=='spring' and 30 or 53)*s
  local originY=y+(kind=='winter' and 8 or kind=='spring' and -112 or -30)*s
  local travel=ease((t-release)/2.1)
  return {x=x,y=y,alpha=entry*(1-exit),action=action,release=release,travel=travel,
    logoX=originX+(cx-originX)*travel,
    logoY=originY+(cy-originY)*travel-math.sin(travel*math.pi)*(kind=='spring' and 10 or 100)*s,
    logoScale=0.12+0.88*travel,logoAlpha=ease((t-release)/0.3),
    rotation=(1-travel)*(kind=='winter' and -0.65 or kind=='spring' and 0.35 or -0.15)}
end

function Seasons.draw(kind,t,cx,cy,s,override)
  if kind=='lightning' then return end
  local g=love.graphics
  local pose=override or Seasons.pose(kind,t,cx,cy,s)
  local function col(r,b,c,a) g.setColor(r/255,b/255,c/255,(a or 1)*pose.alpha) end
  local function oval(x,y,rx,ry,r,b,c) col(r,b,c);g.ellipse('fill',x,y,rx,ry) end
  local function eyes(y,space)
    for _,side in ipairs({-1,1}) do
      oval(side*space,y,10,13,241,248,248)
      oval(side*space+3,y+1,4,7,24,35,58)
      oval(side*space+4,y-2,1.5,2,255,255,255)
    end
  end
  if kind=='autumn' and t>=Score.orbitStart and t<Score.orbitEnd then
    for i=12,1,-1 do
      local trail=Seasons.pose(kind,t-i*.045,cx,cy,s)
      g.setColor(.53,.31,.82,pose.alpha*(1-i/13)*.12)
      g.ellipse('fill',trail.x,trail.y+27*s,(5+i*.5)*s,(3+i*.25)*s)
    end
  end
  if not require('src.import.LauncherCobblemon').draw(kind,t,pose,s) then
  g.push('all');g.translate(pose.x,pose.y);g.scale(s*(pose.size or 1))
  if kind~='autumn' then col(0,0,0,0.24);g.ellipse('fill',8,82,84,10) end
  if kind=='autumn' then
    -- A long-eared wisp with a split vapor tail and a crooked little smile.
    col(58,34,96);g.polygon('fill',-67,5,-48,-53,-58,-102,-18,-71,20,-81,54,-111,48,-50,73,8,49,61,23,48,1,83,-19,55,-47,62)
    oval(1,-4,65,68,99,64,155)
    oval(-13,-22,48,48,130,88,191)
    col(167,122,220,0.65);g.arc('line','open',-9,-21,48,3.4,4.9)
    col(177,243,230);g.polygon('fill',-43,-30,-10,-22,-24,-12)
    col(177,243,230);g.polygon('fill',13,-22,45,-35,29,-12)
    col(34,22,59);g.arc('fill','closed',0,0,37,0.12,3.02)
    col(235,231,251);g.polygon('fill',-29,7,-18,12,-21,20)
    col(235,231,251);g.polygon('fill',27,7,17,13,20,21)
    oval(-72,23,17,23,114,75,172)
    oval(70,8-pose.action*22,20,15,140,96,200)
    for i=1,6 do
      col(154,113,216,0.25)
      g.ellipse('fill',-42-i*12,54+math.sin(t*4+i)*12,15-i,7)
    end
  elseif kind=='winter' then
    -- A blue courier with a copper mail sack, scarf and broad webbed feet.
    oval(73,23,44,55,132,75,38)
    oval(66,19,39,48,182,117,60)
    col(230,168,91);g.setLineWidth(3);g.arc('line','open',69,-28,25,0.2,2.95)
    oval(0,7,57,69,39,92,134)
    oval(-4,19,43,51,225,239,237)
    oval(-2,-54,44,42,58,121,162)
    oval(-4,-48,32,30,237,246,242)
    eyes(-60,14)
    col(243,174,65);g.polygon('fill',-8,-41,18,-39,3,-26)
    oval(-24,72,24,9,236,163,56);oval(28,72,24,9,236,163,56)
    col(222,100,97);g.rectangle('fill',-39,-23,78,15,6,6)
    g.polygon('fill',26,-15,58,-8,49,24,32,15)
    oval(-48,6,15,37,47,109,152)
    oval(42,-2-pose.action*15,16,32,60,128,166)
    col(247,220,165);g.setLineWidth(3);g.line(22,-23,44,4,59,16)
    col(230,188,119);g.rectangle('fill',58,1,22,16,3,3)
    col(123,77,41);g.line(59,2,69,10,79,2)
  elseif kind=='spring' then
    -- A little bark spirit, asymmetric antlers and leaf hands.
    col(84,58,48);g.setLineWidth(18);g.line(-25,37,-35,72,-54,78)
    g.line(23,36,34,73,55,77)
    col(151,111,70);g.rectangle('fill',-40,-65,80,120,24,24)
    col(181,140,85);g.rectangle('fill',-33,-63,55,111,22,22)
    col(111,78,53);g.setLineWidth(5);g.line(-12,-48,-16,-27,-9,-12,-16,9,-10,38)
    col(126,88,58);g.setLineWidth(12);g.line(-23,-49,-47,-88,-51,-130)
    g.line(20,-50,39,-90,33,-135);g.line(37,-95,66,-113)
    g.line(-47,-94,-75,-106)
    for _,leaf in ipairs({{-52,-135},{-77,-112},{32,-141},{71,-116},{7,-111}}) do
      oval(leaf[1],leaf[2],19,12,100,174,117)
      oval(leaf[1]-3,leaf[2]-4,12,6,151,211,136)
    end
    eyes(-24,17)
    col(75,54,43);g.setLineWidth(3);g.arc('line','open',4,-1,12,0.2,2.8)
    col(124,87,57);g.setLineWidth(13);g.line(-34,-1,-67,-21);g.line(32,-3,66,-30)
    oval(-72,-25,21,13,128,188,116);oval(72,-34,21,13,128,188,116)
    oval(-23,-8,7,3,210,151,110);oval(27,-8,7,3,210,151,110)
  else
    -- A turquoise spark drake, saffron sail wings and a firefly tail.
    col(237,170,71);g.polygon('fill',-28,0,-100,-81,-88,-16,-119,-29,-80,35,-40,24)
    col(255,210,116);g.polygon('fill',23,0,87,-75,77,-13,107,-27,80,34,34,28)
    col(38,105,117);g.setLineWidth(19);g.line(-29,42,-68,49,-91,25,-103,32)
    oval(-108,22,12,17,255,190,72)
    oval(0,17,48,60,58,150,156)
    oval(10,24,29,44,171,218,181)
    oval(5,-51,48,39,75,176,178)
    oval(38,-38,29,20,93,189,184)
    col(248,191,83);g.polygon('fill',-23,-78,-30,-106,-8,-85,8,-109,17,-84)
    eyes(-59,15)
    col(29,96,106);g.setLineWidth(3);g.arc('line','open',41,-39,13,0,2.4)
    oval(-26,68,26,10,49,126,137);oval(30,68,26,10,49,126,137)
  end
  g.pop()
  end

  -- Confetti travels from the action into the logo; no enclosing disk/ring.
  g.push('all')
  local tint=kind=='winter' and {180,230,255} or kind=='spring' and {153,220,141}
    or kind=='summer' and {255,193,87} or {183,127,247}
  local strength=math.sin(clamp((t-pose.release+0.2)/2.8)*math.pi)
  for i=1,28 do
    local q=((t-pose.release)*0.5+i/28)%1
    local angle=i*2.39996
    local radius=q*140*s
    local px=pose.logoX+math.cos(angle)*radius
    local py=pose.logoY+math.sin(angle)*radius*0.65
    g.setColor(tint[1]/255,tint[2]/255,tint[3]/255,strength*(1-q)*0.8)
    if kind=='winter' then
      g.setLineWidth(s);g.line(px-3*s,py,px+3*s,py);g.line(px,py-3*s,px,py+3*s)
    elseif kind=='spring' then
      g.push();g.translate(px,py);g.rotate(angle+t);g.ellipse('fill',0,0,5*s,2*s);g.pop()
    else g.circle('fill',px,py,(1+q*2)*s) end
  end
  g.pop()
end

return Seasons
