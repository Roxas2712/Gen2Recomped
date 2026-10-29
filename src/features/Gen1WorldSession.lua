-- Optional Game3 mutation/streaming contract over the admitted native world.
-- Contributions by Roxas2712; see NOTICE.md. No independent frame loop/player.
local Native=require('src.compat.gen1.NativeSession')
local Identity=require('src.compat.gen1.MapIdentity')
local Version=require('src.core.GameVersion')
local M={REVISION=1}
local facing={up=true,down=true,left=true,right=true}
local function integer(n)return type(n)=='number'and n==n and n>=0 and n<math.huge and n%1==0 end
function M.new(value,checkOwner)
  local game,why=Native.game(value);if not game then return nil,why end
  local data,save,mods,edition=game.data,game.save,game.mods,Version.get()
  if not(type(data)=='table'and type(data.maps)=='table'and type(save)=='table')then return nil,'native world data unavailable'end
  local maps=data.maps
  local binding=Identity.bind(maps,edition)
  local released,busy=false,false
  local queue,pending,completed={},{},{}
  local mapEpoch
  local self={revision=M.REVISION}
  function self:valid()
    return not released and(not checkOwner or checkOwner())and package.loaded['src.core.Game']==game and Version.get()==edition and game.data==data and game.save==save
      and game.mods==mods and data.maps==maps
  end
  local function admit(write)
    if not self:valid()then return nil,'Game3 feature session retired'end
    if package.loaded['src.core.Game']~=game then return nil,'Game3 feature requires the current native host'end
    local _,world,player=Native.resolve(game)
    if not world then return nil,'no active native world'end
    if mapEpoch~=world.map then mapEpoch=world.map;queue,pending,completed={},{},{}end
    if write then
      if busy then return nil,'world operation already active'end
      local ok,reason=require('src.mods.Api3WorldEdits').ready(game,world)
      if not ok then return nil,reason end
    end
    return world,player
  end
  local function resolve(id)
    if type(id)~='string'then return nil,'map id must be a string'end
    if maps[id]then return id,maps[id]end
    local native,def=binding:nativeId(id)
    if not native then return nil,'unknown native map: '..id end
    return native,def
  end
  function self:current()
    local world,player=admit();if not world then return nil,player end
    return {map=binding:legacyId(world.map.id),nativeMap=world.map.id,
      x=player.cellX,y=player.cellY,facing=player.facing,world=world}
  end
  function self:load(id,opts)
    opts=opts or {}
    local world,why=admit(true);if not world then return nil,why end
    local native,def=resolve(id);if not native then return nil,def end
    for key in pairs(opts)do
      if key~='x'and key~='y'and key~='facing'and key~='seamless'and key~='keepMusic'and key~='initialLoad'and key~='enterVia'then
        return nil,'unsupported native map option: '..tostring(key)
      end
    end
    if opts.initialLoad~=nil then return nil,'initialLoad belongs to native boot; use enterVia for an active world' end
    local x,y,dir=opts.x or 0,opts.y or 0,opts.facing or 'down'
    if not(integer(x)and integer(y)and integer(def.width)and integer(def.height)
      and x<def.width and y<def.height and facing[dir])then return nil,'invalid native map destination'end
    for _,key in ipairs{'seamless','keepMusic','initialLoad'}do
      if opts[key]~=nil and type(opts[key])~='boolean'then return nil,'invalid map option: '..key end
    end
    if opts.enterVia~=nil and opts.enterVia~='continue'and opts.enterVia~='warp'and opts.enterVia~='connection'then return nil,'invalid map arrival kind'end
    if type(world.setMap)~='function'then return nil,'native map loader unavailable'end
    busy=true
    local ok,result=pcall(world.setMap,world,native,x,y,dir,
      {seamless=opts.seamless,keepMusic=opts.keepMusic,via=opts.enterVia=='continue'and 'boot'or opts.enterVia or 'warp'})
    busy=false
    if not ok then error(result,0)end
    if not self:valid()then return nil,'native map owner changed while loading'end
    local _,current,player=Native.resolve(game)
    if current~=world or world.map.id~=native then return nil,'native map load did not complete'end
    return self:current()
  end
  function self:queueScript(rows,extra)
    local world,why=admit(true);if not world then return nil,why end
    if type(rows)~='table'or #rows==0 then return nil,'nonempty native script rows required'end
    local api=require('src.world.WorldAPI').new(game,'gen1-world-session')
    return api:queueScript(rows,extra)
  end
  function self:warmNow(id)
    local world,why=admit();if not world then return nil,why end
    local native,def=resolve(id or world.map.id);if not native then return nil,def end
    if type(world.prefetchAssets)~='function'then return nil,'native resource prefetch unavailable'end
    world:prefetchAssets(native,true)
    return true
  end
  function self:enqueueWarm(id)
    local world,why=admit();if not world then return nil,why end
    local native,def=resolve(id);if not native then return nil,def end
    if not pending[native]and not completed[native]then queue[#queue+1]=native;pending[native]=true end
    return true
  end
  function self:stepWarm()
    local world,why=admit();if not world then return nil,why end
    -- Only submit work. Existing native resource services own worker polling,
    -- upload budgets, cancellation and clocks; this never services them twice.
    local id=queue[1];if not id then return false end
    local ok,reason=self:warmNow(id);if not ok then return nil,reason end
    table.remove(queue,1);pending[id]=nil;completed[id]=true;return true
  end
  function self:release()
    released=true;queue,pending,completed={},{},{}
    binding,mapEpoch,game,data,save,maps,mods,checkOwner=nil,nil,nil,nil,nil,nil,nil,nil
  end
  return self
end
return M
