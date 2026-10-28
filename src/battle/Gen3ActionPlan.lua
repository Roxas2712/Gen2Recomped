-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observations of the native turn order and its actual queue rows. This
-- ledger never executes, removes, schedules or reorders an action.
local Version=require('src.core.GameVersion')
local M={}
local function valid(b,p)
  if not p or p.retired then return false end
  if not b or b._sourceActionPlan~=p or b.result then p.retired=true;return false end
  local r=p.refs;local game=r[2]
  if r[1]~=b or not game or b.game~=game or b.data~=r[3]or game.data~=r[3]
    or game.save~=r[4]or(game.mods or false)~=r[5]or game.stack~=r[6]
    or b.queue~=r[7]or Version.get()~=p.edition or not Version.isGen3()then p.retired=true;return false end
  for _,state in ipairs(game.stack and game.stack.states or{})do if state==b then return true end end
  p.retired=true;return false
end
function M.begin(b,order)
  if not Version.isGen3()then return end
  M.retire(b)
  local game=b.game
  local p={order=order,rows={},fns={},completed={},byRow=setmetatable({},{__mode='k'}),views=setmetatable({},{__mode='k'}),edition=Version.get(),
    refs=setmetatable({b,game,b.data,game and game.save,game and(game.mods or false),game and game.stack,b.queue},{__mode='v'})}
  b._sourceActionPlan=p
  return p
end
function M.attach(b,p,row,index,nativeFn)
  if b._sourceActionPlan~=p then return false end
  assert(p.order[index],'native action does not belong to its turn')
  -- A separate native act wrapper may replace/suppress the queued body.
  -- Keep that behavior; do not mislabel another row as this native action.
  if type(row)~='table'or row.fn~=nativeFn or p.byRow[row]then M.retire(b);p.retired=true;return false end
  p.rows[index]=row;p.fns[index]=nativeFn;p.byRow[row]=index
  return true
end
function M.retire(b)
  local p=b._sourceActionPlan
  if p then p.retired=true end
  b._sourceActionPlan=nil
end
function M.run(b,item)
  local p=b._sourceActionPlan
  if not(valid(b,p)and p.byRow[item])then return item.fn()end
  local index=p.byRow[item]
  if p.completed[index]or item.fn~=p.fns[index]then M.retire(b);return item.fn()end
  -- This is the same native fn invocation. An exception must retire its
  -- observation instead of leaving a falsely executing action behind.
  p.current=item
  local ok,why=pcall(item.fn)
  p.current=nil
  if not ok then M.retire(b);error(why,0)end
  p.completed[index]=true
end
local function actionValid(b,p,index)
  if not p.completed[index]and p.rows[index].fn~=p.fns[index]then M.retire(b);return false end
  return true
end
function M.cursor(b)
  local p=b and b._sourceActionPlan
  if not valid(b,p)then return 0 end
  local index=p.byRow[p.current or b.queue[1]]
  if not index or p.completed[index]or not actionValid(b,p,index)then return 0 end
  return index
end
local function side(b,actor)
  if actor==b.player then return 'player'end
  if actor==b.enemy then return 'enemy'end
end
local function actionView(b,p,admission,index)
  local views=p.views[admission]
  if not views then views={};p.views[admission]=views end
  local old=views[index];if old then return old end
  local refs=setmetatable({b,p,admission},{__mode='v'})
  local retired=false
  local view=setmetatable({}, {
    __index=function(_,key)
      local screen,plan,current=refs[1],refs[2],refs[3]
      if retired then return nil end
      if not valid(screen,plan)or not current or current.retired or current.screen~=screen
        or not current.ids:valid()or not actionValid(screen,plan,index)then retired=true;return nil end
      local entry=plan.order[index];local action=entry and entry[3]
      if not action then return nil end
      if key=='kind'then return not action.special and action.id~=nil and'move'or'meta'end
      if key=='meta'then return not not action.special or action.id==nil or not side(screen,entry[1])or not side(screen,entry[2])end
      if key=='move'then return not action.special and action.id or nil end
      if key=='user'then return side(screen,entry[1])end
      if key=='target'then return side(screen,entry[2])end
      if key=='userId'then return entry[1]and entry[1].position end
      if key=='targetId'then return entry[2]and entry[2].position end
      if key=='order'then return index end
    end,
    __newindex=function()error('native action observation is read-only',2)end,
    __metatable='native action observation',
  })
  views[index]=view
  return view
end
function M.snapshot(b,admission)
  local p=b and b._sourceActionPlan
  if not valid(b,p)or not admission or admission.retired or admission.screen~=b or not admission.ids:valid()then return end
  local out={}
  for i=1,#p.order do
    if p.rows[i]then
      if not actionValid(b,p,i)then return nil end
      out[i]=actionView(b,p,admission,i)
    end
  end
  return out
end
return M
