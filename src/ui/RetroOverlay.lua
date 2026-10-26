-- This menu owns input and pauses logic while open. Battery saves use the
-- regular slot registry; cloud uploads never replace the running slot.
local O={}
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Task=require('src.cloud.Task')
local Speed=require('src.core.GameSpeed')
local function inside(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.width and y<=r.y+r.height end
local function reset(game)
  if game.input and game.input.reset then game.input:reset() end
  local ok,touch=pcall(require,'src.core.TouchControls');if ok and touch.reset then touch:reset() end
  if game.releasePointerOwners then pcall(game.releasePointerOwners,game) end
end
function O.open(game)
  if not game or O.game then return end
  O.game=game;O.selected=1;O.notice=nil;O.confirm=nil;O.rects={};O.exportPath=nil
  O.page='home';O.scroll=0;O.options=nil;O.touch=nil;reset(game)
  if love.mouse then
    if love.mouse.setRelativeMode then pcall(love.mouse.setRelativeMode,false) end
    if love.mouse.setGrabbed then pcall(love.mouse.setGrabbed,false) end
    if love.mouse.setVisible then pcall(love.mouse.setVisible,true) end
  end
  game.lookRelative=false;game.cameraLookDX=0;game.cameraLookDY=0
end
function O.close()
  if O.job then O.notice='Wait for the upload, or cancel it first.';return end
  local friends=package.loaded['src.ui.FriendsMenu'];if friends then friends.clear(O) end
  local game=O.game;O.game=nil;O.confirm=nil;O.rects={}
  if game then reset(game) end
end
function O.clear()
  local friends=package.loaded['src.ui.FriendsMenu'];if friends then friends.clear(O) end
  if O.job then O.job:cancel() end
  O.job=nil;O.game=nil;O.confirm=nil;O.rects={};O.handle=nil
end
local function canSave(game)
  if game.retroArena or game.linkSession then return false end
  if game.stack and game.stack.worldState==game.overworld and game.overworld then return true end
  for _,state in ipairs(game.stack and game.stack.states or {}) do if state==game.overworld or state.isOverworld then return true end end
  return false
end
local function save(game)
  if not game.save or not game.save.player or not canSave(game) then return nil,'Start or continue a game before saving.' end
  local ran,ok,why=pcall(game.writeSave,game)
  if not ran or not ok then return nil,'Save failed: '..tostring(why or ok) end
  return true
end
function O.action(id)
  local game=O.game;if not game then return end
  if O.job then
    if id=='cancel' then O.job:cancel();O.job=nil;O.notice='Upload stopped. Your local save is kept.' end
    return
  end
  if (id=='friends' or O.page=='friends') and require('src.ui.FriendsMenu').action(O,id) then return end
  if id=='resume' then O.close();return end
  if id=='home' or id=='saves' or id=='options' then
    O.page=id;O.scroll=0;O.selected=1;O.rects={};O.notice=nil
    if id=='options' then
      local ok,menu=pcall(function() return require('src.ui.OptionsMenu').new(game) end)
      O.options=ok and menu.rows or {}
      if not ok then O.notice='Options could not be opened: '..tostring(menu) end
    end
    return
  end
  if id=='mute' then
    game.save.options=game.save.options or {}
    local opts=game.save.options;opts.audioMuted=not opts.audioMuted
    require('src.core.Music').applyOptions(opts);require('src.core.Sound').applyOptions(opts)
    if game.writeOptions then game:writeOptions() end
    return
  end
  if id=='speed' or id=='slower' then
    if game.speedLocked and game:speedLocked() then O.notice='This session requires normal game speed.';return end
    game.save.options=game.save.options or {}
    game.save.options.speed=Speed.cycle(game.save.options.speed,id=='slower' and -1 or 1)
    game.speedOverride=nil
    if game.writeOptions then game:writeOptions() end
    return
  end
  local index,direction=id:match('^option:(%d+):([%-]?%d+)$')
  if index then
    local row=O.options and O.options[tonumber(index)]
    if not row then return end
    local ok,changed=pcall(function()
      if row.activate then O.close();row.activate(game);return false end
      if row.step then return row.step(game,tonumber(direction)) end
    end)
    if not ok then O.notice='Setting could not be changed: '..tostring(changed)
    elseif changed and game.writeOptions then game:writeOptions() end
    return
  end
  if id=='cancel' then O.confirm=nil;return end
  if id=='folder' then
    local path=O.exportPath;local dir=path and path:match('^(.*)[/\\][^/\\]+$')
    if dir then love.system.openURL('file://'..dir) end
    return
  end
  if id=='library' and not O.confirm then O.confirm='library';O.notice='Save your progress and return to the game library?';return end
  if id=='library' and not canSave(game) then O.clear();game:returnToLauncher();return end
  if id~='save' and id~='export' and id~='library' and id~='cloud' then return end
  local ok,why=save(game)
  if not ok then O.notice=why;return end
  local version=Versions.get()
  if id=='save' then O.notice='Saved to this game’s normal save slot.'
  elseif id=='export' then
    local exported,path=require('src.import.SaveFileIO').exportActiveSlot(version)
    if not exported then O.notice=tostring(path);return end
    O.exportPath=path;O.notice='Battery .sav exported. Use Open exports to find it.'
    if love.system and love.system.createFile then
      local rel=path:match('(exports[/\\][^/\\]+)$')
      local bytes=rel and love.filesystem.read(rel)
      if bytes and love.filesystem.write('pending_export.sav',bytes) then
        love.system.createFile(rel:match('[^/\\]+$'),love.filesystem.getSaveDirectory())
      end
    end
  elseif id=='library' then
    O.clear();game:returnToLauncher()
  elseif id=='cloud' then
    local slot=Saves.activeSlot(version)
    O.job,why=Task.new(function()
      local store,err=require('src.cloud.RetroCloud').open();if not store then return nil,err end
      return require('src.import.CloudSync').syncOne(store,version,slot,true)
    end)
    O.notice=O.job and 'Uploading this save to your ModCompass account...' or tostring(why)
  end
end
function O.update(game)
  Task.reap()
  if O.game and O.game~=game then O.clear() end
  if O.job then
    local result=O.job:poll()
    if result then O.job=nil;O.notice=result.kind=='done' and result.first and ('Cloud: '..result.first..'.') or ('Upload paused: '..tostring(result.error or result.second)) end
  end
  if O.game and (O.page=='friends' or O.socialJob) then require('src.ui.FriendsMenu').tick(O) end
  return O.game~=nil
end
local function actions()
  if O.job then return {{id='cancel',label='Cancel upload'}} end
  if O.confirm then return {{id='library',label='Save & open library'},{id='cancel',label='Stay in this game'}} end
  if O.page=='friends' then return require('src.ui.FriendsMenu').rows(O) end
  if O.page=='options' then
    local rows={}
    for i,row in ipairs(O.options or {}) do
      local ok,value=pcall(function() return row.value and row.value(O.game) or 'OPEN' end)
      rows[#rows+1]={id='option:'..i..':1',minus='option:'..i..':-1',label=tostring(row.label),value=ok and tostring(value) or 'Unavailable'}
    end
    return rows
  end
  if O.page=='home' then
    local opts=O.game.save.options or {}
    return {{id='resume',label='Continue playing',note='Return to your adventure'},
      {id='friends',label='FRIENDS',note='Online friends · Meet on maps · Trade · Unranked battles'},
      {id='saves',label='SAVES & CLOUD',note='Save progress · Export .sav · Change game',large=true},
      {id='speed',minus='slower',label='Game speed',value=Speed.levelLabel(opts.speed)},
      {id='mute',label='Game audio',value=opts.audioMuted and 'MUTED' or 'ON'},
      {id='options',label='All game settings',note='Picture · Sound · Controls · Mod options'}}
  end
  local rows={{id='save',label='Save game progress'},
    {id='export',label='Export battery .sav'},{id='cloud',label='Save & upload to cloud'},
    {id='library',label='Choose another game'}}
  if O.exportPath then rows[#rows+1]={id='folder',label='Open exports'} end
  return rows
end
O.actions=actions
function O.key(game,key)
  if key=='f1' then if O.game then O.close() else O.open(game) end;return true end
  if key=='escape' and not O.game then O.open(game);return true end
  if not O.game then return false end
  if O.page=='friends' and require('src.ui.FriendsMenu').key(O,key) then return true end
  if key=='escape' then if O.confirm then O.confirm=nil elseif O.page~='home' then O.action('home') else O.close() end
  elseif key=='up' then O.selected=math.max(1,(O.selected or 1)-1)
  elseif key=='down' then O.selected=math.min(#actions(),(O.selected or 1)+1)
  elseif key=='left' then local row=actions()[O.selected or 1];if row and row.minus then O.action(row.minus) end
  elseif key=='right' or key=='return' or key=='space' or key=='z' then local row=actions()[O.selected or 1];if row then O.action(row.id) end end
  O.followSelection=true
  return true
end
function O.pad(game,button)
  if button=='guide' then if O.game then O.close() else O.open(game) end;return true end
  if not O.game then return false end
  local key=({dpup='up',dpdown='down',dpleft='left',dpright='right',a='return',b='escape',start='escape'})[button]
  if key then O.key(game,key) end
  return true
end
function O.press(game,x,y)
  if not O.game then if inside(O.handle,x,y) then O.open(game);return true end;return false end
  for _,row in ipairs(O.rects or {}) do if (row.pinned or inside(O.viewport,x,y)) and inside(row,x,y) then O.action(row.id);break end end
  return true
end
function O.wheel(_,dy)
  O.scroll=math.max(0,math.min(O.maxScroll or 0,(O.scroll or 0)-dy*44))
end
function O.touchpressed(game,id,x,y)
  if not O.game then return O.press(game,x,y) end
  if not O.touch then O.touch={id=id,x=x,y=y,startX=x,startY=y} end
  return true
end
function O.touchmoved(id,x,y)
  local t=O.touch;if not t or t.id~=id then return end
  t.moved=t.moved or math.abs(y-t.startY)>8 or math.abs(x-t.startX)>8
  if t.moved then O.wheel(0,(y-t.y)/44) end;t.y=y
end
function O.touchreleased(game,id,x,y)
  local t=O.touch;if not t or t.id~=id then return end
  O.touch=nil;if not t.moved then O.press(game,x,y) end
end
function O.draw(game)
  local g=love.graphics;local ww,hh=g.getDimensions()
  local s=math.max(.65,math.min(ww/1050,hh/720,1.35))
  if O.fontScale~=s then O.fontScale=s;O.font=g.newFont(math.max(10,math.floor(16*s)));O.titleFont=g.newFont(math.max(16,math.floor(25*s))) end
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  -- Game/post-process passes can leave depth, stencil or channel masks set.
  -- The OS-window menu must own a clean screen-space state on every path.
  if g.setStencilTest then g.setStencilTest() end
  if g.setDepthMode then g.setDepthMode() end
  if g.setColorMask then g.setColorMask(true,true,true,true) end
  O.handle={x=ww-142*s,y=10*s,width=132*s,height=36*s}
  local function text(value,x,y,w,big)
    g.setFont(big and O.titleFont or O.font);g.printf(value,x,y,w,'left')
  end
  if not O.game then
    g.setColor(.025,.045,.08,.80);g.rectangle('fill',O.handle.x,O.handle.y,O.handle.width,O.handle.height,8,8)
    g.setColor(.42,.90,1,1);text('RETRO · ESC',O.handle.x+10*s,O.handle.y+7*s,O.handle.width-12*s)
    local Play=package.loaded['src.cloud.Play'];local doc=Play and Play.read();local count=0
    for _,i in ipairs(doc and doc.invites or {}) do if i.incoming and i.state=='pending' then count=count+1 end end
    if count>0 then
      g.setColor(.85,.22,.28,1);g.circle('fill',O.handle.x+O.handle.width-5*s,O.handle.y+4*s,10*s)
      g.setColor(1,1,1,1);text(tostring(count),O.handle.x+O.handle.width-10*s,O.handle.y-4*s,24*s)
    end
    g.pop();return
  end
  g.setColor(.015,.025,.05,.87);g.rectangle('fill',0,0,ww,hh)
  local w=math.min(760*s,ww-30*s);local h=math.min(660*s,hh-30*s);local x=(ww-w)/2;local y=(hh-h)/2
  g.setColor(.065,.09,.14,1);g.rectangle('fill',x,y,w,h,16*s,16*s)
  g.setColor(.45,.91,1,1);text('RETRORECOMPED',x+24*s,y+20*s,w-48*s,true)
  g.setColor(.74,.78,.85,1);text(Versions.info().displayName..' · PAUSED',x+24*s,y+61*s,w-48*s)
  local rows=actions();local layoutScroll=O.scroll or 0;local nextScroll=layoutScroll;local top=y+134*s-layoutScroll
  O.rects={};O.selected=math.min(O.selected or 1,math.max(1,#rows))
  for i,tab in ipairs({{'home','QUICK MENU'},{'saves','SAVES & CLOUD'},{'options','SETTINGS'},{'friends','FRIENDS'}}) do
    local tw=(w-48*s)/4;local tx=x+24*s+(i-1)*tw
    g.setColor(.1,.2,.27,1);g.rectangle('fill',tx,y+88*s,tw-6*s,32*s,6*s,6*s)
    g.setColor(.65,.9,1,1);text(tab[2],tx+8*s,y+96*s,tw-16*s)
    O.rects[#O.rects+1]={id=tab[1],x=tx,y=y+88*s,width=tw-6*s,height=32*s,pinned=true}
  end
  local view={x=x+18*s,y=y+132*s,width=w-36*s,height=math.max(1,h-218*s)};O.viewport=view
  g.setScissor(view.x,view.y,view.width,view.height)
  for i,row in ipairs(rows) do
    local noteLines=1
    if row.note and O.font.getWrap then local _,lines=O.font:getWrap(row.note,w-(72+(row.avatar and 58 or 0))*s);noteLines=math.max(1,#lines) end
    local step=math.max((row.large and 88 or row.note and 66 or 52)*s,row.note and (row.large and 52 or 38)*s+noteLines*O.font:getHeight()+12*s or 0)
    local ry=top;local selected=i==O.selected
    g.setColor(selected and .12 or .08,selected and .26 or .13,selected and .34 or .20,1)
    g.rectangle('fill',x+22*s,ry,w-44*s,step-6*s,7*s,7*s)
    local inset=row.avatar and 58 or 0
    if row.avatar then require('src.ui.ProfileAvatar').draw(row.avatar.preset,row.avatar.color,x+30*s,ry+7*s,46*s,row.avatar.image) end
    g.setColor(.88,.95,.99,1);text(row.label,x+(36+inset)*s,ry+12*s,w-(row.value and 195 or 72)*s-inset*s,row.large)
    if row.note then g.setColor(.58,.73,.82,1);text(row.note,x+(36+inset)*s,ry+(row.large and 50 or 38)*s,w-(72+inset)*s) end
    if row.value then g.setColor(.45,.91,1,1);text(row.value,x+w-148*s,ry+12*s,110*s) end
    O.rects[#O.rects+1]={id=row.id,x=x+22*s,y=ry,width=w-44*s,height=step-6*s}
    if row.minus then O.rects[#O.rects+1]={id=row.minus,x=x+w-192*s,y=ry,width=35*s,height=step-6*s}
      g.setColor(.45,.91,1,1);text('‹',x+w-184*s,ry+12*s,25*s)
      -- The smaller arrow owns its hit region before the full row.
      local last=table.remove(O.rects);table.insert(O.rects,#O.rects,last)
    end
    if selected and O.followSelection then
      if ry<view.y then nextScroll=math.max(0,layoutScroll+ry-view.y)
      elseif ry+step>view.y+view.height then nextScroll=layoutScroll+ry+step-view.y-view.height end
    end
    top=top+step
  end
  O.followSelection=false
  O.maxScroll=math.max(0,top+layoutScroll-view.y-view.height);O.scroll=math.min(nextScroll,O.maxScroll)
  g.setScissor()
  g.setColor(.61,.74,.83,1);text(O.notice or (O.page=='options' and 'Change options with ← / →. Your choices are saved immediately.' or 'Normal saves keep game progress. Exact mid-battle savestates are still in development.'),x+24*s,y+h-74*s,w-48*s)
  g.pop()
end
return O
