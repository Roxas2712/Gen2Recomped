-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Real Walker/Link/journal/serializer/atomic-write code, faulted memory IO.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.modkit')
local S=require('src.core.SaveSerializer')
local Safety=require('src.core.SaveSafety')
local fs,files,failAt,mode,writes,openGame,owner
local savePath='saves/ruby/slot.lua'
local Saves={persistenceFs=function()return owner or fs end,
  slotDiskPath=function()return'/walker-transfer-test-save'end,
  slotOpenElsewhere=function()return openGame end}
function Saves.writeSlot(_,_,save)
  return Safety.atomicWrite(fs,savePath,S.encode(save),{bak=savePath..'.bak',decode=Safety.decodeAny})
end
package.loaded['src.core.SaveData']=Saves
package.loaded['src.pokewalker.WalkerCourses']={forGame=function()return{}, {name='Course'}end}
package.loaded['src.pokewalker.WalkerDelivery']={dataset=function()return{}end,apply=function(save)
  save.testItems=save.testItems or 0
  for _,item in ipairs(save.walkerInbox.items or{})do save.testItems=save.testItems+(item.count or 1)end
  save.walkerInbox={mons={},items={},returning={}};return true
end}
package.loaded['src.import.CloudSync']={hash=function(raw)
  local n=1;for i=1,#raw do n=(n*31+raw:byte(i))%2147483647 end;return tostring(n)
end}
local W=require('src.pokewalker.Walker')
local Transfer=require('src.pokewalker.WalkerTransfer')
local Link=require('src.pokewalker.WalkerLink')
local originalOpen=io.open
io.open=function(path,...)
  if path=='/walker-transfer-test-save'then
    local bytes=files[savePath];if not bytes then return end
    return{read=function()return bytes end,close=function()end}
  end
  return originalOpen(path,...)
