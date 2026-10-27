-- Cartridge labels and edition-specific level-up window layouts.
local M={}
local TABLES={ruby=0x40165c,sapphire=0x4016b4,firered=0x459b48,leafgreen=0x459568,emerald=0x625b54}
function M.extract(x)
  local at=assert(TABLES[x.version],'Unknown native stat-growth edition')
  local rs=x.version=='ruby'or x.version=='sapphire'
  local labels={}
  for i=0,5 do labels[i+1]=assert(x:readText(assert(x.rom:pointer(at+i*4))),'Missing native stat label')end
  x._constants.gen3StatGrowth={format=1,version=x.version,labels=labels,
    stats=rs and{'hp','spatk','attack','spdef','defense','speed'}or{'hp','attack','defense','spatk','spdef','speed'},
    box=rs and{x=12,y=1,w=17,h=6}or{x=19,y=x.version=='emerald'and 8 or 1,w=10,h=11},
    layout=rs and'rs'or x.version=='emerald'and'emerald'or'frlg',
    source=('ROM: native six-stat name table %07X and original battle window layout'):format(at)}
  x:write('constants',x._constants)
end
function M.valid(s,version)
  if type(s)~='table'or s.format~=1 or s.version~=version or not TABLES[version]
    or type(s.labels)~='table'or #s.labels~=6 or type(s.stats)~='table'or #s.stats~=6
    or type(s.box)~='table'then return false end
  for _,word in ipairs(s.labels)do if type(word)~='string'or word==''then return false end end
  local expected=(version=='ruby'or version=='sapphire')and'rs'or version=='emerald'and'emerald'or'frlg'
  if s.layout~=expected then return false end
  local seen={};local keys={hp=true,attack=true,defense=true,spatk=true,spdef=true,speed=true}
  for _,key in ipairs(s.stats)do if not keys[key]or seen[key]then return false end;seen[key]=true end
  for _,key in ipairs({'x','y','w','h'})do
    local n=s.box[key];if type(n)~='number'or n%1~=0 or n<1 then return false end
  end
  if s.box.x+s.box.w>30 or s.box.y+s.box.h>20 then return false end
  return true
end
function M.missing(version)
  if not TABLES[version]then return{}end
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  return M.valid(ok and type(c)=='table'and c.gen3StatGrowth,version)and{}or{'<gba:native-level-up-stats>'}
end
return M
