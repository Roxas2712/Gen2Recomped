package.path = "./?.lua;./?/init.lua;" .. package.path
local T = require("tests.modkit")
local F = require("tests.terrain_animation.fixture")
local W = require("src.world.Gen3Weather")
local Json = require("src.link.Json")
local cases = {"NONE","SUNNY","SUNNY_CLOUDS","RAIN","DOWNPOUR","RAIN_THUNDERSTORM","SNOW",
  "VOLCANIC_ASH","SANDSTORM","FOG_HORIZONTAL","FOG_DIAGONAL","UNDERWATER","UNDERWATER_BUBBLES",
  "SHADE","DROUGHT","ABNORMAL","ROUTE119_CYCLE","ROUTE123_CYCLE"}
local function near(a,b,msg) T.check(math.abs(a-b)<1e-12,msg) end
-- The pre-extension native draw order, independent of the new filter helper.
local function legacyDraw(name,frame,stage)
  local look=W.look(name,frame,stage)
  if not look then return false end
  if look.veil then
    love.graphics.setColor(unpack(look.veil));love.graphics.rectangle("fill",0,0,240,160)
  end
  if look.colour and (look.count or 0)>0 then
    love.graphics.setColor(unpack(look.colour))
    for _,p in ipairs(W.particles(name,frame,240,160,stage)) do
      love.graphics.rectangle("fill",math.floor(p.x),math.floor(p.y),p.w,p.h)
    end
  end
  local flash=W.flash(name,frame,stage)
  if flash>0 then love.graphics.setColor(1,1,1,flash);love.graphics.rectangle("fill",0,0,240,160) end
  love.graphics.setColor(1,1,1,1)
  return true
