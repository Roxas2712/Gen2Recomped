-- Account presence is presentation only. Locations require an accepted meeting
-- and the active cartridge's own navigation proof, never guessed map names.
local A={}
local Version=require('src.core.GameVersion')
local MapProof=require('src.world.FriendMap')
local cached=setmetatable({},{__mode='k'})
function A.resolve(game,device)
 local zone=device and device.zone;local data=game and game.data
 if type(zone)~='table' or not data or Version.generation(device.edition)~=Version.generation() then return nil end
 local id=require('src.core.MapIdentity').runtimeId(data,zone.map)
 local def=data.maps and data.maps[id];local ts=def and data.tilesets and data.tilesets[def.tileset]
 if not def or not ts then return nil end
 local world=game.overworld;local proof
 if world and world.map and world.map.def==def then proof=MapProof.describe(world)
 else
  local row=cached[def]
  if not row or row.tileset~=ts then
   local ok,map=pcall(require('src.world.Map').new,def,ts)
   if not ok then return nil end
   local value=MapProof.describe({map=map});row={tileset=ts,proof=value};cached[def]=row
  end
  proof=row.proof
 end
 if not MapProof.same(proof,zone.navigation) then return nil end
 local tm=(data.field or {}).townMap or {};local entry=(tm.locations or tm)[id]
 local landmark=tm.landmarks and (tm.landmarks[def.landmark] or tm.landmarks[tostring(def.landmark)])
 local c=data.constants or {};local sec=tonumber(def.regionMapSection)
 local name=type(entry)=='table' and (entry.name or entry.label) or landmark and landmark.name
  or sec and c.gen3MapSections and c.gen3MapSections[sec] or def.name
 return {id=id,def=def,name=tostring(name or id):gsub('[%c_]',' ')}
end
function A.label(game,device)
 if device and device.edition=='pinballrs'then
  return 'Pokémon Pinball: Ruby & Sapphire',device.available and 'Bereit für ein Punkteduell'or 'Pinball beschäftigt'
 end
 local info=A.resolve(game,device)
 return (Version.info(device.edition) or {}).displayName or tostring(device.edition):upper(),info and info.name or 'Unknown zone'
end
function A.locations(game)
 local doc=require('src.cloud.Play').read();local rows={};local seen={}
 for _,p in ipairs(doc and doc.friends or {})do
  for _,d in ipairs(p.playing or {})do
   if not seen[p.account_id] then
    local loc=A.resolve(game,d)
    if loc then rows[#rows+1]={friend=p,device=d,location=loc};seen[p.account_id]=true end
   end
   if #rows>=5 then return rows end
  end
 end
 return rows
end
function A.markers(game,locate,width,height)
 if game.save and game.save.options and game.save.options.friendMapMarkers==false then return end
 local g=love.graphics;local Font=require('src.render.Font');local labels={}
 g.push('all')
 for _,r in ipairs(A.locations(game))do
  local x,y=locate(r.location)
  if x and y and x>=2 and y>=12 and x<=width-2 and y<=height-12 then
   local name=require('src.ui.PlayerRole').label(r.friend.nickname or r.friend.friend_tag,r.friend):gsub('[%c]','')
   while Font.width(name)>math.min(width-8,104) and #name>0 do name=name:gsub('[%z\1-\127\194-\244][\128-\191]*$','') end
   local w=Font.width(name)+4;local lx=math.max(2,math.min(width-w-2,x-w/2));local ly=math.max(9,y-13)
   for _,old in ipairs(labels)do if lx<old.x+old.w and lx+w>old.x and math.abs(ly-old.y)<10 then ly=math.min(height-20,old.y+10)end end
   labels[#labels+1]={x=lx,y=ly,w=w}
   g.setColor(0,0,0,.8);g.circle('fill',x,y,3);g.setColor(1,1,1,1);g.circle('fill',x,y,1)
   g.setColor(0,0,0,.72);g.rectangle('fill',lx,ly,w,10);g.line(x,y,lx+w/2,ly+9)
   g.setColor(1,1,1,1);Font.draw(name,lx+2,ly+1)
  end
 end
 g.pop()
end
function A.draw(game)
 if not (game.save and game.save.options and game.save.options.friendActivityOverlay) then return end
 local overlay=package.loaded['src.ui.RetroOverlay'];if overlay and overlay.game then return end
 local doc=require('src.cloud.Play').read();local lines={}
 for _,p in ipairs(doc and doc.friends or {})do
  for _,d in ipairs(p.playing or {})do
   local edition,zone=A.label(game,d);lines[#lines+1]=require('src.ui.PlayerRole').label(p.nickname,p)..' · '..edition..' · '..zone;break
  end
  if #lines>=5 then break end
 end
 if #lines==0 then return end
 local g=love.graphics;g.push('all');A.font=A.font or g.newFont(13);g.setFont(A.font)
 local ww=g.getWidth();local width=math.min(420,ww-24);g.setColor(.02,.04,.08,.76);g.rectangle('fill',ww-width-12,48,width,#lines*34+12,8,8)
 for i,line in ipairs(lines)do g.setColor(.8,.95,1,1);g.printf(line,ww-width-4,54+(i-1)*34,width-16,'left')end
 g.pop()
end
return A
