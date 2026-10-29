-- Ordinary-input continuous playthrough operator. No save/party/flag mutation.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Collision=require('src.world.Collision')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-leafgreen%-'))
  assert(require('src.core.GameVersion').get()=='leafgreen')
  -- Only this owned hidden QA process ignores desktop/controller events.
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset()
  local lf=io.open(out..'/story-lineage.json','r');local lineage
  if lf then lineage=J.decode(lf:read('*a'));lf:close()end
  local hasSave=require('src.core.SaveData').saveFileExists('leafgreen')
  assert(hasSave==(lineage~=nil),'Only a proven own normal-menu checkpoint may resume a story test')
  if lineage then
    assert(lineage.personalSave==false and lineage.checkpoint.personalSave==false)
    local path=assert(lineage.copiedSaveAbsolutePath)
    local f=io.open(path,'rb')
    if not f then
      -- saveFileExists resolves the host's ordinary flat-save -> slot migration.
      local Save=require('src.core.SaveData')
      path=assert(Save.slotDiskPath('leafgreen',Save.activeSlot('leafgreen')))
      assert(path:match('/saves/leafgreen/slot%d+%.lua$'))
      f=assert(io.open(path,'rb'));lineage.nativeSlotMigration=true
    end
    assert(path:find('/'..love.filesystem.getIdentity()..'/profiles/guest/',1,true))
    local raw=f:read('*a');f:close()
    assert(love.data.encode('string','hex',love.data.hash('sha256',raw))==lineage.checkpoint.sha256)
    lineage.loadedCheckpointSHA256Preserved=true
  end
  U.teleport=function()error('Story acceptance forbids teleport helpers')end
  local report={edition='leafgreen',status='running',commands={},captures={},maps={},events={},
    continuousFromNewGame=true,noTeleport=true,noPartyInjection=true,noDirectStoryFlagEdits=true,fullStoryTested=false}
  local seq=0;local busy=false;local lastMap;local seenParcel=false;local lastParty=0
  if lineage then
    report.lineage=lineage;report.continuedOwnNormalSave=true
    for k,v in pairs(lineage.inherited)do report[k]=v end
    seenParcel=report.parcelObtained
  end
  local function write(name,value)
    local f=assert(io.open(out..'/'..name..'.tmp','w'));f:write(J.encode(value));f:close()
    assert(os.rename(out..'/'..name..'.tmp',out..'/'..name))
  end
  local function fields(t,keys)
    local r={};for _,k in ipairs(keys)do local v=t and t[k];if type(v)=='string'or type(v)=='number'or type(v)=='boolean'then r[k]=v end end;return r
  end
  local function screen(s)
    if not s then return {}end
    local r=fields(s,{'phase','mode','state','index','menuIndex','moveIndex','cursor','waiting','charIndex','pageIndex','lineIndex','screenId'})
    local f=s.update or s.draw;r.source=type(f)=='function'and debug.getinfo(f,'S').short_src or '?'
    if s.pages and s.pageIndex then r.page=s.pages[s.pageIndex]end
    if s.entries then r.entries={};for i,e in ipairs(s.entries)do r.entries[i]=type(e)=='table'and fields(e,{'key','label','name','text'})or tostring(e)end end
    if s.enemy then r.enemy=fields(s.enemy.mon or s.enemy,{'species','level','hp','status'})end
    if s.player then r.battler=fields(s.player.mon or s.player,{'species','level','hp','status'})end
    if s.trainer then r.trainer=fields(s.trainer,{'name','class','id','index'})end
    return r
  end
  local function snapshot()
    local world=game.overworld;local state={seq=seq,busy=busy,frame=U.frame(),top=screen(game.stack:top()),party={},
      inventory={},flags={},vars={},stack={}}
    for i,s in ipairs(game.stack.states or {})do state.stack[i]=screen(s)end
    for i,m in ipairs(game.save.party or {})do
      local p=fields(m,{'species','name','level','hp','status','exp'});p.maxHp=m.stats and m.stats.hp;p.moves={}
      for n,mv in ipairs(m.moves or {})do p.moves[n]=fields(mv,{'id','pp','maxPp'})end;state.party[i]=p
    end
    for k,v in pairs(game.save.inventory or {})do state.inventory[k]=v
      if tostring(k):find('PARCEL')and tonumber(v)and v>0 then seenParcel=true;report.parcelObtained=true end
    end
    if (state.inventory.TM39 or 0)>0 then report.brockTmRewardObserved=true end
    if #state.party>0 and lastParty==0 and not report.starter then
      report.starter=state.party[1];report.events[#report.events+1]={kind='first-party-member',frame=U.frame(),mon=state.party[1]}
    end
    lastParty=#state.party
    for k,v in pairs(game.save.flags or {})do if v then state.flags[k]=v end end
    for k,v in pairs(game.save.gen3Vars or {})do state.vars[tostring(k)]=v end
    report.pokedexObtained=state.flags.FLAG_G3_0829==true
    if seenParcel and report.pokedexObtained then
      local held=false;for k,v in pairs(state.inventory)do if tostring(k):find('PARCEL')and tonumber(v)and v>0 then held=true end end
      if not held then report.parcelReturned=true end
    end
    if world and world.map then
      local map=world.map;state.map=fields(map,{'id','widthCells','heightCells'});state.map.name=map.def.name
      state.player=fields(world.player,{'cellX','cellY','facing','moving','inputLocked','turnTimer','progress','elevation'})
      state.scriptRunning=world.runner and world.runner:isRunning()or false
      state.entities={};for _,e in ipairs(world.entities or {})do
        local r=fields(e,{'id','cellX','cellY','facing','hidden','passable','moving'})
        r.def=fields(e.def,{'id','localId','script','text','sprite','flag','movementType'});state.entities[#state.entities+1]=r
      end
      local rows={}
      for y=0,map.heightCells-1 do local row={};for x=0,map.widthCells-1 do
        row[#row+1]=map:isWalkableCell(x,y)and '.'or '#'
      end;rows[#rows+1]=table.concat(row)end
      state.map.walkable=rows;state.map.warps=map.def.warps;state.map.connections=map.def.connections
      state.map.coordEvents=map.def.coordEvents;state.map.signs=map.def.signs
      if map.id~=lastMap then
        lastMap=map.id;report.maps[#report.maps+1]={id=map.id,x=world.player.cellX,y=world.player.cellY,frame=U.frame()}
      end
    end
    write('story-state.json',state);write('result.json',report)
    return state
  end
  local inputLog
  local function press(k,n)
    assert(({a=true,b=true,start=true,select=true,up=true,down=true,left=true,right=true,l=true,r=true})[k])
    if inputLog then inputLog[#inputLog+1]={key=k,heldFrames=1,releaseFrames=n or 1,frame=U.frame()}end
    game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 1)
  end
  local function shot(name)
    assert(name:match('^[%w_-]+$'))
    local s=game.stack:top();local old=Serialize.encode(game.save);local rng=love.math.getRandomState()
    local ok,why=require('src.render.GraphicsScope').call(s.draw,s);assert(ok,why)
    assert(old==Serialize.encode(game.save)and rng==love.math.getRandomState(),'Story draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
  end
  local function waitFor(fn,n)for _=1,n do if fn()then return end;U.wait(1)end;error('Story boot timed out')end
  press('b',10);press('b',10)
  local Title=require('src.ui.Gen3TitleFRLG')
  waitFor(function()return getmetatable(game.stack:top())==Title and game.stack:top().phase=='run'end,1400)
  press('start',150);assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  if lineage then
    assert(game.stack:top().items[1].key=='continue');press('a',120)
    local w=assert(game.overworld);local expected=lineage.checkpoint.snapshotAfterSaveCommand
    assert(game.stack:top()==w and w.map.id==expected.map.id)
    assert(w.player.cellX==expected.player.cellX and w.player.cellY==expected.player.cellY)
    assert(#game.save.party==#expected.party)
    for i,m in ipairs(game.save.party)do
      local e=expected.party[i]
      for _,k in ipairs({'species','level','hp','status','exp'})do assert(m[k]==e[k],'Continue changed party '..k)end
      assert(m.stats.hp==e.maxHp and #m.moves==#e.moves)
      for j,mv in ipairs(m.moves)do assert(mv.id==e.moves[j].id and mv.pp==e.moves[j].pp)end
    end
    assert(Serialize.encode(game.save.inventory)==Serialize.encode(expected.inventory),'Continue changed inventory')
    for k,v in pairs(expected.flags)do assert(game.save.flags[k]==v,'Continue lost story flag '..k)end
    report.continuedThroughUI=true;report.checkpointPartyFlagsAndInventoryPreserved=true
    shot('story-continued-normal-checkpoint');snapshot()
  else
    assert(game.stack:top().items[1].key=='newGame');press('a',100)
    for _=1,2500 do
      if game.overworld and game.stack:top()==game.overworld then break end
      press('a',2)
    end
    assert(game.overworld and game.stack:top()==game.overworld and #(game.save.party or {})==0)
    report.newGameThroughUI=true;report.initialPartyEmpty=true;shot('story-new-game-upstairs');snapshot()
  end
  local movement=require('tests.drivers.story_movement').new(game,U,Collision,function()return inputLog end)
  local freeField,step,pathTo=movement.freeField,movement.step,movement.pathTo
  while true do
    local f=io.open(out..'/story-commands.json','r');local commands
    if f then local raw=f:read('*a');f:close();commands=J.decode(raw)end
    local command=commands and commands[seq+1]
    if not command then U.wait(60);snapshot()
    else
      busy=true;snapshot();local record={seq=seq+1,input=command,before=snapshot(),outcome='done',ordinaryInputs={}}
      inputLog=record.ordinaryInputs
      if command.op=='press'then
        for _=1,math.min(tonumber(command.times)or 1,200)do press(assert(command.button),command.wait or 12)end
      elseif command.op=='wait'then U.wait(math.min(command.frames or 60,3600))
      elseif command.op=='step'then local ok,why=step(assert(command.dir));if not ok then record.outcome=why end
      elseif command.op=='hold'then
        assert(type(command.frames)=='number'and command.frames>=1 and command.frames<=6000)
        inputLog[#inputLog+1]={key=command.button,heldFrames=command.frames,releaseFrames=command.wait or 8,frame=U.frame()}
        game.input:overlayPressed(command.button);U.wait(command.frames)
        game.input:overlayReleased(command.button);U.wait(command.wait or 8)
      elseif command.op=='goto'then
        local w=game.overworld;local originalMap=w.map.id
        for _=1,150 do
          if not freeField()or w.map.id~=originalMap then record.outcome='event/map transition';break end
          if w.player.cellX==command.x and w.player.cellY==command.y then break end
          local path=pathTo(command.x,command.y)
          if not path or not path[1]then record.outcome='no walkable path';break end
          local ok,why=step(path[1]);if not ok then record.outcome=why;break end
        end
      elseif command.op=='advance'then
        for _=1,math.min(command.frames or 600,12000)do
          if freeField()then break end
          press('a',command.wait or 12);snapshot()
        end
      elseif command.op=='battle-attack'then record.outcome=require('tests.drivers.story_battle').attack(game,U,press,assert(tonumber(command.slot)))
      elseif command.op=='shot'then shot(assert(command.name))
      elseif command.op=='finish'then
        snapshot()
        assert(report.starter and report.starter.level==5,'Starter was not acquired naturally at level five')
        assert(report.parcelObtained and report.parcelReturned and report.pokedexObtained,'Continuous parcel/Pokedex sequence incomplete')
        assert(game.save.flags.FLAG_G3_0820 and game.save.flags.FLAG_G3_0254,'Brock and badge not complete')
        assert(report.brockTmRewardObserved,'Brock TM reward was never observed in ordinary progress')
        report.badgesAtFinish=require('src.inventory.Badges').count(game.data,game.save)
        -- The inherited normal NEW GAME/SAVE trace proves natural progress;
        -- an opening-only level cap must not reject later earned experience.
        report.partyAtFinish=snapshot().party
        for _,m in ipairs(game.save.party)do assert(m.level>=1 and m.level<=100,'Invalid natural party level')end
        report.continuousOpeningToBrock=true;report.status='pass';seq=seq+1;busy=false;snapshot()
        print('PASS_LEAFGREEN_CONTINUOUS_OPENING');love.event.quit(0);return
      else error('Unsupported ordinary-input story command: '..tostring(command.op))end
      inputLog=nil;seq=seq+1;busy=false;record.after=snapshot();report.commands[#report.commands+1]=record;write('result.json',report)
    end
  end
end
