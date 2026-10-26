-- Item/event receipts stay in the account inbox. Delivery writes a new save
-- slot, including a claim ledger; the selected original remains recoverable.
local M={}
local S=require('src.core.SaveSerializer')
local function clone(v) return S.decode(S.encode(v)) end
function M.decode(receipt)
 if type(receipt)~='table' or receipt.kind~='item' and receipt.kind~='event' or type(receipt.entry)~='string' then return nil,'Invalid item receipt.' end
 local B=require('src.storage.PokemonBank');local entry,why=B.decode(receipt.entry,receipt.digest)
 if not entry then return nil,why end
 if not entry.origin or entry.origin.kind~='retrorecomp_gift' or not entry.origin.reward or entry.origin.reward.kind~=receipt.kind
  or entry.source.version~=receipt.edition then return nil,'The gift receipt does not match its edition.' end
 return entry
end
function M.apply(receipt,draft,data,version)
 local entry,why=M.decode(receipt);if not entry then return nil,why end
 if version~=entry.source.version then return nil,'Receive this prize in its tournament edition.' end
 local reward=entry.origin.reward
 draft.retroGiftClaims=draft.retroGiftClaims or {}
 if draft.retroGiftClaims[receipt.id] then return nil,'This save already received this gift.' end
 if reward.kind=='event' then
  local Ev=require('src.pokewalker.WalkerEvents');local ev=Ev.get(reward.preset);local valid=false
  for _,v in ipairs(ev and ev.games or {}) do if v==version then valid=true end end
  if not valid or ev.kind~='key' then return nil,'The event is unavailable in this edition.' end
  local ok,problem=Ev.deliverGift(draft,data,ev.id,version);if not ok then return nil,problem end
 else
  local id,problem=require('src.storage.GiftPokemon').nativeKey(data.items,reward.item)
  if not id then return nil,problem end
  local quantity=reward.quantity
  if type(quantity)~='number' or quantity%1~=0 or quantity<1 or quantity>99 then return nil,'Invalid gift quantity.' end
  draft.inventory=draft.inventory or {}
  local ok=require('src.inventory.Bag').add(draft,id,quantity,data)
  if not ok then return nil,'The bag cannot hold this gift. No save was changed.' end
 end
 draft.retroGiftClaims[receipt.id]=receipt.digest
 return true
end
function M.deliver(receipt,version,slot,data)
 local permitted,why=require('src.storage.AccountStorage').check();if not permitted then return nil,why end
 local B=require('src.storage.PokemonBank');data=data or B.data(version)
 if not data then return nil,'Import this edition before receiving the prize.' end
 local save,problem=B.readSave(version,slot);if not save then return nil,problem end
 local draft=clone(save);local ok,err=M.apply(receipt,draft,data,version);if not ok then return nil,err end
 return B.commitDraft(version,slot,draft)
end
return M
