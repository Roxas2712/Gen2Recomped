-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local previous=Version.get()
local Game=require('src.core.Game')
local Stack=require('src.core.StateStack')
local Input=require('src.core.Input')
local Choice=require('src.ui.ChoiceBox')
local Picker=require('src.ui.Gen2MoveDeleter')
local Pokemon=require('src.pokemon.Pokemon')
local Evolution=require('src.pokemon.Evolution')
local originalTeach=Game.learnMoveOn
local function fixture(edition)
  Version.set(edition)
  local data=T.fixtures.fresh();data.constants.gen=2
  data.moves.FIELD_FIVE={name='FIFTH MOVE',pp=7,type='NORMAL',power=1,accuracy=100,effect='NO_ADDITIONAL_EFFECT'}
  data.moves.CUT={name='CUT',pp=30,type='NORMAL',power=50,accuracy=100,effect='NO_ADDITIONAL_EFFECT'}
  data.constants.machines={{kind='HM',move='CUT'}}
  T.link.prepare(data)
  local game=setmetatable(T.link.fakeGame(data,'FIXMON_A',{level=10}),{__index=Game})
  local stack=setmetatable({},{__index=Stack});stack:init();game.stack=stack
  local base={name='FIELD OWNER'};stack:push(base)
  local loaded=T.sdk.loadMods({'mods/field_learning'},{data=data,fs=T.sdk.memfs({
    ['mods/field_learning/manifest.json']='{"id":"field_learning","name":"Field learning","version":"1.0.0","api":2,"entry":"main.lua"}',
    ['mods/field_learning/main.lua']=[[
      local mod=...;local G=require('src.core.Game2')
      mod.exports.Game=G;mod.exports.List=require('src.ui.gen2.ForgetMoveList')
      mod.exports.events={};mod.exports.calls=0
      local teach=G.learnMoveOn
      G.learnMoveOn=function(self,mon,id,done)
        mod.exports.calls=mod.exports.calls+1
        return teach(self,mon,id,done)
      end
      mod.events:on('pokemon.move_learned',function(ev)
        mod.exports.events[#mod.exports.events+1]={mon=ev.mon,id=ev.moveId}
      end)
    ]],
  })})
  T.eq(#loaded.errors,0,'unchanged source-name consumer loads on '..edition)
  local probe=loaded.loader.exports.field_learning
  T.eq(probe.Game,Game,'source entry is the actual native Game table')
  T.eq(probe.List,require('src.ui.Gen2ForgetMoveList'),'source and native list are one module')
  local function tick(key)
    Input.pressed=key and {[key]=true} or{};Input.state={a=true}
    stack:update(1/60);Input.pressed={}
  end
  local function until_(predicate,label)
    for _=1,2400 do if predicate(stack:top())then return stack:top()end;tick('a')end
    error('field learning did not reach '..label)
  end
  local function choose(yes)
    local state=until_(function(s)return getmetatable(s)==Choice end,'YES/NO')
    tick(yes and'a'or'b')
    for _=1,20 do if stack:top()~=state then return end;tick()end
    error('native choice did not finish')
  end
  local function picker()
    return until_(function(s)return getmetatable(s)==Picker end,'native four-row list')
  end
  local function close()
    until_(function(s)return s==base end,'field owner')
    T.eq(#stack.states,1,'flow leaves the original field owner intact')
  end
  local function fill(mon)
    mon.moves={{id='FIX_TACKLE',pp=1},{id='FIX_SCRATCH',pp=2},
      {id='FIX_EMBERISH',pp=3},{id='CUT',pp=4}}
  end
  return game,game.save.party[1],probe,loaded,tick,choose,picker,close,fill
end
for _,edition in ipairs{'gold','silver','crystal','prism','polishedcrystal'}do
  local g,mon,p,run,tick,choose,picker,close,fill=fixture(edition)
  local answers={}
  mon.moves={{id='FIX_TACKLE',pp=1}}
  local result=g:learnMoveOn(mon,'FIELD_FIVE',function(value)answers[#answers+1]=value;return 'callback-private-value'end)
  T.eq(result,nil,'source free-slot entry has no return value')
  T.eq(mon.moves[2].id,'FIELD_FIVE');T.eq(mon.moves[2].maxPp,7)
  T.eq(#p.events,1);T.eq(p.events[1].mon,mon)
  T.eq(#answers,0,'completion waits for the actual learned message')
  close();T.same(answers,{true})
  result=g:learnMoveOn(mon,'FIELD_FIVE',function(value)answers[#answers+1]=value;return 'callback-private-value'end)
  T.eq(result,nil,'source known-move entry does not leak a callback return')
  T.same(answers,{true,false},'known move returns false without opening a menu')
  T.eq(#p.events,1);close()

  fill(mon);local old=mon.moves[2]
  g:learnMoveOn(mon,'FIELD_FIVE',function(value)answers[#answers+1]=value end)
  T.eq(#p.events,1,'full-slot prompt does not learn prematurely')
  choose(true);local list=picker()
  T.eq(list.list,mon.moves,'picker observes the actual party move list')
  local nativeDraw,draws=p.List.draw,0
  p.List.draw=function(moves,index,data,...)draws=draws+1;T.eq(moves,mon.moves);return nativeDraw(moves,index,data,...)end
  list:draw();p.List.draw=nativeDraw
  T.eq(draws,1,'native field picker reaches the public source draw method')
  tick('down');tick('a')
  T.eq(mon.moves[2].id,'FIELD_FIVE');T.neq(mon.moves[2],old)
  T.eq(mon.moves[2].maxPp,7);T.eq(#p.events,2)
  T.eq(#answers,2,'replacement completion waits for its real text')
  close();T.same(answers,{true,false,true})

  fill(mon);local snapshot={};for i,m in ipairs(mon.moves)do snapshot[i]=m end
  g:learnMoveOn(mon,'FIELD_FIVE',function(value)answers[#answers+1]=value end)
  choose(true);list=picker()
  tick('up');T.eq(list.row,4,'source forget list wraps over four real slots')
  tick('a') -- CUT is an HM; returns to the same held question/list.
  list=picker();T.eq(list.row,1,'HM rejection reopens the native picker')
  for i,m in ipairs(snapshot)do T.eq(mon.moves[i],m,'HM refusal leaves party records unchanged')end
  T.eq(#p.events,2,'HM refusal emits no learned event')
  tick('b');choose(false) -- NO to Stop learning returns to Ask forget.
  choose(false);choose(true) -- Decline replacing, then stop learning.
  close();T.same(answers,{true,false,true,false})
  for i,m in ipairs(snapshot)do T.eq(mon.moves[i],m,'cancellation retains every original slot')end
  T.eq(#p.events,2)

  -- Native evolution/reminder paths must reach the mod-observable Game seam.
  mon.moves={{id='FIX_TACKLE',pp=1}};local before=p.calls;local finished=0
  Evolution.learnMoves(g,mon,{'FIX_SCRATCH','FIELD_FIVE'},function()finished=finished+1 end)
  close();T.eq(p.calls,before+2,'native sequential field learning uses the public entry twice')
  T.eq(finished,1);T.eq(#p.events,4,'native field path emits exactly once per write')
  require('src.mods.Loader').teardown();run.release()
  T.eq(Game.learnMoveOn,originalTeach,'loader teardown restores the native entry')
end
Version.set(previous);Input.pressed={};Input.state={}
T.finish('native and source GSC field teaching, four-row UI, HM refusal, cancellation and shared events')
