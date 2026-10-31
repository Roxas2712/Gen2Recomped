-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared original-script/actual-input acceptance, separate from campaign saves.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');assert(V.isFRLG())
 local C=require('src.script.Gen3Commands');local VM=require('src.script.Gen3ScriptVM')
 local Warp=require('src.world.Warp');local out=assert(os.getenv('EDITION_QA_OUT'))
 local report={edition=V.get(),status='running',preparedFixture=true,continuousStory=false,cases={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 U.freshSave(game);C.setVar(game.save,0x4068,1)
 local key
 for id,rows in pairs(game.data.map_scripts.scripts)do
  for _,r in ipairs(rows)do
   if r[1]=='setmetatile'and r[2]==6 and r[3]==2 and r[4]==0x296 then key=id end
  end
 end
 assert(key,'Original League open-door program absent')
 for _,mode in ipairs{'opened-after-battle','saved-open-door'}do
  game.save.flags.FLAG_G3_04B8=mode=='saved-open-door'or nil
  C.setVar(game.save,0x4068,1)
  U.teleport(game,'MAP_G01_N75',6,3,'up');U.wait(90)
  local world=game.stack:top();assert(world.map.id=='MAP_G01_N75')
  if mode=='opened-after-battle'then
   game.save.flags.FLAG_G3_04B8=true
   world.runner:run(assert(VM.compile(game.data,key)),{mapId=world.map.id});U.wait(30)
  end
  local map=world.map
  local nativeBlock=map:blockAt(6,2)
  world:stampClosedDoors() -- the actual afterBattle tail must not undo scripts
  assert(map:blockAt(6,2)==nativeBlock,'Legacy afterBattle stamp overwrote the native open door')
  local row={mode=mode,block=map:blockAt(6,2),behavior=map:cellBehaviour(6,2),
   sourceBehavior=map:sourceBehaviourAt(6,2),walkable=map:isWalkableCell(6,2),
   arrival=map:isWarpTileCell(6,2),step=map:isStepWarpCell(6,2),
   arrow=map:arrowWarpDirAt(6,2),resolvedArrival=Warp.onArrive(map,6,2,'up')~=nil}
  report.cases[#report.cases+1]=row;persist()
  game.input:overlayPressed('up');U.wait(20);game.input:overlayReleased('up');U.wait(160)
  row.afterMap=world.map.id;row.afterX=world.player.cellX;row.afterY=world.player.cellY;persist()
  assert(U.shot(game,out..'/'..mode..'.png'))
  assert(world.map.id=='MAP_G01_N76','Native League door did not enter Bruno: '..J.encode(row))
 end
 report.status='pass';persist();print('PASS_NATIVE_FRLG_LEAGUE_DOOR '..V.get());love.event.quit(0)
end
