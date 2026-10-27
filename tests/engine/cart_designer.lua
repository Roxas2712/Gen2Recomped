package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local D=require('src.import.CartDesigner')
local H=require('src.import.LauncherHardware')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local clean=D.normalize({name='\nMY CART\t',shell={-5,999,100.9},label={10,20,30},pattern='bolt',art='../../save.lua'})
check(clean.name=='MY CART','control characters are removed from labels')
check(clean.shell[1]==0 and clean.shell[2]==255 and clean.shell[3]==100,'RGB values are bounded')
check(clean.art==nil,'art cannot point outside the dedicated artwork folder')
check(clean.pattern=='bolt','chosen emblems are retained')
check(D.normalize({pattern='code'}).pattern=='orbit','unknown emblems use the default')
check(D.normalize({shell={0/0,0,0}}).shell==nil,'nonfinite color channels are rejected')
check(D.normalize({art='launcher/cart_art/crystal_123.png'}).art~=nil,'cached PNG references are accepted')
check(#D.normalize({name=string.rep('A',100)}).name==48,'labels have a fixed storage limit')
for _,pair in ipairs({{'red','gb'},{'crystal','gbc'},{'emerald','gba'},{'heartgold','nds'}}) do
  check(H.kind(pair[1])==pair[2],'each game chooses its own handheld family')
  local w,h=H.cartSize(pair[1]);check(w>0 and h>0,'cartridge geometry has usable dimensions')
  local device=H.deviceGeometry(pair[1],500,400,1)
  check(device.slotX>=device.x and device.slotX<=device.x+device.w,'slot stays on the device')
end
local custom=D.normalize({artMode='cartridge',artFit='cover',artZoom=99,artX=-1,artY=0/0})
check(custom.artMode=='cartridge' and custom.artFit=='cover','whole cartridge photos and crop mode persist')
check(custom.artZoom==3 and custom.artX==0 and custom.artY==.5,'image adjustments are bounded and nonfinite values reset')
check(D.normalize({art='https://example.test/cart.png'}).art==nil,'artwork is never a remote download URL')
local x,y,cw,ch,sc=H.artCrop(400,200,100,100,{artFit='cover',artX=1,artY=.5})
check(x==200 and y==0 and cw==200 and ch==200 and sc==.5,'fill crops a wide photo at the chosen edge without distortion')
x,y,cw,ch,sc=H.artCrop(400,200,100,100,{artFit='contain'})
check(cw==400 and ch==200 and sc==.25,'fit preserves the complete original photo')
for _,v in ipairs({'red','crystal','emerald','heartgold'}) do
  local model=H.cartModel(v)
  check(#model.face>=8 and model.depth>0,'every cartridge has its own solid silhouette')
end
check(H.cartModel('emerald').w/H.cartModel('emerald').h>1.65,'GBA cartridges have the broad original proportions')
check(math.abs(H.cartModel('heartgold').w/H.cartModel('heartgold').h-35/33)<.02,'DS cartridges have the near-square original proportions')
check(require('src.core.SaveData').defaultOptions().launcherLogoCards==true,'brand labels are on for new preferences')
local originalImage=function() end
local liveStyle={shell={15,35,75},art='launcher/cart_art/red.png',image=originalImage,artMode='cartridge'}
local liveOptions={launcherLogoCards=true}
local frozen=H.appearance({_cartStyle=function() return liveStyle end,_settings=function() return liveOptions end},'red')
liveStyle.shell[1]=99;liveStyle.art='launcher/cart_art/changed.png';liveOptions.launcherLogoCards=false
check(frozen.design.shell[1]==15 and frozen.design.art=='launcher/cart_art/red.png' and frozen.branded,
  'insertion keeps the exact shell, image path and logo preference captured at launch')
check(frozen.design.image==originalImage,'the captured appearance reuses the decoded artwork rather than loading another design')
local Sources=require('src.import.CartridgeSources')
for _,v in ipairs({'red','blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald','platinum','heartgold','soulsilver','black','white'}) do
  local source=Sources.get(v)
  check(source and source.page:find('https://archives.bulbagarden.net/wiki/File:',1,true)==1,'each original edition links to its own cartridge file page')
end
check(Sources.get('prism')==nil and Sources.get('polishedcrystal')==nil,'ROM hacks never falsely claim an original retail cartridge')
check(Sources.get('red').page~=Sources.get('blue').page,'edition links do not silently share the wrong artwork')
check(Sources.get('red').image:find('https://pokexpert.de/api/cloud/v1/cartridges/',1,true)==1,'downloads use the operator image host rather than the source browser challenge')
for version,asset in pairs(require('src.import.CartridgeImages')) do
  local reference=Sources.get(version)
  check(reference.sha256==asset.sha256 and #asset.sha256==64 and asset.width<=2048 and asset.height<=2048 and asset.bytes<8*1024*1024,'hosted originals have bounded dimensions and a pinned fingerprint')
  check(reference.originalImage:find('https://archives.bulbagarden.net/media/upload/',1,true)==1 and reference.credit~=nil,'the original source and contributor remain attributed')
end
local D=require('src.import.CartridgeDownload')
love.data={hash=function(_,bytes) return bytes=='original' and 'digest' or 'wrong' end,encode=function(_,_,bytes) return bytes end}
check(D.verify('original',{bytes=8,sha256='digest'}),'an unchanged original passes fingerprint verification')
check(not D.verify('modified',{bytes=8,sha256='digest'}),'altered bytes are refused before decoding the cartridge image')
check(not D.verify('original-extra',{bytes=8,sha256='digest'}),'unexpected file length is refused')
check(H.cartModel('gold').family=='dmg' and H.cartModel('crystal').family=='cgb','Gold and Silver use their notched dual-compatible shell while Crystal keeps its Color-only mould')
local Bounds=require('src.import.ImageBounds')
local header='\137PNG\13\10\26\10'..string.char(0,0,0,13)..'IHDR'
check(Bounds.allowed(header..string.char(0,0,4,0,0,0,4,0),2048),'image dimensions are checked before decoding pixels')
check(not Bounds.allowed(header..string.char(0,0,255,255,0,0,255,255),2048),'small compressed images cannot request huge decoded canvases')
check(not Bounds.allowed('\255\216\255',2048),'truncated JPEG marker chains are rejected without raising')
print('Cartridge designer: '..n..' checks passed')

check(not D.start('red',true),'original downloads require a member before starting a worker')
local id='17';package.loaded['src.cloud.RetroCloud']={API='https://pokexpert.de/api/cloud/v1',signedIn=function()return true end,accountId=function()return id end,accessToken=function()return 'private-fixture-token' end}
local request
package.loaded['src.cloud.Http']={request=function(method,url,opts)request={method=method,url=url,opts=opts};return 200,'original' end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()local first,second=fn();return {kind='done',first=first,second=second}end,cancel=function()end}end}
local verify=D.verify;D.verify=function(bytes)return bytes=='original' end
local download=assert(D.start('red',true));local result=download:poll()
check(result.bytes=='original'and request.opts.sensitive and request.opts.headers.Authorization=='Bearer private-fixture-token','member artwork uses the private bearer transport')
check(request.url=='https://pokexpert.de/api/cloud/v1/cartridges/red','artwork has no unauthenticated static fallback')
local pending=assert(D.start('blue',true));id='18';check(pending:poll().kind=='error','switching accounts fences a pending image download')
D.verify=verify
print('Member artwork transport: '..n..' checks passed')
