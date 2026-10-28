-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read-only native species/dex/starter views shared by the Hoenn movies.
local M={}
function M.new(game,starterVar)
  assert(type(starterVar)=='number')
  local data,save=game.data,game.save
  local byNumber,byNational={},{}
  for id,def in pairs(data.pokemon)do
    if def.index then byNumber[def.index]={id=id,def=def}end
    if def.dex and def.dex>=1 and def.dex<=386 and def.index
      and(not byNational[def.dex]or def.index<byNational[def.dex])then byNational[def.dex]=def.index end
  end
  local function row(n)return assert(byNumber[tonumber(n)],'Unknown native credits species '..tostring(n))end
  local hostDex,player=save.pokedex or{},save.player or{}
  local session={version=require('src.core.GameVersion').get(),
    gender=(player.gender=='girl'or player.gender=='female'or player.gender==1 or player.female==true)and 1 or 0,
    dex={unownPersonality=hostDex.unownPersonality,spindaPersonality=hostDex.spindaPersonality}}
  for _,kind in ipairs{'caught','owned'}do
    local bits=hostDex[kind]or(kind=='caught'and hostDex.owned)or{}
    session.dex[kind]=setmetatable({},{__index=function(_,n)
      local r=byNumber[n];return r and(bits[r.id]==true or bits[r.id]==1)or false
    end})
  end
  local starter=(save.gen3Vars or{})[starterVar]or 0
  return session,{
    ['src.core.game3.dataset']={cache=function()return{read=function(_,path)return love.filesystem.read(path)end}end},
    ['src.core.game3.rse.init']={var=function(name)assert(name=='VAR_STARTER_MON');return starter end},
    ['src.core.game3.dex']={isCaught=function(d,n)return d.caught[n]==true or d.owned[n]==true end,
      defaultPersonality=function(d,n)
        local nat=row(n).def.dex
        return tonumber(nat==201 and d.unownPersonality or nat==327 and d.spindaPersonality)or 0
      end},
    ['src.core.game3.pokemon']={speciesFromNational=function(n)return byNational[n]end,
      national=function(n)return row(n).def.dex end,
      dexFrontPic=function(n,pid)
        local r=row(n);local path=require('src.pokemon.Sprites').path(data,r.id,'front',{
          kind='dex',mon={species=r.id,personality=pid or 0,shiny=false}})
        return path and{image=require('src.render.Assets').image(path)}or nil
      end},
  }
end
return M
