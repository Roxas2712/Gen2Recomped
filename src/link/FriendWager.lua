-- Durable local escrow for optional friend-battle stakes. Native adventure
-- battles still run on copies; only this journal changes money/box ownership.
local W={DIR='bank/friend-wagers'}
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local function clone(v)if type(v)~='table' then return v end;return S.decode(S.encode(v))end
local function same(a,b)if a==nil or b==nil then return a==b end;return S.encode(a)==S.encode(b)end
local function hash(v)return love.data.encode('string','hex',love.data.hash('sha256',v))end
local function valid(id)return type(id)=='string' and #id==36 and id:match('^[a-f0-9%-]+$')end
local function path(id)return W.DIR..'/'..id..'.lua'end
local function save(doc)
 local fs=Saves.persistenceFs();fs.createDirectory(W.DIR)
 return require('src.core.SaveSafety').atomicWrite(fs,path(doc.id),S.encode(doc),{decode=S.decode})
end
function W.read(id)
 if not valid(id)then return nil end
 local bytes=Saves.persistenceFs().read(path(id))
 if not bytes or #bytes>2*1024*1024 then return nil end
 local doc=S.decode(bytes)
 if type(doc)=='table' and doc.schema==1 and doc.id==id and doc.account==Auth.accountId() and type(doc.offer)=='table'
  and (doc.offer.kind=='money' or doc.offer.kind=='pokemon') and type(doc.offer.playthrough)=='string' and type(doc.offer.slot)=='string'then return doc end
end
local function location(game,offer)
 if offer.kind=='money'then return game.save,'money' end
 local boxes=game.save.boxes or game.save.box and (game.save.box.boxes or {game.save.box.mons or game.save.box}) or {}
 local box=boxes[offer.box]
 return type(box)=='table' and (box.mons or box) or nil,offer.index
end
local function owns(game,offer,edition)
 return game and game.save and require('src.core.GameVersion').get()==edition
  and Saves.activeSlot(edition)==offer.slot and game.save.meta and game.save.meta.playthroughId==offer.playthrough
end
local function own(wager)
 for _,row in ipairs(wager.offers or {})do if row.account_id==Auth.accountId()then return row end end
end
function W.remember(game,wager,edition)
 if not valid(wager.id)then return nil,'Invalid wager identifier.'end
 local row=own(wager);if not row then return nil,'Choose your own stake first.'end
 local offer=clone(row.offer)
 if not owns(game,offer,edition)then return nil,'Open the original edition and save slot to reserve this stake.'end
 local old=W.read(wager.id)
 if old then
  if old.reserved and not same(old.offer,offer)then return nil,'The reserved stake cannot be changed.'end
  if same(old.offer,offer)then return old end
 end
 local before=offer.kind=='money' and offer.balance or offer.entry.mon
 local doc={schema=1,id=wager.id,account=Auth.accountId(),edition=edition,offer=offer,before=clone(before),
  post=offer.kind=='money' and offer.balance-offer.amount or nil,contract=wager.contract}
 if row.reserved then
  local target,key=location(game,offer)
  if not target or not same(target[key],doc.post)then return nil,'Sync the latest reserved save before recovering this wager on another device.'end
  doc.reserved=true;doc.proof=hash(S.encode({id=doc.id,contract=doc.contract,post=doc.post,source=doc.offer.playthrough}))
 end
 local ok,why=save(doc);return ok and doc or nil,why
end
function W.reserve(game,doc)
 if not owns(game,doc.offer,doc.edition)then return nil,'Open the original save before reserving the stake.'end
 local target,key=location(game,doc.offer);if not target then return nil,'The selected box is unavailable.'end
 local current=target[key]
 if not same(current,doc.before) and not same(current,doc.post)then return nil,'This balance or box Pokémon changed. The wager was not applied.'end
 if not same(current,doc.post)then target[key]=clone(doc.post)end
 local ok,why=game:writeSave();if not ok then return nil,'Could not persist the reservation: '..tostring(why)end
 doc.reserved=true;doc.proof=hash(S.encode({id=doc.id,contract=doc.contract,post=doc.post,source=doc.offer.playthrough}))
 return save(doc)
end
function W.apply(game,doc,receipt)
 if not owns(game,doc.offer,doc.edition) or receipt.id~=doc.id or receipt.kind~=doc.offer.kind then return nil,'This settlement belongs to another save.'end
 local target,key=location(game,doc.offer);if not target then return nil,'The original stake location is unavailable.'end
 -- A local disk reservation whose acknowledgement never reached the server
 -- is compensated from its own before/after journal, never from a prize.
 if not receipt.reserved then
  if same(target[key],doc.post)then target[key]=clone(doc.before)
  elseif not same(target[key],doc.before)then return nil,'Local stake changed; recovery was preserved.'end
  local ok,why=game:writeSave();if not ok then return nil,why end
 elseif doc.offer.kind=='money'then
  local amount=0;for _,award in ipairs(receipt.awards or {})do
   if award.kind~='money' or type(award.amount)~='number' or award.amount%1~=0 or award.amount<1 or award.amount>100000 then return nil,'Invalid wager prize.'end
   amount=amount+award.amount
  end
  local after=doc.post+amount
  if after>999999 then return nil,'The prize exceeds the native money limit.'end
  if not same(target[key],doc.post) and not same(target[key],after)then return nil,'The money balance changed; settlement was preserved.'end
  doc.payout=after;local kept,why=save(doc);if not kept then return nil,why end
  target[key]=after;local ok,err=game:writeSave();if not ok then return nil,err end
 else
  if target[key]~=nil then return nil,'The reserved box slot changed. Recover the original save first.'end
  for _,award in ipairs(receipt.awards or {})do
   if award.kind~='pokemon' or type(award.entry)~='table'then return nil,'Invalid Pokémon prize.'end
   local entry=clone(award.entry);entry.wager={id=doc.id,owner=award.owner}
   local kept,why=require('src.storage.PokemonBank').keep(entry);if not kept then return nil,why end
  end
 end
 doc.settled=true;return save(doc)
