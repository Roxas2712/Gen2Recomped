-- Detached namespace for pinned GSC logic. Contributions by Roxas2712.
-- Vendor code retains its GPLv3/Section 7 grant; see LICENSE.MD/provenance.json.
local Inventory=require('src.features.gen1_gsc.Modules')
local B={}
local unpack=table.unpack or unpack
local hostRequire,hostLoadfile,hostLove=require,loadfile,love
local function loadTrusted(path,env)
  local fn,why
  if hostLove and hostLove.filesystem and hostLove.filesystem.load then
    fn,why=hostLove.filesystem.load(path)
  else fn,why=hostLoadfile(path)end
  if not fn and hostLoadfile then fn,why=hostLoadfile(path)end
  assert(fn,why)
  if setfenv then setfenv(fn,env)else
    -- LÖVE targets LuaJIT; plain Lua tools can also load trusted text chunks.
    fn=assert(loadfile(path,'t',env))
  end
  return fn
end
function B.new(options)
  options=options or {}
  local version=options.version or 'crystal'
  assert(version=='gold'or version=='silver'or version=='crystal','GSC simulation requires gold, silver or crystal')
  local seed=options.seed or 2712
  assert(type(seed)=='number'and seed==seed and math.abs(seed)<math.huge,'finite simulation seed required')
  local state=(math.floor(seed)%2147483646)+1
  local function random(lo,hi)
    state=state*48271%2147483647
    if lo==nil then return (state-1)/2147483646 end
    if hi==nil then lo,hi=1,lo end
    assert(lo%1==0 and hi%1==0 and lo<=hi,'invalid simulation random range')
    return lo+math.floor((state-1)/2147483646*(hi-lo+1))
  end
  local events={}
  local runtime={}
  function runtime.wantsHook(name)return type((options.hooks or {})[name])=='function'end
  function runtime.wants(name)return type(options.onEvent)=='function'end
  function runtime.call(name,default,...)
    local callback=(options.hooks or {})[name]
    if callback then return callback(default,...)end
    return default(...)
  end
  function runtime.emit(name,payload)
    events[#events+1]={name=name,payload=payload}
    if options.onEvent then options.onEvent(name,payload)end
  end
  local pureMath={};for k,v in pairs(math)do pureMath[k]=v end
  pureMath.random=random
  pureMath.randomseed=function(seed)state=(math.floor(seed)%2147483646)+1 end
  local logger={};for _,key in ipairs{'info','warn','error','debug'}do logger[key]=function()end end
  local bridges={
    ['src.mods.Runtime']=runtime,
    ['src.core.Logger']=logger,
    ['src.core.SaveSerializer']=hostRequire('src.core.SaveSerializer'),
    ['src.core.Orientation']={normalize=function(v)return v=='portrait'and v or 'landscape'end},
    -- Source TextBox.strip's data-only portion (same GPL/Section 7 terms).
    ['src.render.TextBox']={strip=function(text)
      if type(text)~='string'then return text end
      text=text:gsub('{DONE}%s*$',''):gsub('{PROMPT}%s*$','')
      return(text:gsub('{DONE}',''):gsub('{PROMPT}',''))
    end},
  }
  local env,cache,loading={},{},{}
  local fixedTime=options.time or 0
  local safeOs={time=function()return fixedTime end,date=function(format,time)return os.date(format,time or fixedTime)end,clock=os.clock}
  local globals={assert=assert,error=error,pcall=pcall,xpcall=xpcall,select=select,type=type,
    tostring=tostring,tonumber=tonumber,pairs=pairs,ipairs=ipairs,next=next,unpack=unpack,
    setmetatable=setmetatable,getmetatable=getmetatable,rawget=rawget,rawset=rawset,rawequal=rawequal,
    string=string,table=table,math=pureMath,os=safeOs,coroutine=coroutine,print=print,
    love={math={random=random}},_VERSION=_VERSION}
  setmetatable(env,{__index=globals});env._G=env
  env.package={path='',loaded=cache,preload={}}
  local bundle={version=version,events=events}
  function bundle:require(name)
    if bridges[name]then return bridges[name]end
    if cache[name]~=nil then return cache[name]end
    assert(not loading[name],'cyclic simulation module: '..tostring(name))
    local path=Inventory[name]
    if path then path='src/features/gen1_gsc/vendor/'..path
    elseif options.testing and name:match('^tests%.gen2_[%w_]+$')then
      path='tests/fixtures/gen1_interfaces/vendor/'..name:gsub('%.','/')..'.lua'
    elseif options.testing and(name=='tests.harness'or name=='tests.love_stub')then return hostRequire(name)
    else error('module is outside the detached GSC contract: '..tostring(name),2)end
    loading[name]=true
    local ok,value=pcall(loadTrusted(path,env))
    loading[name]=nil
    if not ok then error(value,0)end
    cache[name]=value==nil and true or value
    return cache[name]
  end
  env.require=function(name)return bundle:require(name)end
  function bundle:loadFixture(path)
    assert(options.testing and path:match('^tests/fixtures/gen1_interfaces/[%w_]+%.lua$'),'trusted fixture required')
    return loadTrusted(path,env)()
  end
  bundle:require('src.core.GameVersion').set(version)
  return bundle
end
return B
