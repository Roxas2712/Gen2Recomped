-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Rebuild native continuations by deterministic replay from a qualified world
-- checkpoint. No function, coroutine, VM bytecode or executable save is stored.
local J={MAX_STEPS=18000,MAX_EVENTS=180000,MAX_BYTES=24*1024*1024}
local S=require('src.core.SaveSerializer')
local C=require('src.core.Checkpoint')
local tracks=setmetatable({},{__mode='k'})
local active
local unpack=table.unpack or unpack
local function pack(...) return {n=select('#',...),...} end
local function copy(value)
 return assert(S.decode(S.encodeExact(value)))
end
local function same(a,b) return S.encodeExact(a)==S.encodeExact(b) end
J.encode=S.encodeExact
local function difference(a,b,path)
 if type(a)~=type(b) then return path..' type differs' end
 if type(a)~='table' then return a~=b and (path..' differs: '..tostring(a)..' / '..tostring(b)) or nil end
 for k,v in pairs(a) do local why=difference(v,b[k],path..'.'..tostring(k));if why then return why end end
 for k in pairs(b) do if a[k]==nil then return path..'.'..tostring(k)..' is unexpected' end end
end
local function hash(value)
 return love.data.encode('string','hex',love.data.hash('sha256',value))
end
local function mods(game) return game.modStatus and game.modStatus.loaded or {} end
local function permitted(game)
 if game.linkSession or game.retroArena or game.linkNet and not game.linkNet.closed then return nil,'Online sessions cannot be suspended.' end
 if #mods(game)>0 then return nil,'Suspend is not qualified for loaded mods yet. Normal saves remain available.' end
 if require('src.core.GameVersion').generation()>2 then return nil,'Portable replay suspend is currently qualified for Gen 1–2 only.' end
 if not require('src.core.CheckpointWorld').available(game) then return nil,'Suspend reconstruction is not qualified for this edition yet.' end
 if not (love and love.math and love.math.getRandomState and love.math.setRandomState and love.data) then return nil,'Portable suspend is unavailable in this runtime.' end
 return true
end
function J.invalidate(game,reason)
 if active and active.replay then error('Unsupported action during suspend replay: '..tostring(reason),0) end
 tracks[game]={save=game.save,reason=reason,ticks=0}
