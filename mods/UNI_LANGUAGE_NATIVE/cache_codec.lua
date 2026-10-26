-- Data-only cache format. No Lua source/bytecode is executed on cache reads.
-- Length-prefixed strings avoid the save reader's per-character escape scan.
local M={}
local MAGIC='ULAC\1'
local MAX_BYTES,MAX_NODES,MAX_DEPTH=16*1024*1024,500000,40
local pack,unpack=love.data.pack,love.data.unpack
function M.encode(value)
 local out={MAGIC};local nodes,bytes=0,#MAGIC
 local visiting={}
 local function add(s)
  bytes=bytes+#s;assert(bytes<=MAX_BYTES,'Cache payload too large');out[#out+1]=s
 end
 local function write(v,depth)
  nodes=nodes+1;assert(nodes<=MAX_NODES and depth<=MAX_DEPTH,'Cache structure too large')
  local t=type(v)
  if t=='nil' then add('0')
  elseif t=='boolean' then add(v and '2' or '1')
  elseif t=='number' then
   assert(v==v and v~=math.huge and v~=-math.huge,'Non-finite cache number')
   add('3'..pack('string','<d',v))
  elseif t=='string' then add('4'..pack('string','<I4',#v)..v)
  elseif t=='table' then
   assert(not visiting[v] and not getmetatable(v),'Cache tables must be plain and acyclic')
   visiting[v]=true
   local n=0;for k in pairs(v)do assert(type(k)=='string' or type(k)=='number' or type(k)=='boolean','Invalid cache key');n=n+1 end
   add('5'..pack('string','<I4',n))
   for k,x in pairs(v)do write(k,depth+1);write(x,depth+1)end
   visiting[v]=nil
  else error('Unsupported cache type: '..t)end
 end
 write(value,0);return table.concat(out)
end
function M.decode(bytes)
 assert(type(bytes)=='string' and #bytes<=MAX_BYTES and bytes:sub(1,#MAGIC)==MAGIC,'Invalid cache header/size')
 local pos,nodes=#MAGIC+1,0
 local function take(n)
  assert(n>=0 and n<=#bytes-pos+1,'Truncated cache payload')
  local s=bytes:sub(pos,pos+n-1);pos=pos+n;return s
 end
 local function number(format,n)return (unpack(format,take(n)))end
 local function read(depth)
  nodes=nodes+1;assert(nodes<=MAX_NODES and depth<=MAX_DEPTH,'Cache structure too large')
  local tag=take(1)
  if tag=='0' then return nil
  elseif tag=='1' then return false
  elseif tag=='2' then return true
  elseif tag=='3' then
   local n=number('<d',8);assert(n==n and n~=math.huge and n~=-math.huge,'Non-finite cache number');return n
  elseif tag=='4' then return take(number('<I4',4))
  elseif tag=='5' then
   local n=number('<I4',4);assert(n<=math.floor((MAX_NODES-nodes)/2),'Cache table too large')
   local out={}
   for _=1,n do
    local k=read(depth+1);assert(type(k)=='string' or type(k)=='number' or type(k)=='boolean','Invalid cache key')
    assert(out[k]==nil,'Duplicate cache key')
    local v=read(depth+1);assert(v~=nil,'Nil cache table value');out[k]=v
   end
   return out
  end
  error('Unknown cache tag')
 end
 local value=read(0);assert(pos==#bytes+1,'Trailing cache bytes');return value
end
return M
