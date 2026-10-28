-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Chrome=require('src.ui.game3.battle_chrome')
local Battle=require('src.core.game3.battle')
local V=require('src.core.GameVersion')
local original,version=package.loaded['src.core.Game'],V.get()
local function palette(seed)local out={};for i=1,16 do out[i]=(seed+i*99)%32768 end;return out end
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition);package.loaded['src.core.Game']=f.game
 local c=f.data.constants;local a,b,d=palette(1),palette(3),palette(5)
 local rs=edition=='ruby'or edition=='sapphire'
 if rs then
  c.gen3RsBattlePanel={format=1,version=edition,palette=a}
  c.gen3RsBag={format=1,version=edition,palette=b}
 else c.gen3BattleTextbox={images={},palette=a,windowPalette=b,ppPalette=d}end
 local snapshot=Chrome.manifest()
 T.same(snapshot.textboxPal,a);T.same(snapshot.windowTextPal,b);T.same(snapshot.ppTextPal,rs and b or d)
 T.eq(snapshot.native,true);T.eq(snapshot.layout,(edition=='firered'or edition=='leafgreen')and'frlg'or'rse')
 snapshot.textboxPal[1]=999;snapshot.windowTextPal[1]=999;snapshot.ppTextPal[1]=999
 T.same(Chrome.manifest().textboxPal,a);T.same(Chrome.manifest().windowTextPal,b)
 a[1]=32767;b[1]=0;d[1]=12345
 T.eq(Chrome.manifest().textboxPal[1],32767);T.eq(Chrome.manifest().windowTextPal[1],0)
 T.eq(Chrome.manifest().ppTextPal[1],rs and 0 or 12345)
 for _,bad in ipairs{-1,65536,0/0,math.huge,'0',false}do
  local saved=a[16];a[16]=bad;T.eq(Chrome.manifest().textboxPal,nil,'malformed palette is not exposed');a[16]=saved
 end
 if rs then
  c.gen3RsBattlePanel.version='emerald';c.gen3RsBag.version='emerald'
  local mixed=Chrome.manifest();T.eq(mixed.textboxPal,nil);T.eq(mixed.windowTextPal,nil);T.eq(mixed.ppTextPal,nil)
 else
  c.gen3BattleTextbox.windowPalette=palette(10);T.same(Chrome.manifest().windowTextPal,c.gen3BattleTextbox.windowPalette)
  c.gen3BattleTextbox.ppPalette=nil;T.eq(Chrome.manifest().ppTextPal,nil,'missing native PP table is not fabricated')
 end
 package.loaded['src.core.Game']={data={constants={}}}
 local empty=Chrome.manifest();T.eq(empty.textboxPal,nil);T.eq(empty.windowTextPal,nil);T.eq(empty.ppTextPal,nil)
 f.close();Battle._service.release()
end
V.set('crystal');T.eq(Chrome.manifest(),nil,'no GBA manifest bootstrapping for Gen2')
package.loaded['src.core.Game']=original;V.set(version)
T.finish('native palette manifest shapes, PP/window separation and detached edition ownership')
