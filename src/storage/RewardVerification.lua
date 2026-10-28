-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Regenerate only from the server-frozen issuance receipt. A copied seed in
-- a client entry alone is never sufficient evidence of a system reward.
local R={}
function R.check(issued,entry,data,version)
 if not issued then return 'not_applicable'end
 local root
 for id,def in pairs(data.pokemon)do if(def.dex or def.nationalDex or tonumber(id))==issued.canonical.dex then root=id;break end end
 if not root then return 'unverifiable'end
 local seen,queue={[root]=true},{root};local cursor=1
 while queue[cursor]do
  local def=data.pokemon[queue[cursor]];cursor=cursor+1
  for _,e in ipairs(def and def.evolutions or{})do
   local id=e.species or e.target
   if id and data.pokemon[id]and not seen[id]then seen[id]=true;queue[#queue+1]=id end
  end
 end
 if not seen[entry.mon.species]then return 'mismatch'end
 local kind=issued.origin and issued.origin.kind
 local module=kind=='retrorecomp_gift'and'src.storage.GiftReward'or kind=='retrorecomp_league'and'src.storage.LeagueEgg'or kind=='retrorecomp_wonder'and'src.storage.WonderReward'
 if not module then return 'unverifiable'end
 local ok,expected=pcall(require(module).build,issued,root,data,version)
 if not ok or not expected then return 'unverifiable'end
 local gen=require('src.core.GameVersion').generation(version)
 local encode=require('src.core.SaveSerializer').encodeExact
 local P=require('src.link.Protocol');local a,b=P.packMon(expected),P.packMon(entry.mon)
 if gen>=3 then
  if a.personality~=b.personality or encode(a.ivs)~=encode(b.ivs)or a.nature~=b.nature then return 'mismatch'end
 else if encode(a.dvs)~=encode(b.dvs)then return 'mismatch'end end
 local hatched=(expected.isEgg or issued.origin.isEgg)and not entry.mon.isEgg
 if not hatched and(a.ot~=b.ot or a.otId~=b.otId or a.secretId~=b.secretId)then return 'mismatch'end
 if entry.mon.level<expected.level then return 'mismatch'end
 return 'verified'
end
return R
