-- Small orthographic cuboid renderer for the pinned, credited Cobblemon
-- intro mascots. No downloaded scripts, model expressions or Molang execute.
local C={}
local cache={}
local BASE='assets/launcher/cobblemon/'
local rad=math.pi/180
local function rotate(x,y,z,angles,pivot)
  x,y,z=x-pivot[1],y-pivot[2],z-pivot[3]
  local a,b,c=(angles[1] or 0)*rad,(angles[2] or 0)*rad,(angles[3] or 0)*rad
  y,z=y*math.cos(a)-z*math.sin(a),y*math.sin(a)+z*math.cos(a)
  x,z=x*math.cos(b)+z*math.sin(b),-x*math.sin(b)+z*math.cos(b)
  x,y=x*math.cos(c)-y*math.sin(c),x*math.sin(c)+y*math.cos(c)
  return x+pivot[1],y+pivot[2],z+pivot[3]
end
local function load(name)
  if cache[name]~=nil then return cache[name] or nil end
  local ok,model=pcall(function()
    local raw=assert(love.filesystem.read(BASE..name..'.launcher.json'))
    local model=assert(require('src.link.Json').decode(raw));assert(model.schema==1)
    model.image=love.graphics.newImage(BASE..model.texture);model.image:setFilter('nearest','nearest')
    return model
  end)
  cache[name]=ok and model or false
  return ok and model or nil
end
local function hidden(name)
  return name:find('eyelid',1,true) or name:find('half_eye',1,true) or name:find('eye_angry',1,true) or name:find('eye_sad',1,true) or name:find('pupil_left2',1,true) or name:find('pupil_right2',1,true)
end
local faces={
 north={{4,3,2,1},1},south={{7,8,5,6},.78},west={{8,4,1,5},.82},east={{3,7,6,2},.9},up={{8,7,3,4},1},down={{1,2,6,5},.7}}
local faceOrder={'north','south','west','east','up','down'}
local function transforms(model,name,t,pose)
  local out={}
  for i,bone in ipairs(model.bones) do
    local idle=model.idle[bone.name] or {};local a,p={},{}
    for j=1,3 do
      -- Bedrock animation X/Y rotations use the opposite handedness to the
      -- editable Blockbench geometry; Z and positions share its axes.
      a[j]=(bone.rotation[j] or 0)+(j<3 and -1 or 1)*(type(idle.rotation)=='table' and tonumber(idle.rotation[j]) or 0)
      p[j]=type(idle.position)=='table' and tonumber(idle.position[j]) or 0
    end
    local action=pose.action or 0
    if name=='haunter' then
      if bone.name=='hand_left1' or bone.name=='hand_right1' then
        local side=bone.name=='hand_left1' and 1 or -1
        a[3]=a[3]+side*(math.sin(t*3)*7-action*19);a[1]=a[1]-action*25;p[2]=p[2]+math.sin(t*2.8+side)*.65
      elseif bone.name=='jaw' then a[1]=a[1]+math.sin(t*2)*3
      elseif bone.name=='tail2' then a[2]=a[2]+math.sin(t*3)*9 end
    elseif name=='delibird' then
      if bone.name=='arm_right' then a[1]=a[1]-action*20;a[3]=a[3]-action*22
      elseif bone.name=='arm_left' then a[3]=a[3]+action*24
      elseif bone.name=='head' then a[3]=a[3]+math.sin(t*2)*4
      elseif bone.name=='tail_end' then a[1]=a[1]+action*15
      elseif bone.name=='leg_left' then a[1]=a[1]+(1-(pose.slide or 1))*18
      elseif bone.name=='leg_right' then a[1]=a[1]-(1-(pose.slide or 1))*18 end
    elseif bone.name:find('arm',1,true) or bone.name:find('hand',1,true) then
      a[3]=a[3]+math.sin(t*18)*action*8
    end
    out[i]={angle=a,position=p}
  end
  return out
end
local function projector(model,name,t,pose)
  local bones=transforms(model,name,t,pose)
  local yaw=(name=='haunter' and -.22 or -.32)+math.sin(t*1.3)*.09
  local pitch=-.12
  local function project(point,index,cube)
    local x,y,z=rotate(point[1],point[2],point[3],cube.rotation,cube.pivot)
    while index do
      local bone=model.bones[index];local tr=bones[index]
      x,y,z=rotate(x,y,z,tr.angle,bone.pivot)
      x,y,z=x+tr.position[1],y+tr.position[2],z+tr.position[3]
      index=bone.parent
    end
    y=y-(name=='haunter' and 13 or name=='sudowoodo' and 15 or 14)
    local xx,zz=x*math.cos(yaw)+z*math.sin(yaw),-x*math.sin(yaw)+z*math.cos(yaw)
    local yy,depth=y*math.cos(pitch)-zz*math.sin(pitch),y*math.sin(pitch)+zz*math.cos(pitch)
    return {xx,-yy,depth}
  end
  return project
