-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local loaded=package.loaded['src.core.Game']
local C=require('src.core.game3.constants');local G=require('src.core.Game3');local V=require('src.core.GameVersion')
T.eq(package.loaded['src.core.Game'],loaded,'constant queries cannot construct Game')
for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
 local f=require('tools.session-runtime.fixture').new(edition);local game=f.game
 game.data.field.playerForms={boy={picIndex=9},girl={picIndex=10}}
 local view=G.forNative(game);local session=view.session
 local out=C.active(session);T.eq(out.game,edition)
 T.eq(out:require('trainer_classes','TRAINER_PIC_'..(V.isFRLG()and'RED'or'BRENDAN')),9)
 local before=require('src.link.Json').encode(game.save)
 local hoenn=not V.isFRLG()
 if hoenn then
  T.eq(out:require('metatile_labels','METATILE_Building_TV_Off'),2)
  T.eq(out:require('metatile_labels','METATILE_Building_TV_On'),3)
  local copy=out:raw('metatile_labels');copy.byName.METATILE_Building_TV_On=999
  T.eq(out:require('metatile_labels','METATILE_Building_TV_On'),3,'raw enum leaves query detached')
  out.metatile_labels.byName.METATILE_Building_TV_On=777
  T.eq(C.of(edition):require('metatile_labels','METATILE_Building_TV_On'),3,'caller snapshot cannot edit shared facts')
 else
  T.eq(out.metatile_labels,nil,'another tileset namespace is not guessed from Hoenn IDs')
  T.raises(function()out:require('metatile_labels','METATILE_Building_TV_On')end,'missing native constant')
 end
 T.eq(out:id('missing','missing'),nil,'legacy optional query behavior remains')
 T.raises(function()out:require('missing','missing')end,'missing native constant')
 T.raises(function()out:require({},'missing')end,'invalid native constant name')
 T.raises(function()C.active({})end,'foreign or retired')
 T.eq(require('src.link.Json').encode(game.save),before,'queries preserve native save and visit data')
 for _,key in ipairs{'data','save','mods'}do
  out=C.active(session);local old=game[key];game[key]={}
  T.raises(function()out:require('trainer_classes','absent')end,'retired')
  T.raises(function()C.active(session)end,'foreign or retired')
  game[key]=old;session=G.forNative(game).session
 end
 out=C.active(session);V.set('crystal')
 T.raises(function()out:require('trainer_classes','absent')end,'retired')
 T.raises(function()C.active(session)end,'foreign or retired');V.set(edition)
 G.release()
end
V.set('firered');T.finish('native required constants, detached numeric field facts and session boundaries')
