package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local count=0
local function check(v,m) assert(v,m);count=count+1 end
local S=require('src.core.SaveSerializer')
local function clone(v) return assert(S.decode(S.encode(v))) end
-- Deterministic fingerprint seam; native SHA-256 is exercised by LOVE itself.
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(string.format('%08x',h),8) end,encode=function(_,_,v) return v end}
local function digest(v) return love.data.hash('sha256',S.encode(v)) end
local files,writes={},0
local fs={read=function(p) return files[p] end,write=function(p,b) writes=writes+1;files[p]=b;return true end,
  getInfo=function(p) return files[p] and {size=#files[p]} end,remove=function(p) files[p]=nil;return true end,createDirectory=function() return true end,
  getDirectoryItems=function(dir) local rows={};for p in pairs(files) do local n=p:match('^'..dir..'/([^/]+)$');if n then rows[#rows+1]=n end end;return rows end}
local account='1';local permitted=true
local Policy={enabled=true,scope=function() return account end,check=function() return permitted,not permitted and 'account_required' or nil end}
Policy.storeCheck=Policy.check
package.loaded['src.storage.AccountStorage']=Policy
package.loaded['src.core.SaveData']={persistenceFs=function() return fs end,activeSlot=function() return 'slot1' end}
local B=require('src.storage.PokemonBank')
local data={pokemon={BULBASAUR={dex=1}},moves={TACKLE={pp=35}},items={BERRY={name='BERRY'}},constants={}}
B.data=function() return data end
local L=require('src.storage.LuaData')
local mon={species='BULBASAUR',level=12,ot='Original',otId=2712,item='BERRY',moves={{id='TACKLE',pp=20}},kasc={moveMemory={'TACKLE'},lineage={serial=9}},extensions={provider={fateful=true}}}
local info=L.inspect(mon)
check(info.serializable and info.types.table>1 and #info.fields>4,'Lua inventory collects fields and nested types')
local cycle={};cycle.self=cycle
check(not L.inspect(cycle).serializable and not L.encode({callback=function() end}) and not L.encode(setmetatable({},{__index={}})),'cycles, closures and metatables require explicit data adapters')
check(not L.encode({n=math.huge}) and not L.encode({[math.huge]=1}) and not L.encode({value='large'},5),'non-finite values, keys and oversized data are refused')
local Shared=require('src.mods.SharedStorage')
local shared=Shared.new('KASC',fs);local other=Shared.new('OTHER',fs)
check(shared:write('legacy-bank/v1/main',{state='committed',mon=mon}),'the KASC shared namespace accepts complete Lua data')
local returned=shared:read('legacy-bank/v1/main');returned.mon.kasc.lineage.serial=10
check(shared:read('legacy-bank/v1/main').mon.kasc.lineage.serial==9 and not other:read('legacy-bank/v1/main'),'reads are detached and different mods cannot share namespaces')
check(not shared:write('../escape',{}) and not shared:read('/absolute') and not shared:write('unsafe',{callback=function() end}),'paths and executable values cannot enter shared storage')
local corrupt='mod_storage/shared/KASC/legacy-bank/v1/main.lua';local good=files[corrupt]
files[corrupt]='return invalid()';files[corrupt..'.bak']=good;local before=writes
check(not shared:read('legacy-bank/v1/main') and files[corrupt]=='return invalid()' and writes==before,'classification reads do not promote backups or mutate damaged evidence')
files[corrupt]=good
local ok,code,receipt=shared:exportPackage('example',{mon=mon})
check(ok and not code and receipt.name=='example' and shared:listPackages()[1].name=='example','named packages return a receipt and can be listed')
check(shared:exportPackage('example',{mon=mon}) and not shared:exportPackage('example',{different=true}) and shared:importPackage('example').mon.otId==2712,'named exports are immutable and identical retries are safe')
account='2';check(not shared:write('new',{}) and not shared:importPackage('example'),'a handle cannot follow a different account after sign-in changes');account='1'
local I=require('src.storage.BankInterop')
local row={vaultMonId='vault-mon-1',species='BULBASAUR',current={species='BULBASAUR',level=12,payload=clone(mon)},
  identity={otId=2712},genetics={dvs={attack=15}},training={friendship=123},progress={ribbons={}},
  evolution={history={'BULBASAUR'}},moveMemory={'TACKLE'},heldItem='BERRY',extensions={kasc=clone(mon.kasc)},
  origin={edition='gold',run='legacy-run'},transferHistory={{event='deposit'}}}
local function refreshRow(r)
  local p={};for _,k in ipairs({'vaultMonId','species','current','identity','genetics','training','progress','evolution','moveMemory','heldItem','extensions'}) do p[k]=r[k] end
  r.payloadSha256=digest(p)
end
refreshRow(row)
local item={itemId='MEGA_STONE',quantity=2,scope='kanto_only',provenance={{source='KASC'}}}
item.payloadSha256=digest({itemId=item.itemId,quantity=item.quantity,scope=item.scope,provenance=item.provenance})
local vault={kind='kanto-ascendant.legacy-bank-vault',schemaVersion=2,vaultId='vault-1',pokemon={row},items={MEGA_STONE=item},transactions={},migrationReceipts={receipt={version=1}}}
local function package(v)
  local hashes={};for _,r in ipairs(v.pokemon) do hashes[r.vaultMonId]=r.payloadSha256 end
  return {manifest={kind='kanto-ascendant.legacy-bank-package',packageVersion=1,schemaVersion=v.schemaVersion,vaultId=v.vaultId,payloadSha256=digest(v),entrySha256=hashes,itemSha256={MEGA_STONE=item.payloadSha256},containsRom=false,absolutePaths=false},payload=v}
end
local source=package(vault);local bytes=S.encode(source);before=writes
local preview=assert(I.preview(bytes))
check(writes==before and #preview.entries==1 and #preview.blocked==0,'package previews verify data without writing anything')
local entry=preview.entries[1]
check(entry.mon.otId==2712 and entry.mon.item=='BERRY' and entry.extensions.providers.kanto_ascendant.record.moveMemory[1]=='TACKLE','native identity, item and complete provider records survive adaptation')
check(S.encode(entry.mon.kasc)==S.encode(mon.kasc) and preview.items.MEGA_STONE.quantity==2,'unrecognized Lua fields and scoped item inventory are retained')
check(not I.preview(bytes:gsub('BULBASAUR','CHARMANDER')) and not I.preview('return (function() _G.INTEROP_EXECUTED=true end)()') and not _G.INTEROP_EXECUTED,'checksum changes and executable packages are rejected')
local duplicate=clone(vault);duplicate.pokemon[2]=clone(row)
check(not I.preview(S.encode(package(duplicate))),'duplicate Vault Pokémon IDs are rejected')
local sparse=clone(vault);sparse.pokemon[3]=clone(row);sparse.pokemon[1]=nil
check(not I.preview(S.encode(package(sparse))),'sparse package arrays cannot hide uninspected records')
local broken=clone(vault);broken.items.MEGA_STONE.quantity=3
check(not I.preview(S.encode(package(broken))),'item-level checksums are verified even when the outer hash is valid')
local leased=clone(vault);leased.pokemon[1].lease={transactionId='pending'}
local blocked=assert(I.preview(S.encode(package(leased))))
check(#blocked.blocked==1 and not I.commit(blocked,true),'leased KASC records cannot bypass their source transaction')
check(not I.commit(preview,false) and writes==before,'imports need explicit confirmation and blocked previews never write')
preview.entries[1].mon.nickname='Tampered preview'
local imported=assert(I.commit(preview,true));local bank=B.list()
check(#bank==1 and bank[1].mon.nickname~='Tampered preview' and files[imported.archive],'commit recomputes verified entries and retains the entire original Vault archive')
check(assert(I.commit(preview,true)).entries[1]==imported.entries[1] and #B.list()==1,'repeated imports keep stable copies instead of multiplying entries')
local api=I.facade('KASC','6.7')
local exported=assert(api:export(imported.entries[1],true));local again=assert(I.preview(S.encode(exported)))
check(again.provider=='retrorecomped' and again.entries[1].mon.kasc.lineage.serial==9,'the versioned generic Bank-copy package can be read back without losing provider Lua')
local remote={};local store={read=function(p) return remote[p] end,write=function(p,b) remote[p]=b;return true end,
  list=function(dir) local rows={};for p in pairs(remote) do local n=p:match('^'..dir..'/([^/]+)$');if n then rows[#rows+1]=n end end;return rows end}
check(I.sync(store)==1 and remote[imported.archive]==files[imported.archive],'Bank sync includes the complete immutable Legacy archive')
local originalArchive=files[imported.archive];files[imported.archive]=nil
check(I.sync(store)==1 and files[imported.archive]==originalArchive,'another device receives full Vault Lua and item provenance without reimporting Pokémon')
remote[imported.archive]='return {}'
check(not I.sync(store) and files[imported.archive]==originalArchive,'damaged remote archives cannot overwrite the local original')
check(not api:deposit({save={version='gold'},data=data},mon,false),'a mod cannot deposit without confirmation')
check(api:deposit({save={version='gold'},data=data},mon,true),'mods can explicitly deposit full native records through the public facade')
local UI=require('src.import.BankInterchangeWorkspace')
local view={ready={gold=true,red=true},_bankOverlay={bank=B.list()}}
local beforeUi=writes;local beforeBank=#B.list()
check(UI.load(view,bytes) and writes==beforeUi and view._bankOverlay.interop.lua.serializable,'native import review collects Lua information before writing anything')
UI.press(view,{action='interopCommit'})
check(writes==beforeUi and #B.list()==beforeBank,'the native import button cannot bypass its consent checkbox')
UI.press(view,{action='interopConsent'});UI.press(view,{action='interopCommit'})
check(not view._bankOverlay.interopConsent and #B.list()==beforeBank,'confirmed native imports refresh the Bank and remain retry-safe')
view._bankOverlay.inspected={entry=B.list()[1]};UI.press(view,{action='interopExport'})
check(files['bank/exports/'..view._bankOverlay.inspected.entry.id..'.lua'],'selected native Bank copies export as data-only packages')
local oldFs=love.filesystem;love.filesystem=fs;files['imports/bank/legacy.lua']=bytes
UI.choose(view)
check(view._bankOverlay.interopInbox[1]=='legacy.lua','mobile and console fallback lists explicitly chosen Bank-inbox files')
UI.press(view,{action='interopInbox',name='../escape.lua'})
check(view._bankOverlay.notice=='Invalid package name.','programmatic inbox actions cannot traverse outside the import folder')
UI.press(view,{action='interopInbox',name='legacy.lua'})
check(view._bankOverlay.interop and files['imports/bank/legacy.lua']==bytes,'reviewing a chosen inbox package preserves its source file')
love.filesystem=oldFs
if arg and arg[1] then
  -- Optional source-only contract with the installed KASC model/store. It
  -- receives synthetic records and this suite's in-memory filesystem only.
  local options={serializer=S,sha256=function(b) return love.data.hash('sha256',b) end,now=function() return 42 end,randomId=function(kind) return kind..'-synthetic' end}
  local Vault=assert(loadfile(arg[1]..'/legacy_bank_vault.lua'))()(options)
  options.vault=Vault
  local Store=assert(loadfile(arg[1]..'/legacy_bank_store.lua'))()(options)
  local realVault=Vault.newVault({vaultId='real-model-synthetic'})
  realVault.pokemon[1]=Vault.canonicalizeMon(clone(mon),{edition='gold',originRun='synthetic-run',data=data,vaultMonId='synthetic-mon'})
  assert(Vault.addItem(realVault,'MEGA_STONE',2,{edition='gold',source='synthetic'}))
  local handle=Shared.new('KASC_CONTRACT',fs);local store=assert(Store.new(handle))
  check(store:commit(realVault,{reason='synthetic contract'}) and store:load().pokemon[1].current.payload.otId==2712,'the actual KASC transaction store commits and reads through the engine shared facade')
  local receipt=assert(store:export('real-model',realVault,{source='synthetic',engineVersion='test'}))
  local realPackage=assert(handle:importPackage(receipt.name))
  local realPreview=assert(I.preview(S.encode(realPackage)))
  check(#realPreview.entries==1 and realPreview.items.MEGA_STONE.quantity==2 and realPreview.entries[1].extensions.providers.kanto_ascendant.record.moveMemory,'packages produced by the actual KASC Vault retain its native schema, memory and item checksums')
  check(store:previewImport(receipt.name,Vault.newVault({vaultId='destination'})),'the KASC store can read back its package through the same facade')
end
account='2';check(not api:export(imported.entries[1],true),'Bank handles cannot leak records across account switches');account='1'
permitted=false;check(not Shared.new('KASC',fs):read('legacy-bank/v1/main') and not I.commit(preview,true),'unverified accounts cannot access shared Bank storage or import copies')
print('Lua and Bank interchange: '..count..' checks passed')
