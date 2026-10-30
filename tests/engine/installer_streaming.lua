package.path = './?.lua;./?/init.lua;' .. package.path
local S = require('src.import.StreamFiles')
local T = require('tests.harness')
local files, opened, maxRead, writes = {}, {}, 0, {}
local fs = {}
function fs.getInfo(path)
  local f = files[path]
  return f and {type='file',size=f.declaredSize or f.size}
end
function fs.read() error('streaming must not read a complete file') end
function fs.openFile(path, mode)
  assert(mode=='r')
  local f = files[path];if not f then return nil,'missing input' end
  local h={pos=0,closed=false};opened[#opened+1]=h
  function h:read(n)
    maxRead=math.max(maxRead,n)
    if f.failAt and self.pos>=f.failAt then return nil,'injected read error' end
    local count=math.min(n,f.short or n,f.size-self.pos)
    self.pos=self.pos+count
    return string.rep(f.byte or 'A',count),count
  end
  function h:close() self.closed=true;return true end
  return h
end
local sink={}
function sink.openWrite(path)
  local h={size=0,closed=false};opened[#opened+1]=h
  function h:write(bytes)
    writes[#writes+1]=#bytes
    self.size=self.size+#bytes
    if path=='write-error' then return nil,'injected write error' end
    return true
  end
  function h:close()
    self.closed=true
    if path=='close-error' then return nil,'injected close error' end
    return true
  end
  return h
end
local function closed()
  for _,h in ipairs(opened)do T.check(h.closed,'every opened handle is closed') end
  opened={}
end
files.large={size=S.CHUNK_BYTES*2+17,short=32767}
T.check(S.copy(fs,sink,'large','output'),'stream a multi-block private import')
T.eq(#writes,3,'two full writes and one tail')
T.eq(writes[1],S.CHUNK_BYTES,'full block write')
T.eq(writes[3],17,'exact tail length')
T.check(maxRead<=S.CHUNK_BYTES,'native reads have a fixed maximum')
closed()
files.same={size=files.large.size,short=50000}
T.check(S.same(fs,'large','same'),'equal files with different short-read boundaries')
closed()
files.different={size=files.large.size,byte='B'}
T.check(not S.same(fs,'large','different'),'reject changed private bytes')
closed()
files.truncated={size=10,declaredSize=20}
local ok,why=S.copy(fs,sink,'truncated','output')
T.check(not ok and why:find('incomplete',1,true),'reject unexpected EOF before declared size')
closed()
files.broken={size=S.CHUNK_BYTES*2,failAt=S.CHUNK_BYTES}
ok,why=S.copy(fs,sink,'broken','output')
T.check(not ok and why:find('injected read error',1,true),'retain read failure for caller rollback')
closed()
ok,why=S.copy(fs,sink,'same','write-error')
T.check(not ok and why:find('injected write error',1,true),'retain partial-write failure')
closed()
ok,why=S.copy(fs,sink,'same','close-error')
T.check(not ok and why:find('injected close error',1,true),'do not publish an unflushed file')
closed()
T.check(not S.same(fs,'large','missing'),'missing files never compare equal')
closed()
files.empty={size=0}
T.check(S.copy(fs,sink,'empty','output'),'create an empty file')
closed()
local legacy={read=function()return 'old-host' end}
T.check(S.copy(legacy,{write=function(path,data)return path=='legacy'and data=='old-host'end},'input','legacy'),
  'older embedder filesystem contracts remain supported')
T.finish('Bounded installer copy and readback')
