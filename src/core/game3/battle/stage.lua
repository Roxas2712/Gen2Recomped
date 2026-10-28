-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Live presentation observations over one actual native battle admission.
local Battle=require('src.core.game3.battle')
local Native=require('src.battle.Gen3Battle')
local Coords=require('src.core.game3.battle.anim_coords')
local Iteration=require('src.compat.gen1.TableIteration')
local Ball=require('src.compat.gen1.NativeBallObservation')
local Timing=require('src.core.Timing')
local M={}
local current
local function retire(c)
 if not c then return end
 c.retired=true;c.refs[1]=nil;c.view=nil;c.nodes={};c.users={};c.ballRef=nil;c.ballView=nil
 if current==c then current=nil end
end
local function live(c)
 local s=not c.retired and c.refs[1]
 if s and Battle._screen()==s and Battle.getState()==c.view then return s end
 retire(c)
end
local read
local keys={stage={'slide','slideDone','trainer','ball','balls','healthbox','partyBar','bgSlide','win0'},
 trainer={'player','enemy'},healthbox={'player','enemy',0,1,2,3},balls={0,1,2,3},
 portrait={'visible','x','y','ox','oy','frame','gender','picId','pic2','x2'},
 box={'visible','ox'},bg={'enemyOx','playerOx'},mask={1,2},
 party={'player','enemy'},bar={'visible','x','y','ox','balls','ballHidden'}}
local function node(c,kind,id,anim)
 local name=kind..':'..tostring(id or'')
 if not anim and c.nodes[name]then return c.nodes[name]end
 local refs=anim and setmetatable({anim},{__mode='v'})
 local fieldKeys=anim and Ball.keys or keys[kind]
 local function get(key)
  local s=live(c);if not s then if key=='visible'then return false end;return nil end
  if refs then
   local a=refs[1];if not a or s.gen3Ball~=a then if key=='visible'then return false end;return nil end
   return Ball.read(s,a,key)
  end
  return read(c,s,kind,id,key)
 end
 local value=setmetatable({},{__index=function(_,key)return get(key)end,
  __newindex=function()error('native battle stage observation is read-only',2)end})
 local weak=setmetatable({value=value},{__mode='v'})
 -- The registry must not retain its own weak key through this reader's state.
 Iteration.register(value,function(spec)
  local v=spec.value;local out={}
  if v then for _,key in ipairs(fieldKeys)do out[key]=v[key]end end
  return out
 end,weak)
 if not anim then c.nodes[name]=value end
 return value
end
local function battler(s,id)
 return id==0 and s.player or id==1 and s.enemy or s:battlerAt(id)
end
local function ball(c,s)
 local a=s.gen3Ball;if not a then return nil end
 local catch=package.loaded['src.core.game3.battle.catch_seq']
 local caught=catch and catch._ball
 if caught and caught.stage then return caught.stage end
 if c.ballRef and c.ballRef[1]==a then return c.ballView end
 c.ballRef=setmetatable({a},{__mode='v'});c.ballView=node(c,'ball',nil,a)
 return c.ballView
