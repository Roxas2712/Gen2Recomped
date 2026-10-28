-- Legacy queries delegate to the same evolution registry used by native
-- level-ups and stones. This module does not apply or consume an evolution.
local Native=require('src.pokemon.Evolution')
local E={}
local bound,edition
function E.useRegistry(data)
  bound,edition=data,require('src.core.GameVersion').get()
end
function E.checkMon(data,mon,opts)
  opts=opts or {}
  local species,entry=Native.pendingFor({data=data,save=opts.save or {}},mon,
    {kind=opts.item and 'item' or 'levelup',item=opts.item})
  if not species then return nil end
  return entry
end
function E.markPokedex(save,id,data)
  if not data and edition==require('src.core.GameVersion').get() then data=bound end
  if data then id=require('src.core.Gen2SpeciesNames').registryId(data.pokemon,id)end
  save.pokedex=save.pokedex or {seen={},owned={}}
  save.pokedex.seen=save.pokedex.seen or {}
  save.pokedex.owned=save.pokedex.owned or {}
  save.pokedex.seen[id],save.pokedex.owned[id]=true,true
end
return E
