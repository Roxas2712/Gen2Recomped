-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Mods=require('src.mods.LauncherMods')
local Platform=require('src.core.Platform')
local oldNX,oldOpen,oldFS=Platform.isNX,io.open,love.filesystem
local nx=true;Platform.isNX=function()return nx end
local maximum=64*1024*1024
T.eq(Mods.NX_MAX_ZIP_BYTES,maximum,'console preflight exposes its bounded archive contract')
local reads,closes,mounts=0,0,0
local requested
local function dropped(size)
 return {open=function()return true end,getSize=function()return size end,
  read=function(_,amount)reads=reads+1;requested=amount;return 'PK00' end,
  close=function()closes=closes+1;return true end}
end
love.filesystem={newFileData=function(bytes)return bytes end,mount=function()mounts=mounts+1;return false end,
 write=function()return true end,remove=function()return true end}
local ok,why=Mods.installZip(dropped(maximum+1),{replace=true})
T.eq(ok,nil,'oversized dropped archive is refused')
T.check(why:find('64 MiB',1,true),'console refusal explains the usable limit')
T.eq(reads,0,'oversized dropped input body is never allocated')
T.eq(closes,1,'refused dropped handle closes')
T.eq(mounts,0,'refused input never reaches the archive mount or replacement')
Mods.installZip(dropped(maximum))
T.eq(reads,1,'exact console boundary reaches ordinary ZIP validation')
T.eq(requested,maximum,'known dropped input reads no more than its bound')
T.eq(closes,2,'boundary input closes after reading')
nx=false
Mods.installZip(dropped(maximum+1))
T.eq(requested,maximum+1,'desktop dropped archives retain the original size contract')
nx=true
io.open=function(path,mode)
 assert(path=='owned-archive.zip' and mode=='rb')
 return {seek=function(_,kind)if kind=='end'then return maximum+1 end;return 0 end,
  read=function()reads=reads+1;return 'PK00'end,close=function()closes=closes+1 end}
end
local before=reads
ok,why=Mods.installZip('owned-archive.zip')
T.eq(ok,nil,'oversized external file is refused')
T.check(why:find('64 MiB',1,true),'external console refusal is actionable')
T.eq(reads,before,'external size preflight runs before reading archive bytes')
io.open=function()return nil end
love.filesystem.getInfo=function()return {type='file',size=maximum+1}end
love.filesystem.read=function()reads=reads+1;return 'PK00'end
ok,why=Mods.installZip('owned-relative.zip')
T.eq(ok,nil,'oversized merged-filesystem archive is refused')
T.eq(reads,before,'merged filesystem size preflight avoids allocating the body')
love.filesystem.getInfo=function()return nil end
local arity
love.filesystem.read=function(...)arity=select('#',...);local path,amount=...;requested=amount;return 'PK00'end
Mods.installZip('owned-relative.zip')
T.eq(requested,maximum+1,'unknown console size reads only the bounded overflow probe')
nx=false;Mods.installZip('owned-relative.zip')
T.eq(requested,nil,'desktop filesystem reads retain the unlimited legacy contract')
T.eq(arity,1,'desktop provider receives exactly its original read call shape')
Platform.isNX,io.open,love.filesystem=oldNX,oldOpen,oldFS
T.finish('native console archive size admission before ZIP allocation')