end
local function slide(s)return(s.introSlide or 0)*Timing.BATTLE_SLIDE_PX_PER_FRAME end
local names={trainer='trainer',healthbox='healthbox',partyBar='party',bgSlide='bg',balls='balls'}
read=function(c,s,kind,id,key)
 if kind=='stage'then
  if key=='slideDone'then return(s.introSlide or 0)<=0 and(s.frlgIntro and s.frlgIntro.hold or 0)<=0 end
  if key=='slide'then
   local intro=s._sourceIntroSequence
   local total=intro and intro.steps[1].data.slideFrames or Timing.BATTLE_SLIDE_IN_FRAMES
   return total>0 and math.max(0,math.min(1,1-(s.introSlide or 0)/total))or 1
  end
  if key=='ball'then return ball(c,s)end
  if key=='win0'then local top=Native.introWindow(s);return top and node(c,'mask')or nil end
  if names[key]then return node(c,names[key])end
 elseif kind=='trainer'or kind=='party'then
  local pos=key=='player'and 0 or key=='enemy'and 1
  if pos then return node(c,kind=='trainer'and'portrait'or'bar',pos)end
 elseif kind=='healthbox'then
  local pos=Coords.fixedId(key);if pos then return node(c,'box',pos)end
 elseif kind=='balls'then
  if type(key)=='number'and key%1==0 and key>=0 and key<=3 then
   local b=battler(s,key);local a=b and s:gen3BallFor(b)
   if a and(a.battler==b or key==1 and not a.battler)then return ball(c,s)end
  end
 elseif kind=='mask'then
  local top,bottom=Native.introWindow(s);return key==1 and top or key==2 and bottom or nil
 elseif kind=='bg'then
  if key=='enemyOx'then return -slide(s)end
  if key=='playerOx'then return slide(s)end
 elseif kind=='box'then
  if key=='visible'then return Native.healthboxVisible(s,id,slide(s))end
  if key=='ox'then return 0 end -- Visible native panels have no slide offset.
 elseif kind=='portrait'then
  local player=id==0
  local constants=s.data.constants.gen3BattlerCoords
  local positions=constants and(s:isDouble()and constants.doubles or constants.singles)
  local p=positions and positions[id+1]or(s:isDouble()and Coords.DOUBLES or Coords.SINGLES)[id]
  if key=='visible'then return player and s.showPlayerBack==true or not player and s.showEnemyTrainer==true end
  if key=='x'then return p.x or p[1]end
  if key=='y'then return p.y or p[2]end
  if key=='ox'then return(player and slide(s)or -slide(s))+s:picOffset(player and'back'or'foe')end
  if key=='oy'then return 0 end
  if key=='frame'then return player and(s:backThrowFrame()or 0)or 0 end
  if key=='picId'and not player then return c.view.trainerPicId end
  if key=='pic2'and not player then return s.trainerB and s.trainerB.picIndex end
  if key=='x2'and not player and s.trainerB then
   local q=positions and positions[4]or Coords.DOUBLES[3];return q.x or q[1]
  end
  if key=='gender'and player then
   local forms=s.data.field and s.data.field.playerForms
   local form=require('src.pokemon.Sprites').playerForm(s.data,s.game.save)
   return forms and form and(forms.girl==form and 1 or 0)or nil
  end
 elseif kind=='bar'then
  local summary,row,party=Native.partySummary(s,id==0)
  if key=='visible'then return summary~=nil end
  if not summary then return nil end
  if key=='x'then return row.barX+(row.flip and(Native.summaryBarWidth(summary)or 0)or 0)end
  if key=='y'then return row.barY end
  if key=='ox'then return Native.summaryRowOffset(summary,row,(s.frame or 0)-(s.introBallsFrom or s.frame or 0))end
  if key=='balls'then return Native.summarySlots(summary,row,party)end
  if key=='ballHidden'then
   local age=(s.frame or 0)-(s.introBallsFrom or s.frame or 0);local hidden={}
   for i=1,summary.count or 6 do hidden[i]=age<Native.SUMMARY_SLIDE_FRAMES+(i-1)*Native.SUMMARY_BALL_FRAMES end
   return hidden
  end
 end
end
function M.current(owner)
 local s=Battle._screen();local view=s and Battle.getState()
 if current and(not live(current)or current.view~=view)then retire(current)end
 if not s then return nil end
 if not current then current={refs=setmetatable({s},{__mode='v'}),view=view,nodes={},users={}}end
 if owner then current.users[owner]=true end
 return node(current,'stage')
end
M._service={release=function()retire(current)end,poll=function()if current then live(current)end end,
 releaseOwner=function(_,who)if current and current.users[who]then retire(current)end end}
require('src.core.game3.asset_stream').register(M._service)
return M
