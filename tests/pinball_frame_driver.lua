-- Real launcher/display pacing and repeated native rounds. By Roxas2712.
local Json=require('src.link.Json')
local reportPath=assert(os.getenv('PINBALL_FRAME_REPORT'))
local duration=tonumber(os.getenv('PINBALL_FRAME_SECONDS'))or 40
local allowBackground=os.getenv('PINBALL_FRAME_ALLOW_BACKGROUND')=='1'
local pauseUnfocused=os.getenv('PINBALL_FRAME_PAUSE_UNFOCUSED')=='1'
local excludedFocusSeconds,excludedFocusFrames=0,0
local shapeChanges,lastShapes={},{}
local Player=require('src.pinball.Player');local new=Player.new
local player,launcher,started,lastTick;local activeSeconds,focusLost,rounds,unique=0,0,{},0
local series={display={},update={},draw={},present={},native={},step={},simulation={},composition={},thread_cpu={},image={},stats={},audio={},late={},source_gap={},session_display={},startup_display={}}
local sourceOutliers,nativeOutliers={},{}
local previousFrame,lastWork,outliers,states,images=nil, {},{}, {},{}
local lastChanged,repeatRun,maxRepeatRun,skipped,repeated=nil,0,0,0,0
local cacheRows={reused=0,rendered=0}
local activeBySeat,uniqueBySeat,lastBySeat={0,0},{0,0},{}
local activeAudioRestarts,lastAudioRestarts=0,nil
local function summary(values)
 local sorted={};local sum,slow25,slow50=0,0,0
 for i,v in ipairs(values)do sorted[i]=v;sum=sum+v;if v>25 then slow25=slow25+1 end;if v>50 then slow50=slow50+1 end end
 table.sort(sorted)
 return{n=#sorted,mean_ms=sum/math.max(1,#sorted),p95_ms=sorted[math.max(1,math.ceil(#sorted*.95))]or 0,
 p99_ms=sorted[math.max(1,math.ceil(#sorted*.99))]or 0,max_ms=sorted[#sorted]or 0,over25=slow25,over50=slow50}
end
local function writeProgress()
 local file=assert(io.open(reportPath..'.progress','w'))
 file:write(Json.encode{completed=false,seconds=activeSeconds,unique_native_presents=unique,
  images_per_second=unique/math.max(1,activeSeconds),round_count=#rounds,focus_lost_frames=focusLost,
  cache_rows=cacheRows,outlier_count=#outliers});file:close()
end
local function writeReport(final)
 local result={seconds=activeSeconds,target_seconds=duration,wall_seconds=started and love.timer.getTime()-started or 0,
 unique_native_presents=unique,focus_lost_frames=focusLost,allow_background=allowBackground,audio_restarts=player and(player.audioRestarts or 0)or 0,seats=player and player.seats,
 audio_restart_history=player and player.audioRestartHistory,active_audio_restarts=activeAudioRestarts,
 full_table=os.getenv('PINBALL_FRAME_TABLE')=='1',field=tonumber(os.getenv('PINBALL_FRAME_FIELD'))or 0,
 locale=os.getenv('PINBALL_FRAME_LOCALE')or'en',rounds=rounds,states=states,shapes=images,outliers=outliers,source_outliers=sourceOutliers,native_outliers=nativeOutliers,
 scheduler=player and player.diagnostics and{before=player.diagnostics.priority_before,active=player.diagnostics.priority},
 pause_unfocused=pauseUnfocused,focus_excluded_seconds=excludedFocusSeconds,focus_excluded_frames=excludedFocusFrames,shape_changes=shapeChanges,seat_active_seconds=activeBySeat,seat_unique_presents=uniqueBySeat,cache_rows=cacheRows,repeated_presents=repeated,skipped_presents=skipped,max_repeat_run=maxRepeatRun}
 for k,v in pairs(series)do result[k]=summary(v)end
 result.passed=final and(focusLost==0 or allowBackground) and unique/math.max(1,activeSeconds)>59.7275*.95
  and activeAudioRestarts==0 and result.display.p99_ms<25 and result.display.max_ms<75 and result.source_gap.max_ms<75 or false
 local file=assert(io.open(reportPath,'w'));file:write(Json.encode(result));file:close();return result
end
Player.new=function(session,options)
 session.player=assert(os.getenv('PINBALL_FRAME_PLAYER'));options.diagnostics=true
 options.field=tonumber(os.getenv('PINBALL_FRAME_FIELD'))or 0
 if session.guest=='gbc'and options.seats==2 then options.frameLimit=600 end
 local p=new(session,options);love.window.setTitle('Pinball · Bild- und Tontest · separates Profil');player=p;previousFrame=nil;lastTick=nil;lastChanged=nil;repeatRun=0;lastShapes={};p.settings.full_table=os.getenv('PINBALL_FRAME_TABLE')=='1';p:command{action='view',full_table=p.settings.full_table}
 p.probeRound={field=options.field,number=#rounds+1};rounds[#rounds+1]=p.probeRound
 p.input={buttons=function(_,seat)
  local st=p.stats[seat];local n=st and st.frame or 0
  if session.guest=='gbc'then
   if not st then return 0 end
   if st.main==2 or st.main==3 then return n%45<4 and 1 or 0 end
   if st.main==8 then
    if n%45>=4 then return 0 end
    return st.fieldSelection~=options.field and(options.field==1 and 16 or 32)or 1
   end
   if st.main==4 then return n%120<55 and 1 or n%120<110 and 32 or 0 end
   return 0
  end
  if st and st.main==10 then
   if n%45>=4 then return 0 end
   if st.fieldSelectionStep==0 and st.fieldSelection~=options.field then return options.field==1 and 16 or 32 end
   return 1
  end
  if not st or st.main~=2 then return n%45<4 and 1 or 0 end
  local period=seat==1 and 120 or 97
  return n%period<period*.46 and 1 or n%period<period*.92 and 32 or 0
 end,join=function()end}
 return p
end
assert(love.filesystem.load('base-main.lua'))()
local RI=require('src.import.RomImporter');local importerUpdate=RI.update
RI.update=function(self,dt,...)
 launcher=self
 local result=importerUpdate(self,dt,...)
 if player and player.probeRestart and not self._pinPlayer then self._pinAutoStart=true end
 return result
end
local draw=love.draw
love.draw=function(...)local t=love.timer.getTime();if draw then draw(...)end;lastWork.draw=(love.timer.getTime()-t)*1000 end
local present=love.graphics.present
love.graphics.present=function(...)local t=love.timer.getTime();present(...);lastWork.present=(love.timer.getTime()-t)*1000 end
local update=love.update;local nextProgress=10
love.update=function(dt)
 local previousWork={draw=lastWork.draw,present=lastWork.present,update=lastWork.update}
 local t=love.timer.getTime();update(dt);lastWork.update=(love.timer.getTime()-t)*1000
 local p=player;if not p then return end
 if p.error then error(p.error)end
 if pauseUnfocused then
  if not love.window.hasFocus()then
   excludedFocusSeconds=excludedFocusSeconds+dt;excludedFocusFrames=excludedFocusFrames+1
   if not p.probeFocusPaused then p.probeFocusPaused=true;if not p.paused then p:togglePause()end end
   lastTick=nil;lastChanged=nil;return
  elseif p.probeFocusPaused then
   p.probeFocusPaused=nil;if p.paused then p:togglePause()end
   p.probeFocusWarm=love.timer.getTime()+.5;lastTick=nil;lastChanged=nil;previousFrame=nil
  end
 end
 local st=p.stats[1]
 if not st then return end
 series.session_display[#series.session_display+1]=dt*1000
 if p.phase=='playing'and not p.countdown and (p.session.guest=='gbc'and st.main==4 and st.sub==2 or p.session.guest~='gbc'and st.main==2 and st.sub==1)then p.probeRound.started=p.probeRound.started or t;started=started or t end
 local playing=p.probeRound.started and not p.closing and not p.paused and p.phase=='playing'and not p.countdown
 if playing then
  local warm=t-p.probeRound.started<3 or t<(p.probeFocusWarm or 0)
  if warm then series.startup_display[#series.startup_display+1]=dt*1000 end
  local delta=lastTick and t-lastTick or 0
  if not warm and lastTick then
   local restarts=p.audioRestarts or 0
   if lastAudioRestarts then activeAudioRestarts=activeAudioRestarts+math.max(0,restarts-lastAudioRestarts)end
   lastAudioRestarts=restarts
   activeSeconds=activeSeconds+delta
   series.display[#series.display+1]=dt*1000;series.update[#series.update+1]=lastWork.update
   series.draw[#series.draw+1]=previousWork.draw or 0;series.present[#series.present+1]=previousWork.present or 0
   series.native[#series.native+1]=p.frameMs or 0
   for key in pairs(p.diagnostics or {})do if series[key]then series[key][#series[key]+1]=p.diagnostics[key]*1000 end end
   if not love.window.hasFocus()then focusLost=focusLost+1 end
   if p.frame~=previousFrame then
    unique=unique+1
    if previousFrame and p.frame>previousFrame+1 then skipped=skipped+p.frame-previousFrame-1 end
    if lastChanged then
     local gap=(t-lastChanged)*1000;series.source_gap[#series.source_gap+1]=gap
     if gap>50 and #sourceOutliers<256 then sourceOutliers[#sourceOutliers+1]={seconds=activeSeconds,gap_ms=gap,worker=p.diagnostics}end
    end
    if (p.frameMs or 0)>25 and #nativeOutliers<256 then nativeOutliers[#nativeOutliers+1]={seconds=activeSeconds,native_ms=p.frameMs,worker=p.diagnostics}end
    previousFrame=p.frame;lastChanged=t;repeatRun=0
    cacheRows.reused=cacheRows.reused+((p.diagnostics or {}).reused_rows or 0)
    cacheRows.rendered=cacheRows.rendered+((p.diagnostics or {}).rendered_rows or 0)
   else repeated=repeated+1;repeatRun=repeatRun+1;maxRepeatRun=math.max(maxRepeatRun,repeatRun)end
   for seat,v in ipairs(p.stats)do
    local key=seat..':'..v.main..':'..v.sub..':'..v.field;states[key]=(states[key]or 0)+1
    p.probeRound['score'..seat]=math.max(p.probeRound['score'..seat]or 0,v.score)
    p.probeRound['elapsed'..seat]=v.elapsed or v.frame
    if not v.done then
     activeBySeat[seat]=activeBySeat[seat]+delta
     if lastBySeat[seat]~=v.frame then uniqueBySeat[seat]=uniqueBySeat[seat]+1;lastBySeat[seat]=v.frame end
    end
   end
   for seat,image in ipairs(p.images)do
    local key=image:getWidth()..'x'..image:getHeight();images[key]=(images[key]or 0)+1
    if lastShapes[seat]~=key then
     if #shapeChanges<256 then shapeChanges[#shapeChanges+1]={seconds=activeSeconds,seat=seat,shape=key,overlay=(p.stats[seat]or{}).overlay}end
     lastShapes[seat]=key
    end
   end
   if dt>.025 and #outliers<256 then
    outliers[#outliers+1]={seconds=activeSeconds,round=#rounds,display_ms=dt*1000,previous=previousWork,
     native_ms=p.frameMs,worker=p.diagnostics,phase=p.phase,main=st.main,sub=st.sub}
   end
  else lastAudioRestarts=nil end
  lastTick=t
 else lastTick=nil;lastAudioRestarts=nil end
 if p.phase=='finished'or p.probeRound.started and p.seats==1 and(p.session.guest=='gbc'and st.main~=4 or p.session.guest~='gbc'and(st.main==8 or st.main==2 and st.sub>=2))then
  if not p.probeRestart then
   p.probeRestart=true;p.probeRound.finished=true;p.probeRound.result=p.result
   for seat,value in ipairs(p.stats)do p.probeRound['score'..seat]=value.score;p.probeRound['elapsed'..seat]=value.elapsed or value.frame end
   if p.seats==2 then
    local Strings=require('src.core.Strings')
    local expected=p.stats[1].score==p.stats[2].score and Strings('Draw')or p.stats[1].score>p.stats[2].score and Strings('Player 1 wins')or Strings('Player 2 wins')
    assert(p.result==expected,'Incorrect local two-player result')
   end
   p:stop()
   print('PINBALL ROUND '..#rounds..' '..Json.encode(p.probeRound))
  end
 end
 if activeSeconds>=nextProgress then
  nextProgress=nextProgress+10;writeProgress()
  print(string.format('PINBALL PROGRESS %.1fs active · %.2f images/s · round %d',activeSeconds,unique/math.max(1,activeSeconds),#rounds))
 end
 if activeSeconds>=duration then
  local report=writeReport(true);love.event.quit(report.passed and 0 or 1)
 end
end
