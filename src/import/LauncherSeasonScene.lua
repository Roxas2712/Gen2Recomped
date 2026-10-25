-- Deterministic seasonal scenery, independent of game data and game RNG.
local Scene={}
local Score=require('src.import.LauncherIntroScore')
local function ease(v) v=math.max(0,math.min(1,v));return v*v*(3-2*v) end
function Scene.frame(kind,t,x,y,w,h,s)
  local out={alpha=ease(t/.9)*(1-ease((t-Score.carryStart)/(Score.place-Score.carryStart))),particles={}}
  if kind~='winter' and kind~='autumn' then out.alpha=0;return out end
  local winter=kind=='winter'
  for i=1,winter and 112 or 52 do
    local depth=(i%3+1)/3
    local px,py
    if winter then
      px=(i*.61803398875*w+t*(12+depth*20)*s+math.sin(t*.7+i)*18*s)%w
      py=(i*.38196601125*h+t*(24+depth*27)*s)%h
    else
      px=(i*.61803398875*w+t*(90+depth*95)*s)%w
      py=(i*.38196601125*h+math.sin(t*1.4+i*.7)*h*.12+t*depth*12*s)%h
    end
    out.particles[#out.particles+1]={x=x+px,y=y+py,size=(winter and (.7+depth*1.7) or (3+depth*4))*s,
      angle=t*(winter and .3 or 1.7)+i*2.39996,front=i%3==0,shade=i%4,alpha=.25+depth*.6}
  end
  out.tree={x=x+w*.87,y=y+h*.90,height=math.min(h*.39,245*s,w*.32)}
  out.pumpkins={{x=x+w*.10,y=y+h*.84,size=math.min(37*s,w*.06)},
    {x=x+w*.88,y=y+h*.88,size=math.min(46*s,w*.07)},
    {x=x+w*.82,y=y+h*.90,size=math.min(27*s,w*.04)}}
  return out
end
local function glow(g,x,y,rx,ry,r,b,c,alpha)
  for i=7,1,-1 do
    g.setColor(r,b,c,alpha*(1-i/8)*.10)
    g.ellipse('fill',x,y,rx*i/3,ry*i/3)
  end
end
local function tree(g,p,t,a)
  g.push('all');g.translate(p.x,p.y);local h=p.height
  glow(g,0,-h*.45,h*.35,h*.42,.10,.55,.38,a*.6)
  g.setColor(.22,.12,.08,a);g.rectangle('fill',-h*.055,-h*.17,h*.11,h*.17)
  for i=3,1,-1 do
    local top=-h+(i-1)*h*.20;local bottom=top+h*.53;local radius=h*(.16+i*.045)
    g.setColor(.035,.13+i*.025,.10+i*.012,a)
    g.polygon('fill',0,top,-radius,bottom,radius,bottom)
    g.setColor(.61,.79,.83,a*.65)
    g.polygon('fill',0,top,-radius*.48,top+h*.24,-h*.015,top+h*.16,radius*.46,top+h*.24)
  end
  for i=1,31 do
    local q=i/32;local angle=i*2.39996;local yy=-h*.92+q*h*.80
    local xx=math.sin(angle)*h*(.035+q*.24)
    local colors={{1,.35,.2},{1,.79,.28},{.3,.82,1},{.8,.4,1}}
    local c=colors[i%4+1];local pulse=.7+.3*math.sin(t*2+i)^2
    glow(g,xx,yy,h*.014,h*.014,c[1],c[2],c[3],a*pulse)
    g.setColor(c[1],c[2],c[3],a*pulse);g.circle('fill',xx,yy,h*.009)
  end
  local star={}
  for i=0,9 do local angle=-math.pi/2+i*math.pi/5;local r=h*(i%2==0 and .058 or .026)
    star[#star+1]=math.cos(angle)*r;star[#star+1]=-h+math.sin(angle)*r end
  glow(g,0,-h,h*.04,h*.04,1,.73,.2,a)
  g.setColor(1,.85,.42,a);g.polygon('fill',star)
  g.setColor(.72,.86,.96,a*.22);g.ellipse('fill',0,0,h*.37,h*.025)
  g.pop()
end
local function pumpkin(g,p,t,a,index)
  g.push('all');g.translate(p.x,p.y);local r=p.size
  local pulse=.77+.23*math.sin(t*3.1+index*2)^2
  glow(g,0,-r*.15,r*1.2,r*.8,1,.28,.025,a*pulse)
  g.setColor(.10,.045,.025,a*.7);g.ellipse('fill',0,r*.64,r*1.2,r*.18)
  for i=-2,2 do
    g.setColor(.47+(.15*(2-math.abs(i))),.13+.025*(2-math.abs(i)),.025,a)
    g.ellipse('fill',i*r*.30,0,r*.48,r*(.69+.06*(2-math.abs(i))))
  end
  g.setColor(.22,.27,.09,a);g.polygon('fill',-r*.10,-r*.72,-r*.05,-r*1.03,r*.15,-r*1.10,r*.08,-r*.7)
  g.setColor(1,.64+.15*pulse,.12,a)
  g.polygon('fill',-r*.64,-r*.12,-r*.24,-r*.32,-r*.21,r*.02)
  g.polygon('fill',r*.64,-r*.12,r*.24,-r*.32,r*.21,r*.02)
  g.polygon('fill',0,-r*.04,-r*.1,r*.13,r*.10,r*.13)
  g.polygon('fill',-r*.64,r*.23,-r*.32,r*.31,-r*.2,r*.20,0,r*.36,r*.21,r*.21,r*.34,r*.29,r*.65,r*.19,r*.42,r*.53,-r*.40,r*.54)
  g.pop()
end
function Scene.draw(kind,t,x,y,w,h,s,front)
  local f=Scene.frame(kind,t,x,y,w,h,s);if f.alpha<=0 then return end
  local g=love.graphics;g.push('all')
  if not front then
    if kind=='winter' then tree(g,f.tree,t,f.alpha) else
      for i,p in ipairs(f.pumpkins) do pumpkin(g,p,t,f.alpha,i) end
    end
  end
  for _,p in ipairs(f.particles) do if p.front==front then
    g.push();g.translate(p.x,p.y);g.rotate(p.angle)
    if kind=='winter' then
      g.setColor(.83,.94,1,f.alpha*p.alpha*(front and .85 or .65));g.circle('fill',0,0,p.size)
      if p.front then g.setLineWidth(math.max(.5,s*.6));g.line(-p.size*2,0,p.size*2,0);g.line(0,-p.size*2,0,p.size*2) end
    else
      local colors={{.88,.31,.09},{.96,.58,.13},{.68,.22,.07},{.92,.73,.25}};local c=colors[p.shade+1]
      g.setColor(c[1],c[2],c[3],f.alpha*p.alpha)
      local r=p.size;g.polygon('fill',-r,0,-r*.35,-r*.55,r*.15,-r*.34,r,-r*.04,r*.25,r*.5,-r*.3,r*.48)
      g.setColor(.38,.16,.05,f.alpha*p.alpha*.7);g.setLineWidth(math.max(.5,s*.5));g.line(-r*.8,0,r*.8,0)
    end
    g.pop()
  end end
  g.pop()
end
return Scene
