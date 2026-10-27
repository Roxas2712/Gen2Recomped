-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Observe the actual Hoenn dex/search owners; no second screen or save model.
local Native=require('src.compat.gen1.NativeSession')
local Modal=require('src.compat.gen1.NativeModalObservation')
local Version=require('src.core.GameVersion')
local M={}
local classes={'src.ui.Gen3RsPokedex','src.ui.Gen3Pokedex'}
local current
local function hoenn()
 local v=Version.get();return v=='emerald'or v=='ruby'or v=='sapphire'
end
local function screen()
 if not hoenn()then return end
 local game=Native.game()
 if not(game and game.stack and type(game.stack.states)=='table')then return end
 local state=Modal.find(classes);return state and not state.closed and state or nil
end
local function valid(c)
 local r=c and not c.retired and c.refs
 if not r or not r[1]or not r[2]or not r[6]then return false end
 local game,s=r[1],r[2];local G=package.loaded['src.core.Game3']
 return G and G.native(r[6])==game and Native.game()==game and Version.get()==c.edition
  and game.data==r[3]and game.save==r[4]and game.mods==r[5]and screen()==s
  and(not c.rs or type(r[7])=='table'and s.state==r[7])
end
local function release()
 if current then current.retired=true;current.refs=nil;current.view=nil;current.users={}end
 current=nil
end
local function scalarMap(value)
 if type(value)~='table'then return {}end
 local out={}
 for k,v in pairs(value)do
  if type(k)=='number'and(type(v)=='number'or type(v)=='string'or type(v)=='boolean')then out[k]=v end
 end
 return out
end
local function scalar(value)
 local t=type(value);if t=='number'or t=='string'or t=='boolean'then return value end
end
local function index(value,max)
 if type(value)=='number'and value%1==0 and value>=1 and(not max or value<=max)then return value-1 end
end
local function search(c)
 local r=c.refs
 if c.rs then
  local q=r[7].searchState;if type(q)~='table'then return end
  return{phase=scalar(q.phase),topBar=scalar(q.topBar),menuItem=scalar(q.menuItem),message=scalar(q.message),
   cursor=scalarMap(q.cursor),scroll=scalarMap(q.scroll)}
 end
 local s=Modal.find({'src.ui.Gen3DexSearch'})
 if not s or s.closed then return end
 local slot=index(s.picking,6)
 local q={phase=slot~=nil and'param'or s.pane=='topbar'and'topbar'or'menu',
  topBar=index(s.bar,3),menuItem=index(s.row,7),cursor={},scroll={}}
 if slot~=nil then
  local pick=index(s.pick);local top=s.pickTop
  if pick~=nil and type(top)=='number'and top%1==0 and top>=0 then
   q.cursor[slot],q.scroll[slot]=pick-top,top
  end
 end
 return q
end
function M.active()
 local s=screen();local game=Native.game()
 if not s or not game then release();return end
 if not valid(current)then
  release()
  local G=require('src.core.Game3');local view=G.forNative(game)
  if not view then return end
  local rs=getmetatable(s)==package.loaded['src.ui.Gen3RsPokedex']
  if rs and type(s.state)~='table'then return end
  local c={edition=Version.get(),rs=rs,users={},
   refs=setmetatable({game,s,game.data,game.save,game.mods,view,s.state},{__mode='v'})}
  c.view=setmetatable({},{__index=function(_,key)
   if key=='open'then return valid(c)end
   if not valid(c)then return end
   local r=c.refs
   if key=='edition'then return c.edition end
   if key=='searchState'then return search(c)end
   if key=='nationalEnabled'then if c.rs then return scalar(r[7].nationalEnabled)end;return not not r[4].nationalDex end
   if key=='selected'then if c.rs then return scalar(r[7].selected)end;return index(r[2].index)end
   if key=='dexMode'then if c.rs then return scalar(r[7].dexMode)end;return index(r[2].dexMode,2)end
   if c.rs and(key=='fn'or key=='state')then return scalar(r[7][key])end
  end,__newindex=function()error('native Hoenn dex observations are read-only',2)end})
  current=c
 end
 local host=package.loaded['src.mods.Runtime'];local G=package.loaded['src.core.Game3']
 local who=host and host.currentMod or G and G._callbackOwner()
 if who then current.users[who]=true end
 return current.view
end
function M.isOpen()return M.active()~=nil end
M._service={release=release,poll=function()if current and not valid(current)then release()end end,
 releaseOwner=function(_,who)
  if current and current.users[who]then current.users[who]=nil;if not next(current.users)then release()end end
 end}
require('src.core.game3.asset_stream').register(M._service)
return M
