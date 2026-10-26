-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Display-only PC labels omitted by older German catalogs. Offsets refer to
-- exact, digest-validated inputs; words are decoded from that game's ROM.
-- Do not reuse standalone WITHDRAW/DEPOSIT: those label the bank as well.
local P={}
local recipes={
 red={take=31475,deposit=31487,release=136953},
 blue={take=31475,deposit=31487,release=136953},
 yellow={take=31103,deposit=31115,release=137005,print=137029},
 gold={take=58463,deposit=58473,release=927059,print=94173},
 silver={take=58461,deposit=58471,release=927059,print=94173},
 crystal={take=58500,deposit=58510,release=927070,print=93591},
}
function P.decode(rom,profile,game)
 if (profile.language or'de')~='de'then return{}end
 local r=recipes[game];if not r then return{}end
 local function text(off,n)
  assert(off>=0 and off+n<=#rom,'PC label outside validated ROM')
  local chars={};for i=off+1,off+n do chars[#chars+1]=assert(profile.charmap[tostring(rom:byte(i))],'Unknown PC label glyph')end
  return table.concat(chars)
 end
 local s={['WITHDRAW <PK><MN>']='<PK><MN> '..text(r.take,6),['DEPOSIT <PK><MN>']='<PK><MN> '..text(r.deposit,7),['RELEASE <PK><MN>']='<PK><MN> '..text(r.release,10)}
 if r.print then s['PRINT BOX']=text(r.print,7)end
 return s
end
function P.apply(strings,labels)
 for key,value in pairs(labels or{})do if strings[key]==nil then strings[key]=value end end
 -- Asian catalogs already provide the native short RELEASE action. Its
 -- qualified host spelling must use that label, not an English fallback.
 if strings['RELEASE <PK><MN>']==nil and strings.RELEASE then strings['RELEASE <PK><MN>']=strings.RELEASE end
 if strings['PRINT BOX']==nil and strings.PRINT then strings['PRINT BOX']=strings.PRINT end
 if strings['What?']==nil and strings['What? ']then strings['What?']=strings['What? ']:gsub('%s+$','')end
end
return P
