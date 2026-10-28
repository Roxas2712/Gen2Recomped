-- Actual native main callbacks, editor host handoff and real studio state.
-- Constructor is isolated; no cartridge import, player profile or OS IO.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Save=require('src.core.SaveData')
local files={}
local fs=T.sdk.memfs(files)
fs.createDirectory=function()return true end
fs.remove=function(p)files[p]=nil;return true end
fs.getSaveDirectory=function()return '/memory-only-studio-host'end
love.filesystem=fs;Save.persistenceFs=function()return fs end
local osName='Linux'
love.system=love.system or {};love.system.getOS=function()return osName end
local newImage=love.graphics.newImage
love.graphics.newImage=function(...)
 local image=newImage(...)
 function image:setFilter(min,mag)self.filter={min,mag}end
 return image
end
local Runtime=require('src.mods.Runtime')
Runtime.install(require('src.mods.Events').new(),require('src.mods.Hooks').new(),{})
local Host=require('src.core.HostShell')
local launcher
local oldHook=Host.setLauncherHook
Host.setLauncherHook=function(fn)launcher=fn;return oldHook(fn)end
dofile('main.lua');Host.setLauncherHook=oldHook
local function up(fn,wanted)
 for i=1,100 do
  local name,value=debug.getupvalue(fn,i)
  if not name then break end
  if name==wanted then return value end
 end
 error('native host has no '..wanted)
end
local open=up(launcher,'openLauncher')
local Importer=require('src.import.RomImporter')
local oldNew,options=Importer.new
local played=0
local host=setmetatable({tab='crystal',ready={crystal=true},_padCursor={x=90,y=80},
 _padAxis={leftx=1},_padDir={dpright=true},_rawHatDirs={},_padCursorActive=true,
 _slotPress={},_touchGesture={},onComplete=function(v)
  T.eq(v,'crystal','studio Play retains selected native cartridge');played=played+1
 end},{__index=Importer})
Importer.new=function(_,opts)options=opts;return host end
open(false);Importer.new=oldNew
T.check(type(options.onEditTouchSkins)=='function','native launcher actually supplies studio action')
options.onEditTouchSkins()
local Studio=require('src.ui.SkinStudio')
local Skin=require('src.core.TouchSkin')
local Pad=require('src.ui.PadCursor')
local Kit=require('src.ui.kit.Kit')
T.eq(up(love.keypressed,'TouchEditor'),Studio,'actual native host installs real studio owner')
T.eq(up(love.keypressed,'Importer'),nil,'native launcher is suspended')
T.eq(next(host._padAxis),nil,'handoff drops old held axis')
T.eq(host._touchGesture,nil,'handoff drops old launcher gesture')
T.eq(Studio.mode,'library','native entry opens actual skin library')
T.eq(Studio.version,'crystal','editor retains selected cartridge')
love.gamepadaxis(nil,'leftx',1)
T.check(Pad.isActive(),'main forwards controller axis to real studio cursor')
Studio.drag={};Studio.clicked=true
love.focus(false)
T.eq(Studio.drag,nil,'actual focus event releases studio drag with no Game booted')
T.check(not Pad.isActive(),'actual focus event cancels held virtual cursor')
love.gamepadaxis(nil,'leftx',1);love.joystickremoved({})
T.check(not Pad.isActive(),'device removal clears actual studio cursor')
love.visible(false);T.eq(Studio.pointerDown,false,'native visibility event drops gesture')
love.wheelmoved(0,-3);T.eq(Studio.wheel,-3,'actual wheel event reaches studio scroll owner')
Kit.layout(640,576);Kit.focus='native-name'
love.textinput('OWNED')
local text=Kit.textfield('native-name',0,0,200,40,'','Name')
T.eq(text,'OWNED','native text event reaches actual focused widget')
Kit.blur()
Studio.mode='editor';Studio.imageTarget='bezel'
local dropped={getFilename=function()return 'owned-host.png'end,
 open=function()return true end,read=function()return 'OWNED-MEMORY-IMAGE'end,close=function()end}
love.filedropped(dropped)
T.eq(Studio.page().imagePath,'img/owned-host.png','actual file drop imports owned art into selected skin')
T.check(Studio.dirty,'actual import marks native editor dirty')
local previousSkin=Studio.skin
local archive={getFilename=function()return 'another.zip'end,
 open=function()return true end,read=function()return 'PENDING-ARCHIVE'end,close=function()end}
