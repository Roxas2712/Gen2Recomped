-- Uses the real cloud, task, storage and walker modules against loopback Laravel.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local task,started
function love.load()
 local Auth=require('src.cloud.RetroCloud')
 local endpoint=assert(os.getenv('WALKER_HTTP_URL'))
 assert(endpoint:match('^http://127%.0%.0%.1:%d+$'),'Only isolated loopback is permitted')
 Auth.API=endpoint..'/api/cloud/v1'
 assert(Auth.acceptConnection({account_id=assert(os.getenv('WALKER_HTTP_ACCOUNT')),access_token=assert(os.getenv('WALKER_HTTP_TOKEN')),email='qa@example.invalid',expires_in=3600}))
 local Policy=require('src.storage.AccountStorage');Policy.enable();assert(Policy.bind())
 task=assert(require('src.cloud.Task').new(function()
  local W=require('src.pokewalker.Walker');local C=require('src.pokewalker.WalkerCloud')
  local store=assert(Auth.open());local phase=assert(os.getenv('WALKER_HTTP_PHASE'));local checks=0
  local function check(v,m)assert(v,m);checks=checks+1 end
  if phase:match('^native%-')then
   require('src.core.GameVersion').set('ruby')
   require('src.pokewalker.WalkerArt')._roots={assert(os.getenv('NATIVE_WALKER_IMPORT'))}
  end
  if phase=='seed'then
   local st=W.load();st.watts=125;st.minigames={games={memory={best=321,plays=2}},day=1,daily={watts=25}};assert(W.save(st))
   check(C.sync(store)=='uploaded','first isolated client uploads')
  elseif phase=='advance200'or phase=='advance300'or phase=='pull'then
   local result,why=C.sync(store,true);assert(result,why)
   local st=W.load()
   check(st.minigames.games.memory.best==321,'personal record crosses profiles through HTTP')
   if phase=='pull'then check(st.watts==200,'original client resumes the second client’s updated progress')
   else
    st.watts=phase=='advance200'and 200 or 300;assert(W.save(st))
    check(C.sync(store)=='uploaded','restored client advances cloud progress')
   end
  elseif phase=='conflict'then
   local st=W.load();st.watts=250;assert(W.save(st))
   local result,why=C.sync(store)
   check(not result and why:find('both devices',1,true),'real HTTP detects conflicting offline branches')
   check(W.load().watts==250,'local conflicting balance stays unchanged')
   check(C.decode(store.read(C.PATH)).state.watts==300,'cloud conflicting balance stays unchanged')
  elseif phase=='foreign'then
   check(not store.read(C.PATH),'another account cannot read the first account’s snapshot')
   check(C.sync(store,true)=='empty','another account does not restore the first account’s walker')
  elseif phase=='revision'then
   local first=assert(Auth.open());local second=assert(Auth.open())
   local S=require('src.core.SaveSerializer');local raw=assert(first.read(C.PATH));local doc=S.decode(raw);doc.state.watts=301
   assert(second.write(C.PATH,S.encode(doc)))
   local result,why=first.write(C.PATH,raw)
   check(not result and why:find('another device',1,true),'real server enforces If-Match on competing object writes')
  elseif phase=='resolve-local'then
   local preview=assert(C.review(store));check(C.resolve(store,preview,'local')=='uploaded','real HTTP accepts explicit complete local branch')
   check(C.decode(store.read(C.PATH)).state.watts==250,'real HTTP resolution does not add conflicting balances')
  elseif phase=='resolve-cloud'then
   local preview=assert(C.review(store));check(C.resolve(store,preview,'cloud')=='restored','second real client chooses the cloud version')
   check(W.load().watts==250,'second real client receives exactly the chosen balance')
  elseif phase=='stale-choice'then
   local st=W.load();st.watts=251;assert(W.save(st));local preview=assert(C.review(store))
   st.watts=252;assert(W.save(st))
   check(not C.resolve(store,preview,'local'),'real HTTP rejects an obsolete choice')
   check(C.decode(store.read(C.PATH)).state.watts==250,'obsolete choice leaves remote bytes authoritative')
  elseif phase=='native-seed'then
   local Saves=require('src.core.SaveData');local Link=require('src.pokewalker.WalkerLink')
   local data=assert(require('src.pokewalker.WalkerDelivery').dataset('ruby'))
   local save=Saves.newGame{version='ruby',playerName='NATIVE QA',startMap='MAP_G16_N00'}
   save.boxes={{mons={require('src.pokemon.Pokemon').new(data,'TREECKO',5)}}};save.box={}
   local slot=assert(Saves.createSlot('ruby'));assert(Saves.writeSlot('ruby',slot,save))
   local entries=assert(Link.boxMons('ruby',slot));assert(Link.send(W.load(),assert(entries[1]),0))
   check(Saves.peekSlot('ruby',slot).boxes[1].mons[1]==nil,'native Pokémon leaves the original PC')
   assert(require('src.import.CloudSync').syncOne(store,'ruby',slot))
   check(C.sync(store)=='uploaded','native walk follows its actually uploaded source save')
  elseif phase=='native-receive'then
   local Saves=require('src.core.SaveData');local Link=require('src.pokewalker.WalkerLink')
   assert(require('src.import.CloudSync').restoreVersions(store,{'ruby'}));assert(C.sync(store,true))
   local st=W.load();local source=assert(st.walking).source
   check(source.version=='ruby'and Saves.peekSlot('ruby',source.slot).boxes[1].mons[1]==nil,'second native client maps the real source slot')
   assert(Link.bringHome(st,false))
   check(Saves.peekSlot('ruby',source.slot).boxes[1].mons[1].species=='TREECKO'and not W.load().walking,'second native client returns the original imported Pokémon')
   assert(require('src.import.CloudSync').syncOne(store,'ruby',source.slot))
   check(C.sync(store)=='uploaded','completed native return uploads source and walker through their normal owners')
  elseif phase=='native-resume'then
   local Saves=require('src.core.SaveData');local Link=require('src.pokewalker.WalkerLink')
   local source=assert(W.load().walking).source
   assert(require('src.import.CloudSync').restoreVersions(store,{'ruby'}))
   local fs=Saves.persistenceFs();local path='saves/ruby/'..source.slot..'.lua';local before=assert(fs.read(path))
   check(not Link.bringHome(W.load(),false)and fs.read(path)==before,'stale original client cannot return the same Pokémon twice')
   assert(C.sync(store,true));check(not W.load().walking,'original client resumes the completed remote return')
   local save=Saves.peekSlot('ruby',source.slot);local count=0
   for _,box in ipairs(save.boxes)do for _,mon in pairs(box.mons or box)do if type(mon)=='table'and mon.species then count=count+1 end end end
   check(count==1 and save.boxes[1].mons[1].species=='TREECKO','real HTTP/native source ends with exactly one original Pokémon')
  else error('Unknown isolated phase')end
  return{passed=true,checks=checks,phase=phase,scope='Real HTTP with isolated Laravel SQLite and LÖVE profiles; not production'}
 end))
 started=love.timer.getTime()
end
function love.update()
 assert(love.timer.getTime()-started<60,'HTTP scenario timed out')
 local result=task:poll();if not result then return end
 assert(result.kind=='done'and result.first,result.second or result.error)
 local file=assert(io.open(assert(os.getenv('WALKER_HTTP_REPORT')),'wb'))
 file:write(require('src.link.Json').encode(result.first));file:close()
 love.event.quit(0)
end
function love.errorhandler(err)print(tostring(err)..'\n'..debug.traceback());return function()return 1 end end
