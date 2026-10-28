-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- DS identities retain form, hidden abilities and Gen 5's independent nature.
-- The common IV/EV/move validator is shared with GBA; DS-specific fields are
-- validated separately and stats are rebuilt from the native form record.
local C={REVISION=1}
local G=require('src.link.Gen3Party')
local function integer(v,a,b)return type(v)=='number' and v%1==0 and v>=a and v<=b end
local function nature(mon,data,gen)
 if gen==4 then return (mon.personality or 0)%25 end
 for i,id in ipairs((data.constants or {}).natureOrder or {})do if id==mon.nature then return i-1 end end
 return mon.ndsNature or(type(mon.nature)=='number'and mon.nature)or(mon.personality or 0)%25
end
function C.pack(mon,plainCopy)
 local gen=require('src.core.GameVersion').generation()
 local data=require('src.pokemon.IdentityRolls').data()or{constants={}}
 local p=G.pack(mon,plainCopy);p.gen3Codec=nil;p.ndsCodec=C.REVISION;p.generation=gen
 p.form=mon.form or mon.gen4Form or 0;p.nature=nature(mon,data,gen)
 p.abilitySlot=mon.abilitySlot or 1;p.gender=mon.gender or p.gender
 if p.gender=='unknown'or p.gender=='genderless'then p.gender='none'end
 for _,k in ipairs({'ndsGame','metLocation','eggLocation','metLevel','metDate','eggDate','otGender','markings','pokerus'})do p[k]=plainCopy({value=mon[k]}).value end
 if mon.ndsRaw then p.ndsRawHex=mon.ndsRaw:gsub('.',function(c)return('%02x'):format(c:byte())end)end
 if not mon.ndsRaw then p.ndsRawHex=mon.ndsRawHex end
 return p
end
local function formDef(data,p,gen)
 local base=data.pokemon[p.species]
 if not base then return nil,'Unknown native DS species'end
 if gen==4 then
  local F=require('src.pokemon.Gen4Forms')
  if p.form~=0 then local _,valid=F.key(base,p);if not valid then return nil,'Unknown native DS form'end end
  return F.definition(data,p)
 end
 if p.form==0 then return base end
 if p.form>=(base.formCount or 1)then return nil,'Unknown native DS form'end
 if(base.formStatsIndex or 0)==0 then return base end
 return data.pokemon[base.formStatsIndex+p.form-1], 'The native form record is missing from this import'
end
function C.unpack(data,p,opts,plainCopy)
 local gen=require('src.core.GameVersion').generation()
 if type(p)~='table'or p.ndsCodec~=C.REVISION or p.generation~=gen then return nil,'Native DS party codec required'end
 if not integer(p.personality,0,4294967295)or not integer(p.nature,0,24)or not integer(p.form,0,31)then return nil,'Invalid DS personality, nature or form'end
 if gen==4 and p.nature~=p.personality%25 then return nil,'Gen 4 nature does not match personality'end
 local def,why=formDef(data,p,gen);if not def then return nil,why end
 local abilities=def.abilities or{}
 if not integer(p.abilitySlot,1,gen==5 and 3 or 2)or not abilities[p.abilitySlot]or abilities[p.abilitySlot]==0 or abilities[p.abilitySlot]=='NONE'then return nil,'Invalid native DS ability slot'end
 local q={};for k,v in pairs(p)do q[k]=v end
 if p.status=='TOX'then q.status='PSN';q.toxic=true end
 q.gen3Codec=G.REVISION;q.nature=p.personality%25;q.gender=nil;q.abilitySlot=math.min(2,p.abilitySlot)
 q.metLocation=0;q.metGame=0;q.otGender=0
 local shadow={};for k,v in pairs(data)do shadow[k]=v end
 shadow.pokemon=setmetatable({[p.species]=def},{__index=data.pokemon})
 local mon,err=G.unpack(shadow,q,opts,plainCopy);if not mon then return nil,err end
 if p.gender~='male'and p.gender~='female'and p.gender~='none'then return nil,'Invalid native DS gender'end
 local ratio=def.genderRatio
 if(ratio==255 and p.gender~='none')or(ratio==0 and p.gender~='male')or(ratio==254 and p.gender~='female')then return nil,'Native DS gender contradicts species'end
 if gen==4 then
  local expected=require('src.pokemon.IdentityRolls').nativeGender(def,nil,p.personality,3)
  if expected=='unknown'then expected='none'end
  if p.gender~=expected then return nil,'Gen 4 gender does not match personality'end
 end
 mon.form=p.form;mon.gender=p.gender;mon.ndsNature=p.nature
 if not(opts and opts.forceLevel)and p.status=='TOX'then mon.status='TOX';mon.toxic=true end
 mon.nature=((data.constants or{}).natureOrder or{})[p.nature+1]or p.nature
 mon.abilitySlot=p.abilitySlot;mon.ability=abilities[p.abilitySlot];mon.altAbility=p.abilitySlot==2 or nil
 local stats=require('src.pokemon.Stats').calcGen3(def,mon.level,mon.ivs,mon.evs)
 local keys={'attack','defense','speed','spatk','spdef'};local up,down=math.floor(p.nature/5)+1,p.nature%5+1
 if up~=down then stats[keys[up]]=math.floor(stats[keys[up]]*110/100);stats[keys[down]]=math.floor(stats[keys[down]]*90/100)end
 stats.special=stats.spatk;mon.stats=stats;mon.hp=opts and opts.forceLevel and stats.hp or math.min(p.hp or stats.hp,stats.hp)
 for _,k in ipairs({'ndsGame','metLocation','eggLocation','metLevel','metDate','eggDate','otGender','markings','pokerus'})do mon[k]=plainCopy({value=p[k]}).value end
 if p.ndsRawHex then
  if type(p.ndsRawHex)~='string'or #p.ndsRawHex~=272 or not p.ndsRawHex:match('^%x+$')then return nil,'Invalid DS source record'end
  mon.ndsRaw=p.ndsRawHex:gsub('..',function(h)return string.char(tonumber(h,16))end)
 end
 return mon
end
function C.signature(mon)
 return ':nds='..require('src.link.Fingerprint').digest(require('src.core.SaveSerializer').encodeExact(C.pack(mon,require('src.link.Protocol').plainCopy)))
end
return C
