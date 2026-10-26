-- Native counterparts of the shared ModCompass preset avatars.
local A={presets={'compass','spark','leaf','pixel','moon','wave'},colors={'gold','forest','ocean','violet','ember'}}
local colors={gold={{245,213,100},{27,52,56}},forest={{212,231,190},{40,89,70}},ocean={{198,232,239},{36,83,109}},violet={{221,213,244},{81,65,108}},ember={{244,212,183},{123,58,50}}}
local function color(c) love.graphics.setColor(c[1]/255,c[2]/255,c[3]/255,1) end
function A.decode(doc)
 if type(doc)~='table' or type(doc.image_base64)~='string' then return end
 local ok,image=pcall(function()
  local bytes=love.data.decode('string','base64',doc.image_base64)
  if #bytes>2*1024*1024 or not require('src.import.ImageBounds').allowed(bytes,2048) then return end
  if love.data.encode('string','hex',love.data.hash('sha256',bytes))~=doc.sha256 then return end
  local image=love.graphics.newImage(love.image.newImageData(love.filesystem.newFileData(bytes,'avatar.png')));image:setFilter('linear','linear');return image
 end)
 return ok and image or nil
end
function A.draw(preset,tone,x,y,size,image)
 local g=love.graphics;g.push('all')
 if image then
  local iw,ih=image:getDimensions();local fit=size/math.max(iw,ih);g.setColor(1,1,1,1);g.draw(image,x+(size-iw*fit)/2,y+(size-ih*fit)/2,0,fit,fit);g.pop();return
 end
 local palette=colors[tone] or colors.gold;color(palette[1]);g.rectangle('fill',x,y,size,size,size*.2,size*.2)
 g.translate(x,y);g.scale(size/128);color(palette[2]);g.setLineWidth(6)
 if preset=='spark' then g.polygon('line',70,23,42,68,62,68,58,105,87,58,67,58)
 elseif preset=='leaf' then g.polygon('line',91,30,64,32,43,45,35,65,45,82,65,87,83,73,91,51);g.line(35,97,81,48);g.line(52,80,52,62);g.line(52,80,72,80)
 elseif preset=='pixel' then for _,r in ipairs({{35,58},{49,30},{57,14}}) do g.rectangle('line',r[1],r[1],r[2],r[2]) end
 elseif preset=='moon' then g.arc('line','open',65,64,37,.5,5);g.line(75,29,68,48,70,68,83,83,98,88);g.line(96,34,96,48);g.line(89,41,103,41)
 elseif preset=='wave' then for _,yy in ipairs({53,75}) do local points={};for i=0,24 do points[#points+1]=26+i*76/24;points[#points+1]=yy+math.sin(i*math.pi/6)*12 end;g.line(points) end;g.line(32,98,96,98)
 else g.circle('line',64,64,36);g.line(64,28,64,38);g.line(100,64,90,64);g.line(64,100,64,90);g.line(28,64,38,64);g.polygon('line',48,80,56,56,80,48,72,72) end
 g.pop()
end
return A
