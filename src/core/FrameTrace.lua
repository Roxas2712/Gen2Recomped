-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Opt-in bounded flight recorder. Wall/submission time, never GPU execution
-- time. Overlapping spans are intentional and must not be summed.
local T = {}
local active, current, rows, generation = false, nil, {}, 0
local limits, started, sequence, labels, labelCount, context
local clock = function() return love.timer.getTime() end
local function finite(n) return type(n)=='number' and n==n and math.abs(n)<math.huge end
local function bounded(n, default, maximum)
 return finite(n) and math.max(1,math.min(maximum,math.floor(n))) or default
end
local function text(value) return tostring(value or ''):sub(1,160) end
function T.enabled(owner) return active and (owner==nil or owner==generation) end
function T.start(options)
 options=options or {};generation=generation+1
 limits={frames=bounded(options.frames,180,600),events=bounded(options.events,128,512),labels=256}
 rows,current,labels,labelCount,sequence,context={},nil,{},0,0,''
 started=clock();active=true
 return generation
end
function T.setContext(value) if active then context=text(value) end end
function T.beginFrame(focused)
 if not active then return end
 -- Abandoned partial frames are explicit, never silently charged to the next.
 if current then T.endFrame(false) end
 sequence=sequence+1
 current={index=sequence,start=clock()-started,focused=focused==true,
  context=context,events={},stages={},droppedEvents=0,droppedLabels=0}
end
function T.add(name,seconds,ended)
 if not(active and current) or not(finite(seconds) and seconds>=0) then return end
 name=text(name)
 if not labels[name] then
  if labelCount>=limits.labels then current.droppedLabels=current.droppedLabels+1;return end
  labels[name]=true;labelCount=labelCount+1
 end
 local row=current.stages[name]
 if not row then row={calls=0,seconds=0,maxSeconds=0};current.stages[name]=row end
 row.calls=row.calls+1;row.seconds=row.seconds+seconds;row.maxSeconds=math.max(row.maxSeconds,seconds)
 if #current.events<limits.events then
  ended=finite(ended) and ended or clock()
  current.events[#current.events+1]={name=name,start=ended-started-seconds,seconds=seconds}
 else current.droppedEvents=current.droppedEvents+1 end
end
local function noop()end
function T.section(name)
 if not(active and current) then return noop end
 local before,owner,epoch=clock(),current,generation
 local closed=false
 return function()
  if closed then return end;closed=true
  if active and owner==current and epoch==generation then
   local ended=clock();T.add(name,ended-before,ended)
  end
 end
end
function T.endFrame(completed)
 if not(active and current) then return end
 current.seconds=clock()-started-current.start;current.completed=completed~=false
 rows[(current.index-1)%limits.frames+1]=current;current=nil
end
function T.stop()
 if active and current then T.endFrame(false) end
 active=false;generation=generation+1
end
function T.snapshot()
 local out={version=1,instrumented=true,qualifiedFps=false,clock='wall/submission seconds',
  overlappingSpans=true,totalFrames=sequence or 0,frames={}}
 -- Deep copy through the JSON boundary: callers never own live recorder rows.
 local ordered={};for _,row in pairs(rows)do ordered[#ordered+1]=row end
 table.sort(ordered,function(a,b)return a.index<b.index end)
 out.frames=ordered
 return require('src.link.Json').decode(require('src.link.Json').encode(out))
end
function T.write(path)
 assert(not active,'stop frame trace before disk output')
 -- Fixed relative diagnostics directory; no caller-supplied save paths.
 assert(type(path)=='string' and path:match('^[%w_-]+%.json$'),'invalid trace filename')
 local fs=love.filesystem;assert(fs.createDirectory('performance'))
 return fs.write('performance/'..path,require('src.link.Json').encode(T.snapshot()))
end
return T
