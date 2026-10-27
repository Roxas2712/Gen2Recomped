package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local files,remote={},{};local options={launcherLogoCards=true,launcherCartDesigns={}}
local fs={read=function(p) return files[p] end,write=function(p,b) files[p]=b;return true end,
  getInfo=function(p) return files[p] and {size=#files[p]} end,createDirectory=function() return true end,remove=function(p) files[p]=nil;return true end}
love.filesystem=fs
love.data={hash=function(_,b) local h=5381;for i=1,#b do h=(h*33+b:byte(i))%4294967296 end;return string.rep(('%08x'):format(h),8) end,
  encode=function(_,_,b) return b end,decode=function(_,_,b) return b end}
package.loaded['src.core.SaveData']={loadOptions=function() return options end,saveOptions=function(o) options=o;return true end,persistenceFs=function() return fs end}
local allowed=true;package.loaded['src.storage.AccountStorage']={storeCheck=function() return allowed,'Account required.' end}
local calls=0;local store={kind='retro',profileScope='account:fixture',read=function(p) calls=calls+1;return remote[p] end,write=function(p,b) calls=calls+1;remote[p]=b;return true end}
local S=require('src.core.SaveSerializer');local C=require('src.storage.CartridgeCloud')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local f=assert(io.open('assets/launcher/cobblemon/delibird.png','rb'));local png=f:read('*a');f:close()
local readOnly={kind=store.kind,profileScope=store.profileScope,read=store.read,write=function()error('A design restore must never publish')end}
check(C.sync(readOnly,'download')=='absent' and next(remote)==nil,'restoring an account with no cloud design never uploads local defaults')
files['launcher/cart_art/my_label.png']=png
options.launcherOriginalCartridges=true;options.launcherOriginalCartridgesConsent=1
options.launcherCartDesigns.red={name='MY RED',shell={80,15,20},art='launcher/cart_art/my_label.png'}
check(C.sync(store)=='uploaded','explicit account sync uploads the design and its actual image')
local doc=assert(C.decode(remote[C.PATH]));local image=doc.designs.red.image
check(doc.designs.red.style.art==nil and image and image.bytes==#png,'the portable manifest has an image digest instead of a device path')
check(C.sync(store)=='current','unchanged artwork does not produce another profile revision')
files={};options={launcherLogoCards=false,launcherCartDesigns={}}
check(C.sync(readOnly,'download')=='restored','a second device restores its account collection without publishing')
check(options.launcherOriginalCartridges and options.launcherOriginalCartridgesConsent==1,'account restore retains the explicit future-artwork preference')
local restored=options.launcherCartDesigns.red
check(restored.name=='MY RED' and restored.shell[1]==80 and files[restored.art]==png and options.launcherLogoCards,
  'custom name, shell, logo preference and identical PNG pixels survive the round trip')
check(C.sync(store)=='current','the restored device shares the same sync base')
options.launcherCartDesigns.red.name='UNPUBLISHED LOCAL EDIT'
check(C.sync(readOnly,'download')=='restored' and options.launcherCartDesigns.red.name=='MY RED',
  'explicit download restores an unchanged cloud design instead of publishing the newer local edit')
check(S.decode(files['cloud_sync_cartridges_backup.lua']).designs.red.name=='UNPUBLISHED LOCAL EDIT',
  'the local edit remains recoverable after explicit download')
options.launcherCartDesigns.red.name='LOCAL EDIT';doc.designs.red.style.name='OTHER DEVICE';remote[C.PATH]=S.encode(doc)
check(not C.sync(store) and options.launcherCartDesigns.red.name=='LOCAL EDIT' and C.decode(remote[C.PATH]).designs.red.style.name=='OTHER DEVICE',
  'concurrent edits preserve both designs instead of silently overwriting either side')
check(C.sync(store,'cloud')=='restored' and options.launcherCartDesigns.red.name=='OTHER DEVICE',
  'explicit restore resolves the conflict')
check(S.decode(files['cloud_sync_cartridges_backup.lua']).designs.red.name=='LOCAL EDIT','the replaced local design remains in the account-private recovery copy')
local asset='profiles/cartridges/assets/'..image.id..'_1.lua';remote[asset]='broken';files={};options={launcherLogoCards=true,launcherCartDesigns={}}
check(not C.sync(store) and next(options.launcherCartDesigns)==nil,'an incomplete image cannot partially replace the device collection')
allowed=false;local before=calls
check(not C.sync(store) and calls==before,'anonymous or mismatched accounts cannot read or write cloud cartridge data')
check(not C.decode('return os.execute("bad")'),'remote metadata is parsed as data and cannot execute Lua')
print('Cartridge cloud: '..n..' checks passed')
