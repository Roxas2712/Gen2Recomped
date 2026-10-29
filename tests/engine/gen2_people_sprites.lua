-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Version=require('src.core.GameVersion');local edition=Version.get()
local Game=require('src.core.Game');local World=require('src.world.OverworldController')
local NPC=require('src.world.NPC');local Renderer=require('src.render.SpriteRenderer')
local Metadata=require('src.world.Gen2SpriteMetadata')
local old={data=Game.data,save=Game.save,overworld=Game.overworld,renderer=Renderer.new}
local made=0
Renderer.new=function(def)
 assert(not def.fail,'fixture asset failure');made=made+1
 return{def=def,image=def.image,big=def.big}
end
local gameSlot,oldWorldGame
for i=1,100 do local name,value=debug.getupvalue(World.rebuildPeople,i)
 if not name then break end
 if name=='Game'then gameSlot,oldWorldGame=i,value;break end
end
assert(gameSlot,'actual native Game owner missing')
debug.setupvalue(World.rebuildPeople,gameSlot,Game)
for _,version in ipairs{'gold','silver','crystal'}do
 Version.set(version)
 local def={id='ROUTE_30',sourceId='ROUTE30',objects={
  {index=1,x=1,y=1,sprite='PROBE',movement='STAY',range='DOWN'},
  {index=2,x=2,y=2,sprite='PROBE',movement='STAY',range='DOWN',eventFlag='HIDDEN'},
 }}
 local sheet={id='PROBE',image='cart.png',frames=6,walker=true}
 local data={maps={ROUTE_30=def,ROUTE30=def},sprites={PROBE=sheet},constants={speciesOrder={[155]='CYNDAQUIL'}},pokemon={CYNDAQUIL={id='CYNDAQUIL',index=155}},icons={bySpecies={CYNDAQUIL={image='native-icon.png'}}}}
 local save={flags={HIDDEN=true},objectToggles={},party={},daycare={}}
 local world=setmetatable({game=Game,map={id='ROUTE_30',def=def},npcs={},entities={},npcPool={},player={cellX=3,cellY=4},neighbors={}}, {__index=World})
 Game.data,Game.save,Game.overworld=data,save,world
 local neighbors=0;world.rebuildNeighbors=function()neighbors=neighbors+1 end
 world.setMap=function()error('NPC rebuild must never replay map entry')end
 T.eq(world:rebuildPeople({mapEntry=true}),true,'actual map entry owns the public NPC construction seam')
 T.eq(#world.npcs,1,'native event flag filters hidden actor')
 local actor=world.npcs[1]
 T.eq(actor.id,'ROUTE30_obj_1','native pool/storage identity retained')
 T.eq(actor.mapId,'ROUTE_30','public provenance uses verified loaded map identity')
 T.eq(actor.spriteDef,sheet,'public definition is the actual native renderer input')
 T.eq(actor.sprite.def,sheet,'native renderer sees same definition identity')
 T.eq(neighbors,0,'construction boundary does not recursively build neighbors')
 local guest={id='guest',mapId='ROUTE_30'};local otherMap={id='foreign',mapId='OTHER'};local extra={id='draw-only'}
 world.npcs={actor,guest,otherMap};world.entities={world.player,actor,guest,extra}
 actor.cellX,actor.px,actor.moving,actor.progress,actor.frozen=7,115,true,.25,true
 local moves={{entity=actor}};world.scriptMoves=moves;world.talkNpc=actor
 T.eq(world:rebuildPeople({seamless=true}),true,'seamless live refresh succeeds')
 T.eq(world.npcs[1],actor,'pooled native actor identity retained');T.eq(world.npcs[2],guest,'same-map mod follower retained');T.eq(#world.npcs,2,'foreign-map guest not dragged onto map')
 T.eq(actor.cellX,7,'current cell retained');T.eq(actor.px,115,'fractional walk pixels retained');T.eq(actor.progress,.25,'walk progress retained');T.eq(actor.moving,true,'active movement retained');T.eq(actor.frozen,true,'script freeze retained')
 T.eq(world.scriptMoves,moves,'actual script queue retained');T.eq(world.talkNpc,actor,'talk owner remains native actor')
 T.eq(world.entities[1],world.player,'native player stays first');T.eq(world.entities[2],actor,'actual NPC draws in native entity list');T.eq(world.entities[3],guest,'follower draws once');T.eq(world.entities[4],extra,'non-map entity retained');T.eq(#world.entities,4,'no duplicated actor');T.eq(neighbors,1,'explicit refresh rebuilds resident ghost presentation once')
 actor.big=true -- native object footprint is independent of repainting
 local replacement={id='NEW',image='replacement.png',frames=6,walker=true}
 T.eq(actor:setSpriteDef(replacement),true,'source-style setter reaches actual native actor')
 T.eq(actor.sprite.def,replacement,'new definition reaches real renderer construction');T.eq(actor.spriteDef,replacement,'public renderer definition agrees')
 T.eq(actor.big,true,'appearance change retains native object footprint');T.eq(actor.cellX,7,'appearance change never relocates actor');T.eq(actor.moving,true,'appearance change never cancels movement');T.eq(actor.frozen,true,'appearance change never unfreezes script')
 local before=made;T.eq(actor:setSpriteDef(replacement),false,'same definition is ordinary source no-op');T.eq(made,before,'no redundant renderer for same definition')
 local held=actor.sprite
 T.eq(pcall(actor.setSpriteDef,actor,{image='bad',fail=true}),false,'native asset failure remains visible')
 T.eq(actor.sprite,held,'failed asset retains actual renderer');T.eq(actor.spriteDef,replacement,'failed asset retains actual definition')
 T.eq(actor:setSpriteDef(nil),false,'absent definition refused')
 sheet.image='updated-cart.png';actor:refreshSprite(data)
 T.eq(actor.spriteDef,sheet,'native variablesprite path repaints actual resolved sheet');T.eq(actor.sprite.def.image,'updated-cart.png','in-place changed asset reaches renderer')
 local icon=world:breedmonSpriteDef('CYNDAQUIL')
 T.eq(icon.image,'native-icon.png','day-care base comes from native imported icon registry')
 T.eq(icon.species,'CYNDAQUIL','day-care definition identifies deposited species')
 T.eq(icon.spriteType,'POKEMON_SPRITE','source metadata describes actual native icon')
 save.daycare.breed={[1]={mon={species='CYNDAQUIL'}}}
 T.eq(NPC.resolveSpriteDef(data,'SPRITE_MON_BREED_1'),icon,'actual native day-care NPC resolver uses decorated world definition')
 icon.image='mod-follower.png'
 T.eq(world:breedmonSpriteDef('SPECIES_155'),icon,'numeric legacy and named species share actual cached definition')
 T.eq(world:breedmonSpriteDef('CYNDAQUIL').image,'mod-follower.png','consumer decoration persists without altering imported icon source')
 T.eq(data.icons.bySpecies.CYNDAQUIL.image,'native-icon.png','day-care decoration leaves native icon registry intact')
 data.icons.bySpecies.CYNDAQUIL={image='new-native-icon.png'}
 T.eq(world:breedmonSpriteDef('CYNDAQUIL').image,'new-native-icon.png','changed native resource invalidates cached base')
 T.eq(world:breedmonSpriteDef('MISSING'),nil,'unknown species never gets a made-up icon')
 -- A hidden native object is retired without becoming an extra draw actor.
 save.flags.HIDDEN=false;world:rebuildPeople({seamless=true});T.eq(#world.npcs,3,'newly visible native object constructed')
 local retiring=world.npcs[2];save.flags.HIDDEN=true;world:rebuildPeople({seamless=true})
 for _,entity in ipairs(world.entities)do T.neq(entity,retiring,'retired map NPC never leaks into guest entities')end
 local oldActor=world.npcs[1];world:rebuildPeople({})
 T.neq(world.npcs[1],oldActor,'ordinary source rebuild replaces map-owned pool')
 T.eq(world.npcs[2],guest,'ordinary rebuild retains same-map guest')
end
Version.set('crystal')
local Follower=require('src.world.OptionalFollower')
local spawnPolicy=Follower.setShouldSpawn(function()return true end)
local carried={id='carried',optionalFollower=true,mapId='OLD_MAP'}
local carriedWorld={map={id='NEXT_MAP'},npcs={},entities={}}
Follower.onMapEntered(Game,carriedWorld,{keepFollower=carried})
T.eq(Follower.current(carriedWorld),carried,'native map handoff retains actual optional follower')
T.eq(carried.mapId,'NEXT_MAP','carried follower provenance follows its new native map')
Follower.setShouldSpawn(spawnPolicy)
local row={id='SPRITE_MON_155',monIcon=true,image='icon.png',frames=2,walker=false}
local data={sprites={SPRITE_MON_155=row,SPRITE_RED={id='SPRITE_RED',monIcon=true}},constants={speciesOrder={[155]='CYNDAQUIL'}},pokemon={CYNDAQUIL={index=155}}}
T.eq(Metadata.publish(data),true,'warm native mon-icon definition gains verified species metadata')
T.eq(row.species,'CYNDAQUIL','species comes from actual indexed registry');T.eq(row.spriteType,'POKEMON_SPRITE','source icon type published');T.eq(row.monIcon,true,'native icon tag retained');T.eq(row.image,'icon.png','art bytes/path unchanged');T.eq(data.sprites.SPRITE_RED.species,nil,'human row never reinterpreted as mon')
T.eq(Metadata.publish(data),false,'metadata publish idempotent')
row.species='AUTHORED';T.eq(Metadata.publish(data),false,'authored species identity respected');T.eq(row.species,'AUTHORED','authored value never replaced')
row.species,row.spriteType=nil,nil;Version.set('red');T.eq(Metadata.publish(data),false,'other generations unchanged');T.eq(row.species,nil,'no Gen2 metadata leaked to Gen1')
Version.set('crystal');row.monIcon=false;T.eq(Metadata.publish(data),false,'numbered name alone is insufficient proof')
debug.setupvalue(World.rebuildPeople,gameSlot,oldWorldGame)
Game.data,Game.save,Game.overworld=old.data,old.save,old.overworld;Renderer.new=old.renderer;Version.set(edition)
T.finish('native Gen2 NPC rebuild, sprite definitions and mon metadata')
