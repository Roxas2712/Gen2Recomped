local T={}
local function key(v) return tostring(v or ''):gsub('^MOVE_',''):upper():gsub('[^A-Z0-9]','') end
function T.prepare(game,cup,save)
 local V=require('src.core.GameVersion');local gen=V.generation(cup.edition)
 if gen>3 then return nil,'This edition does not yet have a qualified native link-battle module.' end
 if not require('src.link.Handshake').onlineAllowed(game) then return nil,'Disable gameplay mods before entering the league.' end
 if type(save.party)~='table' or #save.party~=cup.team_size then return nil,'Prepare exactly '..cup.team_size..' Pokémon in this save party.' end
 local B=require('src.storage.PokemonBank');local P=require('src.link.Protocol');local members={};local ids={};local packed={};local rebuiltParty={}
 for i,mon in ipairs(save.party) do
  if mon.isEgg or mon.egg or (tonumber(mon.eggSteps) or 0)>0 then return nil,'Eggs cannot enter a battle team.' end
  local def=game.data.pokemon[mon.species];if not def then return nil,'A party member is unavailable in this edition.' end
  local wire=P.packMon(mon);local rebuilt,why=P.unpackMon(game.data,wire,{strict=true,forceLevel=cup.level});if not rebuilt then return nil,why end
  -- Native reconstruction determines stats; battle copies start fully healed.
  packed[i]=P.packMon(rebuilt);rebuiltParty[i]=rebuilt
  local id,problem=B.deposit(mon,cup.edition,'arena','Battle team',game.data,save);if not id then return nil,problem end;ids[i]=id
  local moves={};for _,m in ipairs(packed[i].moves or {}) do moves[#moves+1]=key(m.id) end
  members[i]={dex=def.dex or def.nationalDex,moves=moves,bank_digest=id}
 end
 local store,why=require('src.cloud.RetroCloud').open();if not store then return nil,why end
 local disk=require('src.core.SaveData').persistenceFs()
 for _,id in ipairs(ids) do
  local path=B.DIRECTORY..'/'..id..'.lua';local bytes=disk.read(path)
  if not store.has(path) then local ok,problem=store.write(path,bytes);if not ok then return nil,problem end
  elseif store.read(path)~=bytes then return nil,'A cloud Bank identity conflicts with this team.' end
 end
 return {party=require('src.link.Json').encode(packed),members=members,fingerprint=require('src.link.Handshake').hello(game,'battle').fingerprint},rebuiltParty
end
return T
