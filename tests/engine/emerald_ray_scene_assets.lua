-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local A=require('src.import.Gen3EmeraldRaySceneAssets');local W=require('src.import.LuaWriter')
local resources=A.resources()
T.eq(#resources,37,'manifest, fifteen native BG layers and twenty-one native sprite sheets')
resources[1]='changed';T.eq(A.resources()[1],A.ROOT..'manifest.lua','resource inventory is detached')
local spec={format=1,version='emerald',manifest=A.ROOT..'manifest.lua',resources=A.resources(),
 song=1,rayquaza=1}
T.eq(A.valid(spec,'emerald'),true)
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','crystal'}do
 T.eq(A.valid(spec,version),false,'cinematic is Emerald-specific')
 T.eq(pcall(A.extract,{version=version}),false,'no foreign cartridge read or cache write')
end
local man={format=1,game='emerald',layers={},sprites={},palettes={},smokeCoords={}}
for i=1,10 do man.smokeCoords[i]={0,0}end
for _,path in ipairs(A.resources())do
 local key=path:match('/([^/]+)_idx%.png$')
 if key then local size=key=='ca_ring'and 128 or 256
  man.layers[key]={index=path,w=size,h=size,bpp=(key=='tf_rayquaza'or key=='ca_ring')and 8 or 4}
 else key=path:match('/([^/]+)%.png$');if key then man.sprites[key]={png=path,frames=1,anims={},paletteTag=0}end end
end
local Fs=require('src.import.CacheFs');local read,exists=Fs.read,Fs.exists;local absent
Fs.read=function(path)
 if path=='data/generated/constants.lua'then return W.encode({gen3EmeraldRayScene=spec})end
 if path==spec.manifest then return W.encode(man)end
end
Fs.exists=function(path)return path~=absent end
T.eq(#A.missing(),0,'all native layers and original OAM sheets are ready')
absent=A.ROOT..'tf_rayquaza_idx.png';T.eq(A.missing()[1],absent,'missing affine Rayquaza body requires reimport')
absent=nil;man.layers.tf_rayquaza.bpp=4
T.eq(A.missing()[1],'<emerald:ray-layer-tf_rayquaza>','text encoding cannot satisfy original affine layer')
man.layers.tf_rayquaza.bpp=8;man.layers.ca_ring.w=256
T.eq(A.missing()[1],'<emerald:ray-layer-ca_ring>','original128-pixel ring must not be expanded to a text layer')
man.layers.ca_ring.w=128;man.sprites.ca_rayquaza_tail=nil
T.eq(A.missing()[1],'<emerald:ray-sprite-ca_rayquaza_tail>','missing finale tail cannot be advertised as ready')
Fs.read,Fs.exists=read,exists
T.finish('Emerald native cinematic resource ownership, affine completeness and original layer dimensions')
