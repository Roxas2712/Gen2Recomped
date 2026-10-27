-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Export only the frozen Pokémon, through existing cartridge codecs. This
-- must run on the operator's native-data worker, not on uploaded Lua code.
local R={}
local alphabet='ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/'
local function b64(bytes)
 local out={}
 for i=1,#bytes,3 do
  local a,b,c=bytes:byte(i,i+2);local n=a*65536+(b or 0)*256+(c or 0)
  out[#out+1]=alphabet:sub(math.floor(n/262144)%64+1,math.floor(n/262144)%64+1)
  out[#out+1]=alphabet:sub(math.floor(n/4096)%64+1,math.floor(n/4096)%64+1)
  out[#out+1]=b and alphabet:sub(math.floor(n/64)%64+1,math.floor(n/64)%64+1)or'='
  out[#out+1]=c and alphabet:sub(n%64+1,n%64+1)or'='
 end
 return table.concat(out)
end
function R.export(entry,data)
 local V=require('src.core.GameVersion');local gen=V.generation(entry.source.version)
 assert(gen>=1 and gen<=5 and V.get()==entry.source.version,'Native legality edition mismatch')
 local mon=assert(require('src.core.SaveSerializer').decode(require('src.core.SaveSerializer').encodeExact(entry.mon)));local bytes,ot,nickname
 if mon.ot==nil then mon.ot=mon.gen3OtName or mon.otName end
 if mon.ndsRawHex then
  assert(type(mon.ndsRawHex)=='string'and #mon.ndsRawHex==272 and mon.ndsRawHex:match('^%x+$'),'Invalid DS source record')
  local raw=mon.ndsRawHex:gsub('..',function(h)return string.char(tonumber(h,16))end)
  assert(mon.ndsRaw==nil or mon.ndsRaw==raw,'Conflicting DS source records');mon.ndsRaw=raw
 end
 local function number(v,lo,hi,label)
  assert(type(v)=='number'and v%1==0 and v>=lo and v<=hi,'Invalid or missing native '..label)
 end
 number(mon.level,1,100,'level');number(mon.exp,0,gen<=2 and 16777215 or 4294967295,'experience')
 number(mon.otId,0,gen<=2 and 65535 or 4294967295,'trainer ID')
 assert(type(mon.ot)=='string'and #mon.ot>0,'Original trainer name is missing')
 if mon.gen3OtName then assert(mon.gen3OtName==mon.ot,'Conflicting original trainer names')end
 if mon.otName then assert(mon.otName==mon.ot,'Conflicting original trainer names')end
 local fields=gen>=3 and{'hp','attack','defense','speed','spatk','spdef'}or{'hp','attack','defense','speed','special'}
 local genes=gen>=3 and mon.ivs or mon.dvs;local training=gen>=3 and mon.evs or mon.statExp
 assert(type(genes)=='table','Native genetics are missing')
 local total=0
 for _,k in ipairs(fields)do
  number(genes[k],0,gen>=3 and 31 or 15,'genetics')
  local n=training and training[k]or 0;number(n,0,gen>=3 and 255 or 65535,'training');total=total+n
 end
 assert(gen<3 or total<=510,'Native EV total exceeds 510')
 if gen>=3 then
  number(mon.personality,0,4294967295,'personality')
  local sid=mon.secretId or mon.otSecretId
  if sid~=nil then number(sid,0,65535,'secret trainer ID')end
  assert(mon.otId<65536 or sid==nil or sid==math.floor(mon.otId/65536),'Conflicting secret trainer IDs')
 end
 assert(type(mon.moves)=='table'and #mon.moves>=1 and #mon.moves<=4,'Native moves are missing')
 for k in pairs(mon.moves)do assert(type(k)=='number'and k%1==0 and k>=1 and k<=#mon.moves,'Native move slots are not contiguous')end
 local seen={}
 for _,m in ipairs(mon.moves)do
  local def=data.moves[m.id];assert(def and not seen[m.id],'Unknown or duplicate native move');seen[m.id]=true
  local ups=m.ppUps or 0;number(ups,0,3,'PP enhancement');number(m.pp,0,gen<=2 and math.min(63,math.floor(def.pp*(1+ups*.2)))or math.floor(def.pp*(1+ups*.2)),'move PP')
 end
 assert(not(mon.item and mon.heldItem and mon.item~=mon.heldItem),'Conflicting held item identities')
 local item=mon.item or mon.heldItem;assert(not item or data.items[item],'Unknown native held item')
 for _,field in ipairs({'metLevel','metLocation','eggLocation','metGame','gen3MetGame','ndsGame','ribbons','gen3Ribbons','gen3Markings','markings','pokerus','gen3Pokerus','gen3Language'})do
  local value=mon[field]
  if value~=nil then
   local max=(field=='ribbons'or field=='gen3Ribbons')and 4294967295 or field=='metLevel'and 100 or(field=='metLocation'or field=='eggLocation')and(gen<=3 and 255 or 65535)or(field=='metGame'or field=='gen3MetGame')and 15 or 255
   number(value,0,max,field)
  end
 end
 for _,field in ipairs({'metDate','eggDate'})do
  if mon[field]then local date=mon[field];assert(type(date)=='table','Invalid native date');number(date.year,2000,2255,'date year');number(date.month,1,12,'date month');number(date.day,1,31,'date day')end
 end
 if mon.abilitySlot~=nil then number(mon.abilitySlot,1,gen==5 and 3 or 2,'ability slot')end
 local P=require('src.link.Protocol');local rebuilt=assert(P.unpackMon(data,P.packMon(mon),{strict=true}))
 if mon.hp~=nil then number(mon.hp,0,rebuilt.stats.hp,'current HP')end
 if gen>=3 and mon.nature~=nil then assert(mon.nature==rebuilt.nature,'Native nature contradicts the encoded identity')end
 if mon.ability~=nil then assert(mon.ability==rebuilt.ability,'Native ability contradicts the encoded identity')end
 for k,v in pairs(mon.stats or{})do
  if rebuilt.stats[k]~=nil then assert(v==rebuilt.stats[k],'Native calculated stats do not match genetics and training')end
 end
 if gen<=2 then
  local C=require(gen==1 and'src.save_convert.GenSave'or'src.save_convert.Gen2Save')
  C.setCharmap(gen==1 and require('src.save_convert.data.charmap')or data.charmap)
  bytes,ot,nickname=C.pokemonRecord(mon,data)
 elseif gen==3 then
  assert(mon.gen3MetGame~=nil or mon.metGame~=nil,'The original game of origin is missing')
  assert(mon.metLevel~=nil,'The original encounter level is missing')
  local C=require('src.save_convert.Gen3Save');C.setCharmap(data.charmap)
  bytes=C.buildBoxMon(mon,C.crosswalks(data),{strictIdentity=true,name=mon.ot,secretId=mon.secretId or mon.otSecretId or math.floor(mon.otId/65536),defaults={metGame=mon.gen3MetGame or mon.metGame,language=mon.gen3Language or mon.language}})
 else
  local C=require('src.save_convert.NdsSave')
  local ctx=require('src.save_convert.Gen4Save').context(data,gen==4 and require('src.save_convert.Gen4Save').familyOf(entry.source.version)or'pt',entry.source.version)
  ctx.gen=gen;if gen==5 then ctx.text=C.textCodec(5)end
  bytes=C.encodeMon(mon,ctx,C.STORED)
 end
 return {schema=1,generation=gen,pkm=b64(bytes),ot=ot and b64(ot),nickname=nickname and b64(nickname)}
end
return R
