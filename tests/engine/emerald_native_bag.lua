-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local A=require('src.import.Gen3EmeraldBagAssets')
local View=require('src.ui.Gen3EmeraldBagView');local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter');local V=require('src.core.GameVersion')
local oldV,oldRead,oldGraphics,oldLoad=V.get(),Fs.read,love.graphics,love.filesystem.load
love.filesystem.load=function(path)return loadfile(path)end
local spec={format=1,version='emerald',manifest=A.ROOT..'manifest.lua',resources={}}
for _,name in ipairs(A.files)do spec.resources[#spec.resources+1]=A.ROOT..name end
for _,name in ipairs(A.fonts)do spec.resources[#spec.resources+1]=A.FONTS..name end
T.eq(A.valid(spec,'emerald'),true)
for i,path in ipairs(spec.resources)do
 spec.resources[i]='foreign/'..path;T.eq(A.valid(spec,'emerald'),false);spec.resources[i]=path
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen','gold'}do
 T.eq(A.valid(spec,version),false);T.eq(#A.missing(version),0)
end
local files={['data/generated/constants.lua']=Writer.encode({gen3EmeraldBag=spec})}
for _,path in ipairs(spec.resources)do files[path]='fixture'end
files[spec.manifest]=Writer.encode({game='emerald',format=1})
local widths={};for i=0,511 do widths[i]=6 end
files[A.FONTS..'latin_narrow_widths.lua']=Writer.encode(widths)
for _,face in ipairs{'fg','shadow'}do files[A.FONTS..'latin_narrow_'..face..'.rgba']=string.rep('\0',512*16*16*4)end
Fs.read=function(path)return files[path]end
T.eq(#A.missing('emerald'),0)
for _,path in ipairs(spec.resources)do
 local bytes=files[path];files[path]=nil;T.eq(#A.missing('emerald'),1);files[path]=bytes
end
local path=A.FONTS..'latin_narrow_widths.lua';local raw=files[path]
widths[0]=nil;files[path]=Writer.encode(widths);T.eq(#A.missing('emerald'),1)
widths[0]=17;files[path]=Writer.encode(widths);T.eq(#A.missing('emerald'),1);files[path]=raw
local load=require('compat.gen1-rs.Loader').new('emerald',{['src.core.GameVersion']=V,__package={loaded={}}})
local IR=load('src.core.game3.scripting.text_ir')
local Serial=require('src.core.SaveSerializer')
V.set('emerald')
local texts,glyphs,draws,frames,cursors={}, {}, {}, {}, {};local forcedIcon
love.graphics={setColor=function()end,draw=function(...)draws[#draws+1]={...}end,
 newQuad=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end}
local font={CHAR_SELECTOR_ARROW=239,COLOR={NORMAL={}},
 measure=function(text,opts)return#text*(opts and opts.font=='narrow'and 5 or 6)end,
 draw=function(text,x,y,opts)texts[#texts+1]={text=text,x=x,y=y,opts=opts}end,
 drawGlyph=function(id,x,y,opts)glyphs[#glyphs+1]={id=id,x=x,y=y,opts=opts}end}
local game={data={constants={gen3EmeraldBag=spec,gen3ItemIcons={count=377}},items={
 POTION={name='POTION',index=13},KEY={name='KEY',index=500},ORAN={name='ORAN BERRY',index=139},
 HM01={name='HM01',machine={kind='HM',number=1,move='CUT'}},
 TM01={name='TM01',machine={kind='TM',number=1,move='PUNCH'}}},moves={CUT={name='CUT'},PUNCH={name='PUNCH'}}},
 save={player={gender='boy'},inventory={POTION=1},registeredItem='KEY'}}
local owner={game=game,pockets={{key='ITEM',name='ITEMS'}},pocket=1,index=1,top=1,tick=0,lockPocket=true,
 rows={{id='POTION',label='POTION',qty=1,description='Heals HP.'},{close=true}}}
function owner:selected()return self.rows[self.index]end
function owner:itemIcon(_,forced)forcedIcon=forced end
local top=owner;game.stack={top=function()return top end}
local manifest={background={png='bg',variants={female='female-bg'}},indicator={png='indicator',variants={female='female-indicator'}},
 sprites={male={png='male-bag'},female={png='female-bag'},arrows={png='arrows',w=16,h=16}},
 palettes={male={},female={}},textIR={close=IR.fromAscii('CLOSE BAG'),count=IR.fromAscii('x{STR_VAR_1}'),
 number=IR.fromAscii('{STR_VAR_1} {STR_VAR_2}'),hmNumber=IR.fromAscii('H{STR_VAR_1} {STR_VAR_2}'),
 returnTo=IR.fromAscii('Return to {STR_VAR_1}.'),selected=IR.fromAscii('{STR_VAR_1} is selected.')},
 returnToIR={[0]=IR.fromAscii('field')}}
for i=1,32 do manifest.palettes.male[i]=i;manifest.palettes.female[i]=i end
local view=setmetatable({owner=owner,game=game,manifest=manifest,quads={},images={},
 image=function(_,path)return{path=path,getDimensions=function()return 240,384 end}end,
 load=function(name)
  if name=='src.ui.game3.frlg_font'then return font end
  if name=='src.core.game3.scripting.text_ir'then return IR end
  if name=='src.import.gba.rse.boot_gfx'then return{rgb8=function(i)return i,i,i end}end
  if name=='src.ui.game3.window'then return{
   template=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end,
   stdFrame=function(r)frames[#frames+1]=r end,
   cursorPx=function(x,y)cursors[#cursors+1]={x=x,y=y}end}end
  return load(name)
 end},View)
local before=Serial.encode(game.save)
view:drawNative()
T.eq(glyphs[1].x,112);T.eq(glyphs[1].y,17)
local quantity;for _,row in ipairs(texts)do if row.text=='x 1'then quantity=row end end
T.check(quantity,'single items retain their native quantity');T.eq(quantity.x,216);T.eq(quantity.y,17)
T.eq(quantity.opts.font,'narrow');T.eq(texts[2].opts.font,'narrow')
T.eq(Serial.encode(game.save),before,'drawing does not edit the save')
top=setmetatable({owner=owner},require('src.ui.Gen3BagSale'));texts={};view:drawNative()
local description=false;for _,row in ipairs(texts)do if row.y==105 then description=true end end
T.eq(description,false,'sale dialogue suppresses the underlying description instead of leaving a clipped line')
top=owner;texts={};view:drawNative();description=false
for _,row in ipairs(texts)do if row.text=='Heals HP.'then description=true end end
T.eq(description,true,'ordinary lists retain their item description')
texts={};owner.rows={{id='KEY',label='KEY',qty=1,important=true},{close=true}}
owner.pockets[1].key='KEY_ITEM';view:drawNative()
local badge;for _,row in ipairs(draws)do if row[1].path==A.ROOT..'select.png'then badge=row end end
T.check(badge);T.eq(badge[2],208);T.eq(badge[3],16)
owner.rows={{id='ORAN',label='ORAN BERRY',qty=999},{close=true}};owner.pockets[1].key='BERRY';texts={}
view:drawNative();local berry
for _,row in ipairs(texts)do if row.text=='07 ORAN BERRY'then berry=row.text end end
T.eq(berry,'07 ORAN BERRY');T.eq(texts[3].text,'x999')
owner.index=2;view:drawNative();T.eq(forcedIcon,376,'CLOSE uses the native return icon')
T.eq(view:label({id='TM01',label='TM01'},'TM_HM'),'01 PUNCH')
local hm,isHm=view:label({id='HM01',label='HM01'},'TM_HM');T.eq(hm,'H1 CUT');T.eq(isHm,true)
T.eq(view:label({id='TM01',label='CUSTOM'},'TM_HM'),'CUSTOM','custom item names remain intact')
local Action=require('src.ui.Gen3ItemMenu')
local action=setmetatable({columns=2,rows=2,index=1,emeraldBag=owner,
 entries={{label='USE',kind='use'},{label='REGISTER',kind='register'},
  {label='',kind='blank'},{label='CANCEL',kind='cancel'}}},Action)
T.eq(action:step('left'),false,'native grid clamps at its left edge')
T.eq(action:step('down'),false,'native grid preserves its blank cell')
T.eq(action:step('right'),true);T.eq(action:step('down'),true);T.eq(action.index,4)
view:drawActions(action);T.eq(frames[1].x,15);T.eq(frames[1].y,15)
T.eq(frames[1].w,14);T.eq(frames[1].h,4);T.eq(cursors[1].x,176);T.eq(cursors[1].y,137)
action.columns=1;action.entries={{label='CANCEL',kind='cancel'}};action.index=1
view:drawActions(action);T.eq(frames[2].x,22);T.eq(frames[2].y,17);T.eq(frames[2].w,7);T.eq(frames[2].h,2)
manifest.moveInfo={image='move-info',palette={},rects={}}
for i=1,16 do manifest.moveInfo.palette[i]=i end
for i=1,24 do manifest.moveInfo.rects[i]={x=0,y=0,w=8,h=8}end
game.data.moves.CUT={name='CUT',type='NORMAL',power=50,accuracy=95,pp=30}
game.data.constants.typeOrder={'NORMAL'};texts={}
T.eq(view:drawMoveInfo({id='HM01'}),true)
T.eq(texts[1].text,' 50');T.eq(texts[1].x,63);T.eq(texts[1].y,116)
T.eq(texts[2].text,' 95');T.eq(texts[2].y,128);T.eq(texts[3].text,' 30');T.eq(texts[3].y,140)
T.eq(view:drawMoveInfo({id='POTION'}),false)
owner.pcList=true;T.eq(View.available(owner),false);owner.pcList=false
Fs.read=oldRead;love.graphics=oldGraphics;love.filesystem.load=oldLoad;V.set(oldV)
T.finish('Emerald native bag cache ownership, font readiness, list geometry and unchanged save')
