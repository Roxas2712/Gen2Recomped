-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The PC changes placed bytes. Room callbacks render them after native reload.
local Native=require('src.world.Gen2Decorations')
local Menu=require('src.ui.Menu')
local Runner=require('src.script.ScriptRunner')
local Strings=require('src.core.Strings')
local M={}
local categories={
 {'BED','bed'},{'CARPET','carpet'},{'PLANT','plant'},{'POSTER','poster'},
 {'GAME CONSOLE','console'},{'ORNAMENT','ornament'},{'BIG DOLL','bigDoll'},
}
function M.new(game,opts)
 opts=opts or{}
 local changed,finished=false,false
 local programs=Native.pool(game.data)and Native.pool(game.data).decorationPrograms
 local texts=programs and programs.texts or{}
 local function finish()
  if finished then return end;finished=true
  if opts.onDone then opts.onDone(changed)end
 end
 local function say(role,onDone,extra)
  local id=texts[role]
  if not id then if onDone then onDone()end;return end
  local r=Runner.new(game,game.overworld)
  r:run({{'show_text',id,nil,extra}}, {onDone=onDone})
  return r
 end
 local function perform(id,side)
  local row=Native.attributes(game.data,id);local action=row and Native.action(row.action)
  local state=Native.state(game.data,game.save)
  if not(state and action)or not action.put and not Native.owns(game.data,game.save,id)then return end
  local slot=action.slot or(side=='left'and 'leftOrnament'or side=='right'and 'rightOrnament')
  if not slot then return end
  local old=state[slot]or 0
  game.stringBuffers=game.stringBuffers or{}
  game.stringBuffers[3]=Native.name(game.data,old)
  game.stringBuffers[4]=Native.name(game.data,id)
  local role
  if action.put then role=old==0 and 'empty'or 'put'
  elseif old==id then role='same'
  elseif old==0 then role='setup';game.stringBuffers[3]=Native.name(game.data,id)
  else role='replace'end
  say(role,function()changed=Native.choose(game.data,game.save,id,side)or changed end)
 end
 local function select(id)
  local row=Native.attributes(game.data,id);local action=row and Native.action(row.action)
  if not action then return end
  if not action.ornament then perform(id);return end
  local selected,question
  local function close(side)
   selected=side
   if question then game.stack:pop();question:resume()
   elseif side then perform(id,side)end
  end
  local function sides()
   game.stack:push(Menu.new(game,{
    {label=Strings('RIGHT SIDE'),onSelect=function()close('right')end},
    {label=Strings('LEFT SIDE'),onSelect=function()close('left')end},
    {label=Strings('CANCEL'),onSelect=function()close()end},
   },{tx=6,ty=6,tw=14,th=8,noSound=true,onCancel=function()close()end}))
  end
  local role=action.put and 'sidePut'or 'sideSetup'
  if texts[role]then
   question=say(role,function()if selected then perform(id,selected)end end,{stay={onShown=sides}})
  else sides()end
 end
 local function category(key)
  local items,headers,seen={},{},{}
  for raw,row in pairs(Native.pool(game.data).decorations)do
   local id=tonumber(raw);local action=Native.action(row.action)
   local group=action and(action.slot or 'ornament')
   if id and id~=0 and group==key and not seen[id]then
    seen[id]=true
    if action.put then headers[#headers+1]=id
    elseif Native.owns(game.data,game.save,id)then items[#items+1]=id end
   end
  end
  table.sort(items);table.sort(headers)
  return items,headers
 end
 local rows={}
 if Native.ready(game.data)and Native.state(game.data,game.save)then
  for _,c in ipairs(categories)do
   local key=c[2];local ids=category(key)
   if #ids>0 then
    rows[#rows+1]={label=Strings(c[1]),keepOpen=true,onSelect=function()
     local owned,headers=category(key)
     if #owned==0 then say('noChoice');return end
     local items={}
     for _,id in ipairs(owned)do
      local value=id;items[#items+1]={label=Native.name(game.data,value),onSelect=function()select(value)end}
     end
     for _,id in ipairs(headers)do
      local value=id;items[#items+1]={label=Native.name(game.data,value),onSelect=function()select(value)end}
     end
     items[#items+1]={label=Native.name(game.data,0)~=''and Native.name(game.data,0)or Strings('CANCEL')}
     game.stack:push(Menu.new(game,items,{tx=0,ty=0,tw=20,maxVisible=8,noSound=true}))
    end}
   end
  end
 end
 rows[#rows+1]={label=Strings('EXIT'),onSelect=finish}
 return Menu.new(game,rows,{tx=5,ty=0,tw=15,maxVisible=8,noSound=true,onCancel=finish})
end
return M
