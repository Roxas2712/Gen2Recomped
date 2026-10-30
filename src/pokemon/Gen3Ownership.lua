-- Native OT predicate factored from Gen3SummaryMenu; existing upstream rights apply.
-- Added observation glue (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The native summary's existing OT-name/ID ownership decision, shared by
-- typed battle observations. Missing historical OT fields remain unknown-own.
local M={}
function M.owns(mon,player)
 if not(mon and player)then return true end
 if mon.ot==nil and mon.otId==nil then return true end
 if mon.ot~=nil and player.name~=nil and mon.ot~=player.name then return false end
 if mon.otId~=nil and player.id~=nil and mon.otId~=player.id then return false end
 return true
end
-- Preserve a known flag or the actual encoded GBA ribbon word. An absent
-- record stays unknown; it is never replaced by a fabricated default flag.
function M.fateful(mon)
 if not mon then return nil end
 -- An authored modern flag edits bit 31; keep explicit false as an edit.
 if type(mon.modernFatefulEncounter)=='boolean'then return mon.modernFatefulEncounter end
 local word=mon.gen3Ribbons
 if word==nil then word=mon.ribbons end
 if type(word)=='number'and word==word and word%1==0 and word>=0 and word<4294967296 then
  return math.floor(word/2147483648)%2==1
 end
 if type(mon.fatefulEncounter)=='boolean'then return mon.fatefulEncounter end
 if type(mon.fateful)=='boolean'then return mon.fateful end
end
function M.ribbonWord(mon)
 local word=mon.gen3Ribbons
 if word==nil then word=mon.ribbons end
 if not(type(word)=='number'and word==word and word%1==0 and word>=0 and word<4294967296)then word=0 end
 local marked=M.fateful(mon)==true
 local high=math.floor(word/2147483648)%2==1
 if marked and not high then word=word+2147483648 end
 if not marked and high then word=word-2147483648 end
 return word,marked
end
return M
