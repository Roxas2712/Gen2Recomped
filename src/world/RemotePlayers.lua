-- Presentation only. These actors never enter world.entities, NPC lookup,
-- collision, scripts, encounters, map triggers or the save serializer.
local R={MAX_VISIBLE=5}
local worlds=setmetatable({},{__mode='k'})
local function shortName(value)
 local out={};for char in tostring(value or 'Friend'):gmatch('[%z\1-\127\194-\244][\128-\191]*') do
  if #out==14 then out[#out+1]='…';break end
  if not char:match('[%c]') then out[#out+1]=char end
 end
 return table.concat(out)
end
local function visible(doc,id)
 local p=doc.preferences or {}
 if p.visibility_enabled==false then return false end
 for _,f in ipairs(p.friends or {}) do if tostring(f.account_id)==id then return f.visible~=false end end
 return true
end
-- Stable seed from the account, independent of frame RNG, viewer and device.
-- Prefer rivals and the alternate protagonists; stationary props never qualify.
function R.spriteChoice(data,seed)
 seed=math.floor(tonumber(seed) or 1)
 local sprites=(data or {}).sprites or {};local field=(data or {}).field or {}
 local rivals,forms,people={},{},{}
 local function add(pool,id)
  local d=sprites[id];if type(d)=='table' and type(d.image)=='string' and d.walker==true then pool[#pool+1]=id end
 end
 for _,id in ipairs({'SPRITE_BLUE','SPRITE_GREEN','SPRITE_SILVER','SPRITE_RIVAL'}) do add(rivals,id) end
 -- Gen4's native extractor stores numeric graphics IDs; use its existing
 -- name mapping instead of guessing a model index from a trainer portrait.
 for id,d in pairs(sprites) do
  if type(id)=='string' and type(d)=='table' and d.walker and d.image then
   local index=tonumber(id:match('^SPRITE_G4_(%d+)$'))
   if index then
    local name=require('src.import.Gen4ObjectGfx').name(index)
    if name=='barry' then add(rivals,id) end
   end
  end
 end
 for _,gender in ipairs({'girl','boy'}) do local f=(field.playerForms or {})[gender];if f then add(forms,f.walk) end end
 if #forms==0 then for _,id in ipairs({'SPRITE_KRIS','SPRITE_LYRA','SPRITE_LEAF','SPRITE_RED'}) do add(forms,id) end end
 for _,id in ipairs({'SPRITE_LASS','SPRITE_COOLTRAINER_F','SPRITE_COOLTRAINER_M','SPRITE_YOUNGSTER','SPRITE_BUG_CATCHER','SPRITE_BEAUTY','SPRITE_HIKER','SPRITE_MISTY','SPRITE_BROCK'}) do add(people,id) end
 table.sort(rivals);table.sort(forms);table.sort(people)
 local bucket=seed%10;local pool=bucket<5 and rivals or bucket<9 and forms or people
 if #pool==0 then pool=#forms>0 and forms or #rivals>0 and rivals or people end
 local id=pool[math.floor(seed/10)%math.max(1,#pool)+1]
 return id and sprites[id],id
end
local function draw(self,cx,cy)
 local g=love.graphics;g.push('all')
 g.setColor(1,1,1,.78)
 self.sprite:draw(self.px,self.py,cx,cy,self.facing,self.phase or 0,false)
 if not R.font then R.font=g.newFont(8);if R.font.setFilter then R.font:setFilter('nearest','nearest') end end
 g.setFont(R.font)
 local name=shortName(self.nickname);local w=R.font:getWidth(name)+8
 local x=math.floor(self.px-cx+8-w/2);local y=math.floor(self.py-cy-(self.labelHeight or 8)-15)
 local height=12
 if package.loaded['src.render.PaletteFX'] then require('src.render.PaletteFX').markTrueColor(x-1,y-1,w+2,height+5) end
 g.setColor(.025,.045,.08,.58);g.rectangle('fill',x,y,w,height,3,3)
 g.polygon('fill',x+w/2-2,y+height,x+w/2+2,y+height,x+w/2,y+height+3)
 g.setLineWidth(.5);g.setColor(.63,.88,1,.5);g.rectangle('line',x+.25,y+.25,w-.5,height-.5,3,3)
 g.setColor(0,0,0,.85);g.print(name,x+5,y+3)
 g.setColor(.98,1,1,1);g.print(name,x+4,y+2)
 g.pop()
end
function R.actors(world)
 local Play=require('src.cloud.Play');local doc=Play.read()
 if not doc or not world.map or not world.player or not Play.context(require('src.core.Game')).available then worlds[world]=nil;return {} end
 local cache=worlds[world]
 if not cache or cache.account~=doc.account_id then cache={account=doc.account_id,actors={}};worlds[world]=cache end
 local result,seen={},{};local time=love.timer.getTime()
 local navigation=require('src.world.FriendMap').describe(world)
 for _,v in ipairs(doc.visitors or {}) do
  local id=tostring(v.account_id);local pos=v.position
  local matching=pos and ((pos.navigation or navigation) and require('src.world.FriendMap').same(pos.navigation,navigation)
   or not pos.navigation and not navigation and pos.map==tostring(world.map.id))
  if #result<R.MAX_VISIBLE and not seen[id] and visible(doc,id) and matching
   and type(pos.x)=='number' and type(pos.y)=='number' and pos.x==pos.x and pos.y==pos.y and pos.x>=0 and pos.y>=0 and pos.x<=32768 and pos.y<=32768 then
   seen[id]=true
   local actor=cache.actors[id]
   if not actor or actor.device~=v.device then
    local game=require('src.core.Game');local def,spriteId=R.spriteChoice(game.data,v.character_seed)
    local template=world.player.sprite;def=def or template and template.def
    if def then
     actor={account_id=id,device=v.device,nickname=v.nickname,remotePlayer=true,px=pos.x,py=pos.y,cellX=0,cellY=0,facing=pos.facing,def={},draw=draw,
       character=spriteId,sprite=require('src.render.SpriteRenderer').new(def,'friend:'..tostring(spriteId)),labelHeight=math.max(4,(def.frameHeight or 16)-16)}
     cache.actors[id]=actor
    end
   end
   if actor then
    local delta=math.min(.1,math.max(0,time-(actor.time or time)));actor.time=time
    local dx,dy=pos.x-actor.px,pos.y-actor.py
    if dx*dx+dy*dy>96*96 then actor.px=pos.x;actor.py=pos.y
    else local t=math.min(1,delta*10);actor.px=actor.px+dx*t;actor.py=actor.py+dy*t end
    actor.phase=(math.abs(dx)+math.abs(dy)>1) and math.floor(time*8)%2 or 0
    actor.cellX=math.floor((actor.px+8)/16);actor.cellY=math.floor((actor.py+8)/16)
    actor.facing=({up=true,down=true,left=true,right=true})[pos.facing] and pos.facing or 'down'
    actor.nickname=v.nickname;result[#result+1]=actor
   end
  end
 end
 for id in pairs(cache.actors) do if not seen[id] then cache.actors[id]=nil end end
 return result
end
function R.entities(world,original)
 local actors=R.actors(world);if #actors==0 then return original end
 local render={};for _,e in ipairs(original) do render[#render+1]=e end
 for _,e in ipairs(actors) do render[#render+1]=e end
 table.sort(render,function(a,b)return (a.py or 0)<(b.py or 0) end)
 return render
end
function R.interact(world,cx,cy)
 for _,actor in ipairs(R.actors(world)) do
  if actor.cellX==cx and actor.cellY==cy then
   local O=require('src.ui.RetroOverlay');O.open(require('src.core.Game'));O.action('friends');O.friendTarget=actor.account_id
   O.notice='Choose Trade or Friend battle. Your friend can accept or decline.'
   return true
  end
 end
 return false
end
return R