end
function J.clear(game) tracks[game]=nil end
-- Cached once per application boot; a version label alone is not a code lock.
function J.build()
 if J.buildId then return J.buildId end
 local files={}
 local function visit(path)
  for _,name in ipairs(love.filesystem.getDirectoryItems(path) or {}) do
   local file=path..'/'..name;local info=love.filesystem.getInfo(file)
   if info and info.type=='directory' then visit(file)
   elseif name:match('%.lua$') then files[#files+1]=file end
  end
 end
 visit('src');for _,file in ipairs({'main.lua','conf.lua'})do if love.filesystem.getInfo(file)then files[#files+1]=file end end;table.sort(files)
 local out={}
 for _,file in ipairs(files) do out[#out+1]=file..'\0'..hash(assert(love.filesystem.read(file))) end
 J.buildId=hash(table.concat(out,'\n'));return J.buildId
end
local contentCache=setmetatable({},{__mode='k'})
function J.content(game)
 if J.contentId then return J.contentId end
 local version=game.save.version;local old=contentCache[game.data]
 if old and old.version==version then return old.value end
 local files={}
 local function visit(path)
  for _,name in ipairs(love.filesystem.getDirectoryItems(path)or{})do
   local file=path..'/'..name;local info=love.filesystem.getInfo(file)
   if info and info.type=='directory'then visit(file)
   elseif name:match('%.lua$')then files[#files+1]=file end
  end
 end
 visit('data/generated');table.sort(files)
 assert(#files>0,'Imported suspend data is unavailable')
 local out={require('src.link.Handshake').hello(game,'battle').fingerprint}
 for _,file in ipairs(files)do out[#out+1]=file..'\0'..hash(assert(love.filesystem.read(file)))end
 local value=hash(table.concat(out,'\n'));contentCache[game.data]={version=version,value=value};return value
end

local function input(game)
 local i=game.input
 return copy({state=i.state or {},pressed=i.pressed or {},sources=i.sources or {}})
end
local function progress(game)
 local out={};for k,v in pairs(game.save) do if k~='options' then out[k]=v end end
 return copy(out)
end
local function projection(value,seen,depth,path)
 path=path or '$'
 local kind=type(value)
 if kind=='number'and(value~=value or value==math.huge or value==-math.huge)then return {number=tostring(value)}end
 if kind=='string' or kind=='boolean' or kind=='number' then return value end
 if kind~='table' or depth>12 then return nil end
 if seen[value] then return {reference=seen[value]} end
 local out={};seen[value]=path
 -- Numeric and named keys only. GPU handles, function upvalues and object
 -- addresses never become portable identities.
 local keys={};for k in pairs(value) do if type(k)=='string' or type(k)=='number' then keys[#keys+1]=k end end
 table.sort(keys,function(a,b)if type(a)~=type(b) then return type(a)<type(b) end;return a<b end)
 for _,k in ipairs(keys) do
  if k~='game'and k~='data'and k~='def'and k~='ruleset'then out[k]=projection(value[k],seen,depth+1,path..'['..type(k)..':'..tostring(k)..']')end
 end
 return out
end
-- Native completion owners contain live world/controller references; the
-- replay rebuilds those owners instead of treating their object graph as data.
local PRESENTATION={_checkpointContinuation=true,game=true,data=true,def=true,ruleset=true,battle=true,shownHp=true,animPlayer=true,gen3Anim=true,gen4Anim=true,
 sprite=true,picAnim=true,monAnim=true,bgCanvas=true,waveCanvas=true,stadium=true,waitingSound=true,gen4CrySource=true}
function J.witness(game)
 local states={}
 for _,state in ipairs(game.stack.states or {}) do
  if state.isBattleState then
   local fields={}
   for k,v in pairs(state) do if not PRESENTATION[k] then fields[k]=v end end
   states[#states+1]={kind='battle',runtime=projection(fields,{},0)}
  else
   states[#states+1]={kind=require('src.core.StateStack').describe(state),phase=state.phase,index=state.index,frame=state.frame}
  end
 end
 local world=game.overworld;local player=world and world.player
 return {save=progress(game),states=states,world=player and {map=world.map.id,x=player.cellX,y=player.cellY,facing=player.facing},rng=love.math.getRandomState()}
end
function J.sample(tag,fn,...)
 local a=active
 if not a or a.nested then return fn(...) end
 local args=pack(...)
 if a.replay then
  a.cursor=a.cursor+1;local e=a.events[a.cursor]
  assert(e and e.tag==tag and same(e.args,args),'Suspend replay diverged at '..tag)
  return unpack(e.values,1,e.values.n)
 end
 a.nested=true
 local result=pack(pcall(fn,...));a.nested=nil
 if not result[1] then error(result[2],0) end
 local values={n=result.n-1};for i=2,result.n do values[i-1]=result[i] end
 local detached,record=pcall(copy,{tag=tag,args=args,values=values})
 if detached then a.events[#a.events+1]=record else a.blocked='nonportable observation' end
 return unpack(values,1,values.n)
end
local function observed(frame,replay,run)
 assert(not active,'Nested suspend observation')
 local a={events=frame.events,replay=replay,cursor=0};local undo={}
 local function patch(object,key,tag,deny)
  if not object or type(object[key])~='function' then return end
  local original=object[key]
  object[key]=function(...)
   if deny then
    if a.replay then error('Suspend does not support '..tag,0) end
    a.blocked=tag;return original(...)
   end
   return J.sample(tag,original,...)
  end
  undo[#undo+1]=function()object[key]=original end
 end
 -- Gameplay math.random shares LOVE's portable RNG while recorded/replayed.
 -- The host C library RNG has no cross-platform getState/setState contract.
 local mathRandom=math.random;math.random=function(...)return love.math.random(...)end
 undo[#undo+1]=function()math.random=mathRandom end
 patch(math,'randomseed','host RNG reseeding',true)
 patch(os,'time','os.time');patch(os,'date','os.date')
 patch(os,'execute','shell execution',true);patch(io,'popen','shell execution',true)
 patch(love.timer,'getTime','timer')
 -- Replaying a script save returns its original I/O result but never writes
 -- progress, options, exports or account storage a second time.
 for _,key in ipairs({'write','append','remove','createDirectory'}) do patch(love.filesystem,key,'fs.'..key,true) end
 patch(os,'rename','file rename',true);patch(os,'remove','file removal',true)
 local ioOpen=io.open
 io.open=function(path,mode)
  if mode and mode:find('[wa+]') then
   if a.replay then error('File writes are forbidden during suspend replay',0) end
   a.blocked='file writes'
  end
  return ioOpen(path,mode)
 end
 undo[#undo+1]=function()io.open=ioOpen end
 local saves=require('src.core.SaveData');local base=saves.persistenceFs
 patch(saves,'loadOptions','progress.options');patch(saves,'load','progress.load')
 saves.persistenceFs=function(...)
  local fs=base(...);local facade={}
  for _,key in ipairs({'read','write','append','remove','createDirectory','getInfo','getDirectoryItems'}) do
   local fn=fs[key]
   if fn then facade[key]=function(...)return J.sample('progress.'..key,fn,...)end end
  end
  return setmetatable(facade,{__index=fs})
 end
 undo[#undo+1]=function()saves.persistenceFs=base end
 local http=package.loaded['src.cloud.Http'];patch(http,'request','network requests',true)
 active=a
 local ok,why=pcall(run)
 active=nil
 for i=#undo,1,-1 do undo[i]() end
 if not ok then error(why,0) end
 if replay then assert(a.cursor==#a.events,'Suspend replay omitted recorded observations') end
 return a.blocked
end
function J.step(game,dt,run)
 if active and active.replay then return run() end
 local t=tracks[game]
 if not t or t.save~=game.save then t={save=game.save,ticks=0};tracks[game]=t end
 local allowed,why=permitted(game)
 if not allowed then t.anchor=nil;t.reason=why;return run() end
 t.ticks=t.ticks+1
 if not t.anchor or t.ticks>=60 then
  local anchor=C.capture(game)
  if anchor and anchor.kind=='overworld' then
   t.anchor=anchor;t.memory=progress(game);t.options=copy(game.save.options or {});t.steps={};t.events=0;t.ticks=0;t.reason=nil
  end
 end
 if not t.anchor then t.reason=t.reason or 'Reach a settled overworld to establish a suspend checkpoint.';return run() end
 if #t.steps>=J.MAX_STEPS or t.events>=J.MAX_EVENTS then
  J.invalidate(game,'Reach a settled overworld before suspending this longer scene.');return run()
 end
 local frame={dt=dt,input=input(game),rng=love.math.getRandomState(),events={}}
 local ok,err=pcall(observed,frame,false,run)
 if not ok then
  -- The native frame may have partially run; do not repeat it. Unsupported
  -- side effects are not suppressed during ordinary play.
  J.invalidate(game,'Suspend recording stopped: '..tostring(err));error(err,0)
 end
 if err then J.invalidate(game,'Suspend does not support '..err..' during gameplay.');return end
 t.steps[#t.steps+1]=frame;t.events=t.events+#frame.events
end
function J.capture(game)
 local ok,why=permitted(game);if not ok then return nil,why end
 local t=tracks[game]
 if not t or not t.anchor or t.save~=game.save then return nil,t and t.reason or 'No qualified suspend checkpoint is available yet.' end
 local report=require('src.storage.SaveResume').capture(game.save.version,mods(game),game.save.options or {})
 local got,content=pcall(J.content,game);if not got then return nil,'Could not verify imported suspend data: '..tostring(content)end
 local value={schema=1,build=J.build(),edition=game.save.version,anchor=t.anchor,memory=t.memory,options=t.options,steps=t.steps,
  requirements=report,content=content,witness=J.witness(game)}
 local bytes=S.encodeExact(value)
 if #bytes>J.MAX_BYTES then return nil,'Suspend recording is too large. Save normal progress and continue from the overworld.' end
 return S.decode(bytes)
end
function J.restore(game,value)
 local ok,why=permitted(game);if not ok then return nil,why end
 if type(value)~='table' or value.schema~=1 or type(value.steps)~='table' or #value.steps>J.MAX_STEPS
  or value.edition~=game.save.version or value.build~=J.build() then return nil,'This suspend needs the same edition and exact engine build.' end
 if type(value.memory)~='table' or value.memory.version~=value.edition or type(value.memory.meta)~='table'
  or type(value.anchor)~='table' or type(value.anchor.identity)~='table' or value.memory.meta.playthroughId~=value.anchor.identity.playthroughId then return nil,'Suspend playthrough identity is inconsistent.' end
 local got,content=pcall(J.content,game)
 if not got or value.content~=content then return nil,'Imported game data differs from this suspend.' end
 local options=game.save.options;local oldInput=input(game);local count=0
 local restored,code,message=C.resumeReplay(game,value.anchor,function()
  -- A normal-save projection records the live position. Native memory can
  -- intentionally still hold the last written position (and nil flags).
  -- Keep the reconstructed world, but restore the original memory exactly.
  local memory=copy(value.memory)
  for k in pairs(game.save) do game.save[k]=nil end
  for k,v in pairs(memory) do game.save[k]=v end
  game.save.options=copy(value.options)
  for _,frame in ipairs(value.steps) do
   assert(type(frame.dt)=='number' and frame.dt>0 and frame.dt<=.1 and type(frame.events)=='table','Invalid suspend frame')
   count=count+#frame.events;assert(count<=J.MAX_EVENTS,'Suspend observation limit exceeded')
   game.input.state=copy(frame.input.state);game.input.pressed=copy(frame.input.pressed);game.input.sources=copy(frame.input.sources)
   love.math.setRandomState(frame.rng)
   observed(frame,true,function()
    game.stack:update(frame.dt)
    game.save.playTime=(tonumber(game.save.playTime) or 0)+frame.dt
   end)
  end
  local actual=J.witness(game)
  if not same(actual,value.witness) then error('Suspend runtime mismatch: '..tostring((difference(actual,value.witness,'runtime'))),0) end
 end)
 game.input.state=oldInput.state;game.input.pressed=oldInput.pressed;game.input.sources=oldInput.sources
 if not restored then return nil,message or code end
 -- Keep local display/audio preferences, but no input from the other device.
 game.save.options=options;if game.applyOptions then game:applyOptions(options) end
 if game.input.reset then game.input:reset() end
 tracks[game]={save=game.save,anchor=copy(value.anchor),memory=copy(value.memory),options=copy(value.options),steps=copy(value.steps),events=count,ticks=0}
 return true
end
return J
