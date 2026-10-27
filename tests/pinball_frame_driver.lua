-- Actual launcher/player pacing probe; private native installation required. By Roxas2712.
local Json=require('src.link.Json')
local reportPath=assert(os.getenv('PINBALL_FRAME_REPORT'))
local duration=tonumber(os.getenv('PINBALL_FRAME_SECONDS'))or 40
local Player=require('src.pinball.Player');local new=Player.new;local player;local started;local frames,updates,native,unique={},{},{},0;local previousFrame;local focusLost=0
local function summary(values)
 table.sort(values);local sum=0;local slow25,slow50=0,0
 for _,v in ipairs(values)do sum=sum+v;if v>25 then slow25=slow25+1 end;if v>50 then slow50=slow50+1 end end
 return {n=#values,mean_ms=sum/math.max(1,#values),p95_ms=values[math.max(1,math.ceil(#values*.95))],p99_ms=values[math.max(1,math.ceil(#values*.99))],max_ms=values[#values],over25=slow25,over50=slow50}
end
Player.new=function(session,options)
 session.player=assert(os.getenv('PINBALL_FRAME_PLAYER'))
 local p=new(session,options);player=p;p.settings.full_table=os.getenv('PINBALL_FRAME_TABLE')=='1';p:command{action='view',full_table=p.settings.full_table}
 p.input={buttons=function(_,seat)
  local s=p.stats[seat];local n=s and s.frame or 0
  if not s or s.main~=2 then return n%45<4 and 1 or 0 end
  return n%120<55 and 1 or n%120<110 and 32 or 0
 end,join=function()end}
 return p
end
assert(love.filesystem.load('base-main.lua'))()
local update=love.update
love.update=function(dt)
 local t=love.timer.getTime();update(dt)
 if player and player.stats[1] and player.stats[1].main==2 then
  started=started or t
  if t-started>3 then
   updates[#updates+1]=(love.timer.getTime()-t)*1000
   frames[#frames+1]=dt*1000;native[#native+1]=player.frameMs or 0
   if not love.window.hasFocus()then focusLost=focusLost+1 end
   local frame=player.stats[1].frame;if frame~=previousFrame then unique=unique+1;previousFrame=frame end
  end
  if t-started>duration+3 then
   local display=summary(frames)
   local passed=focusLost==0 and unique/duration>59.7275*.95 and display.p99_ms<25 and display.max_ms<75
   local f=assert(io.open(reportPath,'w'));f:write(Json.encode{passed=passed,display=display,update=summary(updates),native=summary(native),unique_native_presents=unique,focus_lost_frames=focusLost,seconds=duration,seats=player.seats,full_table=player.settings.full_table});f:close();love.event.quit(passed and 0 or 1)
  end
 end
end
