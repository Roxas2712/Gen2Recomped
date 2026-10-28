-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real native editor, image/archive IO, mock-device input and final renderer.
local root=assert(os.getenv('NATIVE_SKIN_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
io.stdout:setvbuf('no')
local Studio,Skin,Touch,Input,S,J,out,report
local jobs,index,capturing={},1,false
local beforeOptions,skinId='','native_gpu_qa'
local function check(v,m)report.checks=report.checks+1;assert(v,m)end
local function add(name,fn)jobs[#jobs+1]={name=name,fn=fn}end
local function pixels(data)return love.data.hash('sha256',data:getString())end
local previousPixels
local function art(r,g,b)
 local data=love.image.newImageData(16,16)
 data:mapPixel(function()return r,g,b,1 end)
 local bytes=data:encode('png'):getString();data:release();return bytes
end
function love.load()
 love.filesystem.setSymlinksEnabled(true)
 assert(love.filesystem.mountFullPath(root,'','read',true))
 out=assert(os.getenv('NATIVE_SKIN_OUTPUT'))
 report={status='running',checks=0,captures={},preparedUIFixture=true,fullModGameplay=false}
 J=require('src.link.Json');S=require('src.core.SaveSerializer')
 Studio=require('src.ui.SkinStudio');Skin=require('src.core.TouchSkin')
 Touch=require('src.core.TouchControls');Input=require('src.core.Input')
 Input:reset();require('src.core.GameVersion').set('crystal')
 local Save=require('src.core.SaveData');beforeOptions=S.encode(Save.loadOptions())
 Studio.load{version='crystal'}
 add('portrait-library',function()check(Studio.mode=='library','real editor opens on library')end)
 add('portrait-editor',function()
  Studio.newSkin();Studio.skin.id=skinId;Studio.skinIdField=skinId;Studio.mode='editor'
  local p=Studio.page();p.controls={Skin.newControl('a',.75,.76,.18,.12,'rect')};Studio.selected=1
  local c=p.controls[1]
  c.imagePath=assert(Skin.importImage(Studio.skin,'idle.png',art(1,.1,.1)))
  c.pressedImagePath=assert(Skin.importImage(Studio.skin,'pressed.png',art(.1,1,.1)))
  c.image=assert(Skin.resolveImage(Studio.skin.root,c.imagePath))
  c.pressedImage=assert(Skin.resolveImage(Studio.skin.root,c.pressedImagePath))
  Studio.save();check(not Studio.dirty,'real editor persists skin and images')
  local loaded=assert(Skin.load(Studio.skin.root,skinId))
  check(#loaded.pages[1].controls==1,'actual saved skin reload retains control')
 end)
 for _,kind in ipairs{'bind','image','export','page'}do
  add('portrait-modal-'..kind,function()Studio.modal=nil;Studio.openModal(kind)end)
 end
 add('portrait-test-idle',function()
  Studio.modal=nil;Studio.testing=true;Touch:setPreview(false)
  check(not Input:isDown('a'),'test starts without held input')
 end)
 add('portrait-test-pressed',function()
  local r=assert(Studio.lastCanvas)
  local x,y=Skin.controlGeometry(Studio.page(),Studio.selectedControl(),r.w,r.h,r.x,r.y)
  Studio.mousepressed(x,y,1)
  check(Input:isDown('a'),'real mock-device press reaches native input')
  check(Skin.surfaceRect==nil,'mock-device press relinquishes temporary viewport')
 end)
 add('portrait-test-released',function()
  Studio.mousereleased(0,0,1)
  check(not Input:isDown('a'),'release retires native held input')
 end)
 add('landscape-editor',function()
  Studio.testing=false;Touch:setPreview(true);love.window.setMode(851,393,{vsync=0})
  if love.window.hide then love.window.hide()end
 end)
 add('landscape-test-idle',function()Studio.testing=true;Touch:setPreview(false)end)
 add('landscape-test-pressed',function()
  local r=assert(Studio.lastCanvas)
  local x,y=Skin.controlGeometry(Studio.page(),Studio.selectedControl(),r.w,r.h,r.x,r.y)
  Studio.mousepressed(x,y,1);check(Input:isDown('a'),'landscape device press reaches native input')
 end)
 add('landscape-focus-release',function()
  Studio.focus(false);check(not Input:isDown('a'),'focus loss clears actual native input')
 end)
 add('landscape-library',function()
  Studio.testing=false;Touch:setPreview(true);Studio.mode='library';Studio.modal=nil
  Studio.available=Skin.list()
  local found=false;for _,e in ipairs(Studio.available)do if e.id==skinId then found=true end end
  check(found,'real library discovers persisted native skin')
  check(S.encode(Save.loadOptions())==beforeOptions,'editing a skin preserves existing native preferences')
 end)
end
function love.draw()
 if capturing or index>#jobs then return end
 local job=jobs[index]
 if not job.started then job.fn();job.started=true end
 local options=S.encode(require('src.core.SaveData').loadOptions());local rng=love.math.getRandomState()
 Studio.draw()
 check(options==S.encode(require('src.core.SaveData').loadOptions()),'editor drawing preserves saved options')
 check(rng==love.math.getRandomState(),'editor drawing preserves native RNG')
 capturing=true
 love.graphics.captureScreenshot(function(data)
  local encoded=data:encode('png');local f=assert(io.open(out..'/'..job.name..'.png','wb'));f:write(encoded:getString());f:close()
  report.captures[#report.captures+1]=job.name
  if job.name=='portrait-test-idle'or job.name=='portrait-test-pressed'then
   local r=Studio.lastCanvas
   local x,y,rx,ry=Skin.controlGeometry(Studio.page(),Studio.selectedControl(),r.w,r.h,r.x,r.y)
   local sx,sy=data:getWidth()/love.graphics.getWidth(),data:getHeight()/love.graphics.getHeight()
   local red,green=0,0
   for py=math.max(0,math.floor((y-ry*.6)*sy)),math.min(data:getHeight()-1,math.floor((y+ry*.6)*sy))do
    for px=math.max(0,math.floor((x-rx*.6)*sx)),math.min(data:getWidth()-1,math.floor((x+rx*.6)*sx))do
     local a,b=data:getPixel(px,py)
     if a>b+.15 then red=red+1 elseif b>a+.15 then green=green+1 end
    end
   end
   if job.name=='portrait-test-idle'then check(red>8,'actual idle art is visible inside the mock-device control')
   else check(green>8,'actual pressed PNG is visible inside the mock-device control')end
  end
  data:release();encoded:release();index=index+1;capturing=false
  if index>#jobs then
   check(not Input:isDown('a'),'fixture leaves no held input')
   report.status='pass';local file=assert(io.open(out..'/skin-result.json','w'));file:write(J.encode(report));file:close()
   print('NATIVE_SKIN_GPU_PASS',report.checks,#report.captures);love.event.quit(0)
  end
 end)
end
function love.errorhandler(why)
 print('NATIVE_SKIN_GPU_FAIL',debug.traceback(tostring(why)))
 return function()return 1 end
end
