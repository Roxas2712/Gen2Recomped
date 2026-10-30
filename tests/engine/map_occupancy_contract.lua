-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Runtime=require('src.mods.Runtime')
local Hooks=require('src.mods.Hooks')
local Events=require('src.mods.Events')
local story=dofile('data/scripts/story3.lua')
local originalText=package.loaded['src.render.TextBox']
package.loaded['src.render.TextBox']={new=function(game,text,done)return{done=done,text=text}end}
for _,mode in ipairs({'absent','allow','deny','truthy','throws','mutates'})do
  local hooks=Hooks.new();Runtime.install(Events.new(),hooks,{})
  local game={save={flags={EVENT_SS_ANNE_LEFT=true},version='red'},data={text={}},stack={}}
  local dialog,warped,blocks,rebuilt,seen=nil,nil,0,0,0
  function game.stack:push(state)dialog=state end
  local ow={player={cellX=2,cellY=9},map={renderer={}}}
  function ow.map:setBlock()blocks=blocks+1 end
  function ow.map.renderer:rebuild()rebuilt=rebuilt+1 end
  function ow:startWarpTo(map)warped=map end
  if mode~='absent'then
    hooks:wrap('map.occupancy_allowed',function(next,host,ctx)
      seen=seen+1
      T.eq(host,game,'hook receives live game')
      T.eq(ctx.mapId,'VERMILION_DOCK','hook names the story map')
      T.eq(ctx.reason,'ss_anne_departed','hook describes ejection reason')
      T.eq(ctx.gameVersion,'red','hook retains edition')
      T.eq(ctx.x,2,'hook observes current x')
      if mode=='throws'then error('occupancy probe')end
      if mode=='mutates'then ctx.x=99;ctx.mapId='OTHER'end
      if mode=='allow'or mode=='mutates'then return true end
      if mode=='truthy'then return 1 end
      return next()
    end,0,'probe')
  end
  story.VERMILION_DOCK.onEnter(game,ow)
  T.check(blocks>0 and rebuilt==1,'ship remains erased for '..mode)
  T.eq(seen,mode=='absent'and 0 or 1,'exactly one policy query')
  T.eq(ow.player.cellX,2,'context edits never move player')
  if mode=='allow'or mode=='mutates'then T.eq(dialog,nil,'exact true permits staying')
  else T.check(dialog~=nil,'default and malformed answers eject');dialog.done();T.eq(warped,'VERMILION_CITY','vanilla ejection destination retained')end
end
package.loaded['src.render.TextBox']=originalText
T.finish('story map occupancy policy')