end
local function setup(walking)
  files={};writes=0;failAt=nil;mode=nil;owner=nil;openGame=false
  fs={read=function(p)return files[p]end,getInfo=function(p)return files[p]and{type='file',size=#files[p]}end,
    createDirectory=function()return true end,remove=function(p)files[p]=nil;return true end}
  function fs.write(p,raw)
    writes=writes+1
    if writes==failAt and mode=='refuse'then return false,'full disk'end
    files[p]=raw
    if writes==failAt and mode=='crash'then error('simulated process interruption')end
    return true
  end
  local raw={species='TREECKO',level=5,nickname='Only one'}
  local save={version='ruby',boxes={{mons=walking and{}or{raw}}}}
  local st=W.newState()
  if walking then st.walking={raw=raw,species=252,name='Only one',source={version='ruby',slot='slot',box=1,index=1},steps=0}end
  files[savePath]=S.encode(save);files[W.FILE]=S.encode(st)
  W.live=nil;W.transferError=nil;st=W.reload()
  return st,{raw=raw,species=252,name='Only one',level=5,source={version='ruby',slot='slot',box=1,index=1}}
end
local function state(walking)
  local save=S.decode(files[savePath]);local st=S.decode(files[W.FILE])
  T.eq(save.boxes[1].mons[1]~=nil,not walking,'source PC has exactly its intended participant')
  T.eq(st.walking~=nil,walking,'durable walker has exactly its intended participant')
  T.eq(save.walkerTransfer,st.transferReceipt,'both durable participants have the same receipt')
  T.eq(Transfer.pending(fs),false,'completed journal cannot replay a delivery')
end
for _,returning in ipairs{false,true}do
  local st,entry=setup(returning)
  local function action(s,e)if returning then return Link.bringHome(s,false)end;return Link.send(s,e,0)end
  T.eq(action(st,entry),true,'ordinary transfer commits')
  local total=writes;state(not returning)
  for _,kind in ipairs{'refuse','crash'}do
    for boundary=1,total do
      st,entry=setup(returning);local before=S.encode(st);mode=kind;failAt=boundary
      local called,ok=pcall(action,st,entry)
      if kind=='refuse'then T.eq(called,true,'reported IO refusals do not escape')end
      if not called then ok=false end -- An abrupt pre-intent interruption is safe too.
      if not ok then
        T.eq(S.encode(st),before,'failed transfer retains complete live state')
        if Transfer.pending(fs)or files[W.FILE]~=before then T.eq(W.check(st),nil,'uncertain commit cannot be repeated by stale screen')end
      end
      failAt=nil;mode=nil
      local loaded=W.reload()
      T.eq(W.transferError,nil,'restart recovers every durable write boundary')
      if not S.decode(files[savePath]).walkerTransfer then
        T.eq(action(loaded,entry),true,'a refused intent may be safely retried')
      end
      state(not returning)
      local saved=files[savePath];local walker=files[W.FILE]
      W.reload();Transfer.recover(fs,W.FILE)
      T.eq(files[savePath],saved,'repeated recovery never duplicates or rewrites source')
      T.eq(files[W.FILE],walker,'repeated recovery never adds walker rewards')
    end
  end
end
local st,entry=setup(false)
-- Stop after durable intent, before source publication.
failAt=3;mode='refuse';T.eq(Link.send(st,entry,0),false,'source write refusal leaves recoverable intent')
failAt=nil;mode=nil
local bytes=files[savePath];local changed=S.decode(bytes);changed.player={name='Changed'};files[savePath]=S.encode(changed)
local source,walker=files[savePath],files[W.FILE]
T.eq(Transfer.recover(fs,W.FILE),nil,'foreign source changes block recovery')
T.eq(files[savePath],source,'foreign save preserved byte for byte')
T.eq(files[W.FILE],walker,'walker retained when source diverges')
files[savePath]=bytes;openGame=true
T.eq(Transfer.recover(fs,W.FILE),nil,'open source game blocks replay')
openGame=false;owner={}
T.eq(Transfer.recover(fs,W.FILE),nil,'another account cannot receive old transfer')
owner=nil;T.eq(Transfer.recover(fs,W.FILE),true,'original owner can finish recovery')
state(true)
local Economy=require('src.pokewalker.WalkerEconomy')
for _,event in ipairs{false,true}do
  local function buy(s)
    if event then return Economy.buyEvent(s,{id='qa_event',games={'ruby'},handler='qa',price=50,name='QA event'},{version='ruby',slot='slot'})end
    return Economy.buyItem(s,{name='Potion',count=1,price=50,gen=1},{version='ruby',slot='slot'})
  end
  local s=setup(false);s.watts=100;assert(W.save(s));writes=0
  T.eq(buy(s),true,'native shop purchase joins debit and destination')
  T.eq(s.watts,60,'50 W purchase retains the existing 10 W first-purchase award')
  local total=writes
  for _,kind in ipairs{'refuse','crash'}do for boundary=1,total do
    s=setup(false);s.watts=100;assert(W.save(s));writes=0;mode=kind;failAt=boundary
    local called,ok=pcall(buy,s);if not called then ok=false end
    failAt=nil;mode=nil;s=W.reload()
    T.eq(W.transferError,nil,'native purchase interruption recovers')
    local dest=S.decode(files[savePath])
    if not dest.walkerTransfer then T.eq(buy(s),true,'unstarted purchase may retry once')end
    dest=S.decode(files[savePath]);s=W.reload()
    T.eq(s.watts,60,'purchase debit and first-purchase award each settle exactly once')
    if event then T.eq(#dest.walkerEvents.pending,1,'recovered event is queued exactly once')
    else T.eq(dest.testItems,1,'recovered parcel arrives exactly once')end
    T.eq(s.transferReceipt,dest.walkerTransfer,'purchase source and debit share durable receipt')
  end end
end
st,entry=setup(false)
local edited=S.decode(files[savePath]);edited.boxes[1].mons[1].originalTrainer='Another trainer'
files[savePath]=S.encode(edited);local before=files[savePath]
T.eq(Link.send(st,entry,0),false,'same species and level cannot substitute a different Pokémon')
T.eq(files[savePath],before,'stale box selection preserves the replacement Pokémon')
st=setup(true)
edited=S.decode(files[savePath]);edited.walkerTransfer='another-device-return';files[savePath]=S.encode(edited)
source,walker=files[savePath],files[W.FILE]
T.eq(Link.bringHome(st,false),false,'stale legacy walk cannot return over a new device receipt')
T.eq(files[savePath],source,'stale cross-device return leaves source bytes untouched')
T.eq(files[W.FILE],walker,'stale cross-device walk remains recoverable')
st=setup(false);files[Transfer.FILE]='broken journal'
T.eq(Transfer.recover(fs,W.FILE),nil,'corrupt intent fails closed')
T.eq(files[Transfer.FILE],'broken journal','corrupt evidence is retained')
io.open=originalOpen
T.finish('Pokéwalker native transfers recover every write boundary without loss, duplication or stale/account writes')