end
function W.finished(game,invite,result)
 if not invite.wager then return end
 local doc=W.read(invite.id)
 if not doc then W.error='The wager journal is missing. Its server receipt was preserved.';return end
 local winner=result.result=='win' and tonumber(Auth.accountId()) or result.result=='lose' and tonumber(invite.peer) or nil
 doc.report={status=winner and 'complete' or result.result=='draw' and 'draw' or 'aborted',winner=winner,
  turns=result.turns or 0,digest=result.digest or string.rep('0',64)}
 return save(doc)
end
function W.closed(game,invite)
 if not invite.wager then return end
 local doc=W.read(invite.id)
 if doc and not doc.report then return W.finished(game,invite,{result='aborted',turns=0})end
end
local function request(path,payload)
 return require('src.cloud.Play').request(payload and 'POST' or 'GET',path,payload)
end
local function start(kind,id,payload)
 W.purpose=kind;W.jobId=id;W.job=Task.new(function()return request('invites/'..id..'/wager'..(kind=='show' and '' or '/'..kind),payload)end)
end
function W.pending(game)
 if not Auth.signedIn() or not game then return nil end
 for _,name in ipairs(Saves.persistenceFs().getDirectoryItems(W.DIR)or {})do
  local id=name:match('^([a-f0-9%-]+)%.lua$');local doc=id and W.read(id)
  if doc and owns(game,doc.offer,doc.edition)then return doc end
 end
end
function W.tick(game)
 local account=Auth.signedIn() and Auth.accountId()or nil
 if W.account~=account then if W.job then W.job:cancel()end;W.account=account;W.job=nil;W.next=0;W.remote=nil;W.readyInvite=nil;W.blocked=nil end
 if not account or not game or not game.save or not game.data then return false end
 W.readyInvite=nil
 local doc=W.pending(game)
 if game.linkSession then return false end
 if W.job then
  local result=W.job:poll();if not result then return doc and doc.reserved or false end
  W.job=nil
  if result.kind~='done' or not result.first then W.error=tostring(result.second or result.error);W.remote=nil;W.next=love.timer.getTime()+5;return doc and doc.reserved or false end
  if W.purpose=='acknowledge' and doc and doc.id==W.jobId then Saves.persistenceFs().remove(path(doc.id));W.error=nil;W.remote=nil;W.next=0;return false end
  if result.first.wagers then
   W.remote=result.first.wagers
  elseif result.first.wager then W.remote={result.first.wager}end
 end
 if not doc then
  for _,wager in ipairs(W.remote or {})do
   local row=own(wager)
   if row and (wager.state=='reserving' or wager.state=='ready' or wager.receipt)then
    local edition=row.offer.entry and row.offer.entry.source.version or row.offer.edition
    local made,why=W.remember(game,wager,edition)
    if made then doc=made;break else W.error=why end
   end
  end
 end
 if not doc then
  if not W.job and love.timer.getTime()>=(W.next or 0)then W.next=love.timer.getTime()+5;W.purpose='list';W.jobId=nil;W.job=Task.new(function()return request('wagers')end)end
  return false
 end
 local wager
 for _,row in ipairs(W.remote or {})do if row.id==doc.id then wager=row;break end end
 if wager and wager.receipt then
  if not doc.settled then local ok,why=W.apply(game,doc,wager.receipt);if not ok then W.error=tostring(why);return true end;doc=W.read(doc.id)end
  start('acknowledge',doc.id,{});return true
 end
 if doc.report then
  if love.timer.getTime()>=(W.next or 0)then W.next=love.timer.getTime()+1;start('report',doc.id,doc.report)end
  return true
 end
 if wager and wager.state=='reserving'then
  local world=game.overworld;local top=game.stack and (game.stack.active and game.stack:active()or game.stack:top())
  if not doc.reserved and (not world or top~=world or world.transitioning or world.runner and world.runner:isRunning())then
   W.error='Return to your free overworld to reserve the agreed stake.';return false
  end
  doc.contract=wager.contract
  if not doc.reserved then local ok,why=W.reserve(game,doc);if not ok then W.error=tostring(why);return true end;doc=W.read(doc.id)end
  start('reserved',doc.id,{contract=wager.contract,proof=doc.proof});return true
 end
 if doc.reserved and wager and wager.state=='ready'then
  W.readyInvite=doc.id
  if love.timer.getTime()>=(W.next or 0)then W.next=love.timer.getTime()+1;start('show',doc.id)end
  return true
 end
 if not W.job and love.timer.getTime()>=(W.next or 0)then W.next=love.timer.getTime()+1;start('show',doc.id)end
 return doc.reserved or false
end
return W
