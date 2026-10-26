-- Full administrative gifts. Native predicates, rather than display-only
-- shiny/gender switches, determine the resulting cartridge identity.
local M={}
local S=require('src.core.SaveSerializer')
local function key(v) return tostring(v or ''):upper():gsub('[^A-Z0-9]','') end
function M.nativeKey(records,wanted)
 local found
 for id,row in pairs(records or {}) do
  if key(id)==wanted or type(row)=='table' and key(row.name)==wanted then
   if found and found~=id then return nil,'Ambiguous native name: '..wanted end;found=id
  end
 end
 return found,not found and ('Unavailable in this edition: '..wanted) or nil
end
function M.apply(mon,entry,data,version,rng)
 local p=(entry.origin.reward or {}).pokemon or {};local o=entry.origin
 local gen=require('src.core.GameVersion').generation(version)
 local Stats=require('src.pokemon.Stats');local def=data.pokemon[mon.species]
 if next(p) and gen~=o.generation then return nil,'Receive this configured gift in its original edition first.' end
 local function copy(v) return S.decode(S.encode(v)) end
 mon.ot=p.ot or mon.ot;mon.otId=(p.tid or 2712)+(p.sid or 0)*65536
 mon.secretId=p.sid or 0;mon.gen3OtName=mon.ot;mon.gen3OtFemale=p.ot_female or nil;mon.otGender=p.ot_female and 'girl' or 'boy'
 mon.nickname=p.nickname;mon.happiness=p.friendship or mon.happiness
 local function gender(pid,dvs)
  local ratio=def.genderRatio
  if ratio==nil or ratio==255 then return 'unknown' end
  if ratio==0 then return 'male' end;if ratio==254 then return 'female' end
  if gen>=3 then return pid%256<ratio and 'female' or 'male' end
  return (dvs.attack*16+dvs.speed)<=ratio and 'female' or 'male'
 end
 if gen>=3 then
  if p.ivs then mon.ivs=copy(p.ivs) end;if p.evs then mon.evs=copy(p.evs) end
  if p.ability_slot and not (def.abilities or {})[p.ability_slot] then return nil,'This species does not have the requested ability slot.' end
  local function valid(pid)
   return Stats.isShinyGen3(pid,mon.otId)==o.shiny and (p.nature==nil or gen==5 or pid%25==p.nature)
    and (p.ability_slot==nil or gen==5 or pid%2==p.ability_slot-1)
    and (p.gender==nil or gender(pid)==p.gender)
  end
  local pid=p.pid
  if pid and not valid(pid) then return nil,'PID conflicts with shiny, nature, gender or ability. Clear PID to generate a matching identity.' end
  if not pid then
   local start=rng(0,65535)
   for i=0,65535 do
    local lo=(start+i)%65536
    if o.shiny then
     local bit=require('bit');local fold=bit.bxor(mon.otId%65536,math.floor(mon.otId/65536))
     for shiny=0,7 do local candidate=bit.bxor(fold,lo,shiny)*65536+lo;if valid(candidate) then pid=candidate;break end end
    else
     local candidate=rng(0,65535)*65536+lo;if valid(candidate) then pid=candidate end
    end
    if pid then break end
   end
  end
  if not pid then return nil,'No personality matches the selected constraints for this species.' end
  mon.personality=pid
  local nature=gen==5 and (p.nature or pid%25) or pid%25
  mon.nature=((data.constants or {}).natureOrder or {})[nature+1];if gen==5 then mon.ndsNature=nature end
  mon.abilitySlot=p.ability_slot or (def.abilities and def.abilities[2] and pid%2+1 or 1)
  mon.altAbility=mon.abilitySlot==2 or nil;mon.gender=gender(pid)
  mon.metLevel=p.met_level or mon.level;mon.metLocation=p.met_location or 0
  mon.gen3Language=p.language or 2;mon.fatefulEncounter=p.fateful or nil;mon.fateful=p.fateful or nil
 else
  if p.stat_exp then mon.statExp=copy(p.stat_exp) end
  local function valid(d) return (gen==1 or Stats.isShiny(d)==o.shiny) and (not p.gender or gender(0,d)==p.gender) end
  local d=p.dvs and copy(p.dvs)
  if d and not valid(d) then return nil,'DVs conflict with the selected shiny or gender setting.' end
  if not d then
   for i=1,65536 do
    local candidate=o.shiny and {attack=({2,3,6,7,10,11,14,15})[rng(1,8)],defense=10,speed=10,special=10} or Stats.randomDVs(rng)
    if valid(candidate) then d=candidate;break end
   end
  end
  if not d then return nil,'No DVs match this species and shiny/gender combination.' end
  d.hp=d.attack%2*8+d.defense%2*4+d.speed%2*2+d.special%2;mon.dvs=d
 end
 for field,dest in pairs({held_item='heldItem',ball='ball'}) do
  if p[field] then local id,why=M.nativeKey(data.items,p[field]);if not id then return nil,why end;mon[dest]=id;if field=='held_item' then mon.item=id end end
 end
 mon.shiny=o.shiny or nil;mon.isShiny=o.shiny or nil
 return mon
end
return M
