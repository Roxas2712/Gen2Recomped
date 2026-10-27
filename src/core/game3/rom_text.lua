-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read the current native cache. Returned IR is detached; no game, ROM reader,
-- translation catalogue or retired dataset is retained by this module.
local Native=require('src.compat.gen1.NativeSession')
local Version=require('src.core.GameVersion')
local Copy=require('src.mods.Merge').deepCopy
local M={}
local function read(key)
 local game=Native.game();local data=game and game.data
 if not data or type(key)~='string'then return nil end
 local catalog=data.text_pointers and data.text_pointers.namedIR
 if catalog and(type(catalog)~='table'or catalog.schema~=1
   or type(catalog.named)~='table'or type(catalog.records)~='table'or catalog.edition~=Version.get()
   or catalog.romSha1~=Version.info().sha1)then return nil,nil,game,true end
 local prose=data._romTextGeneration==3 and data.romText
 if prose and(prose[key]~=nil or data._romTextTouched and data._romTextTouched[key])then
  return prose[key],nil,game,prose[key]==nil
 end
 local id=catalog and catalog.named[key]or key
 local row=catalog and catalog.records[id]
 local text=data.text or{}
 local value=text[key]
 if key~=id and value~=nil then return value,nil,game end
 value=text[id]
 if row then
  if value~=row.nativePlain then return value,nil,game,value==nil end
  return row.plain,row.ir,game
 end
 return value,nil,game
end
local function translated(value,game)
 if type(value)~='string'then return nil end
 local direct=game.data.strings and game.data.strings[value]
 if type(direct)=='string'then return direct end
 local service=package.loaded['src.translation.Service']
 return service and service.lookup(value)or value
end
-- Registry edits have string semantics. Recover their explicit line/page/tag
-- structure without inventing absent cartridge formatting operands.
local function stringIR(value)
 local out,pending={},{}
 local function flush()
  if #pending>0 then out[#out+1]={t='text',s=table.concat(pending)};pending={}end
 end
 local at=1
 while at<=#value do
  local c=value:sub(at,at);local kind=({['\n']='nl',['\v']='scroll',['\f']='para'})[c]
  if kind then flush();out[#out+1]={t=kind};at=at+1
  elseif c=='{'then
   local token=value:match('^%b{}',at)
   if token then flush();out[#out+1]={t='tag',tag=token};at=at+#token
   else pending[#pending+1]=c;at=at+1 end
  else pending[#pending+1]=c;at=at+1 end
 end
 flush();out[#out+1]={t='eos'};return out
end
local function menuIR(game)
 local menu=game and game.data.constants and game.data.constants.gen3BattleMenu
 if not(menu and menu.rows and menu.rows[1]and menu.rows[2]and menu.columnX)then return end
 local out={}
 for y=1,2 do
  for x=1,2 do
   if type(menu.rows[y][x])~='string'then return end
   out[#out+1]={t='text',s=menu.rows[y][x]}
   if x==1 then out[#out+1]={t='ext',cmd=19,args={menu.columnX}}end
  end
  if y==1 then out[#out+1]={t='nl'}end
 end
 out[#out+1]={t='eos'};return out
end
function M.has(key)
 local text,_,_,removed=read(key)
 if removed then return false end
 if text~=nil then return type(text)=='string'end
 local game=Native.game()
 return key=='gText_BattleMenu'and menuIR(game)~=nil or false
end
function M.ir(key)
 local value,nodes,game,removed=read(key)
 if key=='gText_BattleMenu'and game and not removed and(nodes or value==nil)then
  local menu=menuIR(game);if menu then return menu end
 end
 assert(type(value)=='string','native ROM text is unavailable: '..tostring(key))
 local current=translated(value,game)
 if nodes and current==value then return Copy(nodes)end
 return stringIR(current)
end
function M.plain(key,fill)
 local value,_,game=read(key)
 assert(type(value)=='string','native ROM text is unavailable: '..tostring(key))
 value=translated(value,game);fill=fill or{};assert(type(fill)=='table','native text fill must be a table')
 local player=game.save and game.save.player or{}
 return(value:gsub('%b{}',function(token)
  local key=token:sub(2,-2)
  local found=fill[key]
  if found==nil then found=fill[token]end
  if found==nil and key=='PLAYER'then found=fill.playerName or player.name end
  if found==nil and key=='RIVAL'then found=fill.rivalName or player.rival end
  local slot=key:match('^VAR([123])$')
  if found==nil and slot and fill.stringVars then found=fill.stringVars[tonumber(slot)]end
  return found==nil and token or tostring(found)
 end))
end
function M.key(label,index)
 assert(type(label)=='string'and type(index)=='number'and index>=0 and index%1==0,'invalid native text table index')
 return label..'['..index..']'
end
function M.at(label,index,fill)return M.plain(M.key(label,index),fill)end
M.box=M.plain
return M
