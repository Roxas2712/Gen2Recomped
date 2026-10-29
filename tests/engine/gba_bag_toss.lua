-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3BagTossAssets')
local Loader=require('compat.gen1-rs.Loader');local Fs=require('src.import.CacheFs')
local W=require('src.import.LuaWriter');local S=require('src.core.SaveSerializer')
local UI=require('src.ui.Gen3BagToss');local V=require('src.core.GameVersion')
local oldVersion=V.get();local read=Fs.read;local fsLoad=love.filesystem.load
love.filesystem.load=function(path)return loadfile(path)end
local Sound=require('src.core.Sound');local play=Sound.play;Sound.play=function()end
for _,version in ipairs{'emerald','firered','leafgreen'}do
  V.set(version)
  local load=Loader.new(version,{['src.core.GameVersion']=V,__package={loaded={}}})
  local IR=load('src.core.game3.scripting.text_ir')
  local symbols=version=='emerald'and load('src.import.gba.syms').of(version)
  local labels=not symbols and require('src.import.gba.text_labels.'..version)
  local starts={};for _,key in pairs(Assets.labels(version))do starts[symbols and symbols.off(key)or labels[key]]=true end
  local x={version=version,_constants={},beginStage=function()end,write=function()end,
    rom={u8=function(_,at)return starts[at]and 0xBB or 255 end}}
  Assets.extract(x)
  local spec=x._constants.gen3BagToss
  T.eq(Assets.valid(spec,version),true,'actual symbol/decoder graph emits own toss vocabulary')
  Fs.read=function()return W.encode({gen3BagToss=spec})end
  T.eq(#Assets.missing(version),0,'own complete import is admitted')
  for key in pairs(Assets.labels(version))do
    local saved=spec.textIR[key];spec.textIR[key]=nil
    T.eq(Assets.valid(spec,version),false,'every native label is required: '..key);spec.textIR[key]=saved
  end
  spec.version='other';T.eq(Assets.valid(spec,version),false,'cross-edition text cannot be reused');spec.version=version
  spec.format=0;T.eq(#Assets.missing(version),1,'pre-toss cache is visibly incomplete');spec.format=1
  for _,other in ipairs{'ruby','sapphire','gold','diamond'}do
    T.eq(Assets.valid(spec,other),false,'existing other-generation/RS paths remain separate')
    T.eq(#Assets.missing(other),0,'new data does not gate another edition')
  end
  spec.textIR={prompt=IR.fromAscii('OWN {STR_VAR_1}'),confirm=IR.fromAscii('OWN {STR_VAR_2} {STR_VAR_1}'),
    done=IR.fromAscii('DONE {STR_VAR_2} {STR_VAR_1}'),count=IR.fromAscii('x{STR_VAR_1}'),
    yes=IR.fromAscii('YES'),no=IR.fromAscii('NO')}
  local rectangles,draws={},{}
  local font={COLOR={NORMAL={}},wrap=function(text)return text end,measure=function(text)return #text*6 end,
    draw=function(text,x,y,opts)draws[#draws+1]={text=text,x=x,y=y,small=opts.small}end}
  local window={template=function(x,y,w,h)return{x=x,y=y,w=w,h=h}end,
    stdFrame=function(r)rectangles[#rectangles+1]=r end,cursorPx=function()end}
  local modules={['src.ui.game3.frlg_font']=font,['src.ui.game3.window']=window,
    ['src.core.game3.scripting.text_ir']=IR}
  local current,pops,commits;local game={data={constants={gen3BagToss=spec}},save={inventory={POTION=12},unrelated='KEEP'}}
  local before=S.encode(game.save);local key;game.input={wasPressed=function(_,k)return k==key end}
  local owner={message='KEEP'}
  game.stack={top=function()return current end,pop=function()pops=pops+1;current:exit();current=owner end}
  local function make(max)
    pops,commits=0,0;owner.message='KEEP';rectangles,draws={},{}
    current=setmetatable({game=game,owner=owner,frlg=version~='emerald',max=max or 12,qty=1,index=1,
      mode=(max or 12)==1 and'confirm'or'quantity',name='A%BC',oldMessage=owner.message,
      load=function(name)return assert(modules[name])end,onCommit=function(qty)
        commits=commits+1;game.save.inventory.POTION=game.save.inventory.POTION-qty;return true
      end},UI)
    current:refreshMessage();return current
  end
  local function press(k)local state=current;key=k;state:update();key=nil end
  local state=make();press('down');press('left');T.eq(state.qty,1,'lower quantity bound cannot underflow')
  for _=1,30 do press('up')end;T.eq(state.qty,12,'upper quantity bound cannot overflow')
  state:drawNative();T.eq(draws[#draws].text,version=='emerald'and'x12'or'x012','native digit count uses own count placeholder')
  local r=rectangles[#rectangles];T.eq(r.x,24);T.eq(r.y,version=='emerald'and 17 or 15)
  T.eq(r.w,5);T.eq(r.h,version=='emerald'and 2 or 4,'quantity window retains its family geometry')
  T.eq(draws[#draws].small,version~='emerald'and true or nil,'FRLG uses its own small quantity face')
  press('b');T.eq(pops,1);T.eq(commits,0);T.eq(S.encode(game.save),before,'quantity cancel preserves the complete save')
  T.eq(owner.message,'KEEP','closing restores the prior description owner')
  state=make();press('a');state:drawNative();r=rectangles[#rectangles]
  T.eq(r.x,version=='emerald'and 24 or 23,'YES/NO keeps the native right-hand column')
  T.eq(r.y,15);T.eq(r.h,4)
  press('down');press('a')
  T.eq(commits,0);T.eq(pops,1);T.eq(S.encode(game.save),before,'NO cannot remove an item')
  state=make();press('right');press('right');press('a')
  T.eq(state.message,'OWN 3 A%BC','item names and chosen count expand without pattern substitution')
  press('b');T.eq(commits,0);T.eq(S.encode(game.save),before,'B at confirmation cannot remove an item')
  state=make();press('right');press('right');press('a');press('a')
  T.eq(state.mode,'done');T.eq(commits,0);T.eq(game.save.inventory.POTION,12,'result keeps the original count until acknowledged')
  T.eq(state.message,'DONE 3 A%BC');press('a')
  T.eq(game.save.inventory.POTION,9,'result acknowledgement removes exactly the selected quantity')
  key='a';state:update();key=nil
  T.eq(commits,1);T.eq(pops,1,'late input cannot commit or close twice');T.eq(game.save.unrelated,'KEEP')
  state=make(1);T.eq(state.mode,'confirm','one item skips the quantity step');press('b')
  state=make(999);state.berry=true;state.qty=999;draws={};state:drawNative()
  T.eq(draws[#draws].text,'x999','berry quantity keeps all three digits');press('b')
end
Fs.read=read;love.filesystem.load=fsLoad;Sound.play=play;V.set(oldVersion)
T.finish('native bag toss resources, family windows, bounds, variable ownership and cancel-safe transactions')
