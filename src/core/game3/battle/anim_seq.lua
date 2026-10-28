-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Presentation filtering over the rows actually produced by one native action.
-- Gameplay rows, clocks and executable callbacks remain in the native queue.
local Battle=require('src.core.game3.battle')
local Boundary=require('src.compat.gen1.ScriptBoundary')
local CoroutineScopes=require('src.compat.gen1.CoroutineScopes')
local Scopes=CoroutineScopes.new()
local Call=require('src.compat.gen1.SourceCall')
local Iteration=require('src.compat.gen1.TableIteration')
local M={}
local tags=setmetatable({},{__mode='k'})
local unpack=table.unpack or unpack
local function pack(...)return {n=select('#',...),...}end
local function shallow(t)local out={};for k,v in pairs(t)do out[k]=v end;return out end
local function same(a,b)
 for k,v in pairs(a)do if b[k]~=v then return false end end
 for k,v in pairs(b)do if a[k]~=v then return false end end
 return true
end
local function valid(token)
 if token.retired then return false end
 if token.phase and token.phase.closed then token.retired=true;return false end
 if Battle._screen(token.view)~=token.screen or token.screen.queue~=token.queue
  or token.screen.game.stack:top()~=token.screen then token.retired=true;return false end
 local positions={}
 for index,row in ipairs(token.queue)do
  if positions[row]then token.retired=true;return false end
  positions[row]=index
 end
 local previous=0
 for i,row in ipairs(token.rows)do
  local index=positions[row]
  if not index or index<=previous or not same(row,token.signatures[i])then token.retired=true;return false end
  previous=index
 end
 return true
end
local function facts(_,view)
 local out={};for _,key in ipairs{'kind','id','move','attackerId','targetId','text','type'}do out[key]=view[key]end
 return out
end
local function event(token,row,tag)
 local spec={kind='native'}
 for _,kind in ipairs{'fn','ui','drain','anim','text','wait','sound','exp'}do
  if row[kind]~=nil then spec.type=kind;break end
 end
 if tag=='used'then spec.kind,spec.id,spec.text='msg','_ItemUseText001',row.text
 elseif tag=='move'then
  spec.kind,spec.move,spec.attackerId,spec.targetId='move',row.anim,row.attackerPosition,row.targetPosition
 end
 local refs=setmetatable({token},{__mode='v'})
 local view=setmetatable({},{__index=function(_,key)
  local current=refs[1];if current and valid(current)then return spec[key]end
 end,__newindex=function()error('native animation event is read-only',2)end,
 __metatable='native animation event'})
 Iteration.register(view,facts)
 return view
end
-- Called only at the actual native row constructors. No text matching.
function M._nativeMessage(row)tags[row]='used'end
function M._nativeMove(row)tags[row]='move'end
function M.isMoveUsedId(id)return id=='_ItemUseText001'end
local function request(token,meta)
 assert(valid(token),'native animation admission retired')
 assert(type(meta)=='table'and type(meta.events)=='table','native animation events required')
 local keep,previous,count={},0,0
 for key,value in pairs(meta.events)do
  assert(type(key)=='number'and key%1==0 and key>=1 and key<=#meta.events,'native animation events must be dense')
  count=count+1
 end
 assert(count==#meta.events,'native animation events must be dense')
 for _,value in ipairs(meta.events)do
  local index=token.byEvent[value]
  assert(index and index>previous,'native animation event identity/order changed')
  previous=index;keep[index]=true
 end
 local drop={}
 for index,row in ipairs(token.rows)do
  if not keep[index]then
   assert(token.removable[index],'native gameplay/presentation row cannot be removed')
   drop[row]=true
  end
 end
 return drop
end
function M.begin(meta)
 local phase=Scopes:find('sequence')
 if not phase then return false,'animation begin belongs to its native action'end
 if not phase.called then phase.drop=request(phase.value,meta);phase.called=true end
 return Boundary.invoke('battle.anim.begin')
end
function M._nativeAction(screen,row,body)
 -- This boundary observes the same native callback once. Outside a live
 -- source admission there is no presentation permission to lend.
 local view=Battle.getState()
 if Battle._screen(view)~=screen then return body()end
 local queue=screen.queue;local before={}
 for _,entry in ipairs(queue)do before[entry]=true end
 local result=pack(body())
 if Battle._screen(view)~=screen or screen.queue~=queue then return unpack(result,1,result.n)end
 local token={screen=screen,view=view,queue=queue,rows={},events={},signatures={},removable={},byEvent={}}
 for _,entry in ipairs(queue)do if not before[entry]then
  local index=#token.rows+1;token.rows[index]=entry;token.signatures[index]=shallow(entry)
  local tag=tags[entry]
  -- A tagged row acquiring any executable/gameplay payload loses its
  -- removal permission, even if another mod retains its original text.
  local removable=false
  if tag=='used'then
   removable=type(entry.text)=='string';for key in pairs(entry)do if key~='text'then removable=false end end
  elseif tag=='move'then
   removable=type(entry.anim)=='string'or type(entry.anim)=='number'
   local allowed={anim=true,attackerIsPlayer=true,attackerPosition=true,targetPosition=true,animContext=true,hit=true}
   for key in pairs(entry)do if not allowed[key]then removable=false end end
   if entry.hit then
    if type(entry.hit)~='table'then removable=false
    else for key in pairs(entry.hit)do if key~='sfx'and key~='animType'and key~='blink'then removable=false end end end
   end
  end
  token.removable[index]=removable==true
  local value=event(token,entry,removable and tag or nil);token.events[index]=value;token.byEvent[value]=index
 end end
 if #token.rows==0 then token.retired=true;return unpack(result,1,result.n)end
 local phase=Scopes:push('sequence',token);token.phase=phase
 local ok,why=pcall(function()
  return Boundary.dispatch('battle.anim.begin',function()
   assert(valid(token),'native animation admission retired');return true
  end,function()return Call.call(M,'begin',{events=shallow(token.events)})end)
 end)
 -- Commit only after every decorator returns successfully. A throwing
 -- wrapper cannot partly filter the native presentation or replay combat.
 local expired=phase.closed or CoroutineScopes.retired()
 if ok and not expired and phase.called and valid(token)then
  for i=#queue,1,-1 do if phase.drop[queue[i]]then
   if screen.moveAnimRow==queue[i]then screen.moveAnimRow=nil end
   table.remove(queue,i)
   if screen.nextInsert and i<=screen.nextInsert then screen.nextInsert=screen.nextInsert-1 end
  end end
 end
 token.retired=true;Scopes:close(phase)
 if not ok then error(why,0)end
 if expired then error('native animation phase retired while suspended',0)end
 return unpack(result,1,result.n)
end
return M
