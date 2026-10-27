package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3StatGrowthAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local expected={ruby=0x40165c,sapphire=0x4016b4,firered=0x459b48,leafgreen=0x459568,emerald=0x625b54}
local oldRead=Fs.read
for version,at in pairs(expected)do
  local x={version=version,_constants={},rom={}}
  function x.rom:pointer(address)
    T.check(address>=at and address<=at+20 and(address-at)%4==0,'edition-specific six-pointer stat table')
    return 100+(address-at)/4
  end
  function x:readText(address)return({'HP','ATTACK','DEFENSE','SP. ATK','SP. DEF','SPEED'})[address-99]end
  function x:write(key,value)T.eq(key,'constants');T.eq(value,self._constants)end
  M.extract(x);local s=x._constants.gen3StatGrowth
  T.check(M.valid(s,version));T.eq(#s.labels,6);T.eq(s.stats[1],'hp','native window includes HP')
  local ruby=version=='ruby'or version=='sapphire'
  T.eq(s.box.x,ruby and 12 or 19);T.eq(s.box.y,ruby and 1 or version=='emerald'and 8 or 1)
  Fs.read=function()return Writer.encode({gen3StatGrowth=s})end;T.eq(#M.missing(version),0)
  local label=s.labels[6];s.labels[6]=nil;T.check(not M.valid(s,version));s.labels[6]=label
  local key=s.stats[6];s.stats[6]=s.stats[1];T.check(not M.valid(s,version));s.stats[6]=key
  local pos=s.box.x;s.box.x=31;T.check(not M.valid(s,version));s.box.x=pos
end
Fs.read=oldRead
T.finish('GBA stat-growth native labels, edition window geometry and stale-cache rejection')
