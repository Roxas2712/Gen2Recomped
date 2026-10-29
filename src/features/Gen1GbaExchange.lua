-- Data-only Game3 block/commit verification after seats/offers are negotiated.
-- Contributions by Roxas2712. Pinned digest/sanitizer: gen1_gsc/LICENSE.MD.
-- This does not open a room, run a trade scene or mutate a party/save.
local M={REVISION=1}
local Bundle=require('src.features.gen1_gsc.Bundle')
local LuaData=require('src.storage.LuaData')
local function copy(t)if type(t)~='table'then return t end;local o={};for k,v in pairs(t)do o[k]=copy(v)end;return o end
function M.new(codec,mine,theirs,options)
  if type(codec)~='table'or codec.generation~=3 or type(codec.unpackMon)~='function'then return nil,'Game3 packet codec required'end
  options=options or {}
  if options.seat~=0 and options.seat~=1 then return nil,'explicit Game3 seat 0 or 1 required'end
  local count=options.afterRound or 0
  if type(count)~='number'or count%1~=0 or count<0 or count>=2147483647 then return nil,'invalid commit round'end
  local a,why=codec.unpackMon(nil,mine);if not a then return nil,why end
  local b,reason=codec.unpackMon(nil,theirs);if not b then return nil,reason end
  local p=Bundle.new():require('src.features.TradeWire')
  local mineWire,peerWire=p.wireMon3(mine),p.wireMon3(theirs)
  if not mineWire or not peerWire then return nil,'invalid Game3 wire offer'end
  local digest=options.seat==0 and p.tradeDigest(mineWire,peerWire)or p.tradeDigest(peerWire,mineWire)
  local state='offered'
  local exchange={revision=M.REVISION}
  function exchange:state()return state end
  function exchange:block(metadata)
    if state~='offered'then return nil,'exchange block already sent'end
    if metadata~=nil and type(metadata)~='table'then return nil,'invalid Game3 block metadata'end
    if metadata and metadata.mail~=nil then return nil,'mail needs the source mail-block adapter'end
    if metadata~=nil then
      local bytes,why=LuaData.encode(metadata,4096);if not bytes then return nil,why end
      if type(metadata)~='table'or metadata.name~=nil and(type(metadata.name)~='string'or #metadata.name>40)
        or metadata.trainerId~=nil and(type(metadata.trainerId)~='number'or metadata.trainerId%1~=0 or metadata.trainerId<0 or metadata.trainerId>4294967295)then return nil,'invalid Game3 block metadata'end
    end
    state='exchange'
    return {type='game3_trade_mon',mon=copy(mineWire),name=metadata and metadata.name,trainerId=metadata and metadata.trainerId}
  end
  function exchange:receive(block)
    if state~='exchange'then return nil,'exchange is not receiving a block'end
    local bytes,problem=LuaData.encode(block,8*1024*1024)
    if not bytes then state='aborted';return nil,problem end
    if type(block)~='table'or block.type~='game3_trade_mon'or block.mail~=nil then state='aborted';return nil,'unsupported Game3 block'end
    local wire=p.wireMon3(block.mon)
    if not wire or p.canonical(wire)~=p.canonical(peerWire)then state='aborted';return nil,'peer exchanged a different Pokemon than offered'end
    local decoded,err=codec.unpackMon(nil,wire)
    if not decoded then state='aborted';return nil,err end
    b=decoded;state='commit_wait'
    return {type='game3_trade_confirm',digest=digest}
  end
  function exchange:accept(message)
    if state~='commit_wait'then return nil,'exchange is not waiting for commit'end
    local bytes,problem=LuaData.encode(message,4096)
    if not bytes then state='aborted';return nil,problem end
    if type(message)~='table'then return nil,'invalid commit'end
    if message.type=='trade_abort'then state='aborted';return nil,message.why or 'peer aborted'end
    if message.type~='trade_commit'or type(message.n)~='number'or message.n%1~=0 or message.n<=count or message.n>2147483647
        or type(message.digests)~='table'or message.digests[1]~=digest or message.digests[2]~=digest then return nil,'unverified or stale Game3 commit'end
    local current,why=codec.unpackMon(nil,peerWire)
    if not current then state='aborted';return nil,why end
    b=current
    count=message.n;state='committed'
    return copy(b),{digest=digest,round=count,nativeWrites=0,seat=options.seat}
  end
  function exchange:abort()if state=='committed'then return false end;state='aborted';a,b=nil,nil;return true end
  return exchange
end
return M
