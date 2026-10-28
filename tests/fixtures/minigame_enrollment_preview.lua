-- Mandatory-entry renderer: no games, cartridge art, account or networking.
-- Contributions by Roxas2712.
local hub,frame,artCalls=nil,0,0
function love.load()
 require('src.translation.Service').setLauncher({launcherLanguage='de'})
 local G=require('src.pokewalker.minigames.Gfx')
 G.art=function()artCalls=artCalls+1;error('No art may load before acceptance')end
 local H=require('src.ui.WalkerMinigames')
 hub=H.new(nil,require('src.pokewalker.Walker').newState())
 assert(hub.enrolling and not hub.gateChecked,'Fresh profile must remain locked')
end
function love.update()frame=frame+1 end
function love.draw()
 hub:drawFull()
 assert(artCalls==0 and not hub.session,'Unaccepted entry must not prepare a game or its art')
 local layout=assert(hub.gateLayout)
 assert(layout.bodyBottom<=layout.checkTop-4,'Notices overlap the confirmation')
 assert(layout.buttonsBottom<=layout.panelBottom-8,'Buttons exceed the panel')
 local w,h=love.graphics.getDimensions()
 for i,a in ipairs(hub.hits.list)do
  assert(a.x>=0 and a.y>=0 and a.x+a.w<=w and a.y+a.h<=h,'Control exceeds viewport')
  for j,b in ipairs(hub.hits.list)do if j>i then
   assert(not(a.x<b.x+b.w and b.x<a.x+a.w and a.y<b.y+b.h and b.y<a.y+a.h),'Controls overlap')
  end end
 end
 if frame>=4 then frame=-10000;love.graphics.captureScreenshot(function(data)
  local f=assert(io.open(assert(os.getenv('WALKER_PREVIEW_CAPTURE')),'wb'));f:write(data:encode('png'):getString());f:close()
  print('Actual minigame gate rendered; game and cartridge-art loads remained zero');love.event.quit(0)
 end)end
end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());return function()return 1 end end
