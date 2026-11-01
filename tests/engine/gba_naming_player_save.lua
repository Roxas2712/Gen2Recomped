-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Naming=require('src.ui.NamingScreen')
local Assets=require('src.render.Assets')
local Game=require('src.core.Game')
local V=require('src.core.GameVersion')
local Serialize=require('src.core.SaveSerializer')
local oldImage,oldDraw,oldSave=Assets.image,love.graphics.draw,Game.save
local images={}
for _,gender in ipairs{'boy','girl'}do
  images[gender]={gender=gender,getDimensions=function()return 16,32 end}
end
Assets.image=function(path)return assert(images[path],path)end
local drawn
love.graphics.draw=function(image)drawn=image end
local data={sprites={BOY={image='boy',frameWidth=16,frameHeight=32},
  GIRL={image='girl',frameWidth=16,frameHeight=32}},
  field={playerSprites={walk='BOY'},playerForms={boy={walk='BOY'},girl={walk='GIRL'}}}}
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  for _,gender in ipairs{'boy','girl'}do
    -- An embedded intro keeps its choice private until name confirmation.
    -- The unrelated global save deliberately carries the opposite choice.
    Game.save={player={gender=gender=='boy'and'girl'or'boy'}}
    local game={data=data,save={player={gender=gender},inventory={POTION=3}}}
    local before,global=Serialize.encode(game.save),Serialize.encode(Game.save)
    setmetatable({game=game,kind='player'},Naming):drawIcon()
    T.eq(drawn.gender,gender,'keyboard avatar follows its own save context in '..edition)
    T.eq(Serialize.encode(game.save),before,'avatar draw preserves the naming save')
    T.eq(Serialize.encode(Game.save),global,'avatar draw cannot change the authoritative save')
  end
end
Assets.image,love.graphics.draw,Game.save=oldImage,oldDraw,oldSave
T.finish('GBA naming avatars use the owning save without global gender leaks')
