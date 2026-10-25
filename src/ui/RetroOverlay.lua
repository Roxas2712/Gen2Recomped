-- This menu owns input and pauses logic while open. Battery saves use the
-- regular slot registry; cloud uploads never replace the running slot.
local O={}
local Saves=require('src.core.SaveData')
local Versions=require('src.core.GameVersion')
local Task=require('src.cloud.Task')
local function inside(r,x,y) return r and x>=r.x and y>=r.y and x<=r.x+r.width and y<=r.y+r.height end
local function reset(game)
  if game.input and game.input.reset then game.input:reset() end
  local ok,touch=pcall(require,'src.core.TouchControls');if ok and touch.reset then touch:reset() end
  if game.releasePointerOwners then pcall(game.releasePointerOwners,game) end
end
function O.open(game)
  if not game or O.game then return end
  O.game=game;O.selected=1;O.notice=nil;O.confirm=nil;O.rects={};O.exportPath=nil;reset(game)
  if love.mouse then
    if love.mouse.setRelativeMode then pcall(love.mouse.setRelativeMode,false) end
    if love.mouse.setGrabbed then pcall(love.mouse.setGrabbed,false) end
    if love.mouse.setVisible then pcall(love.mouse.setVisible,true) end
  end
  game.lookRelative=false;game.cameraLookDX=0;game.cameraLookDY=0
end
function O.close()
  if O.job then O.notice='Wait for the upload, or cancel it first.';return end
  local game=O.game;O.game=nil;O.confirm=nil;O.rects={}
  if game then reset(game) end
end
function O.clear()
  if O.job then O.job:cancel() end
  O.job=nil;O.game=nil;O.confirm=nil;O.rects={};O.handle=nil
end
local function canSave(game)
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
  if id=='resume' then O.close();return end
  if id=='cancel' then O.confirm=nil;return end
  if id=='folder' then
    local path=O.exportPath;local dir=path and path:match('^(.*)[/\\][^/\\]+$')
    if dir then love.system.openURL('file://'..dir) end
    return
  end
  if id=='library' and not O.confirm then O.confirm='library';O.notice='Save your progress and return to the game library?';return end
  if id=='library' and not canSave(game) then O.clear();game:returnToLauncher();return end
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
  return O.game~=nil
end
local function actions()
  if O.job then return {{id='cancel',label='Cancel upload'}} end
  if O.confirm then return {{id='library',label='Save & open library'},{id='cancel',label='Stay in this game'}} end
  local rows={{id='resume',label='Continue playing'},{id='save',label='Save game progress'},
    {id='export',label='Export battery .sav'},{id='cloud',label='Save & upload to cloud'},
    {id='library',label='Choose another game'}}
  if O.exportPath then rows[#rows+1]={id='folder',label='Open exports'} end
  return rows
end
function O.key(game,key)
  if key=='f1' then if O.game then O.close() else O.open(game) end;return true end
  if not O.game then return false end
  if key=='escape' then if O.confirm then O.confirm=nil else O.close() end
  elseif key=='up' then O.selected=math.max(1,(O.selected or 1)-1)
  elseif key=='down' then O.selected=math.min(#actions(),(O.selected or 1)+1)
  elseif key=='return' or key=='space' or key=='z' then local row=actions()[O.selected or 1];if row then O.action(row.id) end end
  return true
end
function O.pad(game,button)
  if button=='guide' then if O.game then O.close() else O.open(game) end;return true end
  if not O.game then return false end
  local key=({dpup='up',dpdown='down',a='return',b='escape',start='escape'})[button]
  if key then O.key(game,key) end
  return true
end
function O.press(game,x,y)
  if not O.game then if inside(O.handle,x,y) then O.open(game);return true end;return false end
  for _,row in ipairs(O.rects or {}) do if inside(row,x,y) then O.action(row.id);break end end
  return true
end
function O.draw(game)
  local g=love.graphics;local ww,hh=g.getDimensions()
  local s=math.max(.65,math.min(ww/1050,hh/720,1.35))
  O.font=O.font or g.newFont(16);O.titleFont=O.titleFont or g.newFont(25)
  g.push('all');g.setCanvas();g.origin();g.setShader();g.setScissor();g.setBlendMode('alpha')
  O.handle={x=ww-142*s,y=10*s,width=132*s,height=36*s}
  local function text(value,x,y,w,big)
    g.setFont(big and O.titleFont or O.font);g.printf(value,x,y,w,'left')
  end
  if not O.game then
    g.setColor(.025,.045,.08,.80);g.rectangle('fill',O.handle.x,O.handle.y,O.handle.width,O.handle.height,8,8)
    g.setColor(.42,.90,1,1);text('RETRO · F1',O.handle.x+10*s,O.handle.y+7*s,O.handle.width-12*s)
    g.pop();return
  end
  g.setColor(.015,.025,.05,.87);g.rectangle('fill',0,0,ww,hh)
  local w=math.min(620*s,ww-30*s);local x=(ww-w)/2;local y=math.max(18*s,(hh-610*s)/2)
  g.setColor(.065,.09,.14,1);g.rectangle('fill',x,y,w,math.min(610*s,hh-y-18*s),16*s,16*s)
  g.setColor(.45,.91,1,1);text('RETRORECOMPED',x+24*s,y+20*s,w-48*s,true)
  g.setColor(.74,.78,.85,1);text(Versions.info().displayName..' · PAUSED',x+24*s,y+61*s,w-48*s)
  local rows=actions();local top=y+102*s
  local available=math.min(610*s,hh-y-18*s)-240*s
  local step=math.min(51*s,available/math.max(1,#rows))
  O.rects={};O.selected=math.min(O.selected or 1,#rows)
  for i,row in ipairs(rows) do
    local ry=top+(i-1)*step;local selected=i==O.selected
    g.setColor(selected and .12 or .08,selected and .26 or .13,selected and .34 or .20,1)
    g.rectangle('fill',x+22*s,ry,w-44*s,step-6*s,7*s,7*s)
    g.setColor(.88,.95,.99,1);text(row.label,x+36*s,ry+math.max(1,(step-6*s-O.font:getHeight())/2),w-72*s)
    O.rects[#O.rects+1]={id=row.id,x=x+22*s,y=ry,width=w-44*s,height=step-6*s}
  end
  local bottom=top+#rows*step+12*s
  g.setColor(.61,.74,.83,1);text(O.notice or 'Normal saves and exported .sav files share your game progress. A battery save does not capture a running battle.',x+24*s,bottom,w-48*s)
  g.pop()
end
return O
