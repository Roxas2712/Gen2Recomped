-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Authored script fixture: exercise real VM/runner recovery and SAVE bounds.
package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');love.filesystem.load=loadfile
local T=require('tests.harness')
local V=require('src.core.GameVersion')
local W=require('src.import.Gen3RsWhiteout')
local S=require('src.core.SaveSerializer')
local scripts={S0000001={{'call',0x08000020},{'goto',0x08000040}},
 S0000020={{'clearflag',1275},{'clearflag',1276},{'clearflag',1277},
  {'clearflag',1278},{'setvar',0x409C,0},{'return'}},
 S0000040={{'checkflag',123},{'goto_if',1,0x08000060},{'end'}},
 S0000060={{'setflag',124},{'end'}}}
local spec={format=1,version='emerald',entry='S0000001',
 labels={'S0000001','S0000020','S0000040','S0000060'}}
local game={data={constants={gen3RsWhiteout=spec},
 map_scripts={source='RomExtractorGen3',scripts=scripts}},stack={states={}}}
local function fresh(map,scene)
 return {player={map=map,cellX=7,cellY=4},gen3Vars={[0x409C]=scene},
  flags={FLAG_G3_04FB=true,FLAG_G3_04FC=true,FLAG_G3_04FD=true,
   FLAG_G3_04FE=true,FLAG_G3_007B=true,UNRELATED=true},
  party={{species='RAYQUAZA',hp=83}},money=4467,inventory={REVIVE=1}}
end
V.set('emerald')
for _,map in ipairs{'MAP_G16_N10','MAP_G00_N08'}do
 game.save=fresh(map,1)
 T.eq(W.repairEmeraldLeagueReturn(game),true,'stale post-loss healing-point state is recovered')
 for _,flag in ipairs{'04FB','04FC','04FD','04FE'}do
  T.check(not game.save.flags['FLAG_G3_'..flag],'cartridge script clears run-scoped win')
 end
 T.eq(game.save.gen3Vars[0x409C],0,'next room will execute native walk-in')
 T.eq(game.save.flags.FLAG_G3_007C,true,'the complete recovery graph executes its follow-up branch')
 T.eq(game.save.player.map,map);T.eq(game.save.player.cellX,7)
 T.eq(game.save.party[1].hp,83);T.eq(game.save.money,4467)
 T.eq(game.save.inventory.REVIVE,1);T.eq(game.save.flags.UNRELATED,true)
 local after=S.encode(game.save)
 T.eq(W.repairEmeraldLeagueReturn(game),false,'recovery is idempotent')
 T.eq(S.encode(game.save),after)
end
for n=0,9 do
 game.save=fresh(('MAP_G16_N%02d'):format(n),1)
 local before=S.encode(game.save)
 T.eq(W.repairEmeraldLeagueReturn(game),false,'active League rooms and halls retain progress')
 T.eq(S.encode(game.save),before)
end
for _,version in ipairs{'ruby','sapphire','firered','leafgreen'}do
 V.set(version);game.save=fresh('MAP_G16_N10',1)
 local before=S.encode(game.save)
 T.eq(W.repairEmeraldLeagueReturn(game),false,'legacy Emerald repair is edition-scoped')
 T.eq(S.encode(game.save),before)
end
V.set('emerald');game.save=fresh('MAP_G16_N10',0)
local before=S.encode(game.save)
T.eq(W.repairEmeraldLeagueReturn(game),false,'ordinary idle lobby does not reset')
T.eq(S.encode(game.save),before)
T.eq(W.valid(spec,'emerald',{scripts={}}),false,'missing native graph invalidates cache')
local saved=scripts.S0000040;scripts.S0000040=nil
T.eq(W.valid(spec,'emerald',game.data.map_scripts),false,'missing recovery branch invalidates cache')
scripts.S0000040=saved
T.finish('Emerald original whiteout recovery and interrupted League SAVE boundaries')
