package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local V=require('src.core.GameVersion')
local Bag=require('src.ui.Gen3BagMenu')
local Writer=require('src.import.LuaWriter')
local old=V.get()
local function game(frlg)
  return {data={items={},constants={gen3BagScreen={layout=frlg and 'frlg' or 'rse'}}},
    save={inventory={},bagOrder={},options={}},stack={pop=function()end}}
end
for _,edition in ipairs({'ruby','sapphire','emerald','firered','leafgreen'})do
  V.set(edition)
  local g=game(V.isFRLG());local before=Writer.encode(g.save)
  local bag=Bag.new(g)
  T.eq(bag.pockets[bag.pocket].key,'ITEM',edition..' starts at ITEMS')
  bag:movePocket(V.isFRLG() and 2 or 1)
  T.eq(bag.pockets[bag.pocket].key,'BALL',edition..' selects balls')
  T.eq(Bag.new(g).pockets[Bag.new(g).pocket].key,'BALL',edition..' field reopen retains pocket')
  T.eq(Bag.new(g,{battle={}}).pocket,bag.pocket,edition..' battle reuses field pocket')
  T.eq(Bag.new(g,{pick=true}).pocket,bag.pocket,edition..' ordinary item picker uses the last pocket')
  local locked=Bag.new(g,{pocket='BERRY',pick=true,onPick=function()error('unexpected pick')end})
  T.eq(locked.pockets[locked.pocket].key,'BERRY',edition..' explicit pocket wins')
  locked:movePocket(1)
  local expected=V.isFRLG()and bag.pocket or locked.pocket
  T.eq(Bag.new(g).pocket,expected,edition..' Hoenn berry selection changes bag pocket; FRLG pouch stays separate')
  local pc=Bag.new(g,{store='deposit',itemPc=true})
  if V.isFRLG()then
    T.eq(pc.pocket,1,edition..' native item-PC entry forces ITEMS')
    expected=1
  else
    T.eq(pc.pocket,expected,edition..' Hoenn item-PC entry uses previous pocket')
    pc:movePocket(1);expected=pc.pocket
  end
  T.eq(Bag.new(g).pocket,expected,edition..' real item-PC bag retains its native pocket')
  local machine=Bag.new(g,{pocket='TM_HM'})
  expected=V.isFRLG()and expected or machine.pocket
  T.eq(Bag.new(g).pocket,expected,edition..' FRLG TM CASE stays separate from the real bag')
  local tutorial=Bag.new(g,{rows={{id='BALL',qty=1}},noInput=true,rsTutorial=true})
  tutorial:movePocket(1)
  T.eq(Bag.new(g).pocket,expected,edition..' tutorial restores the original bag selection')
  local other=game(V.isFRLG())
  T.eq(Bag.new(other).pocket,1,edition..' another save starts independently')
  T.eq(Writer.encode(g.save),before,edition..' navigation never changes saved data')
  local canceled=0;local cancel=Bag.new(g,{onCancel=function()canceled=canceled+1 end})
  cancel:close();T.eq(canceled,1,edition..' cancel callback preserved')
  T.eq(Bag.new(g,{store='withdraw'}).pocket,1,edition..' PC list keeps its own context')
  T.eq(Bag.new(g).pocket,expected,edition..' separate PC list does not replace bag memory')
end
local shared=game(false)
V.set('ruby');Bag.new(shared):movePocket(4)
V.set('sapphire');T.eq(Bag.new(shared).pocket,1,'edition swap does not inherit another pocket')
V.set('ruby');T.eq(Bag.new(shared).pocket,5,'original edition still retains its pocket')
V.set(old)
T.finish('GBA last active bag pocket, context isolation and save immutability')
