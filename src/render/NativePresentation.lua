-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Drawing leases belong to the existing native frame, never to a second loop.
local Version=require('src.core.GameVersion')
local Session=require('src.compat.gen1.NativeSession')
local Scope=require('src.render.GraphicsScope')
local P={apiVersion=1,features={nativeUiStack=true,windowLayers=true,frameWidgets=true}}
local entries,order={},{}
local nativeDraws,drawKinds={},{}
local frame,revision,checks=nil,0,0
local callbackDepth=0
local unpack=table.unpack or unpack
local function pack(...)return{n=select('#',...),...}end
local function finite(v)return type(v)=='number'and v==v and math.abs(v)<math.huge end
local function valid(f)
 if not f or f.closed or Version.generation()~=3 or Version.get()~=f.edition then return false end
 local g=f.game
 local G=package.loaded['src.core.Game3']
 if not G or G.native(f.view)~=g or Session.game()~=g or g.data~=f.data or g.save~=f.save or g.mods~=f.loader
  or g.stack~=f.stack or f.stack.states~=f.states or #f.states~=#f.sequence then return false end
 for i,state in ipairs(f.sequence)do if f.states[i]~=state then return false end end
 return true
end
local function close(f)
 if not f then return end
 f.closed=true
 for _,job in ipairs(f.jobs)do job.close()end
 f.jobs={};f.selected=nil;f.game=nil;f.view=nil;f.data=nil;f.save=nil
 f.loader=nil;f.stack=nil;f.states=nil;f.sequence=nil
end
local function callback(e,fn,...)
 local G=require('src.core.Game3')
 callbackDepth=callbackDepth+1
 local result=pack(Scope.call(G._withCallbackOwner,e.mod,fn,...))
 callbackDepth=callbackDepth-1
 if not result[1]then e.error=tostring(result[2]);return false,result[2]end
 return unpack(result,1,result.n)
end
local function selected(f)
 if not valid(f)then return end
 if f.known==revision then
  local e=f.selected
  if not e or entries[e.id]==e and not e.error then return e end
 end
 -- Snapshot candidates: callbacks can replace or remove their registration.
 local candidates={};for i=#order,1,-1 do candidates[#candidates+1]=entries[order[i]]end
 local stamp=revision
 f.selected=nil
 for _,e in ipairs(candidates)do
  if entries[e.id]==e and not e.error then
   checks=checks+1
   local ok,on=callback(e,e.provider.enabled,f.view)
   if not valid(f)then return end
   if ok and on and entries[e.id]==e and not e.error then f.selected=e;break end
  end
 end
 f.known=stamp
 return f.selected
end
local function lease(f,native)
 assert(type(native)=='function','native presentation painter must be a function')
 local open,called,result,failure=true,false
 local function paint(...)
  if failure then error(failure,0)end
  if not open or not valid(f)then return false,'native presentation paint retired'end
  if called then return unpack(result,1,result.n)end
  called=true
  local G=require('src.core.Game3')
  local out=pack(Scope.call(G._withCallbackOwner,nil,native,...))
  if not out[1]then failure=out[2];error(failure,0)end
  result={n=out.n-1};for i=2,out.n do result[i-1]=out[i]end
  return unpack(result,1,result.n)
 end
 return paint,function()open=false;native=nil;f=nil;result=nil end,
  function()if failure then error(failure,0)end end
end
function P.unregister(id)
 if not entries[id]then return false end
 entries[id]=nil;revision=revision+1
 for i=#order,1,-1 do if order[i]==id then table.remove(order,i);break end end
 return true
