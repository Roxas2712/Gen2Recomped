-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Keep gift identities at the script boundary where they become save data.
-- Calls the installed host handlers; no engine implementation is duplicated.
local G={}
local function field(rule,name,original)
 local r=rule and rule[name]
 return type(r)=='table'and(type(r.to)=='string'and r.to or r.from)or type(r)=='string'and r or original
end
local english={scriptGifts={{nickname={from='KENYA',to='KENYA'},otName={from='RANDY',to='RANDY'}}},shuckle={nickname={from='SHUCKIE',to='SHUCKIE'},otName={from='MANIA',to='MANIA'}},oddEgg={nickname={from='EGG',to='EGG'},otName={from='ODD',to='ODD'}}}
-- Associate the retail trainer arm with its lowered row, keeping unknown or
-- ambiguous custom gifts unchanged. Source labels survive VM lowering.
local giftScripts=setmetatable({},{__mode='k'})
function G.decorate(rows,pool)
 if not rows or not pool or not pool.scripts then return rows end
 if pool.source and pool.source~='RomExtractorGen2' then return rows end
 local target=giftScripts[pool.scripts]
 if target==nil then
  local count=0;target=false
  for label,commands in pairs(pool.scripts)do for _,ir in ipairs(commands)do
   if ir[1]=='givepoke'and ir[2]==21 and ir[3]==10 and ir[4]==0 and ir[5]==1 then count=count+1;target=label end
  end end
  if count~=1 then target=false end;giftScripts[pool.scripts]=target
 end
 local out,current,position={},nil,0
 for i,row in ipairs(rows)do
  local copy={};for k,v in pairs(row)do copy[k]=v end;out[i]=copy
  if row[1]=='label'and pool.scripts[row[2]]then current=row[2];position=0 end
  if row[1]=='g2_give_poke'and current then
   local gifts={};for _,ir in ipairs(pool.scripts[current])do if ir[1]=='givepoke'then gifts[#gifts+1]=ir end end
   position=position+1;local ir=gifts[position]
   if current==target and ir and ir[2]==row[2]and ir[3]==row[3]and ir[4]==row[4]and ir[5]==1 and ir[2]==21 and ir[3]==10 and ir[4]==0 then
    copy.ulaNamedGift=1
   end
  end
 end
 return out
end
local function mons(save)
 local set={}
 local function add(list)for _,m in ipairs(list or{})do if type(m)=='table'and m.species then set[m]=true end end end
 add(save.party);for _,box in ipairs(save.boxes or{})do add(box)end
 return set
end
function G.newMon(save,before)
 local found
 for m in pairs(mons(save))do if not before[m]then if found then return nil end;found=m end end
 return found
end
function G.give(next,ctx,op,args,rule,kind)
 local before=mons(ctx.save)
 local previous=ctx.ulaNamedGift
 if kind=='named'then ctx.ulaNamedGift=rule end
 local ok,result=pcall(next,ctx,op,args);ctx.ulaNamedGift=previous
 if not ok then error(result,0)end
 local mon=G.newMon(ctx.save,before)
 if not mon then return result end
 if kind=='shuckle'and(mon.species~='SPECIES_213'or mon.nickname~='SHUCKIE'or mon.ot~='MANIA'or mon.otId~=0x0206)then return result end
 if kind=='oddEgg'and(not mon.isEgg or mon.nickname~='EGG')then return result end
 mon.nickname=field(rule,'nickname',mon.nickname)
 local ot=field(rule,'otName',mon.ot);mon.ot=ot;mon.otName=ot
 if kind=='named'then mon.traded=true end
 return result
end
-- Normalize only during the host's post-selection recognition check. The
-- original OT is restored even on an error or a refused return. Input, party
-- selection, health/happiness checks and removal remain with the host.
function G.returnMon(next,ctx,op,args,known)
 local runner=ctx.runner;if not runner then return next(ctx,op,args)end
 local restored={};local proxy=setmetatable({},{__index=runner})
 proxy.resume=function(_,...)return runner:resume(...)end
 proxy.yield=function(_,...)
  runner:yield(...)
  for _,mon in ipairs(ctx.save.party or{})do
   if mon.species=='SPECIES_213'and mon.otId==0x0206 and mon.ot~='MANIA'and known[mon.ot]then
    restored[#restored+1]={mon,mon.ot};mon.ot='MANIA'
   end
  end
 end
 local call={};for k,v in pairs(ctx)do call[k]=v end;call.runner=proxy
 local ok,result=pcall(next,call,op,args)
 for _,row in ipairs(restored)do row[1].ot=row[2]end
 ctx.g2Var,ctx.lastCheck=call.g2Var,call.lastCheck
 if not ok then error(result,0)end
 return result
end
function G.readRules(mod,own,entry)
 local info=mod.imports:info(entry.sourceId or entry.id);if not info then return nil end
 local p=own(entry.profile);local has=false
 for _,cat in ipairs(p.catalogs or{})do if cat=='mon_names.lua'then has=true end end
 if not has then return nil end
 assert(p.sha1==info.sha1 and p.md5==info.md5 and p.size==info.size,'Gift source/profile mismatch')
 local profile={};for k,v in pairs(p)do profile[k]=v end;profile.catalogs={'mon_names.lua'}
 local function only(path)if path==entry.root..'assets.lua'then return{}end;return own(path)end
 local bytes=assert(mod.imports:read(entry.sourceId or entry.id,0,info.size))
 local result=own('gb/compile.lua')(bytes,profile,entry.root,only,{Rom=own('@host/lz3.lua')})
 return assert(require('src.core.SaveSerializer').decode(result.files['lang/mon_names.lua']))
end
function G.install(mod,own,version,live)
 local VM=require('src.script.Gen2ScriptVM');local state=VM.__ulaGiftIdentities
 if not state then
  state={compile=VM.compile};VM.__ulaGiftIdentities=state
  VM.compile=function(data,entry)
   local rows=state.compile(data,entry)
   if not(state.live and state.live())then return rows end
   return G.decorate(rows,VM.store(data))
  end
 end
 state.live=live
 local known={MANIA=true,GABRIELE=true,['MANÍA']=true,MATTIA=true}
 local rules=english
 local function remember(c)
  local ot=c and c.shuckle and field(c.shuckle,'otName')
  if type(ot)=='string'and ot~=''then known[ot]=true end
 end
 -- Cold English boots also recognize saved native names when the matching
 -- source remains imported. Decode only the small identity catalog.
 for _,entry in ipairs(own('catalog.lua'))do if entry.game==version and entry.generation==2 then
  local c=G.readRules(mod,own,entry);remember(c)
 end end
 mod.events:on('pokemon.before_give',function(gift)
  local rule=live()and gift.ctx and gift.ctx.ulaNamedGift
  if rule then gift.nickname=field(rule,'nickname')end
 end)
 mod.hooks:wrap('script.command',function(next,ctx,op,args)
  if not live()then return next(ctx,op,args)end
  if op=='g2_give_shuckle'then return G.give(next,ctx,op,args,rules.shuckle or english.shuckle,'shuckle')end
  if op=='g2_give_odd_egg'then return G.give(next,ctx,op,args,rules.oddEgg or english.oddEgg,'oddEgg')end
  if op=='g2_return_shuckie'then return G.returnMon(next,ctx,op,args,known)end
  local row=ctx.script and ctx.script[ctx.pc or 0]
  if op=='g2_give_poke'and row and row.ulaNamedGift then
   local rule=(rules.scriptGifts or{})[row.ulaNamedGift]or english.scriptGifts[1]
   return G.give(next,ctx,op,args,rule,'named')
  end
  return next(ctx,op,args)
 end)
 return {set=function(_,catalog)rules=catalog or english;remember(catalog)end}
end
return G
