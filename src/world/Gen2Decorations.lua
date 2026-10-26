-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Native ownership flags, placed bytes and callback presentation are distinct.
-- Attribute/name rows come from the current cartridge, never a retail table.
local V=require('src.core.GameVersion')
local Strings=require('src.core.Strings')
local M={}
M.slots={'bed','carpet','plant','poster','console','bigDoll','leftOrnament','rightOrnament'}
local kinds={'BED','CARPET','PLANT','POSTER','CONSOLE','BIG_DOLL','DOLL'}
local slotFor={BED='bed',CARPET='carpet',PLANT='plant',POSTER='poster',CONSOLE='console',BIG_DOLL='bigDoll'}
local actions={}
for _,kind in ipairs(kinds)do
 actions[#actions+1]='SET_UP_'..kind;actions[#actions+1]='PUT_AWAY_'..kind
end
function M.actionName(n)return actions[n]end
function M.action(name)
 if type(name)~='string'then return nil end
 local kind=name:match('^SET_UP_(.+)$');local put=false
 if not kind then kind=name:match('^PUT_AWAY_(.+)$');put=true end
 if kind=='DOLL'then return{ornament=true,put=put}end
 return slotFor[kind] and {slot=slotFor[kind],put=put}or nil
end
function M.pool(data)return data and data.map_scripts end
function M.ready(data)
 local p=M.pool(data);local info=p and p.decorationInfo
 return V.generation(V.get())==2 and type(p)=='table' and type(p.decorations)=='table' and
  type(info)=='table' and info.complete==true or false
end
function M.attributes(data,id)
 if not M.ready(data)then return nil end
 local rows=M.pool(data).decorations
 return rows[tonumber(id)]or rows[tostring(id)]
end
function M.state(data,save)
 if not M.ready(data)or type(save)~='table'then return nil end
 if save.decorations==nil then
  local info=M.pool(data).decorationInfo
  if not info.defaultsComplete then return nil end
  save.decorations=require('src.mods.Merge').deepCopy(info.defaults or{})
 end
 return type(save.decorations)=='table'and save.decorations or nil
end
local names={
 [2]=Strings.source('%s BED'),[3]=Strings.source('%s CARPET'),
 [4]=Strings.source('%s POSTER'),[5]=Strings.source('%s DOLL'),[6]=Strings.source('BIG %s'),
}
function M.name(data,id)
 local row=M.attributes(data,id)
 if not row then return ''end
  local name=row.name
  if row.type>=4 then
    local info=M.pool(data).decorationInfo
    local key=info.sourceNames and info.sourceNames[id]==name and info.species and info.species[id]or name
    local mon=data.pokemon and data.pokemon[key]
    name=mon and mon.name or name
  end
  return names[row.type] and Strings(names[row.type],name)or name
end
function M.owns(data,save,id)
 local row=M.attributes(data,id);local action=row and M.action(row.action)
 return type(save)=='table' and type(save.flags)=='table' and id~=0 and action and not action.put and require('src.script.Flags').get(save,
  require('src.script.Gen2Flags').eventFlag(row.flag))or false
end
function M.give(data,save,id)
 local row=M.attributes(data,id)
 if type(save)~='table' or id==0 or not row or not M.action(row.action)or M.action(row.action).put then return false end
 save.flags=save.flags or{}
 require('src.script.Flags').set(save,require('src.script.Gen2Flags').eventFlag(row.flag));return true
end
function M.giveFlag(data,save,n)
 local info=M.pool(data)and M.pool(data).decorationInfo
 local id=info and info.gifts and info.gifts[(tonumber(n)or -1)+1]
 return id~=nil and M.give(data,save,id)or false
end
function M.choose(data,save,id,side)
 local state=M.state(data,save);local row=M.attributes(data,id)
 local action=row and M.action(row.action)
 if id==0 or not(state and action)then return false end
 if not action.put and not M.owns(data,save,id)then return false end
 local slot=action.slot
 if action.ornament then
  if side~='left'and side~='right'then return false end
  slot=side=='left'and 'leftOrnament'or 'rightOrnament'
 end
 local value=action.put and 0 or id
 local changed=(state[slot]or 0)~=value
 state[slot]=value
 if changed and action.ornament and not action.put then
  local other=side=='left'and 'rightOrnament'or 'leftOrnament'
  if state[other]==id then state[other]=0 end
 end
 return changed
end
-- These callbacks deliberately preserve the VM's current script/check vars.
function M.visibility(ctx)
 local data=ctx.game.data;local state=M.state(data,ctx.save)
 if not state then return end
  ctx.save.flags=ctx.save.flags or{}
 local C=require('src.script.Commands');local Flags=require('src.script.Gen2Flags')
 for _,binding in ipairs({{'console',0,1857},{'leftOrnament',1,1858},{'rightOrnament',2,1859},{'bigDoll',3,1860}})do
  local id=state[binding[1]]or 0;local row=M.attributes(data,id)
  if id~=0 and row then
   C.g2_variablesprite(ctx,binding[2],row.sprite);C.clear_flag(ctx,Flags.eventFlag(binding[3]))
  else C.set_flag(ctx,Flags.eventFlag(binding[3]))end
 end
end
function M.tiles(ctx)
 local data=ctx.game.data;local state=M.state(data,ctx.save)
 if not state then return end
  ctx.save.flags=ctx.save.flags or{}
 local C=require('src.script.Commands')
 local function paint(slot,x,y)
  local id=state[slot]or 0;local row=id~=0 and M.attributes(data,id)
  if row then C.replace_block(ctx,x,y,row.sprite);return row.sprite end
 end
 paint('bed',0,2);paint('plant',3,2);paint('poster',3,0)
 local carpet=paint('carpet',0,0)
 if carpet then
  C.replace_block(ctx,0,1,(carpet+1)%256);C.replace_block(ctx,1,1,(carpet+2)%256)
  C.replace_block(ctx,2,1,(carpet+1)%256)
 end
 local flag=require('src.script.Gen2Flags').eventFlag(716)
 if (state.poster or 0)~=0 then C.set_flag(ctx,flag)else C.clear_flag(ctx,flag)end
end
function M.description(data,save,kind)
 local state=M.state(data,save);local programs=M.pool(data)and M.pool(data).decorationPrograms
 if not state or type(programs)~='table'then return nil end
 if kind==0 then return programs.posters and programs.posters[state.poster or 0]or programs.null end
 if kind==3 then return programs.big end
 local slot=({[1]='leftOrnament',[2]='rightOrnament',[4]='console'})[kind]
 if slot then return programs.ornament,M.name(data,state[slot]or 0)end
end
return M
