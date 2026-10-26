-- Shared Arena artwork and responsive cup/bracket presentation.
local A={}
local images,fonts={},{}
local scrim
local colors={teal={.30,.87,.82},blue={.37,.65,1},violet={.73,.52,1},gold={1,.78,.37}}
local function image(name)
 if images[name]==nil then
  local ok,v=pcall(love.graphics.newImage,'assets/launcher/arena/'..name..'.png')
  images[name]=ok and v or false
  if ok and v.setFilter then v:setFilter('linear','linear') end
 end
 return images[name] or nil
end
local function font(size)
 size=math.floor(size);if not fonts[size] then fonts[size]=love.graphics.newFont(size) end;return fonts[size]
end
local function label(self,value,x,y,w,size,color)
 local g=love.graphics;local f=font(size);g.setFont(f);g.setColor(unpack(color or {1,1,1}))
 local t=tostring(value or '')
 if self._ui.ellipsize then t=self._ui.ellipsize(f,t,w) end
 g.printf(t,x,y,w,'left')
end
local function art(name,x,y,w,h,cover,alpha)
 local im=image(name);if not im then return end
 local g=love.graphics;local iw,ih=im:getDimensions();local z=(cover and math.max or math.min)(w/iw,h/ih)
 g.push('all');if g.intersectScissor then g.intersectScissor(x,y,w,h) end
 g.setColor(1,1,1,alpha or 1);g.draw(im,x+(w-iw*z)/2,y+(h-ih*z)/2,0,z,z);g.pop()
end
function A.hero(self,x,y,w,title,subtitle)
 local g,s=love.graphics,self._s;local h=244*s
 g.push('all');g.setColor(.035,.05,.10);g.rectangle('fill',x,y,w,h,14*s,14*s)
 art('league-stadium',x,y,w,h,true)
 -- A left-to-right scrim leaves the art visible while keeping text readable.
 if g.newMesh then
  scrim=scrim or g.newMesh({{0,0,0,0,.025,.035,.075,.94},{1,0,0,0,.025,.035,.075,.13},{1,1,0,0,.025,.035,.075,.13},{0,1,0,0,.025,.035,.075,.94}},'fan','static')
  g.setColor(1,1,1,1);g.draw(scrim,x,y,0,w,h)
 else g.setColor(.025,.035,.075,.55);g.rectangle('fill',x,y,w,h) end
 art('champion-trophy',x+w*.72,y+12*s,w*.25,h-26*s,false)
 local tw=w*.69-36*s
 label(self,'RETRORECOMPED  /  COMMUNITY LEAGUE',x+24*s,y+24*s,tw,11*s,{.53,.90,1})
 label(self,title or 'ROAD TO CHAMPION',x+24*s,y+60*s,tw,math.min(34*s,w*.043),{1,.96,.86})
 label(self,subtitle or 'Find your rival. Build your legacy.',x+24*s,y+116*s,tw,16*s,{.83,.89,.98})
 label(self,'3–6 POKÉMON  /  K.O. CUPS  /  CHAMPION REWARDS',x+24*s,y+h-35*s,tw,11*s,{1,.80,.41})
 g.setColor(.47,.66,.86,.55);g.setLineWidth(s);g.rectangle('line',x,y,w,h,14*s,14*s);g.pop()
 return h+18*s
end
function A.progress(self,x,y,w,arena)
 local s,g=self._s,love.graphics;local h=100*s;local points=tonumber(arena.points) or 0;local target=math.max(1,tonumber(arena.worlds_points) or 1000)
 g.push('all');g.setColor(.055,.08,.14);g.rectangle('fill',x,y,w,h,10*s,10*s)
 label(self,tostring(points)..' LEAGUE POINTS',x+18*s,y+13*s,w*.5,18*s,{1,.81,.40})
 label(self,arena.worlds_unlocked and 'BEST OF WORLDS · UNLOCKED' or 'BEST OF WORLDS · '..math.max(0,target-points)..' TO GO',x+w*.50,y+17*s,w*.48-12*s,12*s,{.65,.84,1})
 g.setColor(.13,.18,.27);g.rectangle('fill',x+18*s,y+49*s,w-36*s,8*s,4*s,4*s)
 if points>0 then g.setColor(1,.77,.30);g.rectangle('fill',x+18*s,y+49*s,(w-36*s)*math.min(1,points/target),8*s,4*s,4*s) end
 label(self,(arena.season and 'Native league · +' or 'Community results · +')..tostring(arena.win_points or 50)..' win / '..(arena.season and '-' or '+')..tostring(arena.loss_points or 10)..' loss'..(arena.season and ' · Three-month season' or ' · once per opponent / UTC day'),x+18*s,y+70*s,w-36*s,11*s,{.63,.71,.83})
 g.pop();return h+18*s
