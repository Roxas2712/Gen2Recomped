-- Actual full import, final renderer, native inputs, and host item callbacks.
return function(game)
  io.stdout:setvbuf('no')
  local U=require('tests.drivers.util')
  local J=require('src.link.Json')
  local Serializer=require('src.core.SaveSerializer')
  local edition=require('src.core.GameVersion').get()
  assert(love.filesystem.getIdentity():match('^oasc%-rs%-bag%-qa%-'))
  local spec=assert(game.data.constants.gen3RsBag)
  assert(spec.version==edition and spec.format==1)
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  assert(#require('src.import.Gen3RsBag').missing(edition)==0)
  local root=assert(os.getenv('RS_BAG_QA_OUT'))
  local report={edition=edition,status='running',captures={},fullStory=false}
  local function persist()
    local f=assert(io.open(root..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  persist()
  U.teleport(game,'MAP_G00_N16',10,12,'up')
  local world=game.stack:top()
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',12)}
  local items={}
  local tm
  for id,def in pairs(game.data.items) do
    if def.pocket=='ITEM' and def.index>0 and not def.name:find('^%?') then items[#items+1]=id end
    if def.machine and def.machine.kind=='TM' and (not tm or def.index<game.data.items[tm].index) then tm=id end
  end
  table.sort(items,function(a,b)return game.data.items[a].index<game.data.items[b].index end)
  assert(#items>=12 and tm and game.data.items.CHERI_BERRY and game.data.items.MACH_BIKE)
  local inventory,order={},{}
  for i=1,12 do inventory[items[i]]=i;order[#order+1]=items[i] end
  for id,qty in pairs({REPEL=2,POKE_BALL=3,CHERI_BERRY=2,MACH_BIKE=1,[tm]=1}) do
    if not inventory[id] then order[#order+1]=id end
    inventory[id]=qty
  end
  game.save.inventory,game.save.bagOrder=inventory,order
  game.save.registeredItem=nil
  local Bag=require('src.ui.Gen3BagMenu')
  local Action=require('src.ui.Gen3ItemMenu')
  local function press(key)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(1)
  end
  local function shot(name)
    assert(U.shot(game,root..'/'..name..'.png'))
    report.captures[#report.captures+1]=name;persist()
  end
  local function immutableDraw(state)
    local before=Serializer.encode(game.save)
    local rng=love.math.getRandomState()
    love.graphics.push('all')
    local ok,err=pcall(state.draw,state)
    love.graphics.pop()
    assert(ok,err)
    assert(Serializer.encode(game.save)==before,'Drawing changed save contents')
    assert(love.math.getRandomState()==rng,'Drawing consumed gameplay RNG')
  end
  for _,gender in ipairs({'male','female'}) do
    game.save.player.gender=gender=='female' and 'girl' or 'boy'
    local bag=Bag.new(game);assert(bag.rs and bag:listRows()==8)
    game.stack:push(bag);U.wait(20)
    for _=1,#bag.rows do press('up')end
    for pocket=1,5 do
      assert(bag.pocket==pocket and bag:selected().id)
      immutableDraw(bag)
      shot(gender..'-pocket-'..pocket)
      local before=Serializer.encode(game.save.inventory)
      press('a')
      local action=game.stack:top();assert(getmetatable(action)==Action and action.rsBag==bag)
      immutableDraw(action);shot(gender..'-actions-'..pocket)
      if pocket==2 then
        press('right');assert(action.index==1,'Native ball menu entered a blank cell')
        press('down');assert(action.entries[action.index].kind=='toss')
      elseif pocket==5 then
        press('right');assert(action.entries[action.index].kind=='register')
      end
      press('b');assert(game.stack:top()==bag)
      assert(Serializer.encode(game.save.inventory)==before,'Cancelled action changed items')
      press('right');U.wait(18)
    end
    assert(bag.pocket==1)
    for _=1,8 do press('down')end
    assert(bag.index==9 and bag.top==2,'Native ninth row does not scroll')
    shot(gender..'-scroll')
    press('right');U.wait(18);press('left');U.wait(18)
    assert(bag.index==9 and bag.top==2,'Pocket return forgot position')
    for _=1,30 do press('down')end
    assert(bag:selected().close)
    shot(gender..'-close')
    press('select');assert(not bag.rsSwap,'Close row entered inventory reorder')
    press('a');assert(game.stack:top()==world,'Close row did not return to world')
  end
  local bag=Bag.new(game,{pocket='KEY_ITEM'});game.stack:push(bag);U.wait(20)
  press('a');press('right');press('a')
  assert(game.stack:top()==bag and game.save.registeredItem=='MACH_BIKE','REGISTER did not use host callback')
  shot('registered-key-item')
  press('a');press('right');press('a')
  assert(not game.save.registeredItem,'REGISTER did not toggle off')
  press('b')
  bag=Bag.new(game,{pocket='BALL'});game.stack:push(bag);U.wait(20)
  local before=Serializer.encode(game.save.inventory)
  press('a');press('down');press('a')
  assert(game.stack:top()==bag and bag.rsToss and bag.rsView.view.mode=='toss')
  press('b');assert(game.stack:top()==bag)
  assert(Serializer.encode(game.save.inventory)==before,'Cancelled toss consumed inventory')
  press('b')
  bag=Bag.new(game,{pocket='ITEM'});game.stack:push(bag);U.wait(20)
  for _=1,#bag.rows do press('up')end
  while bag:selected().id~='REPEL' do assert(not bag:selected().close);press('down')end
  local repelBefore=game.save.inventory.REPEL
  press('a');press('a')
  assert(game.save.inventory.REPEL==repelBefore-1 and game.save.repelSteps==100,'USE did not consume exactly one Repel')
  for _=1,300 do
    if game.stack:top()==bag then break end
    press('a');U.wait(2)
  end
  assert(game.stack:top()==bag,'Item-use message failed to return to bag')
  game.save.repelSteps=0 -- Fixture: the first Repel has expired.
  press('a');press('a')
  assert(game.save.inventory.REPEL==nil,'Last-use removal left an inventory item')
  for _=1,300 do
    if game.stack:top()==bag then break end
    press('a');U.wait(2)
  end
  assert(game.stack:top()==bag,'Last-use message failed to return to bag')
  for _,row in ipairs(bag.rows) do assert(row.id~='REPEL','Bag retained a removed row')end
  immutableDraw(bag);shot('after-item-removal')
  press('b')
  game.save.inventory={};game.save.bagOrder={}
  bag=Bag.new(game);game.stack:push(bag);U.wait(20)
  assert(#bag.rows==1 and bag:selected().close)
  immutableDraw(bag);shot('empty-bag')
  press('a');assert(game.stack:top()==world)
  report.nativeGraphics=true;report.nativeInput=true;report.drawSaveAndRngImmutable=true
  report.registerCallback=true;report.repelCallback=true;report.quantityCancel=true;report.lastItemRemoval=true
  report.cancelAndEmptyReturn=true;report.status='pass'
  persist();print('PASS_RS_BAG_NATIVE '..edition);love.event.quit(0)
end
