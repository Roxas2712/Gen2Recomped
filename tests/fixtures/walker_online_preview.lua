-- Offline renderer fixture. No real account, ROM, save or HTTP request.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local screen,frames,fonts= nil,0
function love.load()
 local guest=os.getenv('WALKER_PREVIEW_GUEST')=='1'
 package.loaded['src.cloud.RetroCloud']={signedIn=function()return not guest end,accountId=function()return not guest and'17'end}
 package.loaded['src.cloud.Presence']={read=function()return {account_id='17',_receivedAt=os.time(),friends={
  {account_id='29',friend_tag='QA Trainer#4821',online=true,status='online',playing={{edition='crystal'}}},
  {account_id='31',friend_tag='QA Friend#1234',online=true,status='away',playing={}},
 }}end}
 require('src.translation.Service').setLauncher({launcherLanguage='de'})
 local P=require('src.ui.PokewalkerScreen')
 screen=setmetatable({st=require('src.pokewalker.Walker').newState(),t=0,rects={},host={_storageSync=function()error('Preview cannot sync')end}},P)
 if not guest and os.getenv('WALKER_PREVIEW_CONFLICT')=='1'then
  screen._walkerConflict={accountId='17',localWatts=125,cloudWatts=300,localWalking='TREECKO',cloudWalking='MUDKIP'}
 end
 fonts={body=love.graphics.newFont(16),head=love.graphics.newFont(22),small=love.graphics.newFont(13)}
end
function love.update()frames=frames+1 end
function love.draw()
 love.graphics.clear(.035,.045,.065)
 screen.rects={}
 local w,h=love.graphics.getDimensions()
 local height=screen:pageOnline(12,18,w-24,h-36,fonts)
 assert(height>=h-36,'Page must report its drawn height')
 for i,a in ipairs(screen.rects)do
  assert(a.x>=12 and a.x+a.w<=w-12,'Control exceeds narrow viewport')
  for j,b in ipairs(screen.rects)do if j>i then
   assert(not(a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h),'Controls overlap')
  end end
 end
 if frames>=4 then frames=-10000;love.graphics.captureScreenshot(function(data)
  local file=assert(io.open(assert(os.getenv('WALKER_PREVIEW_CAPTURE')),'wb'));file:write(data:encode('png'):getString());file:close()
  print('Real Pokéwalker page renderer passed with isolated offline social fixture');love.event.quit(0)
 end)end
end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());return function()return 1 end end
