package.path='./?.lua;'..package.path
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local getenv=os.getenv
local function case(ambiguous,cancel,force)
 os.getenv=function(k)if force and k=='RETRO_WINDOWS_CHOOSE_PROFILE'then return'1'end;return getenv(k)end
 local loaded,frames,remembered,selected=0,0,0,nil
 local profile={identity='Gen2Recomp'}
 package.loaded['tools.windows-demo.Profile']={valid=function()return true end,scan=function()return{profile,profile}end,
  readChoice=function()end,choose=function()return not ambiguous and profile or nil end,
  remember=function()remembered=remembered+1;return true end}
 package.loaded['src.core.SaveIdentity']={migrateLegacy=function()error('Legacy migration must not run')end}
 package.loaded['src.update.Check']={start=function()error('Stable updater must not run')end}
 local fired=false
 local fonts,highlighted=0,0
 love={filesystem={setIdentity=function(v)selected=v end,getIdentity=function()return selected end,
  load=function(path)assert(path=='tools/windows-demo/original-main.lua');return function()
   love.load=function()loaded=loaded+1 end
   love.run=function()love.load();return function()frames=frames+1 end end
  end end},event={pump=function()end,poll=function()return function()
   if not fired then fired=true;return cancel and'quit'or'keypressed',cancel and 0 or'return'end
  end end},handlers={},graphics={isActive=function()return false end,getDimensions=function()return 960,640 end,
   getWidth=function()return 960 end,getHeight=function()return 640 end,clear=function()end,
   newFont=function()fonts=fonts+1;return{}end,setFont=function()end,printf=function()end,print=function()end,rectangle=function()end,
   setColor=function(r,g,b)if r==.12 and g==.27 and b==.33 then highlighted=highlighted+1 end end},timer={sleep=function()end}}
 love.handlers.keypressed=function(k)love.keypressed(k)end
 assert(loadfile('tools/windows-demo/main.lua'))()
 local frame=love.run()
 check(loaded==0,'profile selection does not initialize the engine twice')
 if ambiguous or force then
  love.wheelmoved(0,-.25);love.draw()
  check(highlighted==1,'fractional touchpad scrolling keeps a selectable integer row')
  love.keypressed('up');love.draw()
  check(fonts==2,'profile rendering reuses its fonts')
 end
 local result=frame()
 if cancel then check(result==0 and loaded==0 and remembered==0,'cancel leaves every profile unopened');return end
 if ambiguous or force then check(loaded==0,'picker completes before engine initialization');frame()end
 frame()
 check(loaded==1 and frames==2,'the original engine frame loop and initialization run exactly once')
 check(selected=='Gen2Recomp'and remembered==1,'the existing profile identity is retained')
 check(require('src.core.SaveIdentity').migrateLegacy()==0,'selection cannot silently merge legacy profiles')
 os.getenv=getenv
end
case(false,false);case(true,false);case(false,false,true);case(true,true);os.getenv=getenv
print('Windows demo boot: '..n..' checks passed (event-loop fixture)')
