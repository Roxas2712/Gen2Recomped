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
print('Cartridge designer: '..n..' checks passed')
