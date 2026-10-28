-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Private bounded CPU jobs over detached copies, including mod-edited data.
local Pool=require('src.core.BuildWorker')
local P=require('src.core.Performance')
local Pixels=require('src.compat.gen1.AtlasPixels')
local M={}
local models=setmetatable({}, {__mode='k'})
local KIND,MODULE='gen3atlas','src.compat.gen1.AtlasPixelsCore'
local pending=setmetatable({}, {__mode='k'})
local totals={submitted=0,published=0,cancelled=0,failed=0}
if not Pool.handlerFor(KIND)then Pool.register(KIND,MODULE)end
local function clock()return love and love.timer and love.timer.getTime and love.timer.getTime()or os.clock()end
function M.available()
  local guard=type(Pixels)=='table'and getmetatable(Pixels)==nil and rawget(Pixels,'_workerCompatible')
  return getmetatable(P)==nil and P.atlasWorker and Pool.available()
    and Pool.handlerFor(KIND)==MODULE and type(guard)=='function'and guard()
end
local function snapshot(pair,layout)
  local tables,seen,visiting={}, {}, {}
  local count,bytes=0,0
  local function copy(value)
    local kind=type(value)
    if kind=='string'then bytes=bytes+#value;assert(bytes<=8*1024*1024);return value end
    if kind=='number'or kind=='boolean'or kind=='nil'then return value end
    assert(kind=='table'and getmetatable(value)==nil and not visiting[value])
    if seen[value]then return seen[value]end
    local out,values={},{};seen[value]=out;visiting[value]=true
    tables[#tables+1]={source=value,values=values}
    for key,child in next,value do
      count=count+1;assert(count<=65536)
      assert(type(key)=='number'or type(key)=='string'or type(key)=='boolean')
      values[key]=child;out[key]=copy(child)
    end
    visiting[value]=nil
    return out
  end
  local payload={pair=copy(pair),layout=copy(layout)}
  return payload,tables
end
local function current(job)
  if not M.available()then return false end
  for _,row in ipairs(job.source)do
    if getmetatable(row.source)~=nil then return false end
    for key,value in next,row.values do if rawget(row.source,key)~=value then return false end end
    for key in next,row.source do if row.values[key]==nil then return false end end
  end
  return true
end
function M.cancel(job)
  if not job or not pending[job]then return end
  if Pool.cancel(job.id)then totals.cancelled=totals.cancelled+1 end
  pending[job]=nil
end
-- A waiting reply cannot publish. Check its deadline/admission each frame;
-- validate every captured source value once when the reply can actually commit.
function M.expired(job,waiting)
  if clock()-job.started>=5 or not M.available()then return true end
  return not(waiting==true or current(job))
end
function M.prepare(pair,layout,done,failed)
  if not M.available()then return nil end
  local count=0
  for job in pairs(pending)do
    if M.expired(job)then M.cancel(job)else count=count+1 end
  end
  if count>=Pool.count()*2 then return nil end
  local ok,payload,source=pcall(snapshot,pair,layout)
  if not ok then return nil end
  local job={source=source,started=clock()}
  local function failure()
    if not pending[job]then return end
    pending[job]=nil;totals.failed=totals.failed+1;failed()
  end
  pending[job]=true
  local accepted,id=pcall(Pool.submit,KIND,'atlas',payload,function(result)
    if not pending[job]then return end
    if M.expired(job)then failure();return end
    pending[job]=nil
    -- Uploads may span several main-thread slices. Keep a read-only source
    -- validator alive until publication, after this pool handle has retired.
    local ok=pcall(done,result,function()return current(job)end)
    if not ok then totals.failed=totals.failed+1;failed()end
  end,failure)
  if not accepted or not id then pending[job]=nil;return nil end
  job.id=id;totals.submitted=totals.submitted+1
  return pending[job]and job or nil
end
function M.published(model)
  models[model]=true;totals.published=totals.published+1
  require('src.core.FrameProfile').bake('gen3.worker.atlas')
end
function M._cacheInfo(pairsTable)
  local out={worker=0,native=0}
  for _,model in pairs(pairsTable or {})do
    local key=models[model]and 'worker'or 'native';out[key]=out[key]+1
  end
  return out
end
function M._counters()
  local out={};for key,value in pairs(totals)do out[key]=value end;return out
end
return M
