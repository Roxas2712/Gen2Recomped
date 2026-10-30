-- Private feature relay socket; never enters the account-gated public relay.
-- Contributions by Roxas2712; see NOTICE.md.
local Json=require('src.link.Json')
local M={}
function M.new(options)
  options=options or{}
  local self={closed=false,rx='',tx='',inbox={}}
  function self:connectTCP(address)
    local ok,Socket=true,options.socketApi
    if not Socket then ok,Socket=pcall(require,'socket')end
    if not ok then self.error='LuaSocket is unavailable';return false end
    local host,port=address:match('^([^:]+):(%d+)$')
    if not host or tonumber(port)<1 or tonumber(port)>65535 then self.error='Use host:port';return false end
    self.socket=Socket.tcp();self.socket:settimeout(0);self.api=Socket;self.started=Socket.gettime()
    local connected,why=self.socket:connect(host,tonumber(port))
    if not connected and why~='timeout'and why~='Operation already in progress'then self.error=why;self:close();return false end
    self.connected=connected;return true
  end
  function self:send(message)
    local line=Json.encode(message)..'\n'
    if #line>32768 or #self.tx+#line>131072 then self.error='Relay send budget exceeded';self:close();return nil end
    self.tx=self.tx..line;return true
  end
  function self:update()
    if self.closed or not self.socket then return end
    if not self.connected then
      local _,writable=self.api.select({}, {self.socket},0)
      if #writable>0 then self.connected=self.socket:getpeername()~=nil end
      if not self.connected then
        if self.api.gettime()-self.started>5 then self.error='Relay connection timed out';self:close()end
        return
      end
    end
    if #self.tx>0 then
      local sent,why,last=self.socket:send(self.tx)
      self.tx=self.tx:sub((sent or last or 0)+1)
      if why and why~='timeout'then self.error=why;self:close();return end
    end
    local data,why,partial=self.socket:receive(8192)
    self.rx=self.rx..(data or partial or'')
    while self.rx:find('\n',1,true)do
      local cut=self.rx:find('\n',1,true);local line=self.rx:sub(1,cut-1);self.rx=self.rx:sub(cut+1)
      if #line>32768 then self.error='Relay frame budget exceeded';self:close();return end
      local message=Json.decode(line)
      if type(message)~='table'or #self.inbox>=128 then self.error='Invalid relay frame';self:close();return end
      self.inbox[#self.inbox+1]=message
    end
    if #self.rx>32768 then self.error='Relay frame budget exceeded';self:close();return end
    if why and why~='timeout'then self.error=why;self:close()end
  end
  function self:poll()local out=self.inbox;self.inbox={};return out end
  function self:close()self.closed=true;if self.socket then self.socket:close();self.socket=nil end end
  return self
end
return M
