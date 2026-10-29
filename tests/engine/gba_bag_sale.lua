-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local A=require('src.import.Gen3BagSaleAssets')
local UI=require('src.ui.Gen3BagSale');local V=require('src.core.GameVersion')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local Loader=require('compat.gen1-rs.Loader');local Serial=require('src.core.SaveSerializer')
local Bag=require('src.inventory.Bag');local Sound=require('src.core.Sound')
local oldVersion=V.get();local oldLoad=love.filesystem.load;local oldRead,oldWrite=Fs.read,Fs.write
local oldPlay=Sound.play;local sounds={};Sound.play=function(_,name)sounds[#sounds+1]=name end
love.filesystem.load=function(path)return loadfile(path)end
local function literal(bytes)
  local out={16,#bytes%256,math.floor(#bytes/256)%256,0}
  for i=1,#bytes,8 do out[#out+1]=0;for j=i,math.min(i+7,#bytes)do out[#out+1]=bytes[j]end end
  return out
end
for _,version in ipairs{'emerald','firered','leafgreen'}do
  V.set(version);local load=Loader.new(version,{['src.core.GameVersion']=V,__package={loaded={}}})
  local S=version=='emerald'and load('src.import.gba.syms').of(version)
  local labels=not S and require('src.import.gba.text_labels.'..version)
  local memory={};for _,name in pairs(A.labels(version))do memory[S and S.off(name)or labels[name]]=0xBB end
  local function put(at,bytes)for i,b in ipairs(bytes)do memory[at+i-1]=b end end
  local pixels={};for i=1,256 do pixels[i]=i%3==0 and 0 or 0x11 end
  if S then
    local colors={};for i=1,32 do colors[i]=255 end
    put(S.off('gShopMenu_Pal'),literal(colors));put(S.off('gShopMenuMoney_Gfx'),literal(pixels))
  else
    local cfg=load('src.import.gba.versions_frlg');cfg.select(version)
    put(cfg.RED_ARROW_OTHER_GFX,literal(pixels))
  end
  local captured={};Fs.write=function(path,bytes)captured[path]=bytes;return true end
  local x={version=version,_constants={},write=function()end,rom={u8=function(_,at)return memory[at]or 255 end,u16=function()return 32767 end}}
  A.extract(x);local spec=x._constants.gen3BagSale;T.eq(A.valid(spec,version),true)
  T.eq(#captured[spec.graphic],2048);T.check(captured[spec.graphic]:find(string.char(255,255,255,255),1,true))
  Fs.read=function(path)if path=='data/generated/constants.lua'then return Writer.encode({gen3BagSale=spec})end;return captured[path]end
  T.eq(#A.missing(version),0)
  local raw=captured[spec.graphic];captured[spec.graphic]=raw:sub(1,-2);T.eq(#A.missing(version),1);captured[spec.graphic]=raw
  for key in pairs(A.labels(version))do local value=spec.textIR[key];spec.textIR[key]=nil;T.eq(A.valid(spec,version),false);spec.textIR[key]=value end
  for _,other in ipairs{'ruby','sapphire','gold','crystal'}do T.eq(A.valid(spec,other),false);T.eq(#A.missing(other),0)end
  spec.version='other';T.eq(A.valid(spec,version),false);spec.version=version

  local IR=load('src.core.game3.scripting.text_ir')
  spec.textIR={prompt=IR.fromAscii(version=='emerald'and'HOW {STR_VAR_2}'or'HOW {STR_VAR_1}'),
    confirm=IR.fromAscii(version=='emerald'and'PAY {STR_VAR_1}'or'PAY {STR_VAR_3}'),
    done=IR.fromAscii(version=='emerald'and'SOLD {STR_VAR_2} {STR_VAR_1}'or'SOLD {STR_VAR_1} {STR_VAR_3}'),
    cant=IR.fromAscii('CANNOT BUY'),money=IR.fromAscii('${STR_VAR_1}'),label=IR.fromAscii('MONEY'),
    count=IR.fromAscii('x{STR_VAR_1}'),yes=IR.fromAscii('YES'),no=IR.fromAscii('NO')}
  local game={data={constants={gen=3,gen3Bag={version=version,pockets={ITEM=30,BERRY=46,KEY_ITEM=30,BALL=16,TM_HM=64}}},items={
    POTION={index=13,name='A%BC',pocket='ITEM',price=100},BERRY={index=133,name='BERRY',pocket='BERRY',price=20},
    QUEST={index=259,name='QUEST',pocket='KEY_ITEM',price=100,keyItem=true},FREE={index=14,name='FREE',pocket='ITEM',price=0}}},
    save={inventory={},bagOrder={},money=50,unrelated='KEEP'}}
  local current,pops,refresh,key;local owner={game=game,rebuild=function()refresh=refresh+1 end}
  local frames,draws={},{}
  local modules={['src.core.game3.scripting.text_ir']=IR,
    ['src.ui.game3.frlg_font']={COLOR={NORMAL={}},LINE_PITCH=15,wrap=function(s)return s end,advance=function()return 6 end,
      measure=function(s)return #s*5 end,draw=function(text,x,y,opts)draws[#draws+1]={text=text,x=x,y=y,small=opts.small}end},
    ['src.ui.game3.window']={template=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end,
      stdFrame=function(r)frames[#frames+1]=r end,dialogueFrame=function()end,cursorPx=function()end,optionHeight=function()return 15 end},
    ['src.core.game3.trig']={sin=function()return 0 end}}
  game.input={wasPressed=function(_,k)return key==k end}
  game.stack={top=function()return current end,pop=function()pops=pops+1;current:exit();current=owner end,
    push=function()error('Native sales must not fall back to a generic quantity/text box')end}
  local function make(id,quantity)
    game.save={inventory={},bagOrder={},money=50,unrelated='KEEP'};assert(Bag.add(game.save,id or'POTION',quantity or 12,game.data))
    pops,refresh=0,0;sounds={}
    local row={id=id or'POTION',qty=quantity or 12}
    if version=='emerald'then
      row.rsSlot=require('src.inventory.Gen3RsInventory').rows(game.save,game.data,game.data.items[row.id].pocket)[1].slot
    end
    current=setmetatable({game=game,owner=owner,row=row,version=version,frlg=version~='emerald',
      spec=spec,name=game.data.items[row.id].name,berry=row.id=='BERRY',qty=1,index=1,k=0,mode='opening',
      load=function(name)return assert(modules[name],name)end},UI)
    current:begin();return current
  end
  local function press(button)local state=current;key=button;state:update();key=nil end
  local s=make();local before=Serial.encode(game.save);T.eq(s.mode,'quantity');T.eq(s:prose(),'HOW A%BC')
  frames,draws={},{};s:drawNative();local frame=frames[#frames]
  T.eq(frame.x,version=='emerald'and 18 or 17);T.eq(frame.y,version=='emerald'and 11 or 9)
  T.eq(frame.w,version=='emerald'and 10 or 12);T.eq(frame.h,version=='emerald'and 2 or 4)
  local count;for _,d in ipairs(draws)do if d.text=='x01'then count=d end end
  T.check(count);T.eq(count.x,version=='emerald'and 144 or 140);T.eq(count.y,version=='emerald'and 89 or 82)
  T.eq(count.small,version~='emerald'and true or nil);T.eq(Serial.encode(game.save),before)
  press('down');T.eq(s.qty,12);press('up');T.eq(s.qty,1);press('right');T.eq(s.qty,11)
  press('right');T.eq(s.qty,12);press('left');T.eq(s.qty,2);press('left');T.eq(s.qty,1)
  press('b');T.eq(pops,1);T.eq(Serial.encode(game.save),before)
  s=make();press('right');press('a');T.eq(s.mode,'confirm');T.eq(s:prose(),'PAY 550')
  frames={};s:drawNative();frame=frames[#frames];T.eq(frame.x,21);T.eq(frame.y,9)
  T.eq(frame.w,version=='emerald'and 5 or 6);T.eq(frame.h,4)
  press('down');press('a');T.eq(pops,1);T.eq(Serial.encode(game.save),before)
  s=make();press('right');press('a');press('b');T.eq(Serial.encode(game.save),before)
  s=make();press('right');press('a');press('a');T.eq(s.mode,'done');T.eq(s:prose(),'SOLD A%BC 550')
  T.eq(game.save.money,600);T.eq(game.save.inventory.POTION,1);T.eq(refresh,1)
  local purchases=0;for _,name in ipairs(sounds)do if name=='Purchase'then purchases=purchases+1 end end;T.eq(purchases,1)
  press('a');key='a';s:update();key=nil;T.eq(pops,1);T.eq(game.save.money,600);T.eq(game.save.unrelated,'KEEP')
  s=make();press('a');game.save.inventory.POTION=0;press('a')
  T.eq(pops,1,'stale sale closes without a false result');T.eq(game.save.money,50,'stale sale cannot create money')
  T.eq(refresh,0,'refused sale does not announce a transaction')
  s=make(nil,1);T.eq(s.mode,'confirm');game.save.money=999990;press('a');T.eq(game.save.money,999999)
  s=make('FREE');T.eq(s.mode,'cant');T.eq(game.save.inventory.FREE,12);press('a');T.eq(game.save.money,50)
  s=make('QUEST',1);T.eq(s.mode,'cant');press('b');T.eq(game.save.inventory.QUEST,1)
  s=make('BERRY',999);T.eq(s.max,version=='emerald'and 999 or 99);press('b')
  if version=='emerald'then
    s=make(nil,99);assert(Bag.add(game.save,'POTION',50,game.data))
    s.row.rsSlot=require('src.inventory.Gen3RsInventory').rows(game.save,game.data,'ITEM')[2].slot;s.row.qty=50;s:begin()
    press('right');press('a');press('a');local rows=require('src.inventory.Gen3RsInventory').rows(game.save,game.data,'ITEM')
    T.eq(rows[1].qty,99);T.eq(rows[2].qty,39);T.eq(game.save.money,600);press('a')
  end
end
Fs.read,Fs.write=oldRead,oldWrite;love.filesystem.load=oldLoad;Sound.play=oldPlay;V.set(oldVersion)
T.finish('native E/FRLG bag sale resources, ordinary inputs and shared atomic transactions')
