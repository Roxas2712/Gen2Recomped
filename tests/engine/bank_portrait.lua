package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local S=require('src.core.SaveSerializer');local function clone(v) return assert(S.decode(S.encode(v))) end
local checks=0;local function check(v,m) assert(v,m);checks=checks+1 end
local mon={species='BULBASAUR',level=12,moves={},otId=2712,kasc={moveMemory={'TACKLE'}}}
local entry={id=string.rep('a',64),mon=mon,source={version='gold',slot='source',place='Party 1'},origin={recordId=string.rep('b',64),version='gold',slot='source',trainerId=2712}}
local writes=0
local data={pokemon={},moves={},items={}}
package.loaded['src.storage.PokemonBank']={list=function() return {clone(entry)} end,data=function() return data end,
  readSave=function() return {party={clone(mon)},boxes={{}}} end,shape=function() return 14,20 end,
  boxes=function(s) return s.boxes end,boxMons=function(b) return b or {} end,
  makeEntry=function(m,v,slot,place) local e=clone(entry);e.mon=clone(m);e.source={version=v,slot=slot,place=place};return e end,
  convert=function(e) return clone(e.mon) end,
  commitDraft=function() writes=writes+1;return 'copy' end}
package.loaded['src.core.SaveData']={listSlots=function() return {{id='slot1',exists=true}} end}
package.loaded['src.cloud.RetroCloud']={signedIn=function() return true end}
local W=require('src.import.BankWorkspace')
local font=love.graphics.newFont(12)
function font:getWrap(value,w)
  local lines={};local columns=math.max(1,math.floor(w/6))
  for i=1,#value,columns do lines[#lines+1]=value:sub(i,i+columns-1) end
  return w,lines
end
local ui={ready={gold=true},hintFont=font,stateFont=font,_ui={ellipsize=function(_,value) return value end}}
W.open(ui);local f=ui._bankOverlay
assert(W.select(ui,f.left,{version='gold',slot='slot1',label='Gold A'}))
assert(W.select(ui,f.right,{version='gold',slot='slot2',label='Gold B'}))
local width,height=390,844
love.graphics.getDimensions=function() return width,height end
for _,size in ipairs({{375,812},{390,844},{430,932},{390,640}}) do
  width,height=size[1],size[2]
  for _,view in ipairs({'bank','left','right'}) do
    f.mobileView=view;W.draw(ui)
    check(#f.cells>0,'portrait view renders usable cells')
    for _,cell in ipairs(f.cells) do
      check(cell.width>=44 and cell.height>=44,'portrait Pokémon cells remain touch-sized at '..width..'x'..height..' / '..view)
      check(cell.x>=0 and cell.y>=0 and cell.x+cell.width<=width and cell.y+cell.height<=height,'portrait cells remain inside the screen')
    end
    for _,rect in ipairs(f.rects) do
      check(rect.height>=44 and rect.width>=44,'portrait controls remain touch-sized')
      check(rect.x>=0 and rect.y>=0 and rect.x+rect.width<=width and rect.y+rect.height<=height,'portrait controls remain inside the screen')
    end
  end
end
width,height=390,844;f.mobileView='bank';W.draw(ui)
local cell=f.cells[1];W.press(ui,cell.x+5,cell.y+5);W.release(ui,cell.x+5,cell.y+5)
check(f.selected and f.selected.entry.id==entry.id,'tap selects a Bank Pokémon for cross-view copying')
for _,r in ipairs(f.rects) do if r.action=='mobileView' and r.view=='right' then W.press(ui,r.x+4,r.y+4);break end end
W.draw(ui)
check(f.mobileView=='right' and f.selected,'changing the mobile view preserves the selected source Pokémon')
local target=f.cells[1];W.press(ui,target.x+5,target.y+5)
check(f.right.dirty and f.right.save.boxes[1][1].otId==2712 and writes==0,'tap into an empty PC cell stages the selected copy without writing a save')
for _,r in ipairs(f.rects) do if r.action=='mode' and r.mode=='details' then W.press(ui,r.x+4,r.y+4);break end end
local printed={};local printf=love.graphics.printf
love.graphics.printf=function(value,...) printed[#printed+1]=value;return printf(value,...) end
W.draw(ui);love.graphics.printf=printf
check(f.mode=='details' and table.concat(printed,' '):find('kasc %(table%)'),'the full-width details page exposes retained mod Lua fields')
width,height=1280,800;f.mode='bank';W.draw(ui)
local names={};for _,cell in ipairs(f.cells) do names[cell.target.bank and 'bank' or cell.target.panel]=true end
check(names.bank and names.left and names.right,'desktop keeps all three simultaneous Bank/save panels')
print('Bank portrait: '..checks..' checks passed')
