love=require('tests.love_stub');love.filesystem.load=loadfile
local n=0
local function check(v,why)n=n+1;assert(v,why)end
local writes=0
local load=require('compat.gen1-rs.Loader').new('ruby',{
 ['src.core.game3.rtc']={calcLocalTime=function()return{hours=23,minutes=59}end,
   initLocalTimeOffset=function(_,h,m)writes=writes+1;check(h==10 and m==0,'Original default setting')end},
 ['src.core.game3.audio']={playSe=function()end},['src.core.game3.se_ids']={SE_SELECT=5},
 ['src.core.game3.rom_text']={},['src.ui.game3.frlg_font']={},['src.ui.game3.chrome']={},
 ['src.ui.game3.rs.menu_cursor']={},['src.import.CacheBlob']={},
})
local kit=load('src.ui.game3.rse.scene_kit');kit.manifest=function()return{layout='rs'}end
local C=load('src.ui.game3.rse.wall_clock')
for _,v in ipairs({{0,1},{10,1},{11,2},{30,2},{31,3},{60,3},{61,6},{255,6}})do
 check(C.calcMinHandDelta(v[1])==v[2],'Original held-input thresholds')
end
check(C.calcNewMinHandAngle(0,C.MOVE.BACKWARD,61)==354,'Backward zero wrap')
check(C.calcNewMinHandAngle(354,C.MOVE.FORWARD,61)==0,'Forward full-circle wrap')
local t={hours=23,minutes=59,period=C.PERIOD.PM}
C.advanceClock(t,C.MOVE.FORWARD);check(t.hours==0 and t.minutes==0 and t.period==C.PERIOD.AM,'Midnight')
C.advanceClock(t,C.MOVE.BACKWARD);check(t.hours==23 and t.minutes==59 and t.period==C.PERIOD.PM,'Backward midnight')
t={hours=11,minutes=59,period=C.PERIOD.AM};C.advanceClock(t,C.MOVE.FORWARD)
check(t.hours==12 and t.minutes==0 and t.period==C.PERIOD.PM,'Noon')
local function input(key,held)return{new=key and{[key]=true}or{},held=held or{}}end
local s=C.new({mode=C.MODE.SET})
for _=1,60 do s:frame(input())end
check(s.state=='set_input'and s.t.hours==10 and s.t.minutes==0,'RS starts in the actual minute-hand state')
s:frame(input('a'));s:frame(input());check(s.state=='confirm_input'and s.confirm.cursor==1,'RS defaults to NO')
s:frame(input('a'));check(s.state=='set_input'and writes==0,'Default NO is a rejection')
s:frame(input('a'));s:frame(input());s:frame(input('b'))
check(s.state=='set_input'and writes==0,'B returns without an RTC write')
s:frame(input('a'));s:frame(input());s:frame(input('up'));s:frame(input('a'));s:frame(input())
for _=1,60 do s:frame(input())end
check(s.done and s.result.confirmed and writes==1,'Only explicit YES writes once')
s=C.new({mode=C.MODE.VIEW});for _=1,60 do s:frame(input())end
for _=1,120 do s:frame(input(nil,{right=true}))end
check(s.t.hours==23 and s.t.minutes==59 and writes==1,'Viewing ignores setting input')
s:frame(input('b'));for _=1,60 do s:frame(input())end
check(s.done and not s.result.confirmed and writes==1,'Read-only VIEW exit')
local Gate=require('src.import.Gen3RsClockAssets')
check(not Gate.valid({format=1,version='ruby'},'ruby'),'Incomplete old metadata rejected')
check(not Gate.valid({format=1,version='ruby',resources={},textIR={}},'sapphire'),'Mixed edition rejected')
print('RS_CLOCK_CONTRACT_CHECKS',n)
