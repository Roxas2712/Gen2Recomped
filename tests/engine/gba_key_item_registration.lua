-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion');local previous=V.get()
local UI=require('src.ui.Gen3BagMenu');local BagMenu=require('src.ui.BagMenu')
local S=require('src.core.SaveSerializer');local Sound=require('src.core.Sound')
local play=Sound.play;Sound.play=function()end
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(version)
  local rs=version=='ruby'or version=='sapphire'
  local frlg=version=='firered'or version=='leafgreen'
  local menu={columns=frlg and 1 or 2,register=2,deselect=5,
    labels={[1]='USE',[2]='REGISTER',[3]='',[4]='CANCEL',[5]='DESELECT'},
    kinds={[1]='use',[2]='register',[3]='blank',[4]='cancel',[5]='register'},
    pockets={KEY_ITEM=frlg and{1,2,4}or{1,2,3,4},ITEM={1,4}}}
  local key
  local g={data={constants={gen3BagScreen={layout=frlg and'frlg'or'rse'},gen3ItemMenu=menu},
    items={ROD={id='ROD',pocket='KEY_ITEM',registrability=1,name='OWN ROD'},
      LETTER={id='LETTER',pocket='KEY_ITEM',registrability=0,name='OWN LETTER'},
      LEGACY={id='LEGACY',pocket='KEY_ITEM',name='OWN LEGACY'},
      POTION={id='POTION',pocket='ITEM',registrability=1,name='OWN POTION'}}},
    save={inventory={ROD=1,LETTER=1,POTION=3,LEGACY=1},bagOrder={'ROD','LETTER','POTION','LEGACY'},options={}},
    input={wasPressed=function(_,k)return k==key end},stack={pop=function()end}}
  local owner=UI.new(g,{pocket='KEY_ITEM'})
  T.eq(UI.canRegister(g,'ROD'),true,version..' own registrable key item')
  T.eq(UI.canRegister(g,'LETTER'),rs,version..' quest-item eligibility follows edition')
  T.eq(UI.canRegister(g,'LEGACY'),rs,version..' missing new metadata is not invented')
  T.eq(UI.canRegister(g,'POTION'),false,version..' byte alone cannot register another pocket')
  T.eq(BagMenu.canRegister(g,'ROD'),true,version..' overworld uses the same rule')
  T.eq(BagMenu.canRegister(g,'LETTER'),rs,version..' overworld and bag agree')
  local a=owner:actionsFor('LETTER')
  if frlg then
    T.eq(#a.entries,2);T.eq(a.entries[1].kind,'use');T.eq(a.entries[2].kind,'cancel')
  else
    T.eq(#a.entries,4);T.eq(a.entries[2].kind,rs and'register'or'blank')
    T.eq(a.entries[3].kind,'blank');T.eq(a.entries[4].kind,'cancel')
  end
  local before=S.encode(g.save)
  owner:act('register','POTION')
  T.eq(S.encode(g.save),before,version..' direct dispatch cannot register an ordinary item')
  if not rs then
    owner:act('register','LETTER')
    T.eq(S.encode(g.save),before,version..' nonregistrable key action is refused')
    local function press(k)key=k;owner:update();key=nil end
    press('select');T.eq(g.save.registeredItem,'ROD',version..' SELECT registers the actual selected row')
    T.eq(owner:actionsFor('ROD').entries[2].label,'DESELECT',version..' action label reflects registration')
    press('select');T.eq(S.encode(g.save),before,version..' second SELECT clears only registration')
    owner:act('register','ROD');T.eq(g.save.registeredItem,'ROD')
    T.eq(assert(S.decode(S.encode(g.save))).registeredItem,'ROD',version..' registration serializes')
    owner:act('register','ROD');T.eq(S.encode(g.save),before)
    for i,row in ipairs(owner.rows)do if row.id=='LETTER'then owner.index=i end end
    press('select');T.eq(S.encode(g.save),before,version..' SELECT ignores nonregistrable quest items')
    owner.index=#owner.rows;T.eq(owner:selected().close,true)
    press('select');T.eq(S.encode(g.save),before,version..' CANCEL never becomes a registered item')
    for _,opts in ipairs{{battle={}},{pick=true},{sell=true},{store='deposit'},{itemPc=true},{noInput=true}}do
      opts.pocket='KEY_ITEM';owner=UI.new(g,opts)
      for i,row in ipairs(owner.rows)do if row.id=='ROD'then owner.index=i end end
      press('select');T.eq(S.encode(g.save),before,version..' special bag context cannot alter registration')
    end
    owner=UI.new(g,{pocket='KEY_ITEM'});g.save.inventory.ROD=nil
    local without=S.encode(g.save);owner:act('register','ROD')
    T.eq(S.encode(g.save),without,version..' stale row cannot register an item no longer held')
  else
    owner:act('register','LETTER')
    T.eq(g.save.registeredItem,'LETTER',version..' RS pocket-wide REGISTER remains available')
  end
end
-- Exercise the actual item-table reader, including its zero byte. A missing
-- field and a cartridge that explicitly disallows registration differ.
local X=require('src.import.RomExtractorGen3')
local x=setmetatable({manifest={pocketEnum={[2]='KEY_ITEM'}},rom={}},X)
x.beginStage=function()end;x.tick=function()end;x.write=function()end
x.need=function()return 1000 end;x.layoutValue=function(_,name,fallback)return name=='numItems'and 3 or fallback end
x.readString=function(_,off)return 'FIXTURE_'..math.floor((off-1000)/44)end
x.resolveEvolutionItems=function()end
x.rom.pointer=function()return nil end;x.rom.u16=function()return 0 end
x.rom.u8=function(_,off)
  local row=math.floor((off-1000)/44);local field=(off-1000)%44
  if field==24 then return 1 elseif field==25 then return row elseif field==26 then return 2 end
  return 0
end
x:extractItems()
for _,def in pairs(x._items)do
  T.eq(def.registrability,def.index,'extractor reads the exact independent byte at +25')
  T.eq(def.importance,1);T.eq(def.pocket,'KEY_ITEM')
end
local Import=require('src.import.RomImporter')
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  T.check(Import.cacheContract(version).marker:find('gba-item-registrability-v1:',1,true),
    version..' old item tables require their own fresh import')
end
for _,version in ipairs{'red','gold','crystal'}do
  T.eq(Import.cacheContract(version).marker:find('gba-item-registrability-v1:',1,true),nil,
    version..' unrelated generation keeps its existing marker')
end
Sound.play=play;V.set(previous)
T.finish('GBA own-item registration, native action holes, SELECT contexts and independent ROM byte')
