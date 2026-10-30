-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local M=require('src.import.Gen3TMCaseAssets')
local Image=require('src.import.ImageWriter');local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter');local Serial=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion');local Bag=require('src.inventory.Bag')
local Case=require('src.ui.Gen3TMCase');local Use=require('src.ui.BagMenu')
local Sale=require('src.ui.Gen3BagSale')
local old={blank=Image.blank,read=Fs.read,load=love.filesystem.load,
 use=Use.useItem,give=Use.giveItem,sale=Sale.open,version=V.get()}
love.filesystem.load=loadfile
local pixels={}
Image.blank=function(w,h)
 T.eq(w,16);T.eq(h,12)
 return{setPixel=function(_,x,y,a,b,c,d)
  assert(x>=0 and x<16 and y>=0 and y<12);pixels[y*16+x+1]={a,b,c,d}
 end}
end
local raw,bytes,palette={}, {},{[0]={255,255,255}}
for i=1,128 do raw[i]=(i*37)%256;bytes[i]=string.char(raw[i])end
for i=1,15 do palette[i]={i*11,i*7,i*3}end
local load=require('compat.gen1-rs.Loader').new('firered',{
 ['src.core.GameVersion']=V,__package={loaded={}}})
local expected=load('src.import.gba.rse.boot_gfx').bakeSprite(table.concat(bytes),16,16,0,4)
M.decodeHmTag(raw,palette)
for i=1,192 do
 local index=expected[i];local want={0,0,0,0}
 if index~=0 then local c=palette[index];want={c[1]/255,c[2]/255,c[3]/255,1}end
 T.same(pixels[i]or{0,0,0,0},want,'HM tag matches tiled bake at visible pixel '..i)
end
T.raises(function()M.decodeHmTag({},palette)end,'HM tag requires','truncated tag cannot be accepted')
local function u32(n)return string.char(math.floor(n/16777216)%256,math.floor(n/65536)%256,math.floor(n/256)%256,n%256)end
local function png(w,h)
 return '\137PNG\r\n\26\n'..u32(13)..'IHDR'..u32(w)..u32(h)..string.rep('\0',9)
  ..u32(1)..'IDAT'..'x'..string.rep('\0',4)..u32(0)..'IEND'..string.rep('\0',4)
end
for _,version in ipairs{'firered','leafgreen'}do
 local spec={format=M.FORMAT,version=version,images={hm_tag=M.PATH}}
 local image=png(16,12)
 Fs.read=function(path)
  if path=='data/generated/constants.lua'then return Writer.encode({gen3FRLGPocketArt=spec})end
  if path==M.PATH then return image end
 end
 T.eq(#M.missing(version),0,'current own tiled tag satisfies readiness')
 for _,bad in ipairs{'',png(16,16),png(8,12),image:sub(1,-2),'not a PNG'}do
  image=bad;T.eq(#M.missing(version),1,'bad native tag is rejected')
 end
 image=png(16,12);spec.format=nil;T.eq(#M.missing(version),1,'old scanline cache needs reimport')
 spec.format=M.FORMAT
 local other=version=='firered'and'leafgreen'or'firered'
 T.eq(#M.missing(other),1,'other cartridge marker cannot satisfy readiness')
 spec.images.hm_tag='wrong.png';T.eq(#M.missing(version),1,'resource belongs to this cache contract')
end
Fs.read=function()error('unrelated editions must not read the FRLG cache')end
for _,version in ipairs{'ruby','sapphire','emerald','gold'}do T.eq(#M.missing(version),0)end

local used,given,sold,current,pops,cancels
Use.useItem=function(game,battle,id,owner)used={id=id,owner=owner}end
Use.giveItem=function(game,id,done)given=id end
Sale.open=function(owner,row)sold={owner=owner,row=row};return true end
for _,version in ipairs{'firered','leafgreen'}do
 V.set(version)
 local items={POTION={id='POTION',pocket='ITEM'},TM_CASE={id='TM_CASE',pocket='KEY_ITEM',keyItem=true}}
 local function machine(id,kind,number)
  items[id]={id=id,name=id,pocket='TM_HM',machine={kind=kind,number=number,move=id}}
 end
 machine('TM39','TM',39);machine('TM03','TM',3);machine('TM28','TM',28)
 machine('HM03','HM',3);machine('HM01','HM',1)
 machine('ALIAS03','TM',3);machine('CUSTOM_A','TM','unknown');machine('CUSTOM_B','TM','unknown')
 local order={'POTION','TM39','TM03','TM_CASE','HM03','TM28','HM01','ALIAS03','CUSTOM_B','CUSTOM_A'}
 local game={data={items=items,moves={}},save={inventory={},bagOrder=order,options={keep='KEEP'}}}
 for _,id in ipairs(order)do game.save.inventory[id]=id=='TM03'and 4 or 1 end
 game.stack={push=function(_,screen)current=screen;return screen end,pop=function()pops=pops+1 end}
 pops,cancels=0,0
 local before=Serial.encode(game.save)
 local case=Case.new(game,{onCancel=function()cancels=cancels+1 end})
 local want={'HM01','HM03','TM03','ALIAS03','TM28','TM39','CUSTOM_B','CUSTOM_A'}
 for i,id in ipairs(want)do T.eq(case.rows[i].id,id,'native list order '..i);T.eq(case.rows[i].qty,game.save.inventory[id])end
 T.eq(case.rows[#want+1].close,true);T.eq(#case.rows,#want+1)
 T.eq(Serial.encode(game.save),before,'sorting the view preserves inventory, acquisition order and options')
 case.index=3;case:choose();current.onPick('use')
 T.eq(used.id,'TM03');T.eq(used.owner,case,'teaching receives the selected stable item')
 current.onPick('give');T.eq(given,'TM03')
 case.sell=true;case:choose();T.eq(sold.row.id,'TM03');T.eq(sold.row.qty,4);T.eq(sold.owner,case)
 T.eq(Serial.encode(game.save),before,'opening actions does not consume or rename a machine')
 case.index=#case.rows;case:choose();T.eq(pops,1);T.eq(cancels,1)
 T.eq(game.save.inventory.CLOSE,nil,'cancel is not an inventory item')
 Bag.remove(game.save,'TM03',4,game.data);local afterRemoval=Serial.encode(game.save)
 case:rebuild();T.eq(case.rows[3].id,'ALIAS03');T.eq(case.rows[3].qty,1)
 T.eq(Serial.encode(game.save),afterRemoval,'refresh preserves the actual completed transaction')
 local scripted={{id='TM39'},{id='HM01'},{close=true}}
 local custom=Case.new(game,{rows=scripted})
 T.eq(custom.rows,scripted,'explicit scripted rows keep their authored order')
 T.eq(custom.rows[1].id,'TM39')
 local empty=Case.new({data={items={},moves={}},save={inventory={},bagOrder={}}})
 T.eq(#empty.rows,1);T.eq(empty.rows[1].close,true)
end
Image.blank,Fs.read,love.filesystem.load=old.blank,old.read,old.load
Use.useItem,Use.giveItem,Sale.open=old.use,old.give,old.sale;V.set(old.version)
T.finish('FRLG tiled HM tag readiness and native TM CASE order with stable callbacks')
