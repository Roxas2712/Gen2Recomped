-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Legacy Gen1 saves use male/female; native Crystal uses boy/girl. Reading
-- either spelling must select the same native art without rewriting a save.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness')
love=require('tests.love_stub')
local Version=require('src.core.GameVersion')
local Sprites=require('src.pokemon.Sprites')
local Player=require('src.world.Player')
local Json=require('src.link.Json')
local previousVersion=Version.get()
local previousGame=package.loaded['src.core.Game']
Version.set('crystal')

local data={constants={gen=2},field={playerSprites={walk='SPRITE_CHRIS',bike='SPRITE_CHRIS_BIKE'}},sprites={}}
for _,id in ipairs{'SPRITE_CHRIS','SPRITE_CHRIS_BIKE','SPRITE_KRIS','SPRITE_KRIS_BIKE'}do
 data.sprites[id]={id=id,image=id..'.png',frames=6}
end
local function form(id)
 return {walk='SPRITE_'..id,bike='SPRITE_'..id..'_BIKE',
  card=id..'-card.png',intro=id..'-intro.png',back=id..'-back.png',
  fish={down=id..'-fish-down.png',up=id..'-fish-up.png',side=id..'-fish-side.png'}}
end
local boy,girl=form('CHRIS'),form('KRIS')
data.field.playerForms={boy=boy,girl=girl}
local game={data=data}
package.loaded['src.core.Game']=game

for _,row in ipairs{{'boy',boy},{'male',boy},{'girl',girl},{'female',girl}}do
 local gender,expected=row[1],row[2]
 local save={player={gender=gender,name='QA HERO'},flags={untouched=true}}
 local before=Json.encode(save)
 game.save=save
 T.eq(Sprites.playerForm(data,save),expected,gender..' explicit save selects native form')
 T.eq(Sprites.playerForm(data),expected,gender..' active save selects native form')
 local player=Player.new(data,3,4,'down')
 T.eq(player.walkId,expected.walk,gender..' native walking identity')
 T.eq(player.sprite.def,data.sprites[expected.walk],gender..' actual walking renderer definition')
 T.eq(player.bikeId,expected.bike,gender..' native bicycle identity')
 T.eq(player.bikeSprite.def,data.sprites[expected.bike],gender..' actual bicycle renderer definition')
 T.eq(player.fishTiles.down,expected.fish.down,gender..' native fishing pose')
 T.eq(Sprites.playerPath(data,'front',{save=save}),expected.card,gender..' trainer-card portrait')
 T.eq(Sprites.playerPath(data,'front',{save=save,kind='intro'}),expected.intro,gender..' intro portrait')
 T.eq(Sprites.playerPath(data,'back',{save=save}),expected.back,gender..' battle back portrait')
 T.eq(Json.encode(save),before,gender..' rendering leaves the entire save unchanged')
 local restored=Json.decode(before)
 game.save=restored
 player:refreshForm(data)
 T.eq(player.walkId,expected.walk,gender..' identity after save round trip')
 T.eq(restored.player.gender,gender,gender..' saved spelling is preserved')
end

-- Switching the active save in one process must refresh an existing player.
game.save={player={gender='male'},flags={}}
local player=Player.new(data,1,1)
game.save={player={gender='female'},flags={}};player:refreshForm(data)
T.eq(player.sprite.def.id,'SPRITE_KRIS','live legacy male -> female refresh')
T.eq(player.bikeSprite.def.id,'SPRITE_KRIS_BIKE','live legacy bicycle refresh')
game.save={player={gender='boy'},flags={}};player:refreshForm(data)
T.eq(player.sprite.def.id,'SPRITE_CHRIS','live legacy female -> native boy refresh')

-- Cartridge/mod-specific keys win over aliases, including a literal female
-- form. Prism's named forms and the historical unknown-key fallback survive.
local custom={walk='CUSTOM'}
data.field.playerForms.female=custom
T.eq(Sprites.playerForm(data,{player={gender='female'}}),custom,'explicit female form retains priority')
data.field.playerForms.female=nil
data.field.playerForms.p3=custom
T.eq(Sprites.playerForm(data,{player={gender='p3'}}),custom,'custom cartridge form is not normalized')
T.eq(Sprites.playerForm(data,{player={gender='unknown'}}),boy,'unknown-key fallback unchanged')
T.eq(Sprites.playerForm(data,{player={}}),boy,'missing-gender fallback unchanged')
data.field.playerForms=nil
for _,edition in ipairs{'gold','silver','red'}do
 Version.set(edition)
 T.eq(Sprites.playerForm(data,{player={gender='female'}}),nil,edition..' gains no unsupported form')
end

Version.set(previousVersion)
package.loaded['src.core.Game']=previousGame
T.finish('Crystal native player gender aliases')
