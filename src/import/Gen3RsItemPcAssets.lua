-- Native PC words and authored control codes; existing RS fonts/frames suffice.
local M={}
local EXTRA={'gOtherText_Exit','gOtherText_HowManyToDeposit','gOtherText_CantStoreSomeoneItem',
  'gOtherText_NoRoomForItems','gOtherText_DepositedItems'}
function M.extract(x,load,rom)
  x:beginStage('Ruby/Sapphire original item PC')
  local S=load('src.import.gba.syms').of(x.version)
  local ir=load('src.core.game3.scripting.text_ir')
  local policy=load('src.ui.game3.rs.player_pc_policy');local labels={}
  local function read(at)
    local bytes={}
    for i=0,1023 do
      local b=rom:get(at+i);bytes[#bytes+1]=b
      if b==255 then return ir.decode(bytes,{dialect='rs'})end
    end
    error('Unterminated native RS item PC text')
  end
  for key,symbol in pairs(policy.aliases)do
    local value=read(assert(S.off(symbol)));labels[key]=value;labels[symbol]=value
  end
  for _,symbol in ipairs(EXTRA)do labels[symbol]=read(assert(S.off(symbol)))end
  local at=assert(S.off(policy.storageDescriptions))
  assert(S.count(policy.storageDescriptions,4)==4,'Native PC description count')
  for i=0,3 do
    local ptr=rom:u32(at+i*4);assert(ptr>=0x08000000 and ptr<0x0A000000,'Native PC text pointer')
    labels[policy.storageDescriptions..':'..i]=read(ptr-0x08000000)
  end
  x._constants.gen3RsItemPc={format=1,version=x.version,textIR=labels,
    source='ROM: original player PC, item storage, descriptions and deposit text'}
end
function M.valid(spec,version)
  if not((version=='ruby'or version=='sapphire')and type(spec)=='table'and spec.format==1
    and spec.version==version and type(spec.textIR)=='table')then return false end
  -- Read only its authored data here: validation also runs in the plain-Lua
  -- cache installer, without a LÖVE filesystem or a native profile session.
  local policy=require('compat.gen1-rs.reference.src.ui.game3.rs.player_pc_policy')
  for key,symbol in pairs(policy.aliases)do
    if type(spec.textIR[key])~='table'or type(spec.textIR[symbol])~='table'then return false end
  end
  for _,key in ipairs(EXTRA)do if type(spec.textIR[key])~='table'then return false end end
  for i=0,3 do if type(spec.textIR[policy.storageDescriptions..':'..i])~='table'then return false end end
  return true
end
function M.missing(version)
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,value=false,nil;if f then ok,value=pcall(f)end
  if ok and type(value)=='table'and M.valid(value.gen3RsItemPc,version)then return{}end
  return{'<rs:native-item-pc-text>'}
end
return M
