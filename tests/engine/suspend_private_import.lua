package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local prefix='';local files={['data/generated/pokemon.lua']='return {one=1}',
 ['data/generated/nested/moves.lua']='return {two=2}'}
local function digest(b)local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8)end
love.data={hash=function(_,b)return digest(b)end,encode=function(_,_,b)return b end}
love.filesystem.read=function(p)return files[p]end
love.filesystem.getDirectoryItems=function(p)
 local out,seen={},{};for name in pairs(files) do if name:sub(1,#p+1)==p..'/' then
  local child=name:sub(#p+2):match('^[^/]+');if not seen[child]then out[#out+1]=child;seen[child]=true end
 end end;return out
end
love.filesystem.getInfo=function(p)
 if files[p]then return {type='file'}end
 for name in pairs(files)do if name:sub(1,#p+1)==p..'/'then return {type='directory'}end end
end
package.loaded['src.import.CacheFs']={activePrefixShim=function()return prefix~='' and prefix or nil end}
package.loaded['src.link.Handshake']={hello=function()return {fingerprint='native-data'}end}
local J=require('src.core.SuspendJournal');local game={save={version='emerald'},data={}}
local expected=J.content(game)
local private='launcher/private_games/1/first/'
local copy={};for p,b in pairs(files)do copy[private..p]=b end;files=copy;prefix=private
assert(J.content(game)==expected,'the same imported files have identical content identity after private cloud restore')
local second='launcher/private_games/1/second/'
copy={};for p,b in pairs(files)do copy[second..p:sub(#private+1)]=b end;files=copy;prefix=second
files[second..'data/generated/pokemon.lua']='return {one=99}'
assert(J.content(game)~=expected,'changing the active private import invalidates the fingerprint cache even for the same Data object and edition')
print('Private import suspend identity: 2 checks passed')