end
do
  local color,rect=love.graphics.setColor,love.graphics.rectangle
  local calls={}
  love.graphics.setColor=function(...) calls[#calls+1]={"color",...} end
  love.graphics.rectangle=function(...) calls[#calls+1]={"rectangle",...} end
  for _,name in ipairs(cases) do for _,frame in ipairs({0,5,8,220}) do for stage=0,3 do
    calls={};local got=W.draw(name,frame,240,160,stage);local actual=calls
    calls={};local expected=legacyDraw(name,frame,stage)
    T.eq(got and true or false,expected,"native draw visibility unchanged without consumer")
    T.same(actual,calls,"all native weather commands, particle positions and resets preserve baseline")
  end end end
  love.graphics.setColor,love.graphics.rectangle=color,rect
end
for _,version in ipairs({"emerald","firered"}) do
  for _,api in ipairs({1,2}) do
    local f=F.new(version,api,true)
    local s,e=f.state,f.exports
    local names={}
    for i,name in ipairs(cases) do names[i-1]=name end
    s.game.data.constants.gen3WeatherNames=names
    s.game.save={gen3WeatherActive=0,gen3WeatherStage=0,gen3WeatherDay=17}
    local sourceBefore=Json.encode(f.records)
    local color,rect=love.graphics.setColor,love.graphics.rectangle
    local rgba,overlays
    love.graphics.setColor=function(r,g,b,a) rgba={r,g,b,a} end
    love.graphics.rectangle=function(mode,x,y,w,h)
      if x==0 and y==0 and w==240 and h==160 then overlays[#overlays+1]={unpack(rgba)} end
    end
    for i,name in ipairs(cases) do
      for _,stage in ipairs({0,1,2,3,255}) do
        for _,frame in ipairs({0,2,3,4,5,8,9,10,219,220,9007199254740991}) do
          s.game.save.gen3WeatherActive,s.game.save.gen3WeatherStage=i-1,stage
          s.world.weatherFrame=frame
          local v=assert(e.weather(1,s.mapId))
          T.eq(v.mapId,s.mapId,"weather belongs to active map")
          T.eq(v.weatherId,i-1,"active weather byte observed")
          T.eq(v.name,name,"raw weather name observed")
          T.eq(v.ticks,frame,"weather clock independent of terrain ticks")
          T.eq(v.resolved,W.resolve(name,frame,stage),"route cycles use committed daily save stage")
          overlays={}
          W.draw(name,frame,240,160,stage)
          local pixels={0.2,0.5,0.8}
          for _,overlay in ipairs(overlays) do
            for c=1,3 do pixels[c]=pixels[c]*(1-overlay[4])+overlay[c]*overlay[4] end
          end
          for c=1,3 do near(pixels[c],0.1*(c*3-1)*v.scale[c]+v.bias[c],"public affine filter equals native overlay order") end
          T.eq(assert(e.weather(1,s.mapId)).contentKey,v.contentKey,"same observed filter retains key")
        end
      end
    end
    love.graphics.setColor,love.graphics.rectangle=color,rect
    -- Independent historical values: do not merely compare a helper to itself.
    s.game.save.gen3WeatherActive=3;s.world.weatherFrame=20
    local rain=assert(e.weather(1,s.mapId))
    T.same(rain.veil,{0.10,0.13,0.22,0.20},"existing native rain look stays unchanged")
    near(rain.scale[1],0.8,"rain leaves 80 percent of opaque world colour")
    near(rain.bias[3],0.044,"rain blue bias")
    s.world.weatherFrame=21
    T.eq(assert(e.weather(1,s.mapId)).contentKey,rain.contentKey,"weather key excludes unchanged clock")
    s.game.save.gen3WeatherActive=5;s.world.weatherFrame=0
    local storm=assert(e.weather(1,s.mapId))
    near(storm.scale[1],0.64*0.45,"lightning follows storm veil")
    near(storm.bias[1],0.06*0.36*0.45+0.55,"lightning adds after dark tint")
    storm.veil[1]=-10
    T.eq(assert(e.weather(1,s.mapId)).veil[1],0.06,"weather descriptor cannot mutate native look")
    s.world.weatherFrame=5
    T.check(assert(e.weather(1,s.mapId)).contentKey~=storm.contentKey,"lightning phase invalidates filter")
    local before=Json.encode(s.game.save)
    local now,random,file,newImage=os.time,math.random,io.open,love.graphics.newImage
    os.time=function() error("observer cannot update calendar") end
    math.random=function() error("observer cannot consume RNG") end
    io.open=function() error("observer cannot read files") end
    love.graphics.newImage=function() error("observer cannot build graphics") end
    assert(e.weather(1,s.mapId))
    os.time,math.random,io.open,love.graphics.newImage=now,random,file,newImage
    T.eq(Json.encode(s.game.save),before,"weather reads never write saves or update daily stage")
    T.eq(Json.encode(f.records),sourceBefore,"weather never rewrites source palettes")
    T.eq(e.weather(1,"stale"),nil,"stale weather read refused")
    T.eq(e.weather(2,s.mapId),nil,"wrong weather version refused")
    for _,bad in ipairs({"9",-1,256,math.huge,0/0}) do
      s.game.save.gen3WeatherActive=bad
      local v,err=e.weather(1,s.mapId)
      T.eq(v,nil,"invalid weather byte refused");T.eq(err,"weather color unavailable","weather failure reason")
    end
    s.game.save.gen3WeatherActive=0
    for _,bad in ipairs({"1",-1,0.5,math.huge,0/0,9007199254740992}) do
      s.world.weatherFrame=bad
      T.eq(e.weather(1,s.mapId),nil,"invalid weather frame refused")
    end
    s.world.weatherFrame=0
    for _,bad in ipairs({"1",-1,256,math.huge,0/0}) do
      s.game.save.gen3WeatherStage=bad
      T.eq(e.weather(1,s.mapId),nil,"invalid weather stage refused")
    end
    s.game.save.gen3WeatherStage=0
    s.game.data.constants.gen3WeatherNames[0]="UNRECOGNIZED"
    T.eq(e.weather(1,s.mapId),nil,"unknown weather cannot become invented clear weather")
    s.game.save=nil
    T.eq(e.weather(1,s.mapId),nil,"absent save cannot become invented clear weather")
    f.run.release()
  end
end
T.finish("Public Gen3 weather colours, daily cycles and native overlay parity")