end
function C.geometry(model,name,t,pose)
  local project=projector(model,name,t,pose)
  local quads={};local serial=0
  for i,bone in ipairs(model.bones) do if not hidden(bone.name) then
    for _,cube in ipairs(bone.cubes) do
      local a,b=cube['from'],cube.to;local inf=cube.inflate or 0
      local x,y,z=a[1]-inf,a[2]-inf,a[3]-inf;local X,Y,Z=b[1]+inf,b[2]+inf,b[3]+inf
      local points={{x,y,z},{X,y,z},{X,Y,z},{x,Y,z},{x,y,Z},{X,y,Z},{X,Y,Z},{x,Y,Z}}
      local eye=name=='haunter' and (bone.name:find('full_eye',1,true) or bone.name:find('pupil',1,true))
      -- The launcher uses visible white eyes and black pupils. Put the eye
      -- planes in front of the opaque body instead of burying them in it.
      if eye then for _,p in ipairs(points) do p[3]=p[3]-.4 end end
      for j,p in ipairs(points) do points[j]=project(p,i,cube) end
      for _,face in ipairs(faceOrder) do
        local info=faces[face]
        local uv=cube.faces[face]
        -- Zero-area box faces (flat fur/eyelid planes) can carry negative
        -- unused UV edges in Blockbench. They are not drawable surfaces.
        if uv and uv[1]~=uv[3] and uv[2]~=uv[4] then
          if eye then
            -- Unchanged texture swatches: pale white (35,79), black (0,1).
            local u,v=35.5,79.5;if bone.name:find('pupil',1,true) then u,v=.5,1.5 end
            uv={u,v,u,v}
          end
          local q={depth=0,color=eye and 1 or info[2],points={},uv=uv};serial=serial+1;q.serial=serial
          for j,index in ipairs(info[1]) do q.points[j]=points[index];q.depth=q.depth+points[index][3]/4 end
          quads[#quads+1]=q
        end
      end
    end
  end end
  table.sort(quads,function(a,b) if math.abs(a.depth-b.depth)<.00001 then return a.serial<b.serial end;return a.depth>b.depth end)
  local vertices={}
  for _,q in ipairs(quads) do
    local uv={{q.uv[1]/model.width,q.uv[2]/model.height},{q.uv[3]/model.width,q.uv[2]/model.height},{q.uv[3]/model.width,q.uv[4]/model.height},{q.uv[1]/model.width,q.uv[4]/model.height}}
    for _,j in ipairs({1,2,3,1,3,4}) do local p=q.points[j];vertices[#vertices+1]={p[1],p[2],uv[j][1],uv[j][2],q.color,q.color,q.color,1} end
  end
  return vertices
end
local function modelScale(name) return name=='haunter' and 4.6 or name=='sudowoodo' and 5.2 or 5.2 end
function C.sackOrigin(t,pose,s)
  local model=load('delibird');if not model then return nil end
  for i,bone in ipairs(model.bones) do if bone.name=='tail_end' then
    local point=projector(model,'delibird',t,pose)(bone.pivot,i,{rotation={0,0,0},pivot={0,0,0}})
    local a=pose.bodyRotation or 0;local scale=s*modelScale('delibird')
    return pose.x+(point[1]*math.cos(a)-point[2]*math.sin(a))*scale,
      pose.y+(point[1]*math.sin(a)+point[2]*math.cos(a))*scale
  end end
end
function C.mist(t,pose,s,foreground)
  local g=love.graphics;local scale=s*(pose.size or 1)
  g.push('all');g.translate(pose.x,pose.y);g.scale(scale)
  for i=1,foreground and 7 or 16 do
    local age=(t*.23+i*.137)%1
    local angle=i*2.39996+t*.35
    local x=math.cos(angle)*(40+age*85)-age*30
    local y=20+math.sin(angle)*(18+age*28)-age*50
    local radius=18+age*26
    for layer=5,1,-1 do
      local a=pose.alpha*math.sin(age*math.pi)*(foreground and .009 or .018)*(1-layer/6)
      g.setColor(foreground and .41 or .16,.08,foreground and .6 or .3,a)
      g.ellipse('fill',x,y,radius*layer/3,radius*layer/5)
    end
  end
  g.pop()
end
function C.draw(kind,t,pose,s)
  local name=kind=='autumn' and 'haunter' or kind=='winter' and 'delibird' or kind=='spring' and 'sudowoodo'
  if not name or not love.graphics.newMesh then return false end
  local model=load(name);if not model then return false end
  if kind=='autumn' then C.mist(t,pose,s,false) end
  local vertices=C.geometry(model,name,t,pose)
  if model.mesh then model.mesh:setVertices(vertices) else model.mesh=love.graphics.newMesh(vertices,'triangles','stream');model.mesh:setTexture(model.image) end
  local g=love.graphics
  g.push('all');g.translate(pose.x,pose.y);g.rotate(pose.bodyRotation or 0);g.scale(s*(pose.size or 1)*modelScale(name))
  local material=kind=='autumn' and (.72+.28*math.sin(t*1.9)^2) or 1
  g.setColor(1,1,1,pose.alpha*material);g.draw(model.mesh);g.pop()
  if kind=='autumn' then C.mist(t,pose,s,true) end
  return true
end
return C
