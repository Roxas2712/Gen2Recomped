-- Companion adapter for the pinned Gen1 engine's actual g3u modules.
-- Copy this compat/gen1_session directory to either engine. Roxas2712; NOTICE.md.
local Core=require('compat.gen1_session.Sync')
local Channel=require('compat.gen1_session.Channel')
local M={PROFILE=Channel.PROFILE,credentials=require('compat.gen1_session.Credentials').new}
function M.new(options)
  local namespace=options.namespace or{require=function(_,name)return require(name)end}
  local Wire=namespace:require('src.battle.g3u.Wire')
  local channel,why=Channel.new(options.journal,{mode='battle',room=options.room,address=options.address,netFactory=options.netFactory})
  if not channel then return nil,why end
  local self={channel=channel,parties={},hellos={},phase='connecting'}
  local function fail(reason)self.error=tostring(reason);self:close();return nil,self.error end
  local function publish(key,body)local ok,err=channel:publish(key,body);if not ok then return fail(err)end;return true end
  local function drain()
    if self.core then
      for _,row in ipairs(self.core:poll())do publish(row.key,row.body)end
      self.events=self.core:takeEvents()
      if options.onEvents then options.onEvents(self.events)end
      if self.core:result()then self.result=self.core:result();self.phase='done';channel:close(true);self.closed=true end
    end
  end
  function self:close()self.closed=true;channel:close()end
  function self:choose(action)
    if not self.core or self.closed then return nil,'battle not active'end
    local key,body=self.core:choose(action);if not key then return nil,body end;return publish(key,body)
  end
  function self:update(dt)
    if self.closed then return end
    channel:update(dt);if channel.error then return fail(channel.error)end
    for _,event in ipairs(channel:poll())do
      local body,seat=event.body,event.seat
      if seat~=0 and seat~=1 then return fail('invalid peer seat')end
      if body.type=='session_hello'then
        if body.profile~=Channel.PROFILE or body.mode~='battle'or self.hellos[seat]then return fail('profile mismatch or repeated hello')end
        self.hellos[seat]=body
      elseif body.type=='g3u_table'then
        local ok,err=Wire.validate(body)
        if not ok or seat~=0 or self.table then return fail(err or 'duplicate rules')end
        self.table=body.table
      elseif body.type=='g3u_party'then
        local ok,err=Wire.validate(body,{table=self.table})
        if not ok or self.parties[seat]then return fail(err or 'duplicate party')end
        self.parties[seat]=body.records
      elseif self.core then
        local ok,err=self.core:handle(seat,body);if not ok then return fail(err)end
      else return fail('action preceded shared setup')end
      if self.table and self.parties[0]and self.parties[1]and not self.core then
        self.core=Core.new({table=self.table,parties=self.parties,seat=channel.seat,seed=channel.seed},namespace)
        self.phase='battle'
      end
      drain()
    end
    if not channel.paired or self.closed then return end
    local seat=channel.seat
    if not self.hellos[seat]then return publish('hello',{type='session_hello',profile=Channel.PROFILE,mode='battle',generation=options.generation or 2,engineVersion=options.engineVersion or 'Gen1 peer'})end
    if seat==0 and not self.table then
      local rules=options.table or assert(namespace:require('src.battle.g3u.Table').build(options.data))
      return publish('table',{type='g3u_table',table=rules})
    end
    if self.table and not self.parties[seat]then
      local records=type(options.records)=='function'and options.records(self.table)or options.records
      return publish('party',{type='g3u_party',records=records})
    end
  end
  return self
end
return M
