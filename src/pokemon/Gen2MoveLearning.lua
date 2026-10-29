-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Field teaching uses the native stack, text boxes and four-row Gen2 picker.
-- The source Game2 entry and native item/evolution paths share these writes.
local TextBox=require('src.render.TextBox')
local Screens=require('src.ui.Screens')
local Strings=require('src.core.Strings')
local M={}

function M.teach(game,mon,moveId,onDone)
  assert(require('src.core.GameVersion').isGen2(),'Gen2 teaching requires a Gen2 game')
  local data,stack=game.data,game.stack
  local complete=false
  local function done(learned)
    if complete then return end
    complete=true
    if onDone then onDone(learned)end
  end
  local function say(text,next_,opts)
    stack:push(TextBox.new(game,text,next_,opts))
  end
  local name=require('src.pokemon.Pokemon').displayName(mon)
  local def=data.moves and data.moves[moveId]
  local moveName=def and def.name or moveId
  -- Source wrappers remain authoritative here; the default source method
  -- dispatches to the same native Gen2Learnset write/event owner.
  local ok,reason,entry=require('src.compat.gen2.Mon').learnMove(mon,moveId,data)
  if ok then
    return say(Strings('%s learned\n%s!',name,moveName),function()done(true)end)
  end
  if reason~='full' then return done(false)end

  local ask,pick,stop
  stop=function()
    say(Strings('Stop learning\n%s?',moveName),nil,{choice=function(yes)
      if yes then
        say(Strings('%s\ndid not learn\v%s.',name,moveName),function()done(false)end)
      else ask()end
    end})
  end
  pick=function()
    local question
    local function showList()
      local list
      local function closeList()
        -- Only remove the states this choice owns, never an unrelated menu.
        if stack.removeAll then stack:removeAll({list,question})
        else stack:pop();stack:pop()end
      end
      list=Screens.push(game,'Gen2MoveDeleter',{
        mon=mon,moves=data.moves,layout='forget',
        onCancel=function()closeList();stop()end,
        onChoose=function(index)
          local old=mon.moves[index]
          if not old then return end
          if require('src.ui.MoveLearnMenu').hmMoves(game)[old.id]then
            stack:pop() -- the list; the held question stays beneath the text
            return say(Strings("HM moves can't be\nforgotten now."),showList)
          end
          closeList()
          -- Install the same pending slot returned by the shared learner.
          mon.moves[index]=entry
          require('src.mods.Runtime').emit('pokemon.move_learned',{mon=mon,moveId=moveId})
          local oldDef=data.moves and data.moves[old.id]
          say(Strings('1, 2 and... Poof!\f%s forgot\n%s.\fAnd...\f%s learned\n%s!',
            name,oldDef and oldDef.name or old.id,name,moveName),function()done(true)end)
        end,
      })
    end
    question=TextBox.new(game,Strings('Which move should\nbe forgotten?'),nil,
      {stay={onShown=showList}})
    stack:push(question)
  end
  ask=function()
    say(Strings('%s is\ntrying to learn\v%s.\fBut %s\ncan\'t learn more\vthan four moves.\fDelete an older\nmove to make room\vfor %s?',
      name,moveName,name,moveName),nil,{choice=function(yes)
      if yes then pick()else stop()end
    end})
  end
  ask()
end

return M