end
function P.register(id,provider)
 assert(type(id)=='string'and id~=''and #id<=256,'invalid presentation owner')
 assert(type(provider)=='table'and type(provider.enabled)=='function'and type(provider.draw)=='function',
  'presentation provider needs enabled and draw callbacks')
 for _,name in ipairs{'begin','notify','widget','finishWidgets','defer','present','finishWindow'}do
  assert(provider[name]==nil or type(provider[name])=='function','invalid presentation callback: '..name)
 end
 assert(entries[id]or #order<64,'too many presentation providers')
 require('src.ui.game3.ui_pass') -- Install only the native modal seam, not Game.
 P.unregister(id)
 local copy={};for k,v in pairs(provider)do copy[k]=v end
 local e={id=id,provider=copy,mod=require('src.core.Game3')._callbackOwner()}
 entries[id]=e;order[#order+1]=id;revision=revision+1
 return function()if entries[id]==e then return P.unregister(id)end;return false end
end
function P._active()return next(entries)~=nil end
function P.begin(current,w,h)
 if callbackDepth>0 or frame and frame.flushing then return false,'presentation callback cannot restart its frame'end
 close(frame);frame=nil
 local g=Session.game(current)
 if not g or not g.stack or type(g.stack.states)~='table'then return false end
 local view=require('src.core.Game3').forNative(g);if not view then return false end
 local sequence={};for i,state in ipairs(g.stack.states)do sequence[i]=state end
 if not finite(w)or w<=0 or not finite(h)or h<=0 then
  w,h=require('src.render.Renderer'):uiSize()
 end
 local f={game=g,view=view,data=g.data,save=g.save,loader=g.mods,stack=g.stack,
  states=g.stack.states,sequence=sequence,edition=Version.get(),jobs={},width=w,height=h}
 frame=f
 local e=selected(f)
 if e and e.provider.begin then callback(e,e.provider.begin,view)end
 return valid(f)
end
function P._nativeBegin(game,w,h)
 if not P._active()then close(frame);frame=nil;return false end
 return P.begin(game,w,h)
end
function P.draw(kind,ctx)
 if kind==nil or drawKinds[kind]then return false end
 local e=selected(frame);if not e then return false end
 drawKinds[kind]=true
 local ok,on=callback(e,e.provider.draw,kind,ctx or{})
 drawKinds[kind]=nil
 return ok and on==true
end
function P._inFrame()return frame~=nil end
-- Native frame helpers can fall back into another helper (e.g. a standard
-- strip missing from an old cache). That internal path remains ordinary
-- native drawing; a provider asking for the base borrows it only once.
function P._nativeDraw(kind,ctx,native,after,...)
 local active=nativeDraws[kind]
 if active then
  if active.painting then return native(...)end
  local result=pack(active.paint())
  if active.after then active.after()end
  return unpack(result,1,result.n)
 end
 local f=frame
 if not selected(f)then return native(...)end
 local args=pack(...);local record={after=after}
 local paint,done,check=lease(f,function()
  record.painting=true
  local out=pack(pcall(native,unpack(args,1,args.n)))
  record.painting=false
  if not out[1]then error(out[2],0)end
  record.result={n=out.n-1};for i=2,out.n do record.result[i-1]=out[i]end
  return unpack(record.result,1,record.result.n)
 end)
 record.paint=paint;nativeDraws[kind]=record
 local ok,why=pcall(function()
  local handled=P.draw(kind,ctx);check()
  if not handled then paint()end
 end)
 local result=record.result
 local afterPaint=record.after
 nativeDraws[kind]=nil;record.paint=nil;record.result=nil;record.after=nil;args=nil;done()
 if not ok then error(why,0)end
 if afterPaint then afterPaint()end
 if result then return unpack(result,1,result.n)end
end
function P.notify(kind,ctx)
 local e=selected(frame)
 if e and e.provider.notify then callback(e,e.provider.notify,kind,ctx or{})end
end
function P.widget(id,native,ctx)
 if not valid(frame)then native();return false end
 local paint,done,check=lease(frame,native)
 local e=selected(frame);local handled=false
 local ok,why=pcall(function()
  if e and e.provider.widget then
   local success,on=callback(e,e.provider.widget,id,paint,ctx or{});handled=success and on==true
  end
  check();if not handled then paint()end
 end)
 done();if not ok then error(why,0)end
 return handled
end
function P.finishWidgets()
 local e=selected(frame)
 if e and e.provider.finishWidgets then callback(e,e.provider.finishWidgets)end
end
function P.layer(kind,native,ui)
 local f=frame;local e=selected(f)
 if e and not f.flushing and #f.jobs<128 and e.provider.defer and e.provider.present then
  local ok,on=callback(e,e.provider.defer,kind)
  if ok and on and valid(f)and entries[e.id]==e and not e.error then
   local paint,done,check=lease(f,native)
   f.jobs[#f.jobs+1]={entry=e,kind=kind,paint=paint,close=done,check=check,ui=ui}
   return true
  end
 end
 native();return false
end
local function fallback(f,job,w,h)
 local r=require('src.render.Renderer'):surfaceRects(f.width,f.height,w,h)
 local g=love.graphics
 local ok,why=Scope.call(function()
  -- Keep the compositor's current target, including a capture/postprocess canvas.
  g.origin();g.setShader();g.setScissor();if g.setDepthMode then g.setDepthMode()end;g.setColor(1,1,1,1)
  g.translate(r.uox,r.uoy);g.scale(r.Ux,r.Uy);job.paint()
 end)
 if not ok then error(why,0)end
end
function P.flush(current,w,h)
 local f=frame
 if not f or f.flushing then return false end
 if Session.game(current)~=f.game or not valid(f)then close(f);frame=nil;return false end
 assert(finite(w)and w>0 and finite(h)and h>0,'invalid presentation window size')
 f.flushing=true;f.known=nil -- Recheck enablement once at the window boundary.
 local ok,why=pcall(function()
  for _,job in ipairs(f.jobs)do
   if not valid(f)then break end
   local e=selected(f);local handled=false
   if e==job.entry and e.provider.present then
    local success,on=callback(e,e.provider.present,job.kind,job.paint,
     {game=f.view,width=w,height=h,ui=job.ui})
    handled=success and on==true
   end
   job.check()
   if not handled and valid(f)then fallback(f,job,w,h)end
   job.close()
  end
  local e=selected(f)
  if e and e.provider.finishWindow then callback(e,e.provider.finishWindow,f.view,w,h)end
 end)
 close(f);if frame==f then frame=nil end
 if not ok then error(why,0)end
 return true
end
function P._nativeFlush(w,h)
 return frame and P.flush(frame.game,w,h)or false
end
function P.health(id)
 local e=entries[id]
 return{registered=e~=nil,error=e and e.error,queued=frame and #frame.jobs or 0,enabledChecks=checks}
end
P._service={release=function()
 close(frame);frame=nil;entries={};order={};revision=revision+1
end,releaseOwner=function(_,owner)
 local retired={}
 for id,e in pairs(entries)do if e.mod==owner or id==owner then retired[#retired+1]=id end end
 for _,id in ipairs(retired)do P.unregister(id)end
end}
require('src.core.game3.asset_stream').register(P._service)
return P