love.filedropped(archive)
T.check(Studio.confirm~=nil,'native archive drop asks before discarding unsaved artwork')
T.eq(Studio.skin,previousSkin,'pending archive drop retains actual edited skin')
Studio.confirmNo()
T.eq(Studio.skin,previousSkin,'cancelling drop retains edits')
-- The editor must preserve native DS controls, in addition to Gen1's binds.
local Version=require('src.core.GameVersion');Version.set('platinum')
Studio.addControl();Studio.setBindSpec('x|y')
local Input=require('src.core.Input');Input:init()
local Touch=require('src.core.TouchControls');Touch:setPreview(false)
local w,h=love.graphics.getDimensions()
local cx,cy=Skin.controlGeometry(Studio.page(),Studio.selectedControl(),w,h)
T.check(Touch:touchpressed('ds-buttons',cx,cy),'studio-created native DS bind captures real contact')
T.check(Input:isDown('x') and Input:isDown('y'),'both DS buttons reach actual native input owner')
Touch:touchreleased('ds-buttons',cx,cy)
T.check(not Input:isDown('x') and not Input:isDown('y'),'DS bind release reaches native owner')
Touch:setPreview(true)
Version.set('crystal')
Touch:setPreview(false)
T.eq(Touch:hitTest(cx,cy),nil,'DS-only art cannot steal a GB pointer gesture')
T.eq(Touch:touchpressed('gb-only',cx,cy),nil,'DS-only binding is inert in Crystal')
T.check(not Input:isDown('x') and not Input:isDown('y'),'unsupported buttons cannot reach GB input')
Studio.setBindSpec('x|a')
Touch:touchpressed('mixed',cx,cy)
T.check(Input:isDown('a') and not Input:isDown('x'),'mixed binding retains supported GB button only')
Touch:touchreleased('mixed',cx,cy)
T.check(not Input:isDown('a'),'mixed release retires actual GB input')
Touch:setPreview(true)
-- The studio's mock device occupies a rectangle inside the editor window.
-- Its Test input must use that same rectangle, not the full window surface.
Studio.setBindSpec('a');Studio.testing=true;Touch:setPreview(false)
Studio.lastCanvas={x=60,y=70,w=180,h=300}
local r=Studio.lastCanvas
cx,cy=Skin.controlGeometry(Studio.page(),Studio.selectedControl(),r.w,r.h,r.x,r.y)
Studio.mousepressed(cx,cy,1)
T.check(Input:isDown('a'),'Test input uses actual mock-device coordinates')
T.eq(Skin.surfaceRect,nil,'Test input restores outer skin surface')
Studio.mousereleased(cx,cy,1)
T.check(not Input:isDown('a'),'mock-device release clears native button')
Studio.testing=false;Touch:setPreview(true)
local calls=0
local mouse=Studio.mousepressed
Studio.mousepressed=function(...)calls=calls+1;return mouse(...)end
for _,platform in ipairs{'iOS','Android'}do
 osName=platform
 love.touchpressed(platform,400,300)
 local after=calls
 love.mousepressed(400,300,1,true)
 T.eq(calls,after,'synthetic '..platform..' mouse does not duplicate real touch')
 love.touchreleased(platform,400,300)
 T.eq(Studio.touchId,nil,'actual '..platform..' release ends finger ownership')
end
Studio.mousepressed=mouse;osName='Linux'
Studio.mode='library';Studio.dirty=false
love.gamepadpressed(nil,'b')
T.eq(up(love.keypressed,'TouchEditor'),nil,'normal B closes actual native studio owner')
T.eq(up(love.keypressed,'Importer'),host,'normal close restores the same native launcher')
T.eq(next(host._padDir),nil,'close cannot restore stale held launcher direction')
T.eq(host._padCursor.x,90,'close preserves launcher cursor location')
T.check(host._padCursorActive,'close restores prior pad navigation mode')
options.onEditTouchSkins()
Studio.newSkin();Studio.skinIdField='native_host_play';Studio.play()
T.eq(played,0,'Play never starts a cartridge inside editor draw')
Studio.update(1/60)
T.eq(played,1,'deferred Play reaches actual native ready-cartridge admission')
T.eq(up(love.keypressed,'TouchEditor'),nil,'deferred Play unloads native editor before admission')
T.eq(Save.loadOptions().touchControls.skin,'native_host_play','Play persists actual selected native skin')
T.eq(Skin.active,nil,'unload relinquishes editor viewport before game boot')
T.finish('native studio launcher, callbacks and deferred play admission')
