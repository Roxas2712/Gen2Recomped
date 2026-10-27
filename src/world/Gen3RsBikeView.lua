-- Select native RS bicycle images without changing shared sprite definitions
-- or save fields. Animation clocks advance only from the field update.
local M={}
function M.bind(player,data)
  player.rsBikeBodies=nil
  local spec=data and data.constants and data.constants.gen3RsBikeSprites
  if not require('src.import.Gen3RsBikeSprites').valid(spec,require('src.core.GameVersion').get())then return end
  local Render=require('src.render.SpriteRenderer');local bodies={}
  for gender,kinds in pairs(spec.avatars)do
    bodies[gender]={}
    for kind,row in pairs(kinds)do
      local renderer=Render.new({id='RS_BIKE_'..gender..'_'..kind,image=row.image,
        frames=row.frameCount,poseFrames=row.frameCount,trueColor=true,gen3ObjectEvent=true,
        frameWidth=32,frameHeight=32,walker=false},'player')
      renderer.poseFrame=function(_,_,frame,flip)return frame,flip end
      local reflected=require('src.render.Assets').image(row.reflectionImage)
      renderer.reflectionImage=function()return reflected end
      bodies[gender][kind]={renderer=renderer,row=row}
    end
  end
  player.rsBikeBodies=bodies
end
function M.update(player)
  if not player.rsBikeBodies then return end
  local state=player.acroState or 'normal'
  if not player.onBike or not player.acroBike then
    player.rsBikeLowerClock=nil;player.rsBikePreviousAcro='normal';return
  end
  if state=='normal'and player.rsBikePreviousAcro and player.rsBikePreviousAcro~='normal'then
    player.rsBikeLowerClock=0
  elseif player.rsBikeLowerClock then
    player.rsBikeLowerClock=player.rsBikeLowerClock+1
    if player.rsBikeLowerClock>=8 then player.rsBikeLowerClock=nil end
  end
  if state~='normal'then player.rsBikeLowerClock=nil end
  player.rsBikePreviousAcro=state
end
function M.pose(player,save)
  if not(player.onBike and player.rsBikeBodies)then return end
  local gender=save and save.player and save.player.gender or 'boy'
  local kind=save and save.bikeKind
  local kinds=player.rsBikeBodies[gender]or player.rsBikeBodies.boy
  local body=kinds and kinds[kind];if not body then return end
  local moving=player.moving or player.freeWalking or player.stepLanded
  local role=moving and 'moving'or 'stand';local clock=player.animClock or 0
  if kind=='acro'then
    if player.acroState=='bunnyHop'then role='wheelie';clock=player.acroHopClock or 0
    elseif player.acroState=='wheelieMoving'then role='pedal'
    elseif player.acroState=='wheelieStanding'then role='wheelie';clock=math.max(0,(player.acroHold or 1)-1)
    elseif player.rsBikeLowerClock then role='lowering';clock=player.rsBikeLowerClock end
  end
  local frame,flip=require('src.import.Gen3RsBikeSprites').frame(body.row,role,player.facing,clock)
  return body.renderer,frame,flip,role
end
return M
