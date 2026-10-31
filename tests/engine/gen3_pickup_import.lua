-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion')
local Extract=require('src.import.Gen3PickupData')
for _,edition in ipairs{'ruby','sapphire','firered','leafgreen','emerald'}do
 local sha=V.info(edition).sha1;local p=require('src.import.Gen3PickupProfiles').get(edition,sha)
 local values={};local function row(at,n,width,start)for i=1,n do values[at+(i-1)*width]=(start or 0)+i end end
 if p.style=='fixed'then
  for i=1,p.count do values[p.items+(i-1)*4]=100+i;values[p.items+(i-1)*4+2]=i*5 end
 else
  row(p.common,18,2);row(p.rare,11,2,100);row(p.cuts,9,1)
  row(p.pyramid50,200,2);row(p.pyramidOpen,200,2,100);row(p.pyramidCuts,10,1)
 end
 local rom={size=0x800000,u8=function(_,at)return assert(values[at],'unexpected byte address')end,
   u16=function(_,at)return assert(values[at],'unexpected word address')end}
 local r=assert(Extract.extract(rom,{romSha1=sha},sha,edition))
 T.eq(r.edition,edition);T.eq(r.romSha1,sha);T.eq(r.schema,1)
 if p.style=='fixed'then
  T.eq(#r.items,p.count);T.eq(#r.thresholds,p.count-1);T.eq(r.items[p.count],100+p.count)
 else
  T.eq(#r.common,18);T.eq(r.rare[11],111);T.eq(#r.pyramid.open,200);T.eq(r.pyramid.open[200],300)
 end
 T.eq(Extract.extract(rom,{romSha1=string.rep('0',40)},sha,edition),nil,'foreign manifest cannot authenticate ROM offsets')
 T.eq(Extract.extract(rom,{romSha1=sha},string.rep('0',40),edition),nil,'unknown cartridge cannot use known offsets')
 rom.size=1;T.eq(Extract.extract(rom,{romSha1=sha},sha,edition),nil,'truncated cartridge has no Pickup table')
end
T.finish('All-five digest-bound own-ROM Pickup table extraction and import bounds')
