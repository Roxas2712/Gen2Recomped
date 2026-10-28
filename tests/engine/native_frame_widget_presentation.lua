-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local P=require('src.ui.game3.presentation');local Font=require('src.render.Font')
local Window=require('src.ui.game3.window');local G=require('src.core.Game3')
local V=require('src.core.GameVersion');local original=package.loaded['src.core.Game']
local g=love.graphics;local rectangle,code=g.rectangle,Font.drawCode
local trace={};local function log(kind,...)
 trace[#trace+1]={kind,...}
end
g.rectangle=function(...)log('rect',...)end;Font.drawCode=function(...)log('glyph',...)end
local function provider(draw)return{enabled=function()return true end,draw=draw}end
local function pack(...)return{n=select('#',...),...}end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);local game=f.game
 package.loaded['src.core.Game']=game;game.stack:push({});Font.load(game.data)
 for _,sample in ipairs{
  {'drawBox','user',{1,2,8,6},{8,16,64,48}},
  {'drawStandardBox','standard',{1,2,8,6},{8,16,64,48}},
  {'drawDialogueBox','dialogue',{1,14,28,6},{8,112,224,48}},
  {'drawSignpostBox','sign',{1,14,28,6},{8,112,224,48}}}do
  local method,style,args,bounds=unpack(sample)
  P._service.release();trace={};g.setColor(.2,.3,.4,.5);Font[method](unpack(args));local expected=trace
  local nativeColor={g.getColor()}
  T.check(#expected>0,'native fallback frame is actually painted')
  local calls=0;local mode='false';local seen
  G._withCallbackOwner('frame-owner',function()P.register('frames',provider(function(kind,ctx)
   calls=calls+1;seen=ctx
   T.eq(kind,'frame');T.eq(ctx.style,style);T.eq(G._callbackOwner(),'frame-owner')
   T.same({ctx.x,ctx.y,ctx.width,ctx.height},bounds)
   if mode=='handled'then return true end
   if mode=='error'then g.push();g.setColor(.1,.2,.3,.4);error('provider frame failed')end
   if mode=='borrow'or mode=='native-error'then
    local a=pack(pcall(Font[method],unpack(args)))
    if mode=='borrow'then T.same({g.getColor()},nativeColor,'base callers see native font postconditions')end
    Font[method](unpack(args))
    if mode=='borrow'then T.eq(a[1],true)end
   end
   return false
  end))end)
  local function draw()
   P.begin(game,240,160);trace={};g.setColor(.2,.3,.4,.5);local color={g.getColor()}
   Font[method](unpack(args));T.same({g.getColor()},mode=='handled'and color or nativeColor,
    'native colour postconditions survive provider isolation')
   return trace
  end
  T.same(draw(),expected,'false preserves native frame and fallback chain');T.eq(calls,1)
  mode='borrow';T.same(draw(),expected,'multiple base calls plus false paint once');T.eq(calls,2)
  mode='handled';T.eq(#draw(),0,'handled provider owns only the frame')
  mode='error';T.same(draw(),expected,'provider error restores native frame')
  T.check(P.health('frames').error:find('provider frame failed',1,true)~=nil)
  P._service.release()
 end
 -- The public tile-template helper uses the native standard frame owner.
 local style
 P.register('template',provider(function(_,ctx)style=ctx.style;return true end));P.begin(game,240,160)
 Window.stdFrame(Window.template(2,3,6,4));T.eq(style,'standard')
 -- Direct source draws may ask the native font for their fallback without
 -- recursively re-entering the same provider.
 local loops=0
 P.register('direct',provider(function()loops=loops+1;Font.drawBox(1,2,8,6);return true end))
 P.begin(game,240,160);trace={};T.eq(P.draw('frame',{}),true);T.eq(loops,1);T.check(#trace>0)
 -- Once-only body tuples and native failures survive nested provider calls.
 local calls=0
 P.register('tuple',provider(function()
  local values=pack(P._nativeDraw('frame',{},function()error('wrong recursive body')end))
  T.same(values,{n=3,[2]=4});return false
 end));P.begin(game,240,160)
 T.same(pack(P._nativeDraw('frame',{},function()calls=calls+1;return nil,4,nil end)),{n=3,[2]=4})
 T.eq(calls,1)
 P.register('failed',provider(function()
  pcall(Font.drawBox,1,2,8,6);pcall(Font.drawBox,1,2,8,6);return true
 end));P.begin(game,240,160);calls=0
 g.rectangle=function()calls=calls+1;g.push();error('native frame body failed')end
 T.raises(function()Font.drawBox(1,2,8,6)end,'native frame body failed');T.eq(calls,1)
 g.rectangle=function(...)log('rect',...)end
 P._service.release();game.stack:pop();f.close();G.release()
end
for _,edition in ipairs{'red','crystal','platinum','black'}do
 local f=require('tools.battle-source-runtime.fixture').new('firered');package.loaded['src.core.Game']=f.game
 V.set(edition);P.register('other',provider(function()error('GBA frame provider reached another generation')end))
 T.eq(P._nativeBegin(f.game,160,144),false);trace={};Font.drawBox(1,2,8,6);T.check(#trace>0)
 T.eq(P.health('other').error,nil);P._service.release();f.close();G.release()
end
g.rectangle,Font.drawCode=rectangle,code;package.loaded['src.core.Game']=original;V.set('firered')
T.finish('native user/standard/dialogue/sign frames, provider recursion, base leases and generation routing')