end
function A.format(self,x,y,w,c,locked,selected,edition)
 local s,g=self._s,love.graphics;local h=170*s;local col=colors[c.color] or colors.teal
 g.push('all');g.setColor(.065,.095,.16);g.rectangle('fill',x,y,w,h,12*s,12*s)
 art('league-stadium',x+w*.48,y,w*.52,h,true,locked and .17 or .42)
 g.setColor(.04,.06,.12,.53);g.rectangle('fill',x,y,w,h,12*s,12*s)
 art('champion-trophy',x+w-86*s,y+16*s,72*s,85*s,false,locked and .35 or .9)
 g.setColor(unpack(col));g.rectangle('fill',x,y+16*s,3*s,h-32*s,2*s,2*s)
 label(self,edition and ('GEN '..require('src.core.GameVersion').generation(edition)..' / '..edition:upper()..' / '..c.team_size..'v'..c.team_size) or 'LEAGUE CUP / '..c.team_size..'v'..c.team_size,x+18*s,y+17*s,w-110*s,10*s,col)
 label(self,c.title,x+18*s,y+40*s,w-112*s,20*s,{1,.97,.91})
 label(self,c.team_size..' Pokémon · Lv. '..c.level..' · Singles',x+18*s,y+77*s,w-36*s,12*s,{.78,.85,.94})
 label(self,c.rule_summary or ((c.legendary or c.id=='champion' or c.id=='worlds') and 'Legends allowed · No duplicate species' or 'No legends · No duplicate species'),x+18*s,y+100*s,w-36*s,11*s,{.62,.73,.86})
 if c.rule_summary then label(self,c.legendary and 'Legends allowed · No duplicate species' or 'No legends · No duplicate species',x+18*s,y+118*s,w-36*s,10*s,{.62,.73,.86}) end
 label(self,locked and ('LOCKED · '..c.minimum_points..' POINTS') or (selected and 'SELECTED · READY TO FIND A RIVAL' or 'SELECT CUP >'),x+18*s,y+137*s,w-36*s,11*s,col)
 g.setColor(col[1],col[2],col[3],selected and .95 or .32);g.setLineWidth(selected and 2*s or s);g.rectangle('line',x,y,w,h,12*s,12*s);g.pop()
 return h
end
function A.cup(self,x,y,w,c)
 local s,g=self._s,love.graphics;local h=142*s;local col=c.state=='completed' and colors.gold or colors.blue
 g.push('all');g.setColor(.055,.08,.14);g.rectangle('fill',x,y,w,h,12*s,12*s)
 art('league-stadium',x+w*.60,y,w*.40,h,true,.38);art('champion-trophy',x+w-90*s,y+12*s,76*s,105*s,false)
 label(self,(c.state or 'open'):upper()..' / GEN '..c.generation..' / '..c.edition:upper(),x+18*s,y+15*s,w-120*s,11*s,col)
 label(self,c.title,x+18*s,y+42*s,w-130*s,22*s,{1,.97,.92})
 label(self,c.team_size..' Pokémon · Lv. '..c.level..' · '..c.entries..'/'..c.capacity..' players',x+18*s,y+79*s,w-120*s,13*s,{.75,.84,.94})
 label(self,c.matchmaking and 'ASSIGNED ONLINE PAIRING' or 'SINGLE ELIMINATION > CHAMPION',x+18*s,y+110*s,w-110*s,10*s,col)
 g.pop();return h
end
function A.bracket(self,x,y,w,c,names)
 local s,g=self._s,love.graphics;local rounds={};local count=0
 for _,m in ipairs(c.matches or {}) do rounds[m.round]=rounds[m.round] or {};table.insert(rounds[m.round],m);count=math.max(count,m.round) end
 if count==0 then return 0 end
 local first=#(rounds[1] or {});local h=70*s+math.max(1,first)*68*s;local gap=14*s;local cw=(w-gap*(count-1))/count
 g.push('all')
 if cw<128*s then
  local cy=y;local cols=math.max(1,math.floor(w/(160*s)));local width=(w-(cols-1)*12*s)/cols
  for r=1,count do
   label(self,r==count and 'FINAL · CHAMPION' or ('ROUND '..r),x,cy,w,11*s,colors.gold);cy=cy+28*s
   for i,m in ipairs(rounds[r] or {}) do
    local bx=x+((i-1)%cols)*(width+12*s);local by=cy+math.floor((i-1)/cols)*60*s
    g.setColor(.07,.11,.19);g.rectangle('fill',bx,by,width,48*s,6*s,6*s)
    local function name(id) return id and (names[id] or 'Player') or 'Awaiting winner' end
    label(self,(m.winner==m.left and 'WIN · ' or '')..name(m.left),bx+8*s,by+6*s,width-16*s,11*s,{.85,.9,1})
    label(self,(m.winner==m.right and 'WIN · ' or '')..name(m.right),bx+8*s,by+28*s,width-16*s,11*s,{.66,.77,.91})
   end
   cy=cy+math.ceil(#(rounds[r] or {})/cols)*60*s+16*s
  end
  g.pop();return cy-y
 end
 for r=1,count do
  local bx=x+(r-1)*(cw+gap)
  label(self,r==count and 'FINAL · CHAMPION' or ('ROUND '..r),bx,y,cw,11*s,colors.gold)
  for i,m in ipairs(rounds[r] or {}) do
   local cy=y+36*s+((i-.5)*2^(r-1))*68*s;local by=cy-24*s
   if r<count then
    local target=y+36*s+(math.ceil(i/2)-.5)*2^r*68*s
    g.setColor(.30,.42,.61);g.setLineWidth(s);g.line(bx+cw,cy,bx+cw+gap/2,cy,bx+cw+gap/2,target,bx+cw+gap,target)
   end
   g.setColor(.07,.11,.19);g.rectangle('fill',bx,by,cw,48*s,6*s,6*s)
   g.setColor(m.winner and 1 or .30,m.winner and .77 or .45,m.winner and .36 or .67,.8);g.rectangle('line',bx,by,cw,48*s,6*s,6*s)
   local function name(id) return id and (names[id] or 'Player') or 'Awaiting winner' end
   label(self,(m.winner==m.left and 'WIN · ' or '')..name(m.left),bx+8*s,by+6*s,cw-16*s,11*s,{.85,.9,1})
   label(self,(m.winner==m.right and 'WIN · ' or '')..name(m.right),bx+8*s,by+28*s,cw-16*s,11*s,{.66,.77,.91})
  end
 end
 g.pop();return h+12*s
end
return A
