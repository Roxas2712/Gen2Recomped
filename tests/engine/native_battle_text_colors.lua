-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Chrome=require('src.ui.game3.battle_chrome')
local Battle=require('src.core.game3.battle')
local Font=require('src.ui.game3.frlg_font')
local NativeFont=require('src.render.Font')
local V=require('src.core.GameVersion')
local original,version=package.loaded['src.core.Game'],V.get()
local function rgb(word)
 local out={}
 for i=1,3 do local n=math.floor(word/32^(i-1))%32;out[i]=(n*8+math.floor(n/4))/255 end
 out[4]=1;return out
end
local function expect(colors,a,b)
 T.same(colors.fg,a);T.same(colors.shadow,b);T.same(colors.bg,{0,0,0,0})
 T.same({colors[1],colors[2],colors[3],colors[4]},a)
end
local begin,finish=NativeFont.beginTwoTone,NativeFont.endTwoTone
local observed
NativeFont.beginTwoTone=function(a,b)observed={a,b};return false end
for index,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.battle-source-runtime.fixture').new(edition)
 package.loaded['src.core.Game']=f.game
 local constants=f.data.constants;local palette={}
 for i=1,16 do palette[i]=((i*2131+index*1777)%32768)end
 local rs=edition=='ruby'or edition=='sapphire'
 local record={palette=palette,images={},format=1,version=edition}
 constants[rs and 'gen3RsBattlePanel'or'gen3BattleTextbox']=record
 constants.gen3BattleTextbox=constants.gen3BattleTextbox or{images={}}
 constants.gen3BattleTextbox.text={message={foreground={12,34,56},shadow={78,90,12},indices={fg=1,shadow=6}}}
 expect(Chrome.textboxColors(),{12/255,34/255,56/255,1},{78/255,90/255,12/255,1})
 for fg=0,15 do for sh=0,15 do
  local colors,second,why=Chrome.textboxColors(fg,sh)
  expect(colors,rgb(palette[fg+1]),rgb(palette[sh+1]));T.same(second,colors.shadow);T.eq(why,nil)
  T.eq(Font.draw('PAIR',0,0,{colors=colors}),Font.measure('PAIR'))
  T.same(observed,{colors.fg,colors.shadow},'the real font receives both indexed tones')
 end end
 local c=Chrome.textboxColors(1,8);c.fg[1]=999;c.shadow[1]=999;c.bg[4]=1;c[1]=999
 expect(Chrome.textboxColors(1,8),rgb(palette[2]),rgb(palette[9]))
 palette[2]=32767;expect(Chrome.textboxColors(1,8),rgb(32767),rgb(palette[9]))
 record.palette={};for i=1,16 do record.palette[i]=0 end
 expect(Chrome.textboxColors(1,8),rgb(0),rgb(0))
 record.palette[16]=nil
 local unavailable,_,why=Chrome.textboxColors(1,8)
 expect(unavailable,Font.COLOR.WHITE.fg,Font.COLOR.WHITE.shadow);T.eq(why,'native textbox palette unavailable')
 record.palette=palette
 for _,bad in ipairs{-1,16,0.5,0/0,math.huge,'1',false,{}}do
  T.raises(function()Chrome.textboxColors(bad,8)end,'invalid native textbox colour index')
  T.raises(function()Chrome.textboxColors(1,bad)end,'invalid native textbox colour index')
 end
 for _,bad in ipairs{-1,65536,0/0,math.huge,'1',false}do
  local saved=palette[16];palette[16]=bad
  T.eq(select(3,Chrome.textboxColors(1,8)),'native textbox palette unavailable');palette[16]=saved
 end
 if rs then
  record.version=edition=='ruby'and'sapphire'or'ruby'
  T.eq(select(3,Chrome.textboxColors(1,8)),'native textbox palette unavailable','edition-bound RS data')
 else
  record.palette=nil;record.text={message={foreground={12,34,56},shadow={78,90,12},indices={fg=1,shadow=8}}}
  local legacy={12/255,34/255,56/255,1};local shade={78/255,90/255,12/255,1}
  expect(Chrome.textboxColors(1,8),legacy,shade);expect(Chrome.textboxColors(),legacy,shade)
  T.eq(select(3,Chrome.textboxColors(2,8)),'native textbox palette unavailable','old role data cannot invent other indices')
 end
 package.loaded['src.core.Game']={data={constants={}}}
 T.eq(select(3,Chrome.textboxColors(1,8)),'native textbox palette unavailable','no retained prior game palette')
 f.close();Battle._service.release()
end
NativeFont.beginTwoTone,NativeFont.endTwoTone=begin,finish
V.set('crystal');package.loaded['src.core.Game']={data={constants={gen3BattleTextbox={images={},palette={}}}}}
T.eq(select(3,Chrome.textboxColors()),'native textbox palette unavailable','Gen2 cannot select a GBA palette')
package.loaded['src.core.Game']=original;V.set(version)
T.finish('native indexed battle text records, proportional font consumption and edition/data isolation')
