local U={}
local Play=require('src.cloud.Play')
local S=require('src.core.SaveData')
local V=require('src.core.GameVersion')
local function game(O)return O.game or require('src.core.Game')end
local function boxes(g)
 local out={}
 for _,row in ipairs(require('src.storage.PokemonBank').scan(g.save,V.get()))do
  local box,index=row.place:match('^Box (%d+) / (%d+)$')
  if box then row.box=tonumber(box);row.index=tonumber(index);out[#out+1]=row end
 end
 return out
end
function U.accept(O,doc)
 local w=doc.wager or doc.invite and doc.invite.wager
 if not w then return end
 O.wager=O.wager or {};O.wager.id=w.id;O.wager.kind=w.kind;O.wager.doc=w
 if w.state=='refunded' or w.state=='settled'then O.notice='Settlement recorded. Reserved Pokémon are delivered to the Bank; money returns to the original save.';return end
 local ok,why=require('src.link.FriendWager').remember(game(O),w,V.get())
 O.notice=ok and 'Review both exact stakes, then confirm. Nothing is removed before both players agree.' or tostring(why)
end
function U.action(O,id,job)
 local device=id:match('^wager:new:([a-f0-9%-]+)$')
 if device then O.wager={device=device,kind='money',amount=100};O.scroll=0;O.selected=1;return true end
 local invite=id:match('^wager:review:([a-f0-9%-]+)$')
 if invite then
  for _,row in ipairs((Play.read()or {}).invites or {})do if row.id==invite then O.wager={id=invite,kind=row.wager.kind,doc=row.wager,amount=100};O.scroll=0;O.selected=1;return true end end
  O.notice='Refresh this invitation first.';return true
 end
 if not O.wager then return false end
 local w=O.wager
 if id=='wager:back'then O.wager=nil;O.scroll=0;O.selected=1;return true end
 if id=='wager:type'then if not w.id then w.kind=w.kind=='money' and 'pokemon' or 'money';w.selected=nil end;return true end
 if id=='wager:amount'then local values={100,500,1000,5000,10000};local next=1;for i,n in ipairs(values)do if n==w.amount then next=i%#values+1 end end;w.amount=values[next];return true end
 local index=id:match('^wager:box:(%d+)$')
 if index then w.selected=tonumber(index);return true end
 if id=='wager:submit'then
  local g=game(O);local permitted,why=require('src.storage.AccountStorage').check();if not permitted then O.notice=tostring(why);return true end
  if not Play.context(g).available then O.notice='Return to your free overworld before choosing a stake.';return true end
  if not S.ensurePlaythroughId(g.save)then O.notice='Could not persist this playthrough identity. No stake was reserved.';return true end
  local written,err=g:writeSave();if not written then O.notice='Save your original adventure first: '..tostring(err);return true end
  local offer={kind=w.kind,playthrough=g.save.meta.playthroughId,slot=S.activeSlot(V.get())}
  if w.kind=='money'then
   offer.amount=w.amount or 100;offer.balance=g.save.money
   if type(offer.balance)~='number' or offer.balance<offer.amount then O.notice='You do not have enough in-game money for this stake.';return true end
  else
   local row=boxes(g)[w.selected or 0];if not row then O.notice='Select a Pokémon from your boxes first.';return true end
   offer.box=row.box;offer.index=row.index
   offer.entry=require('src.link.Json').encode(require('src.storage.PokemonBank').makeEntry(row.mon,V.get(),offer.slot,row.place,g.data,g.save))
  end
  local target=w.device;local known=w.id
  job(O,'wager',function()
   local id=known
   if not id then local doc,e=Play.request('POST','invites',{device=target,mode='battle',wager=offer.kind});if not doc then return nil,e end;id=doc.invite.id end
   return Play.request('POST','invites/'..id..'/wager/offer',offer)
  end)
  return true
 end
 if id=='wager:confirm' and w.id and w.doc and w.doc.contract then
  local target,contract=w.id,w.doc.contract
  job(O,'wager',function()return Play.request('POST','invites/'..target..'/wager/confirm',{contract=contract,consent=true})end);return true
 end
 if id=='wager:cancel' and w.id then
  local target=w.id;job(O,'wager',function()return Play.request('POST','invites/'..target..'/wager/cancel',{})end);return true
 end
 return id:match('^wager:')~=nil
end
local function label(offer)
 if offer.kind=='money'then return tostring(offer.amount)..' Pokédollars'end
 local mon=offer.entry and offer.entry.mon or {}
 return tostring(mon.nickname or mon.species)..' · Lv. '..tostring(mon.level)..' · Box '..tostring(offer.box)..' / '..tostring(offer.index)
end
function U.rows(O)
 local w=O.wager;local rows={{id='wager:back',label='‹ Friends'},{id='noop',label='FRIEND BATTLE · OPTIONAL STAKES',note='Both players approve both offers. Winner receives both stakes. Pokémon prizes/refunds go to the Bank. Interrupted or unresolved battles return stakes.'}}
 local doc=w.doc
 for _,row in ipairs((Play.read()or {}).invites or {})do if row.id==w.id and row.wager then doc=row.wager;w.doc=doc;break end end
 for _,row in ipairs(doc and doc.offers or {})do
  local mon=row.offer.entry and row.offer.entry.mon
  rows[#rows+1]={id='noop',label=(row.account_id==require('src.cloud.RetroCloud').accountId() and 'YOUR STAKE · ' or 'FRIEND’S STAKE · ')..label(row.offer),
   note=(row.reserved and 'RESERVED' or row.confirmed and 'CONFIRMED' or 'Awaiting confirmation')..(mon and (' · OT '..tostring(mon.ot)..' · Held item '..tostring(mon.item or mon.heldItem or 'none'))or '')}
 end
 if not doc or doc.state=='offering'then
  if not w.id then rows[#rows+1]={id='wager:type',label='Stake type',value=w.kind=='money' and 'IN-GAME MONEY' or 'BOX POKÉMON'}end
  if w.kind=='money'then rows[#rows+1]={id='wager:amount',label='Choose your stake',value=tostring(w.amount or 100)..' Pokédollars'}
  else
   for i,row in ipairs(boxes(game(O)))do rows[#rows+1]={id='wager:box:'..i,label=(w.selected==i and '✓ ' or '')..tostring(row.mon.nickname or row.mon.species)..' · Lv. '..tostring(row.mon.level),note=row.place}end
  end
  rows[#rows+1]={id='wager:submit',label='Submit / update my offer',note='Changing either offer cancels both earlier confirmations.'}
  if doc and #(doc.offers or {})==2 then rows[#rows+1]={id='wager:confirm',label='I AGREE TO THESE TWO STAKES',note='Reserve my stake and start only after my friend also agrees.'}end
 else rows[#rows+1]={id='noop',label='Wager · '..doc.state:upper(),note='Reservations are saved before the native battle opens.'}end
 if w.id then rows[#rows+1]={id='wager:cancel',label='Cancel wager & return reserved stakes'}end
 return rows
end
return U
