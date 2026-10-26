-- Server redemption is idempotent per account. Local Bank storage uses the
-- immutable entry digest, so retrying from any device keeps the same gift.
local G={}
function G.keep(receipt)
 local ok,why=require('src.storage.AccountStorage').check();if not ok then return nil,why end
 if type(receipt)~='table' or type(receipt.id)~='string' or #receipt.id~=36 or not receipt.id:match('^[a-f0-9%-]+$') then return nil,'Invalid gift receipt.' end
 if receipt.kind=='item' or receipt.kind=='event' then
  local entry,problem=require('src.storage.GiftItems').decode(receipt);if not entry then return nil,problem end
  return {id=receipt.id,title=receipt.title,kind=receipt.kind,receipt=receipt,alreadyRedeemed=receipt.already_redeemed}
 end
 local Bank=require('src.storage.PokemonBank')
 local entry,err=Bank.decode(receipt.entry,receipt.digest);if not entry then return nil,err end
 if not entry.origin or entry.origin.kind~='retrorecomp_gift' then return nil,'This receipt is not a RetroRecomped gift.' end
 local id,problem=Bank.keep(entry);if not id then return nil,problem end
 return {id=id,title=receipt.title,entry=entry,alreadyRedeemed=receipt.already_redeemed,receipt=receipt}
end
function G.redeem(code,edition)
 local ok,why=require('src.storage.AccountStorage').check();if not ok then return nil,why end
 local receipt,err=require('src.cloud.NativeAccount').request('POST','/gifts/redeem',{code=code,edition=edition},true)
 if not receipt then return nil,err end
 return G.keep(receipt)
end
return G
