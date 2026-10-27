local T=require('src.pokemon.Gen3RsStorageTransaction')
local S=require('src.core.SaveSerializer')
local checks=0
local function check(x,label)checks=checks+1;assert(x,label)end
local function fixture()
  local a={species='A',hp=20,stats={hp=30},stableId='a',unknown={nested={preserve=99}},moves={{id='CUT',pp=2}}}
  local b={species='B',hp=10,stats={hp=20},stableId='b'}
  local c={species='C',hp=5,stats={hp=10},stableId='c'}
  local game={data={items={POTION={index=13}}},save={party={a,b},boxes={},currentBox=14,boxNames={[14]='LONG ORIGINAL BOX NAME'},extra={retain=true}}}
  for i=1,14 do game.save.boxes[i]={}end
  game.save.boxes[14][30]=c;game.save.boxes[14].wallpaper=15
  return game,a,b,c
end
local g,a,b,c=fixture();local party,boxes,box,unknown=g.save.party,g.save.boxes,g.save.boxes[14],a.unknown
local before=S.encode(g.save);local tx=T.new(g);local s=tx.session
check(s.storage.boxes[14].mons[30]._host.stableId=='c','slot 30 missing')
check(s.storage.boxes[14].mons[1]==nil,'sparse box compacted')
check(s.party[1].maxHp==30,'native max HP bridge')
local held=table.remove(s.party,2);held.hp=20;s.storage.boxes[1].mons[7]=held
check(S.encode(g.save)==before,'working movement leaked into authoritative save')
s.storage.boxes[14].name='NEW NAME';s.storage.boxes[14].wallpaper=1;s.storage.currentBox=1
s.party[1].unknown.nested.preserve=100
check(a.unknown.nested.preserve==99,'nested table shared')
tx:commit()
check(g.save.party==party and g.save.boxes==boxes and g.save.boxes[14]==box,'save table identities replaced')
check(g.save.party[1]==a and g.save.boxes[1][7]==b and g.save.boxes[14][30]==c,'stable mon references replaced')
check(a.unknown==unknown and unknown.nested.preserve==100,'unknown fields lost')
check(g.save.boxNames[14]=='NEW NAME'and box.wallpaper==0 and g.save.currentBox==1,'metadata conversion')
check(not pcall(function()tx:commit()end),'double commit accepted')
g=fixture();before=S.encode(g.save);tx=T.new(g);tx:commit();check(S.encode(g.save)==before,'untouched PC normalized save')
g=fixture();before=S.encode(g.save);tx=T.new(g);table.remove(tx.session.party,2)
check(not pcall(function()tx:commit()end)and S.encode(g.save)==before,'unaccounted held Pokemon committed')
g=fixture();before=S.encode(g.save);tx=T.new(g);tx.session.storage.boxes[1].mons[1]=tx.session.party[1]
check(not pcall(function()tx:commit()end)and S.encode(g.save)==before,'duplicate Pokemon committed')
g=fixture();tx=T.new(g);local gone=table.remove(tx.session.party,2);tx:confirmRelease(gone);tx:commit()
check(#g.save.party==1 and g.save.boxes[14][30].stableId=='c','confirmed release broke unrelated storage')
g=fixture();tx=T.new(g);g.save.party[1].hp=1;before=S.encode(g.save)
check(not pcall(function()tx:commit()end)and S.encode(g.save)==before,'external save edit clobbered')
g=fixture();g.save.party[1].item='POTION';tx=T.new(g)
check(tx.session.party[1].heldItem==13 and tx.session.party[1].item==13,'held item native ID')
check(not pcall(function()tx.session.party[1].heldItem=0 end),'RS item edit unexpectedly allowed')
g=fixture();g.save.party[1].statusWord=8;g.save.party[1].gen3Markings=2;tx=T.new(g)
check(tx.session.party[1].status==8 and tx.session.party[1].markings==2,'imported status/markings aliases unreadable')
tx.session.party[1].status=nil;tx.session.party[1].markings=3
check(g.save.party[1].statusWord==8 and g.save.party[1].gen3Markings==2,'alias edits leaked before close')
tx:commit();check(g.save.party[1].statusWord==0 and g.save.party[1].gen3Markings==3 and g.save.party[1].markings==3,'imported aliases not committed consistently')
print('PASS_RS_STORAGE_TRANSACTION',checks)
