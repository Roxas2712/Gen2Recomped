-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Original FR/LG credit script, map pans, sprite windows and native artwork.
local M={ROOT='data/generated/gba/credits/'}
local files={'manifest.lua','pack.lua','copyright.rgba','the_end.rgba','circle.rgba',
 'pokeball_0.rgba','pokeball_1.rgba','pokeball_2.rgba','pokeball_3.rgba',
 'mon_0_1.rgba','mon_0_2.rgba','mon_1_1.rgba','mon_1_2.rgba',
 'mon_2_1.rgba','mon_2_2.rgba','mon_3_1.rgba','mon_3_2.rgba',
 'player_male.rgba','player_female.rgba','rival.rgba','ground_grass.rgba','ground_dirt.rgba','ground_city.rgba'}
function M.resources()
 local out={};for _,name in ipairs(files)do out[#out+1]=M.ROOT..name end;return out
end
local function read(path)
 local raw=require('src.import.CacheFs').read(path);local f=raw and loadstring(raw,'@'..path)
 if not f then return end;setfenv(f,{})
 local ok,t=pcall(f);return ok and type(t)=='table'and t or nil
end
function M.valid(spec,version)
 if not((version=='firered'or version=='leafgreen')and type(spec)=='table'and spec.format==1
  and spec.version==version and type(spec.resources)=='table'and#spec.resources==#files)then return false end
 for i,path in ipairs(M.resources())do if spec.resources[i]~=path then return false end end
 return true
end
function M.packValid(p)
 if not(type(p)=='table'and p.format_version==1 and type(p.title)=='string'and p.title~=''
  and type(p.script)=='table'and#p.script==66 and type(p.texts)=='table'
  and type(p.scenes)=='table'and type(p.spriteParams)=='table'and type(p.mons)=='table')then return false end
 for _,row in ipairs(p.script)do
  if not(type(row)=='table'and type(row.cmd)=='number'and row.cmd%1==0 and row.cmd>=0 and row.cmd<=5
   and type(row.param)=='number'and type(row.duration)=='number')then return false end
 end
 for i=0,42 do local r=p.texts[i];if not(type(r)=='table'and type(r.title)=='string'and type(r.names)=='string')then return false end end
 for i=0,12 do
  local r=p.scenes[i];local first=type(r)=='table'and r[1]
  if not(type(first)=='table'and first.op=='loadmap'and type(first.mapGroup)=='number'
   and type(first.mapNum)=='number'and type(first.x)=='number'and type(first.y)=='number')then return false end
 end
 for i=0,4 do local r=p.spriteParams[i];if not(type(r)=='table'and type(r.character)=='number'
  and type(r.ground)=='number'and type(r.motion)=='number')then return false end end
 for i,n in ipairs{6,3,9,25}do local r=p.mons[i-1];if not(type(r)=='table'and r.species==n
  and type(r.windows)=='table'and#r.windows==3)then return false end end
 return true
end
function M.manifestValid(p)
 if not(type(p)=='table'and p.format_version==1 and type(p.screen)=='table'and p.screen.w==240 and p.screen.h==160
  and type(p.circle)=='table'and type(p.circle.w)=='number'and p.circle.w>0 and p.circle.w==p.circle.h
  and type(p.mons)=='table'and type(p.sheets)=='table')then return false end
 for i=0,3 do local r=p.mons[i];if type(r)~='table'then return false end
  for _,key in ipairs{'frame1','frame2'}do local f=r[key];if not(type(f)=='table'and type(f.w)=='number'
   and type(f.h)=='number'and f.w>0 and f.h>0)then return false end end
 end
 for _,key in ipairs{'player_male','player_female','rival','ground_grass','ground_dirt','ground_city'}do
  local r=p.sheets[key];local ground=key:sub(1,7)=='ground_'
  if not(type(r)=='table'and r.w==64 and r.h==(ground and 32 or 64)and r.frames==(ground and 8 or 6))then return false end
 end
 return true
end
function M.extract(x)
 local version=x.version;if version~='firered'and version~='leafgreen'then return end
 x:beginStage('FireRed/LeafGreen original credits')
 local GV=require('src.core.GameVersion')
 assert(love.data.encode('string','hex',love.data.hash('sha1',x.rom.data))==GV.info(version).sha1,'FR/LG credits cartridge mismatch')
 local bindings={['src.core.GameVersion']=GV,__package={loaded={}}}
 local load=require('compat.gen1-rs.Loader').new(version,bindings)
 local V=load('src.import.gba.versions_frlg');V.select(version);bindings['src.import.gba.versions']=V
 local rom={id=version,size=x.rom.size}
 function rom:get(off)return x.rom:u8(off)end
 function rom:u16(off)return x.rom:u16(off)end
 function rom:u32(off)return x.rom:u32(off)end
 function rom:ptrOffset(value)local at=value-0x08000000;return at>=0 and at<self.size and at or nil end
 local Fs=require('src.import.CacheFs')
 assert(load('src.import.gba.credits_extract').run(rom,{write=function(_,path,bytes)
  local ok,why=Fs.write(path,bytes);assert(ok,why);return true
 end},{game=version}))
 assert(M.packValid(read(M.ROOT..'pack.lua')),'Invalid original FR/LG credit script')
 assert(M.manifestValid(read(M.ROOT..'manifest.lua')),'Invalid original FR/LG credit artwork')
 x._constants.gen3FrlgCredits={format=1,version=version,resources=M.resources()}
 x:write('constants',x._constants)
end
function M.missing(version)
 local spec=(read('data/generated/constants.lua')or{}).gen3FrlgCredits
 if not M.valid(spec,version)then return{'<frlg:native-credits>'}end
 local Fs=require('src.import.CacheFs');local out={}
 for _,path in ipairs(spec.resources)do if not Fs.exists(path)then out[#out+1]=path end end
 if not M.packValid(read(M.ROOT..'pack.lua'))then out[#out+1]=M.ROOT..'pack.lua'end
 if not M.manifestValid(read(M.ROOT..'manifest.lua'))then out[#out+1]=M.ROOT..'manifest.lua'end
 return out
end
return M
