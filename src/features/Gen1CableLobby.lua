-- Additional native cable/lobby and shared-kernel battle presentation.
-- Contributions by Roxas2712; see NOTICE.md. No source UI/launcher is copied.
local M={};M.__index=M;M.isOpaque=true
local Font=require('src.render.Font')
local V=require('src.core.GameVersion')
local alphabet='23456789ABCDEFGHJKMNPQRSTUVWXYZ'
function M.new(game,options)
  options=options or{}
  local journal=options.journal or require('src.features.Gen1SessionJournal').new(game,options)
  local self=setmetatable({game=game,options=options,journal=journal,index=1,page='menu',address=options.address or os.getenv('GEN1_FEATURE_RELAY')or'127.0.0.1:7780'},M)
  return self
end
function M:uiSize()return V.generation()==3 and 240 or 160,V.generation()==3 and 160 or 144 end
function M:rows()
  local out={}
  if V.generation()==3 then out[#out+1]={label='Host a cable trade',mode='trade'};out[#out+1]={label='Join a cable trade',mode='trade',join=true}end
  out[#out+1]={label='Host shared-rule battle',mode='battle'}
  out[#out+1]={label='Join shared-rule battle',mode='battle',join=true}
  for _,row in ipairs(self.journal:list())do out[#out+1]={label='Resume '..row.room,mode=row.mode,room=row.room}end
  out[#out+1]={label='Relay address',address=true}
  return out
end
function M:connect(mode,room)
  if mode=='trade'and not self.options.journal then
    local ok,why=self.game:writeSave()
    if not ok then self.error=why or 'Save the current adventure before connecting.';return nil,self.error end
    self.journal=require('src.features.Gen1SessionJournal').new(self.game,self.options)
  end
  local options={mode=mode,room=room,address=self.address,netFactory=self.options.netFactory}
  local channel,why=require('src.features.Gen1RelayChannel').new(self.journal,options)
  if not channel then self.error=why;return nil,why end
  local session,problem=require('src.features.Gen1CableSession').new(self.game,channel,{journal=self.journal,checkOwner=self.options.checkOwner,table=self.options.table,records=self.options.records})
  if not session then channel:close();self.error=problem;return nil,problem end
  self.session,self.page,self.index=session,'session',1;self.error=nil;return true
end
function M:close()if self.session then self.session:close()end end
function M:leave()
  self:close()
  if self.game.stack:top()==self then self.game.stack:pop()end
end
local function label(game,mon)
  if mon.nickname and mon.nickname~=''then return mon.nickname end
  for _,row in pairs(game.data.pokemon or{})do
    if type(row)=='table'and(row.dex or row.nationalDex or row.index)==mon.species then return row.name end
  end
  return 'POKéMON'
end
function M:update(dt)
  local input=self.game.input
  if self.options.checkOwner and not self.options.checkOwner()then self:leave();return end
  if self.page=='edit'then
    local direction=input:wasPressed('up')and 1 or input:wasPressed('down')and -1 or 0
    if direction~=0 then
      local ch=self.edit:sub(self.cursor,self.cursor)
      local at=(self.charset:find(ch,1,true)or 1)-1
      local replacement=self.charset:sub((at+direction)%#self.charset+1,(at+direction)%#self.charset+1)
      self.edit=self.edit:sub(1,self.cursor-1)..replacement..self.edit:sub(self.cursor+1)
    end
    if input:wasPressed('left')then self.cursor=(self.cursor-2)%#self.edit+1 end
    if input:wasPressed('right')then self.cursor=self.cursor%#self.edit+1 end
    if input:wasPressed('b')then self.page='menu'end
    if input:wasPressed('a')then
      if self.editMode=='address'then self.address=self.edit:match('^%s*(.-)%s*$');self.page='menu'
      else self:connect(self.editMode,self.edit)end
    end
    return
  end
  if self.page=='menu'then
    local rows=self:rows()
    if input:wasPressed('up')then self.index=(self.index-2)%#rows+1 end
    if input:wasPressed('down')then self.index=self.index%#rows+1 end
    if input:wasPressed('b')then self:leave();return end
    if input:wasPressed('a')then
      local row=rows[self.index]
      if row.address then
        self.page,self.editMode,self.charset='edit','address',' 0123456789.:abcdefghijklmnopqrstuvwxyz-'
        self.edit=self.address..string.rep(' ',math.max(0,32-#self.address));self.cursor=1
      elseif row.join then self.page,self.editMode,self.charset,self.edit,self.cursor='edit',row.mode,alphabet,'22222222',1
      else self:connect(row.mode,row.room)end
    end
    return
  end
  local s=self.session
  local ok,why=pcall(s.update,s,dt)
  if not ok then s.error=tostring(why);s.phase='recovery';s:close()end
  for _,event in ipairs(s.events or{})do
    if event.kind=='move'then
      local moveName='an attack'
      for _,row in pairs(self.game.data.moves or{})do if type(row)=='table'and row.index==event.moveId then moveName=row.name;break end end
      self.lastLine=(event.user==s.channel.seat and 'You used 'or 'Foe used ')..moveName
    elseif event.kind=='faint'then self.lastLine=event.side==s.channel.seat and 'Your POKéMON fainted.'or 'The foe fainted.'
    elseif event.kind=='status'then self.lastLine='Status: '..tostring(event.status)end
  end
  s.events={}
  if s.phase=='done'and s.mode=='trade'and not self.learningChecked then
    self.learningChecked=true
    local mon,moves,problem=self.journal:pendingLearning(s.channel.room,s.codec)
    if problem then self.error=problem end
    if mon then
      require('src.pokemon.Evolution').learnMoves(self.game,mon,moves,function()
        local saved,why=self.journal:finishLearning(s.channel.room)
        if not saved then self.error=why end
      end)
      return
    end
  end
  if input:wasPressed('b')then self:leave();return end
  local choices=s.mode=='battle'and s.battle and s.battle:legal()or nil
  local count=choices and #choices or s.parties[s.channel.seat]and #s.parties[s.channel.seat]or 1
  count=math.max(1,count);self.index=math.min(self.index,count)
  if input:wasPressed('up')then self.index=(self.index-2)%count+1 end
  if input:wasPressed('down')then self.index=self.index%count+1 end
  if input:wasPressed('a')then
    local accepted,problem
    if s.phase=='done'or s.phase=='cancelled'then self:leave();return
    elseif s.phase=='select'then accepted,problem=s:pick(self.index)
    elseif s.phase=='confirm'then accepted,problem=s:confirm()
    elseif choices and choices[self.index]then accepted,problem=s:choose(choices[self.index])end
    if accepted==nil and problem then self.error=problem end
  end
end
function M:draw()
  local width,height=self:uiSize()
  love.graphics.setColor(0.05,0.08,0.12,1);love.graphics.rectangle('fill',0,0,width,height)
  love.graphics.setColor(1,1,1,1);Font.draw('COMPATIBILITY CABLE',8,4)
  if self.page=='menu'then
    local rows=self:rows();local first=math.max(1,self.index-5)
    for i=first,math.min(#rows,first+5)do Font.draw((i==self.index and '> 'or'  ')..rows[i].label,8,23+(i-first)*14)end
    Font.draw('Shared battles: Gen3 rules.',8,height-30)
    Font.draw('No held items or abilities.',8,height-19)
  elseif self.page=='edit'then
    Font.draw(self.editMode=='address'and 'Relay host:port'or 'Enter room code',8,30)
    local columns=math.floor(width/6)-2;local first=math.max(1,self.cursor-columns+1)
    Font.draw(self.edit:sub(first,first+columns-1),8,55)
    Font.draw(string.rep(' ',self.cursor-first)..'^',8,67)
    Font.draw('D-pad: edit  A: connect',8,height-25)
  else
    local s=self.session
    Font.draw('Room: '..tostring(s.channel.room or 'Connecting'),8,20)
    if s.battle then
      local match=s.battle.match
      for side=0,1 do
        local active=match:party(side)[match:active(side)or 1]
        if active then
          local y=36+side*23
          Font.draw(label(self.game,active)..' '..active.hp..'/'..active.maxHp,8,y)
          love.graphics.setColor(0.2,0.8,0.4,1);love.graphics.rectangle('fill',8,y+10,math.floor((width-16)*math.max(0,active.hp)/active.maxHp),3);love.graphics.setColor(1,1,1,1)
        end
      end
      local choices=s.battle:legal();local first=math.max(1,self.index-2)
      for i=first,math.min(#choices,first+2)do
        local choice=choices[i];local text='Forfeit'
        if choice.kind=='move'then
          text='STRUGGLE'
          local mon=match:party(s.channel.seat)[match:active(s.channel.seat)or 1]
          local number=mon and mon.moves[choice.slot]
          for _,row in pairs(self.game.data.moves or{})do if type(row)=='table'and row.index==number then text=row.name;break end end
        elseif choice.kind=='switch'then text='Switch '..label(self.game,match:party(s.channel.seat)[choice.index])end
        Font.draw((i==self.index and '> 'or'  ')..text,8,88+(i-first)*12)
      end
      if not s.result and self.lastLine then Font.draw(self.lastLine:sub(1,math.floor(width/6)-2),8,122)end
      if s.result then Font.draw(s.result.draw and 'DRAW'or s.result.winner==s.channel.seat and 'YOU WON'or 'YOU LOST',8,122)
      elseif #choices==0 then Font.draw('Waiting for peer...',8,105)end
    elseif s.phase=='select'then
      for i,mon in ipairs(s.parties[s.channel.seat]or{})do Font.draw((i==self.index and '> 'or'  ')..label(self.game,mon),8,34+i*12)end
    else
      if s.phase=='confirm'then
        for side=0,1 do
          local mon=s.parties[side]and s.parties[side][s.picks[side]]
          if mon then Font.draw((side==s.channel.seat and 'Yours: 'or 'Theirs: ')..label(self.game,mon),8,34+side*12)end
        end
      end
      local text=({connecting='Connecting...',confirm='A: confirm selected trade',committing='Saving trade decision...',done='Trade saved. A: return',cancelled='Trade cancelled.',recovery='Recovery record retained.'})[s.phase]or'Waiting for other player...'
      Font.draw(text,8,s.phase=='confirm'and 75 or 58)
    end
    if s.channel.notice then Font.draw(s.channel.notice:sub(1,math.floor(width/6)-2),8,height-30)end
  end
  local problem=self.error or self.session and self.session.error
  Font.draw(problem and tostring(problem):sub(1,math.floor(width/6)-2)or 'B: leave / resume later',8,height-9)
end
function M.open(game,options)
  if V.generation()<1 or V.generation()>3 then return nil,'cable feature supports Gen1/2/3'end
  if type(game)~='table'or type(game.stack)~='table'then return nil,'native game unavailable'end
  local world=game.stack:top()
  if not world or not world.isOverworld or game.linkSession then return nil,'return to the native overworld first'end
  local screen=M.new(game,options);game.stack:push(screen);return screen
end
return M
