-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Explicit QA driver utility, never installed in the game loop. No writes,
-- GPU fences, collections, JIT settings or graphics changes during capture.
local B={}
local function bounded(n,default,cap)
 return type(n)=='number'and n==n and math.max(1,math.min(cap,math.floor(n)))or default
end
local function ranked(values)
 local rows={};for name,hits in pairs(values)do rows[#rows+1]={name=name,hits=hits}end
 table.sort(rows,function(a,b)return a.hits==b.hits and a.name<b.name or a.hits>b.hits end)
 return rows
end
function B.capture(o)
 assert(type(o)=='table'and type(o.wait)=='function'and type(o.clock)=='function')
 assert(type(o.observe)=='function','read-only frame observer required')
 local p=assert(o.profiler,'LuaJIT sampling profiler required')
 local count=bounded(o.frames,240,600);local cap=bounded(o.keys,2048,4096)
 local result={version=1,diagnosticOnly=true,qualifiedFps=false,
  clock='wall/submission seconds',samplingIntervalMs=1,frames={},samples=0,
  states={},overflow={},scope='live clocks; graphics untouched; instrumented'}
 local self,inclusive,stacks={},{},{};local sizes={}
 local function add(bank,key,n,kind)
  key=tostring(key):sub(1,2048)
  if bank[key]then bank[key]=bank[key]+n
  elseif(sizes[kind]or 0)<cap then bank[key]=n;sizes[kind]=(sizes[kind]or 0)+1
  else result.overflow[kind]=(result.overflow[kind]or 0)+n end
 end
 local function sample(thread,n,state)
  if type(n)~='number'or n~=n or n<=0 or n==math.huge then return end
  result.samples=result.samples+n;state=tostring(state):sub(1,32)
  add(result.states,state,n,'states')
  add(self,p.dumpstack(thread,'pl',1),n,'self')
  add(stacks,p.dumpstack(thread,'pF;',16),n,'stacks')
  local seen={}
  for name in p.dumpstack(thread,'pF|',32):gmatch('[^|]+')do
   if not seen[name]then seen[name]=true;add(inclusive,name,n,'inclusive')end
  end
 end
 local previous=o.clock()
 -- Always stop this sampler on observer/driver failures, including a yielded
 -- observer. The caller owns any other profiler and must keep it stopped.
 local ok,why=pcall(function()
  p.start('li1',sample)
  for i=1,count do
   o.wait(1);local now=o.clock();local frame=assert(o.observe(),'frame observer failed')
   assert(type(frame)=='table','frame observer must return a fresh row')
   frame.index=i;frame.ms=(now-previous)*1000;previous=now
   result.frames[i]=frame
  end
 end)
 p.stop()
 if not ok then error(why,0)end
 result.self=ranked(self);result.inclusive=ranked(inclusive);result.stacks=ranked(stacks)
 result.worstFrames={}
 for _,frame in ipairs(result.frames)do result.worstFrames[#result.worstFrames+1]=frame end
 table.sort(result.worstFrames,function(a,b)return a.ms>b.ms end)
 for i=#result.worstFrames,31,-1 do result.worstFrames[i]=nil end
 return result
end
return B
