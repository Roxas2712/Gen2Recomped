-- Ordinary-input continuous playthrough operator. No save/party/flag mutation.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Serialize=require('src.core.SaveSerializer');local Collision=require('src.world.Collision')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local edition=require('src.core.GameVersion').get()
  assert(edition=='ruby'or edition=='sapphire')
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  assert(not require('src.core.SaveData').saveFileExists(edition),'RS baseline needs a fresh own QA profile')
  U.teleport=function()error('Story acceptance forbids teleport helpers')end
  local report={edition=edition,status='running',commands={},captures={},maps={},events={},inputs={},
    continuousFromNewGame=true,noTeleport=true,noPartyInjection=true,noDirectStoryFlagEdits=true,fullStoryTested=false}
  local seq=0;local busy=false;local lastMap;local lastParty=0
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
    for k,v in pairs(game.save.inventory or {})do state.inventory[k]=v end
    if #state.party>0 and lastParty==0 and not report.starter then
      report.starter=state.party[1];report.events[#report.events+1]={kind='first-party-member',frame=U.frame(),mon=state.party[1]}
    end
    lastParty=#state.party
    for k,v in pairs(game.save.flags or {})do if v then state.flags[k]=v end end
    for k,v in pairs(game.save.gen3Vars or {})do state.vars[tostring(k)]=v end
    report.pokedexObtained=state.flags[assert(game.data.constants.gen3StartMenu.pokedexFlag)]==true
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
  local function press(k,n)
    local input={key=k,frame=U.frame(),commandSeq=seq+1}
    local top=game.stack:top()
    if k=='a'and getmetatable(top)==require('src.ui.ChoiceBox')and top.index==1 then
      for _,s in ipairs(game.stack.states)do
        if getmetatable(s)==require('src.ui.Gen3StartMenu')then
          input.before={top=screen(top),stack={}}
          for i,row in ipairs(game.stack.states)do input.before.stack[i]=screen(row)end
          report.normalSaveYesInput=#report.inputs+1
        end
      end
    end
    report.inputs[#report.inputs+1]=input
    assert(({a=true,b=true,start=true,select=true,up=true,down=true,left=true,right=true,l=true,r=true})[k])
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
  local dirs={up={0,-1},down={0,1},left={-1,0},right={1,0}}
  local function freeField()
    local w=game.overworld
    return w and game.stack:top()==w and not w.player.moving and not w.player.inputLocked and not(w.runner and w.runner:isRunning())
  end
  local function step(dir)
    assert(dirs[dir]);if not freeField()then return false,'event/UI is active'end
    local w=game.overworld;local map=w.map.id;local x,y=w.player.cellX,w.player.cellY
    game.input:overlayPressed(dir)
    for _=1,60 do U.wait(1)
      if w.map.id~=map or w.player.moving or w.player.cellX~=x or w.player.cellY~=y or not freeField()then break end
    end
    game.input:overlayReleased(dir)
    for _=1,120 do if not game.overworld.player.moving then break end;U.wait(1)end
    U.wait(8)
    return w.map.id~=map or w.player.cellX~=x or w.player.cellY~=y,'blocked or interrupted'
  end
  local function pathTo(tx,ty)
    local w=game.overworld;local map=w.map;local q={{w.player.cellX,w.player.cellY}};local seen={};local prev={}
    local function key(x,y)return x..','..y end
    seen[key(q[1][1],q[1][2])]=true
    local head=1
    while q[head]do
      local p=q[head];head=head+1
      if p[1]==tx and p[2]==ty then
        local path={};local k=key(tx,ty)
        while prev[k]do local e=prev[k];table.insert(path,1,e.dir);k=e.from end
        return path
      end
      for _,dir in ipairs({'up','down','left','right'})do
        local d=dirs[dir];local x,y=p[1]+d[1],p[2]+d[2];local k=key(x,y)
        if not seen[k]and map:inBounds(x,y)and map:isWalkableCell(x,y)
           and not Collision.occupied(w.entities or {},x,y,w.player)then
          seen[k]=true;prev[k]={dir=dir,from=key(p[1],p[2])};q[#q+1]={x,y}
        end
      end
    end
  end
  local commands=J.decode([=[[{"op":"shot","name":"story-truck-before-exit"},{"op":"step","dir":"right"},{"op":"wait","frames":180},{"op":"shot","name":"story-truck-door-opening"},{"op":"step","dir":"right"},{"op":"wait","frames":120},{"wait":10,"op":"advance","frames":120},{"op":"shot","name":"story-first-littleroot"},{"wait":10,"op":"advance","frames":200},{"x":8,"op":"goto","y":2},{"op":"step","dir":"left"},{"op":"wait","frames":60},{"op":"shot","name":"story-room-before-clock"},{"x":5,"op":"goto","y":2},{"button":"up","op":"press","wait":8},{"button":"a","op":"press","wait":60},{"op":"shot","name":"story-clock-interaction"},{"op":"advance","frames":50},{"op":"shot","name":"story-clock-ui"},{"op":"advance","frames":50},{"op":"shot","name":"story-room-after-clock"},{"x":7,"op":"goto","y":2},{"op":"step","dir":"up"},{"op":"advance","frames":100},{"op":"shot","name":"story-house-downstairs-after-clock"},{"op":"advance","frames":150},{"x":9,"op":"goto","y":7},{"op":"step","dir":"down"},{"op":"advance","frames":100},{"op":"shot","name":"story-littleroot-after-clock"},{"x":14,"op":"goto","y":9},{"op":"step","dir":"up"},{"op":"advance","frames":150},{"op":"shot","name":"story-rivals-house"},{"x":2,"op":"goto","y":3},{"op":"step","dir":"up"},{"op":"advance","frames":150},{"op":"shot","name":"story-rival-room"},{"op":"advance","frames":120},{"x":7,"op":"goto","y":2},{"button":"right","op":"press","wait":8},{"button":"a","op":"press","wait":20},{"op":"advance","frames":150},{"op":"shot","name":"story-rival-first-meeting"},{"x":6,"op":"goto","y":2},{"button":"right","op":"press","wait":8},{"button":"a","op":"press","wait":20},{"op":"advance","frames":180},{"op":"shot","name":"story-rival-first-dialogue"},{"x":1,"op":"goto","y":2},{"op":"step","dir":"up"},{"op":"wait","frames":90},{"x":2,"op":"goto","y":7},{"op":"step","dir":"down"},{"op":"advance","frames":100},{"x":10,"op":"goto","y":2},{"op":"step","dir":"up"},{"op":"advance","frames":180},{"op":"shot","name":"story-littleroot-north"},{"op":"step","dir":"right"},{"op":"step","dir":"up"},{"op":"advance","frames":180},{"op":"step","dir":"up"},{"op":"step","dir":"up"},{"op":"advance","frames":180},{"op":"shot","name":"story-route-101-first-entry"},{"op":"advance","frames":250},{"op":"shot","name":"story-birch-rescue-request"},{"x":7,"op":"goto","y":15},{"button":"up","op":"press","wait":8},{"button":"a","op":"press","wait":60},{"op":"native-starter"},{"times":100,"button":"a","op":"press","wait":10},{"op":"shot","name":"story-first-rescue-battle-result"},{"times":100,"button":"a","op":"press","wait":12},{"op":"advance","frames":150},{"op":"shot","name":"story-after-rescue-lab"},{"op":"advance","frames":250},{"op":"shot","name":"story-birch-lab-after-nickname"},{"button":"start","op":"press","wait":30},{"op":"shot","name":"story-lab-start-menu"},{"times":3,"button":"down","op":"press","wait":8},{"button":"a","op":"press","wait":45},{"op":"shot","name":"story-lab-save-question"},{"button":"a","op":"press","wait":30},{"op":"shot","name":"story-lab-save-yes-no"},{"op":"advance","frames":100},{"op":"shot","name":"story-lab-normal-save-done"},{"op":"finish"}]]=])
  while true do
    local command=commands[seq+1]
    if not command then U.wait(60);snapshot()
    else
      busy=true;snapshot();local record={seq=seq+1,input=command,before=snapshot(),outcome='done'}
      if command.op=='press'then
        for _=1,math.min(tonumber(command.times)or 1,200)do press(assert(command.button),command.wait or 12)end
      elseif command.op=='wait'then U.wait(math.min(command.frames or 60,3600))
      elseif command.op=='step'then local ok,why=step(assert(command.dir));if not ok then record.outcome=why end
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
      elseif command.op=='shot'then shot(assert(command.name))
      elseif command.op=='native-starter'then
        local screen=game.stack:top()
        assert(getmetatable(screen)==require('src.ui.Gen3RsStarterSelect'),'Route 101 did not open native RS Pokeballs')
        assert(#game.save.party==0 and screen.scene.state=='input')
        report.nativeStarterThroughRescueScript=true
        local function confirm()
          press('a',1)
          for _=1,500 do if screen.scene.state=='confirm'then return end;U.wait(1)end
          error('Natural starter portrait never reached confirmation')
        end
        press('b',8);assert(game.stack:top()==screen)
        for target=0,2 do
          for _=1,5 do press('left',5)end
          for _=1,target do press('right',5)end
          assert(screen.scene.selection==target);confirm();shot('natural-starter-'..target..'-preview')
          assert(screen.cry);press('b',8);assert(screen.scene.state=='input'and #game.save.party==0)
        end
        press('left',5);press('left',5);confirm()
        press('down',5);press('a',8);assert(screen.scene.state=='input'and #game.save.party==0)
        confirm();press('a',80);snapshot()
        assert(#game.save.party==1 and game.save.party[1].species=='TREECKO'and game.save.party[1].level==5)
        report.naturalStarterAccepted=true
      elseif command.op=='finish'then
        snapshot()
        assert(report.starter and report.starter.level==5 and report.naturalStarterAccepted)
        assert(freeField()and game.overworld.map.id=='MAP_G01_N04','Rescue did not return to Birch lab')
        local mon=assert(game.save.party[1]);assert(mon.species=='TREECKO'and mon.level==5 and mon.exp==150)
        assert(mon.hp==mon.stats.hp and mon.moves[1].pp==35)
        assert(require('src.core.SaveData').saveFileExists(edition),'Normal SAVE did not write a native checkpoint')
        local yes=assert(report.inputs[assert(report.normalSaveYesInput)],'No observed normal SAVE/YES press')
        local first
        for i=#report.commands,1,-1 do
          local row=report.commands[i]
          if row.seq<yes.commandSeq and row.before.top.source=='src/ui/Gen3StartMenu.lua'then first=row.seq;break end
        end
        assert(first)
        local Save=require('src.core.SaveData');local relative=assert(Save.saveFilename(edition))
        assert(relative:match('^profiles/guest/')and not relative:find('..',1,true))
        local root=love.filesystem.getSaveDirectory();local path=root..'/'..relative
        local file=assert(io.open(path,'rb'));local bytes=file:read('*a');file:close()
        write('normal-save-checkpoint.json',{profileIdentity=love.filesystem.getIdentity(),sourceRun=out:match('[^/]+$'),
          saveRelativePath=path:sub(#root+2),sha256=love.data.encode('string','hex',love.data.hash('sha256',bytes)),
          producedThroughNormalSaveMenu=true,saveMenuCommandRange={first,report.commands[#report.commands].seq},
          saveConfirmedSeq=yes.commandSeq,saveConfirmedInputIndex=report.normalSaveYesInput,
          inputProofKind='native-per-press-state',snapshotAfterSaveCommand=report.commands[#report.commands].after,
          personalSave=false,continuedThroughTitleTested=false})
        report.continuousOpeningThroughRescueAndNormalLabSave=true;report.firstBadgeTested=false
        report.status='pass';seq=seq+1;busy=false;snapshot()
        print('PASS_RS_NATURAL_STARTER_RESCUE_LAB_SAVE');love.event.quit(0);return
      else error('Unsupported ordinary-input story command: '..tostring(command.op))end
      seq=seq+1;busy=false;record.after=snapshot();report.commands[#report.commands+1]=record;write('result.json',report)
    end
  end
end
