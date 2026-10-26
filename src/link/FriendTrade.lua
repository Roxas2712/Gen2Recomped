-- A confirmation is journalled before it is sent. Recovery applies only to
-- the exact recorded slot/party; divergent saves are never overwritten.
local J={DIR='bank/play-trades'}
local Auth=require('src.cloud.RetroCloud')
local Task=require('src.cloud.Task')
local S=require('src.core.SaveSerializer')
local Saves=require('src.core.SaveData')
local P=require('src.link.Protocol')
local function clone(v) return S.decode(S.encode(v)) end
local function same(a,b) return require('src.link.ArenaProof').same(a,b) end
local function valid(id)return type(id)=='string' and #id==36 and id:match('^[a-f0-9%-]+$')end
local function path(id) return J.DIR..'/'..id..'.lua' end
local function write(doc) local fs=Saves.persistenceFs();fs.createDirectory(J.DIR);return require('src.core.SaveSafety').atomicWrite(fs,path(doc.id),S.encode(doc),{decode=S.decode}) end
function J.keep(game,id)
 if not valid(id) then return nil,'Invalid friend trade session.' end
 local doc={schema=1,id=id,account=Auth.accountId(),edition=require('src.core.GameVersion').get(),slot=Saves.activeSlot(require('src.core.GameVersion').get()),before=P.packParty(game.save.party)}
 local fs=Saves.persistenceFs()
 if fs.getInfo(path(id)) then
  local prior=J.read(id)
  return prior and prior.edition==doc.edition and prior.slot==doc.slot and same(prior.before,doc.before) or nil,'This trade already has a different recovery record.'
 end
 return write(doc)
end
function J.read(id)
 if not valid(id) then return end
 local bytes=Saves.persistenceFs().read(path(id));if not bytes or #bytes>2*1024*1024 then return end
 local ok,doc=pcall(S.decode,bytes)
 if ok and type(doc)=='table' and doc.schema==1 and doc.id==id and doc.account==Auth.accountId() then return doc end
end
local function materialize(game,receipt)
 local copy={data=game.data,save=clone(game.save)}
 local mon,why=P.unpackMon(game.data,receipt.received,{strict=true});if not mon then return nil,why end
 local t=P.TradeSession.new(game.data,copy.save.party,{strict=true})
 t.myPick=receipt.slot_index;t.theirPick=1;t.theirParty={mon};t.stage='done'
 local received,evo,row=t:apply(copy);local pre=P.packParty(copy.save.party)
 if evo then require('src.pokemon.Evolution').apply(copy,received,evo,'TRADE',row) end
 return {save=copy.save,party=copy.save.party,pre=pre,after=P.packParty(copy.save.party),evolution=evo}
end
function J.prepare(game,id,receipt)
 local doc=J.read(id)
 if not doc or receipt.edition~=doc.edition or not same(receipt.before,doc.before) or not same(P.packParty(game.save.party),doc.before) then return nil,'The confirmed trade does not match this save. Its recovery record was kept.' end
 local built,why=materialize(game,receipt);if not built then return nil,why end
 doc.receipt=receipt;doc.pre=built.pre;doc.after=built.after;doc.evolution=built.evolution
 return write(doc)
end
function J.saved(game,id,evolutionDone)
 local doc=J.read(id);if not doc then return end
 if doc.evolution and not evolutionDone then return true end
 doc.after=P.packParty(game.save.party);doc.saved=true
 return write(doc)
end
function J.pending(game)
 for _,name in ipairs(Saves.persistenceFs().getDirectoryItems(J.DIR) or {}) do
  local id=name:match('^([a-f0-9%-]+)%.lua$')
  if id and #id==36 then local doc=J.read(id);if doc and (not game or doc.edition==require('src.core.GameVersion').get() and doc.slot==Saves.activeSlot(doc.edition)) then return doc end end
 end
end
function J.tick(game)
 if J.account~=Auth.accountId() then
  if J.job then J.job:cancel() end
  J.account=Auth.accountId();J.job=nil;J.next=nil;J.error=nil
 end
 local doc=J.pending(game)
 if not doc or not game or not game.save or not game.data then return false end
 if require('src.core.GameVersion').get()~=doc.edition or Saves.activeSlot(doc.edition)~=doc.slot then return false end
 -- The active link owns its own commit and animation. Recovery runs on exit.
 if game.linkSession or game.friendTradeAnimating then return false end
 if J.job then
  local r=J.job:poll();if not r then return true end;J.job=nil
  if r.kind~='done' or not r.first then J.error=tostring(r.second or r.error);J.next=os.time()+5;return true end
  if J.purpose=='ack' or J.purpose=='cancel' and not r.first.committed then Saves.persistenceFs().remove(path(doc.id));J.error=nil;return false end
  if J.purpose=='receipt' then
   local receipt=r.first.receipt
   if not receipt then J.purpose='cancel';J.job=Task.new(function()return require('src.cloud.Play').request('POST','invites/'..doc.id..'/cancel',{})end);return true end
   local current=P.packParty(game.save.party)
   if doc.saved and doc.after and same(current,doc.after) then
    J.purpose='ack';J.job=Task.new(function()return require('src.cloud.Play').request('POST','invites/'..doc.id..'/acknowledge',{})end);return true
   end
   if same(current,doc.before) or doc.pre and same(current,doc.pre) or doc.after and same(current,doc.after) then
    if not doc.receipt then local ok,why=J.prepare(game,doc.id,receipt);if not ok then J.error=why;return true end;doc=J.read(doc.id) end
    if not same(current,doc.after) then
     if same(current,doc.before) then
      local built,why=materialize(game,receipt);if not built then J.error=why;return true end;game.save.party=built.party;game.save.pokedex=built.save.pokedex;game.save.pikachuHappiness=built.save.pikachuHappiness;game.save.pikachuMood=built.save.pikachuMood;game.save.gen3Stats=built.save.gen3Stats
     elseif doc.evolution then
      local target=game.save.party[receipt.slot_index]
      local evo,row=require('src.pokemon.Evolution').pendingFor(game,target,{kind='trade'})
      if evo then require('src.pokemon.Evolution').apply(game,target,evo,'TRADE',row) end
     end
     local mon=game.save.party[receipt.slot_index]
     if game.save.pokedex then game.save.pokedex.seen[mon.species]=true;game.save.pokedex.owned[mon.species]=true end
    end
    local persisted,problem=game:writeSave();if not persisted then J.error='Trade recovery could not save: '..tostring(problem);return true end
    local ok,why=J.saved(game,doc.id,true);if not ok then J.error=why;return true end
    J.purpose='ack';J.job=Task.new(function()return require('src.cloud.Play').request('POST','invites/'..doc.id..'/acknowledge',{})end);return true
   end
   J.error='This save changed after the trade. Open the original slot to recover it; no data was overwritten.';J.next=os.time()+5;return true
  end
 end
 if os.time()<(J.next or 0) then return true end
 J.purpose='receipt';J.job=Task.new(function()return require('src.cloud.Play').request('GET','invites/'..doc.id..'/receipt')end)
 return true
end
return J
