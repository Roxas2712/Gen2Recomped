package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local T=require('src.import.LauncherTheme')
local pal=require('src.import.RomImporter').palette()
local n=0;local function check(v,m)assert(v,m);n=n+1 end
local function equal(a,b)return a[1]==b[1] and a[2]==b[2] and a[3]==b[3]end
local original={pal.bgTop[1],pal.bgTop[2],pal.bgTop[3]};local cartridge={pal.chipRedTop[1],pal.chipRedTop[2],pal.chipRedTop[3]}
local theme,accent=T.fromOptions({launcherTheme='ember',launcherAccent='mint'})
check(theme=='rubyred' and accent==nil,'legacy combinations migrate to a coordinated edition preset')
T.apply(pal,'heartgold');local gold={pal.link[1],pal.link[2],pal.link[3]}
check(equal(pal.link,pal.playTop),'primary play actions follow the same edition accent as links')
T.apply(pal,'pureyellow');check(not equal(gold,pal.link),'edition changes distinguish gold from yellow')
check(equal(pal.chipRedTop,cartridge),'theme changes preserve original cartridge identities')
check(math.max(unpack(pal.bgGlow))<45,'the ambient glow keeps the background dark and restrained')
T.apply(pal,'rubyred','mint');check(equal(pal.link,T.ACCENTS.mint.link),'an explicit custom accent overrides a preset consistently')
T.apply(pal,false,false,false);check(equal(pal.bgTop,original),'reset restores the original palette without accumulated tint')
-- Observe the shader boundary, not its source: tint applies only to the brand
-- and returns the surrounding render state to the previous shader.
local old={};local current=old;local used
love.graphics.getShader=function()return current end
love.graphics.setShader=function(v)current=v end
love.graphics.newShader=function()return {send=function(_,key,value)used=value end}end
love.graphics.draw=function()check(current~=old,'logo draw uses the edition treatment')end
T.apply(pal,'heartgold');T.drawLogo({})
check(used and used[1]>used[3] and current==old,'gold reaches the logo while the renderer state is restored')
print('Edition themes: '..n..' checks passed')
