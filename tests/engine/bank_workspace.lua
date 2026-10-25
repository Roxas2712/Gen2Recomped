package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local S=require('src.core.SaveSerializer');local function clone(t) return S.decode(S.encode(t)) end
local original={player={name='Test'},party={{species='BULBASAUR',level=5,moves={}}},boxes={{}}}
local bank={};local writes=0
local B={list=function() return clone(bank) end,readSave=function() return clone(original) end,data=function() return {} end,
  boxes=function(save) return save.boxes or {} end,boxMons=function(box) return box or {} end,shape=function() return 12,20 end,
  convert=function(entry,_,_,allow) if entry.adapt and not allow then return nil,'needs adaptation' end;return clone(entry.mon) end,
  deposit=function(mon,v,slot,place) bank[#bank+1]={id=tostring(#bank+1),mon=clone(mon),source={version=v,slot=slot,place=place}};return tostring(#bank) end,
  commitDraft=function(_,_,save) writes=writes+1;Written=clone(save);return 'slot-copy' end}
package.loaded['src.storage.PokemonBank']=B
package.loaded['src.core.SaveData']={listSlots=function() return {{id='slot1',exists=true,name='Test'}} end}
local W=require('src.import.BankWorkspace')
local ui={ready={red=true,gold=true},_refreshSlots=function() end}
W.open(ui);check(#ui._bankOverlay.slots==2,'the native workspace lists saves across imported games')
check(W.select(ui,ui._bankOverlay.left,{version='red',slot='slot1',label='Red'}),'source panel reads the chosen save')
check(W.select(ui,ui._bankOverlay.right,{version='gold',slot='slot1',label='Gold'}),'target panel reads a separate save')
local entry={mon=clone(original.party[1]),source={version='red',slot='slot1',place='Party 1'}}
local payload={entry=entry,data={}}
check(W.place(ui,payload,{panel='right',slot=2},false),'drop into an empty target PC cell stages a copy')
check(ui._bankOverlay.right.dirty and writes==0 and not original.boxes[1][2],'dragging never writes the source or base save')
check(not W.place(ui,payload,{panel='right',slot=2},false),'an occupied PC cell cannot be overwritten')
check(W.place(ui,payload,{bank=true},false) and #bank==1 and #ui._bankOverlay.bank==1,'a drop into the Bank keeps a durable original copy')
local f=ui._bankOverlay
f.cells={{x=0,y=0,width=40,height=40,entry=entry,data={},target={panel='left',slot=1}},
 {x=100,y=0,width=40,height=40,target={panel='right',slot=3}}};f.rects={}
W.press(ui,10,10);check(f.drag and f.selected,'pointer press picks up a Pokémon')
W.release(ui,110,10);check(not f.drag and f.right.save.boxes[1][3] and writes==0,'pointer release stages a copy in the actual drop target')
check(W.save(ui,'right') and writes==1 and Written.boxes[1][2] and Written.boxes[1][3],'Save copy commits all staged drops in one new save slot')
check(not f.right.dirty and f.right.slot=='slot-copy' and not original.boxes[1][2],'the panel follows its new slot and preserves the original')
local adapted={entry=clone(entry),data={}};adapted.entry.adapt=true
check(not W.place(ui,adapted,{panel='right',slot=4},false) and f.adapt,'a cross-model drop opens explicit adaptation review')
check(W.place(ui,adapted,{panel='right',slot=4},true) and not f.adapt,'confirmed adaptation stages only the target copy')
local signed=false;local started,cancelled=0,0
package.loaded['src.cloud.RetroCloud']={signedIn=function() return signed end}
package.loaded['src.cloud.BankExchange']={profile=function() error('cancelled networking must not execute') end}
package.loaded['src.cloud.Task']={new=function(fn) started=started+1;return {cancel=function() cancelled=cancelled+1 end} end}
W.mode(ui,'trade');W.trade(ui,'submit');W.mode(ui,'wonder');W.trade(ui,'submit')
check(started==0 and not f.tradeJob and f.notice:find('Register',1,true),'signed-out visitors cannot start either native trade flow')
signed=true;W.trade(ui,'submit')
check(started==0,'registration alone does not bypass choosing a copy and explicitly consenting to share it')
W.trade(ui,'profile');check(started==1 and f.tradeJob,'registered players can request their account-wide device and trade profile')
W.close(ui);check(not ui._bankOverlay and cancelled==1,'closing the Bank cancels its pending background request')
print('Bank workspace: '..n..' checks passed')
