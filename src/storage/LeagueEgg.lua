-- A Bank egg has a national identity even when no mounted cartridge supports it.
local E={POOL='league-eggs-v1'}
function E.origin(entry)
 local o=type(entry)=='table' and entry.origin
 return type(o)=='table' and o.kind=='retrorecomp_league' and o.pool==E.POOL and type(o.seed)=='string' and #o.seed==64 and o.seed:match('^[a-f0-9]+$')
  and type(o.shiny)=='boolean' and o.isEgg==true and type(entry.canonical)=='table' and type(entry.canonical.dex)=='number' and entry.canonical.dex%1==0 and entry.canonical.dex>=1 and entry.canonical.dex<=1025
end
function E.universal(entry)
 return E.origin(entry) and type(entry.source)=='table' and type(entry.mon)=='table' and entry.source.version=='bank' and entry.mon.species=='DEX_'..entry.canonical.dex and entry.mon.level==1 and entry.mon.isEgg==true
end
function E.build(entry,species,data,version)
 if not E.universal(entry) then return nil,'Invalid universal league egg.' end
 local gen=require('src.core.GameVersion').generation(version)
 if gen==1 then return nil,'Generation 1 has no eggs. Keep this egg in your Bank for a compatible edition.' end
 local S=require('src.core.SaveSerializer');local e=S.decode(S.encode(entry));e.source.version=version
 e.origin.kind='retrorecomp_gift';e.origin.pool='native-gifts-v1';e.origin.generation=gen
 e.origin.reward={dex=e.canonical.dex,egg=true,shiny=e.origin.shiny,level=gen>=4 and 1 or 5}
 e.mon.level=e.origin.reward.level
 return require('src.storage.GiftReward').build(e,species,data,version)
end
function E.keep(receipt)
 if type(receipt)~='table' or receipt.kind~='league_egg' then return nil,'Invalid league reward.' end
 local B=require('src.storage.PokemonBank');local e,why=B.decode(receipt.entry,receipt.digest)
 if not e or not E.universal(e) then return nil,why or 'Invalid league egg identity.' end
 return B.keep(e)
end
return E
