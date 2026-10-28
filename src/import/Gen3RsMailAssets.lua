-- Stationery, authored Easy Chat word order/gates and original mail UI text.
local M={}
local ROOT='data/generated/gba/'
local TEXT={'OtherText_Read','OtherText_Read2','OtherText_Take','OtherText_Mail',
  'OtherText_Give2','gOtherText_MoveToBag','gOtherText_CancelNoTerminator',
  'gOtherText_BagFullCannotRemoveItem','gOtherText_WasGivenToHold','gOtherText_ReceivedTheThingFrom',
  'gOtherText_SendRemovedMailPrompt','gOtherText_MailTaken','gOtherText_MailWasSent',
  'gOtherText_MailboxIsFull','gOtherText_MailRemovedMessageLost','gOtherText_CantWriteMail',
  'gOtherText_AlreadyHolding','gOtherText_MailMustBeRemoved','gOtherText_PokeHoldingItemCantMail'}
function M.extract(x,base,rom,cache)
  x:beginStage('Ruby/Sapphire original mail and Easy Chat')
  local S=base('src.import.gba.syms').of(x.version)
  local V={BUILD=x.version,SYMS=S,SPECIES_NAMES=S.off('gSpeciesNames'),SPECIES_NAME_LENGTH=11,
    MOVE_NAMES=S.off('gMoveNames'),MOVE_NAME_LENGTH=12}
  local load=require('compat.gen1-rs.Loader').new(x.version,{['src.import.gba.versions']=V})
  local resources={ROOT..'easy_chat/words.lua'}
  for _,name in ipairs({'extract_mail','extract_easy_chat_ui'})do
    local reader=load('src.import.gba.rs.'..name);assert(reader.run(rom,cache,{}))
    resources[#resources+1]=ROOT..reader.SUB..'/manifest.lua'
    for _,file in ipairs(reader.FILES)do resources[#resources+1]=ROOT..reader.SUB..'/'..file end
  end
  assert(load('src.import.gba.rs.extract_easy_chat').run(rom,cache,{}).ok)
  local ir=load('src.core.game3.scripting.text_ir');local labels={}
  local function read(symbol)
    local at=assert(S.off(symbol),'Missing native RS mail text '..symbol);local bytes={}
    for i=0,1023 do local b=rom:get(at+i);bytes[#bytes+1]=b
      if b==255 then return ir.decode(bytes,{dialect='rs'})end
    end
    error('Unterminated RS mail text '..symbol)
  end
  for _,symbol in ipairs(TEXT)do labels[symbol]=read(symbol)end
  local policy=base('src.ui.game3.rs.player_pc_policy')
  for key,symbol in pairs(policy.aliases)do labels[key]=read(symbol);labels[symbol]=labels[key]end
  x._constants.gen3RsMail={format=1,version=x.version,resources=resources,textIR=labels,
    source='ROM: 12 stationery designs, both gender palettes, native nine-word Easy Chat editor and 22 word groups'}
end
function M.valid(s,v)
  if not((v=='ruby'or v=='sapphire')and type(s)=='table'and s.format==1 and s.version==v
    and type(s.resources)=='table'and #s.resources==33 and type(s.textIR)=='table')then return false end
  for _,key in ipairs(TEXT)do if type(s.textIR[key])~='table'then return false end end
  return true
end
function M.missing(version)
  local Fs=require('src.import.CacheFs')
  local function read(path)
    local raw=Fs.read(path);local f=raw and loadstring(raw);if not f then return end;setfenv(f,{})
    local ok,v=pcall(f);return ok and type(v)=='table'and v or nil
  end
  local s=(read('data/generated/constants.lua')or{}).gen3RsMail
  if not M.valid(s,version)then return{'<rs:native-mail>'}end
  local out={}
  for _,p in ipairs(s.resources)do if type(p)~='string'or p:sub(1,#ROOT)~=ROOT or not Fs.exists(p)then out[#out+1]=tostring(p)end end
  for _,sub in ipairs({'rse/mail','rse/easy_chat'})do
    local p=ROOT..sub..'/manifest.lua';local m=read(p)
    if not m or m.game~=version or m.layout~='rs'then out[#out+1]=p end
  end
  local w=read(ROOT..'easy_chat/words.lua')
  if not w or w.build~=version or w.assetLayout~='rs'or type(w.groups)~='table'then out[#out+1]='<rs:native-mail-words>'end
  return out
end
return M
