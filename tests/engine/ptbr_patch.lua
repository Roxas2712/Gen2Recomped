-- No cartridge bytes: exercise verification and atomic publication with a
-- synthetic BPS vector. Real hashes/images are covered by check_ptbr_auto.py.
package.path='./?.lua;'..package.path
local B=require('src.translation.Bps');local J=require('src.link.Json')
local count=0;local function check(v,m)assert(v,m);count=count+1 end
local function u32(v)local t={};for _=1,4 do t[#t+1]=string.char(v%256);v=math.floor(v/256)end;return table.concat(t)end
local source,target='abc','abXY'
local patch='BPS1'..string.char(131,132,128,132,133)..'XY'..u32(B.crc32(source))..u32(B.crc32(target));patch=patch..u32(B.crc32(patch))
local function hash(kind,bytes)return kind..':'..bytes end
local recipe={game='gold',baseImportId='gold_en',sourceId='gold_ptbr',baseSize=3,baseSha1=hash('sha1',source),targetSize=4,targetSha1=hash('sha1',target),targetMd5=hash('md5',target),path='assets/language-patches/pt-BR/gold-us.bps',patchSize=#patch,patchSha256=hash('sha256',patch)}
local files={[recipe.path]=patch};local available,installed,fail=true,nil,false
local entries={{id='gold_en'},{id='gold_ptbr'}}
local I={of=function()return entries end,have=function(_,e)return e.id=='gold_en'and available or e.id=='gold_ptbr'and installed~=nil end,
 api=function()return{read=function(_,id,at,n)assert(id=='gold_en');return source:sub(at+1,at+n)end}end,
 install=function(_,e,bytes)assert(e.id=='gold_ptbr');if fail then return nil,'disk full'end;installed=bytes;return true end}
package.loaded['src.mods.ModImports']=I
love={filesystem={read=function(path)if path:match('index.json$')then return J.encode({format='native-ptbr-bps-v1',recipes={recipe}})end;return files[path]end},
 data={encode=function(_,_,bytes)return bytes end,hash=function(kind,bytes,...)
  assert(select('#',...)==0,'LÖVE hash takes algorithm and bytes')
  assert(kind=='sha256'or kind=='sha1'or kind=='md5','unsupported hash algorithm')
  return hash(kind,bytes)
 end}}
local P=require('src.translation.PtbrPatch')
check(P.describe('gold',{}).baseReady,'supported retained base resolves')
check(not P.describe('emerald',{}),'unavailable editions cannot invent a recipe')
local callbacks=0;check(P.prepare('gold',{},function()callbacks=callbacks+1 end)and installed==target and callbacks>0,'verified image is published through the native import store')
installed=nil;available=false;check(not pcall(P.prepare,'gold',{})and not installed,'absent base cannot publish');available=true
files[recipe.path]=patch..'!';check(not pcall(P.prepare,'gold',{})and not installed,'corrupt patch rejected before publication');files[recipe.path]=patch
source='xyz';check(not pcall(P.prepare,'gold',{})and not installed,'incorrect US identity rejected');source='abc'
recipe.targetSha1='wrong';check(not pcall(P.prepare,'gold',{})and not installed,'target SHA-1 mismatch rejected');recipe.targetSha1=hash('sha1',target)
recipe.targetMd5='wrong';check(not pcall(P.prepare,'gold',{})and not installed,'target MD5 mismatch rejected');recipe.targetMd5=hash('md5',target)
check(not pcall(P.prepare,'gold',{},function()error('cancel')end)and not installed,'cancel before publication has no side effects')
fail=true;check(not pcall(P.prepare,'gold',{})and not installed,'failed atomic store cannot report success');fail=false
recipe.path='../outside.bps';check(not pcall(P.describe,'gold',{}),'index cannot escape the patch bundle')
print('PT-BR preparation: '..count..' checks passed')
