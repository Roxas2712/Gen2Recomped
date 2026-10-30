-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared medicine fixtures; never accepted as ordinary story progress.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local Serialize=require('src.core.SaveSerializer');local Pokemon=require('src.pokemon.Pokemon')
 local Bag=require('src.ui.Gen3BagMenu');local Party=require('src.ui.Gen3PartyMenu')
 local TextBox=require('src.render.TextBox');local edition=require('src.core.GameVersion').get()
 local out=assert(os.getenv('EDITION_QA_OUT'))
 assert(edition=='ruby'or edition=='sapphire')
 assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset()
 local report={edition=edition,status='running',preparedMedicineFixture=true,continuousStory=false,
  captures={},cases={},drawSaveAndRngPreserved=true}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 persist();U.freshSave(game);U.teleport(game,'MAP_G11_N05',7,7,'up');U.wait(60)
 local world=assert(game.overworld);assert(game.stack:top()==world)
 local function press(key,n)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(n or 18)end
 local function shot(name)
  local saved=Serialize.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
  local ok,why=require('src.render.GraphicsScope').call(top.draw,top);assert(ok,why)
  assert(saved==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Drawing changed save/RNG')
  assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
 end
 local first=Pokemon.new(game.data,'GROVYLE',18);local second=Pokemon.new(game.data,'ZIGZAGOON',7)
 game.save.party={first,second};game.save.inventory={POTION=3}
 local bag=Bag.new(game,{});game.stack:push(bag);U.wait(120)
 assert(bag.rs and bag:selected().id=='POTION')
 local function result(which,name,expectedHp,expectedCount)
  press('a',30);local action=game.stack:top();assert(action.entries[action.index].kind=='use')
  press('a',60);local picker=game.stack:top();assert(getmetatable(picker)==Party and picker.keepOpen and picker.rsNative)
  U.wait(90);if which==2 then press('right')end
  assert(picker.index==which)
  local closes,prompts=0,0;local close=picker.close;local policy=picker.rsNative.policy;local prompt=policy.drawPrompt
  picker.close=function(self,...)closes=closes+1;return close(self,...)end
  policy.drawPrompt=function(...)prompts=prompts+1;return prompt(...)end
  press('a',30)
  for _=1,600 do if getmetatable(game.stack:top())==TextBox then break end;U.wait(1)end
  local box=game.stack:top();assert(getmetatable(box)==TextBox and box.rsMachineParty==picker)
  U.wait(240);assert(game.stack:top()==box and box.done,'Result must await ordinary acknowledgment')
  assert(first.hp==expectedHp[1]and second.hp==expectedHp[2]and game.save.inventory.POTION==expectedCount)
  assert(closes==0,'Picker closed before acknowledgment')
  local previous=prompts;shot(name);assert(prompts==previous,'Parent prompt was painted beneath medicine result')
  press('a',30)
  assert(game.stack:top()==bag and closes==1,'Acknowledgment must close exactly its own picker')
  assert(game.save.inventory.POTION==expectedCount,'Acknowledgment consumed the item again')
  policy.drawPrompt=prompt
  report.cases[#report.cases+1]={name=name,oneNativeWindow=true,callbackOnce=true,hp={first.hp,second.hp},count=expectedCount}
  persist()
 end
 first.hp=first.stats.hp-15
 result(1,'medicine-lead-result',{first.stats.hp,second.stats.hp},2)
 result(1,'medicine-full-hp-refusal',{first.stats.hp,second.stats.hp},2)
 second.hp=math.max(1,second.stats.hp-20)
 result(2,'medicine-second-slot-result',{first.stats.hp,second.stats.hp},1)
 press('a',30);press('a',60);local picker=game.stack:top();assert(getmetatable(picker)==Party)
 U.wait(90);press('b',30);assert(game.stack:top()==bag and game.save.inventory.POTION==1)
 report.cases[#report.cases+1]={name='cancel-target',inventoryPreserved=true}
 shot('medicine-bag-after-return');press('b',30);assert(game.stack:top()==world)
 report.status='pass';persist();print('PASS_RS_NATIVE_MEDICINE_MESSAGE '..edition);love.event.quit(0)
end
