-- Ordinary-input continuous playthrough operator. No save/party/flag mutation.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Collision=require('src.world.Collision')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  -- Hidden SDL windows can still receive desktop typing. Only this owned QA
  -- process ignores physical events; the trace uses the ordinary overlay API.
  for _,event in ipairs({'keypressed','keyreleased','textinput','gamepadpressed',
    'gamepadreleased','joystickpressed','joystickreleased','joystickaxis','joystickhat',
    'touchpressed','touchreleased','touchmoved','mousepressed','mousereleased'})do
    love[event]=function()end
  end
  game.input:reset()
  local lf=io.open(out..'/story-lineage.json','r');local lineage,originalSave
  if lf then lineage=J.decode(lf:read('*a'));lf:close()end
  local Save=require('src.core.SaveData')
  assert(Save.saveFileExists(edition)==(lineage~=nil),'Only a qualified own checkpoint may resume')
  local function checkpointBytes()
    local relative=Save.saveFilename(edition);assert(relative:match('^profiles/guest/')and not relative:find('..',1,true))
    local path=love.filesystem.getSaveDirectory()..'/'..relative
    local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close()
    assert(love.data.encode('string','hex',love.data.hash('sha256',raw))==lineage.checkpoint.sha256,'Checkpoint bytes changed')
    lineage.resolvedSaveRelativePath=relative
    return raw
  end
  if lineage then
    assert(not lineage.personalSave and not lineage.checkpoint.personalSave)
    originalSave=assert(Serialize.decode(checkpointBytes()))
    lineage.loadedCheckpointSHA256Preserved=true
  end
  U.teleport=function()error('Story acceptance forbids teleport helpers')end
  local report={edition=edition,status='running',commands={},captures={},maps={},events={},
    continuousFromNewGame=true,noTeleport=true,noPartyInjection=true,noDirectStoryFlagEdits=true,fullStoryTested=false}
  local Sound=require('src.core.Sound');local nativeSoundPlay=Sound.play
  Sound.play=function(data,name,...)
    local source=nativeSoundPlay(data,name,...)
    if data==game.data and name=='Level_Up'then
      local role=assert(data.audio.sfx.Level_Up)
      assert(source and role.m4a==367 and role.fanfare=='LEVEL_UP','Natural RS level-up fanfare missing')
      report.events[#report.events+1]={kind='native-level-up-audio',frame=U.frame(),index=role.m4a,sourceCreated=true}
    elseif data==game.data and ({Save=55,Run=17,Start_Menu=6,Select=5,Purchase=95})[name]then
      local expected=({Save=55,Run=17,Start_Menu=6,Select=5,Purchase=95})[name]
      assert(source and data.audio.sfx[name].m4a==expected,'Natural RS effect missing: '..name)
      report.events[#report.events+1]={kind='native-shared-effect-audio',role=name,frame=U.frame(),index=expected,sourceCreated=true}
    end
    return source
  end
  local seq=0;local busy=false;local lastMap;local lastParty=0
  if lineage then
    report.lineage=lineage;report.continuedOwnNormalSave=true
    for key,value in pairs(lineage.inherited)do report[key]=value end
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
    local r=fields(s,{'phase','mode','state','index','menuIndex','moveIndex','cursor','waiting','charIndex','pageIndex','lineIndex','screenId','pocket','keepOpen','rs'})
    local f=s.update or s.draw;r.source=type(f)=='function'and debug.getinfo(f,'S').short_src or '?'
    if s.pages and s.pageIndex then r.page=s.pages[s.pageIndex]end
    if s.entries then r.entries={};for i,e in ipairs(s.entries)do r.entries[i]=type(e)=='table'and fields(e,{'key','label','name','text'})or tostring(e)end end
    if s.screenId=='Gen3StartMenu'and s.rows then
      r.rows={};for i,row in ipairs(s.rows)do r.rows[i]=fields(row,{'key','id','label'})end
    end
    if s.enemy then r.enemy=fields(s.enemy.mon or s.enemy,{'species','level','hp','status'})end
    if s.player then r.battler=fields(s.player.mon or s.player,{'species','level','hp','status'})end
    if s.trainer then r.trainer=fields(s.trainer,{'name','class','className','id','index'})end
    if s.musicKind then r.musicKind=s.musicKind end
    if s.player and s.player.mon and s.enemy and s.enemy.mon then
      r.nativeBattle={turnCount=s.turnCount,result=s.result,
        player=fields(s.player,{'lastMove','gbaWrapTurns','gbaWrapMove','gbaWrapSource','trappingTurns','boundTurns'}),
        enemy=fields(s.enemy,{'lastMove','gbaWrapTurns','gbaWrapMove','gbaWrapSource','trappingTurns','boundTurns'}),
        playerStages=fields(s.player.stages,{'attack','defense','spatk','spdef','speed','accuracy','evasion'}),
        enemyStages=fields(s.enemy.stages,{'attack','defense','spatk','spdef','speed','accuracy','evasion'})}
      if s.current then r.nativeBattle.current=fields(s.current,{'kind','text','anim'})end
    end
    if s.screenId=='Gen3RsChoice'and s.scene then
      r.nativeChoiceKind=s.scene.kind;r.nativeChoiceStyle=s.scene.style or'field'
    end
    if s.screenId=='Gen3RsSaveMenu'and s.scene then
      r.nativeSaveKind=s.nativeSaveKind;r.phase=s.scene._phase;r.index=s.scene.cursor
    end
    if s.screenId=='Gen3RsPcRoot'and s.items then
      r.nativePcRoot={};for i,row in ipairs(s.items)do r.nativePcRoot[i]=row.label end
    elseif s.screenId=='Gen3RsPlayerPC'and s.pc then
      r.nativePc=fields(s.pc,{'mode','cursor','_status'})
    elseif s.screenId=='Gen3RsItemStorage'and s.ui then
      r.nativeItemStorage=fields(s.ui,{'state','row','scroll','quantity','yesCursor','swapFrom','_toss'})
    end
    if s.rsView and s.rsView.view then
      r.nativeRsBag=fields(s.rsView.view,{'mode','tossQty'})
      if s.selected then r.selected=fields(s:selected(),{'id','qty','close'})end
    end
    if s.screenId=='Gen3RsShop'and s.shop then
      r.nativeShop=fields(s.shop,{'state','mode','cursor','row','scroll','qty','_totalCost','_maxQty','yesCursor','_itemId','_martType','_status'})
    elseif s.screenId=='Gen3RsShopSale'and s.flow then
      r.nativeSale=fields(s.flow,{'state','qty','owned','unit','yesNo','itemId','text','sold'})
    end
    if s.screenId=='Gen3RsPokenav'and type(s.state)=='table'then
      r.pokenav=fields(s.state,{'menu','cursor','phase','headerScroll','dotOffset','helpOverride'})
      if s.state.feature then
        r.pokenav.feature=fields(s.state.feature,{'index','top','detail','zoomed','x','y','section','name','scrollX','scrollY','selecting'})
        if s.state.feature.entries then r.pokenav.entryCount=#s.state.feature.entries end
      end
    end
    if s.rsWally then
      r.wally={stage=s.rsWally.state.wallyState,events=s.rsWally.events,hidden=s.rsWally.hidden,hideHud=s.rsWally.hideHud,recallFrame=s.rsWally.recallFrame}
      r.showPlayerBack=s.showPlayerBack;r.demoName=s.demoName;r.playerBackPath=s.demoBackPath
      r.playerPP=s.player and s.player.curMoves and s.player.curMoves[1].pp
    end
    if s.gen3Ball then r.ball=fields(s.gen3Ball,{'phase','phaseFrame','sendOut','monHidden','caught'})end
    return r
  end
  local function snapshot(persistReport)
    local world=game.overworld;local state={seq=seq,busy=busy,frame=U.frame(),top=screen(game.stack:top()),money=game.save.money,party={},
      inventory={},pcItems={},pcOrder={},flags={},vars={},stack={},music=require('src.core.Music').current()}
    state.savedGameCount=(game.save.gen3Stats or{})[0]or 0
    state.bike={onBike=game.save.onBike==true,kind=game.save.bikeKind,registeredItem=game.save.registeredItem}
    for i,s in ipairs(game.stack.states or {})do state.stack[i]=screen(s)end
    for i,m in ipairs(game.save.party or {})do
      local p=fields(m,{'species','name','level','hp','status','exp'});p.maxHp=m.stats and m.stats.hp;p.moves={}
      for n,mv in ipairs(m.moves or {})do p.moves[n]=fields(mv,{'id','pp','maxPp'})end;state.party[i]=p
    end
    for k,v in pairs(game.save.inventory or {})do state.inventory[k]=v end
    for k,v in pairs(game.save.pcItems or{})do state.pcItems[k]=v end
    for i,id in ipairs(game.save.pcOrder or{})do state.pcOrder[i]=id end
    if #state.party>0 and lastParty==0 and not report.starter then
      report.starter=state.party[1];report.events[#report.events+1]={kind='first-party-member',frame=U.frame(),mon=state.party[1]}
    end
    lastParty=#state.party
    for k,v in pairs(game.save.flags or {})do if v then state.flags[k]=v end end
    for k,v in pairs(game.save.gen3Vars or {})do state.vars[tostring(k)]=v end
    report.pokedexObtained=state.flags[assert(game.data.constants.gen3StartMenu.pokedexFlag)]==true
    if world and world.map then
      local map=world.map;state.map=fields(map,{'id','widthCells','heightCells'});state.map.name=map.def.name
      state.player=fields(world.player,{'cellX','cellY','facing','moving','inputLocked','turnTimer','progress','elevation',
        'machBike','acroBike','bikeCounter','rsMachSpeed','acroState','acroHold','acroHopClock'})
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
    write('story-state.json',state)
    -- Keep idle heartbeats small; completed input receipts flush the full ledger.
    if persistReport~=false then write('result.json',report)end
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
  press('a',10);press('start',20)
  waitFor(function()local top=game.stack:top();return top and top.kind=='title'and top.scene.phase=='phase3'end,6000)
  press('start',100);assert(getmetatable(game.stack:top())==require('src.ui.Gen3MainMenu'))
  if lineage then
    local menu=game.stack:top();assert(menu.items[1].key=='continue')
    if menu.rsNative then
      assert(menu.rsNative.scene.info,'Original RS CONTINUE must show its saved stats')
      shot('story-continue-summary');press('a',120)
    else
      press('a',30)
      assert(game.stack:top().info,'Host CONTINUE must show its existing save summary')
      shot('story-continue-summary');press('a',120)
    end
    local w=assert(game.overworld);local e=lineage.checkpoint.snapshotAfterSaveCommand
    assert(game.stack:top()==w and w.map.id==e.map.id and w.player.cellX==e.player.cellX and w.player.cellY==e.player.cellY)
    checkpointBytes() -- includes any ordinary flat-save -> native-slot adoption
    for _,key in ipairs({'name','gender','rival','map','x','y','facing'})do
      assert(game.save.player[key]==originalSave.player[key],'Continue changed player '..key)
    end
    for _,key in ipairs({'party','inventory','money','pokedex'})do
      assert(Serialize.encode(game.save[key])==Serialize.encode(originalSave[key]),'Continue changed saved '..key)
    end
    -- ClearTempFieldEventData clears the first four flag bytes on map load.
    -- A smashed rock uses FLAG_TEMP_11, so its in-memory reset is authentic;
    -- FLAG_TEMP_20 is outside those bytes and must remain protected.
    local keys={};report.transientFlagsCleared={}
    for key in pairs(originalSave.flags or{})do keys[key]=true end
    for key in pairs(game.save.flags or{})do keys[key]=true end
    for key in pairs(keys)do
      local before,after=(originalSave.flags or{})[key],(game.save.flags or{})[key]
      if before~=after then
        local id=type(key)=='string'and tonumber(key:match('^FLAG_G3_(%x%x%x%x)$'),16)
        assert(id and id<0x20 and after==nil,'Continue changed persistent flag '..tostring(key))
        report.transientFlagsCleared[#report.transientFlagsCleared+1]=key
      end
    end
    table.sort(report.transientFlagsCleared)
    local function permanentVars(vars)
      local out={}
      for key,value in pairs(vars or {})do
        if key>=0x4010 and key<0x8000 then out[key]=value end
      end
      return out
    end
    assert(Serialize.encode(permanentVars(game.save.gen3Vars))==Serialize.encode(permanentVars(originalSave.gen3Vars)),
      'Continue changed persistent script variables')
    report.continuedThroughUI=true;report.checkpointFullSavePreserved=true
    report.transientVarsExcluded='Native RS VAR_TEMP_0..F (4000..400F) and special vars (8000+) are map/call-local'
    shot('story-continued-normal-checkpoint');snapshot()
  else
    assert(game.stack:top().items[1].key=='newGame');press('a',100)
    local speechCaptured=false
    for _=1,4000 do
      if game.overworld and game.stack:top()==game.overworld then break end
      for _,screen in ipairs(game.stack.states)do
        if not speechCaptured and getmetatable(screen)==require('src.ui.BirchSpeech')then
          speechCaptured=true;U.wait(60);shot('story-birch-greeting')
        end
      end
      press('a',2)
    end
    assert(game.overworld and game.stack:top()==game.overworld and #(game.save.party or {})==0)
    report.newGameThroughUI=true;report.initialPartyEmpty=true;shot('story-new-game-first-field');snapshot()
  end
  local movement=require('tests.drivers.story_movement').new(game,U,Collision,function()return inputLog end)
  local freeField,step,pathTo=movement.freeField,movement.step,movement.pathTo
  -- Resolve one chosen move through the actual controller. Stop at subordinate
  -- menus (learning/naming/party etc.), and never write battle or save fields.
  local function attack(slot)return require('tests.drivers.story_battle').attack(game,U,press,slot)end

  while true do
    local f=io.open(out..'/story-commands.json','r');local commands
    if f then local raw=f:read('*a');f:close();commands=J.decode(raw)end
    local command=commands and commands[seq+1]
    if not command then U.wait(60);snapshot(false)
    else
      busy=true;snapshot(false);local record={seq=seq+1,input=command,before=snapshot(false),outcome='done',ordinaryInputs={}}
      inputLog=record.ordinaryInputs
      if command.op=='press'then
        for _=1,math.min(tonumber(command.times)or 1,200)do press(assert(command.button),command.wait or 12)end
      elseif command.op=='wait'then U.wait(math.min(command.frames or 60,3600))
      elseif command.op=='step'then local ok,why=step(assert(command.dir));if not ok then record.outcome=why end
      elseif command.op=='hold'then
        assert(type(command.frames)=='number'and command.frames>=1 and command.frames<=6000)
        inputLog[#inputLog+1]={key=command.button,heldFrames=command.frames,
          releaseFrames=command.wait or 8,frame=U.frame()}
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
          press('a',command.wait or 12);snapshot(false)
        end
      elseif command.op=='battle-attack'then record.outcome=attack(assert(tonumber(command.slot)))
      elseif command.op=='shot'then shot(assert(command.name))
      elseif command.op=='verify-continue'then
        assert(report.continuedThroughUI and report.checkpointFullSavePreserved)
        report.status='pass';seq=seq+1;busy=false;snapshot()
        print('PASS_RS_NATIVE_CHECKPOINT_CONTINUE');love.event.quit(0);return
      elseif command.op=='finish'then
        snapshot()
        assert(report.starter and report.starter.level==5,'Starter was not acquired naturally at level five')
        assert(require('src.inventory.Badges').count(game.data,game.save)>=1,'RS first badge is not complete')
        local dex=assert(game.data.constants.gen3StartMenu.pokedexFlag)
        assert(game.save.flags[dex],'RS Pokedex receipt is not complete')
        -- Continuations now go beyond the opening. Natural starter lineage,
        -- full checkpoint equality and the ordinary input trace remain the
        -- proof; a level cap must not reject later earned experience.
        report.partyAtFinish=snapshot().party
        for _,m in ipairs(game.save.party)do assert(m.level>=1 and m.level<=100,'Invalid natural party level')end
        report.continuousOpeningToFirstBadge=true;report.status='pass';seq=seq+1;busy=false;snapshot()
        print('PASS_RS_CONTINUOUS_OPENING');love.event.quit(0);return
      else error('Unsupported ordinary-input story command: '..tostring(command.op))end
      inputLog=nil;seq=seq+1;busy=false;record.after=snapshot(false);report.commands[#report.commands+1]=record;write('result.json',report)
    end
  end
end
