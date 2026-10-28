-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.battle-source-runtime.fixture')
local R=require('src.script.ScriptRunner')
require('src.script.Gen3Commands')
for _,edition in ipairs{'ruby','sapphire','emerald'}do
  for _,outcome in ipairs{'win','caught','run','lose'}do
    local f=F.new(edition);f.fresh('TACKLE')
    local species=edition=='ruby'and'GROUDON'or'KYOGRE'
    local number=edition=='ruby'and 405 or 404
    local mon=require('src.mods.Merge').deepCopy(f.data.pokemon.CHARMANDER)
    mon.id,mon.name,mon.index=species,species,number
    f.data.pokemon[species]=mon;f.data.constants.speciesOrder[number]=species
    local entered,resumed,created=0,0
    local ow={pushBattle=function(_,b)entered=entered+1;created=b end,
      afterBattle=function(_,result,b)
        resumed=resumed+1;T.eq(result,outcome);T.eq(b,created)
        if result=='win'then T.eq(f.game.save.flags.PROOF_LEGENDARY_FINISHED,true,
          'win field work follows script completion')end
      end}
    local r=R.new(f.game,ow)
    r:run({{'g3_set_wild',number,45,0},{'g3_special',313},{'g3_wait_state'},
      {'g3_special',183,0x800D},{'set_flag','PROOF_LEGENDARY_FINISHED'}})
    T.eq(entered,1,'weather legendary special enters a real battle constructor')
    T.check(r:isRunning(),'script parks for the legendary battle')
    T.eq(f.game.save.flags.PROOF_LEGENDARY_FINISHED,nil,'story cannot complete before a battle outcome')
    T.eq(created.kind,'wild');T.eq(created.legendary,true)
    T.eq(created.enemy.mon.species,species);T.eq(created.enemy.mon.level,45)
    for _=1,5 do r:update()end
    T.eq(entered,1,'waiting does not create duplicate encounters')
    T.eq(f.game.save.flags.PROOF_LEGENDARY_FINISHED,nil,'waiting preserves incomplete story')
    created.onFinish(outcome)
    T.eq(r:isRunning(),false,'actual battle callback releases the VM')
    T.eq(f.game.save.flags.PROOF_LEGENDARY_FINISHED,true)
    T.eq(r.ctx.lastBattleResult,outcome,'script receives its own battle result')
    T.eq(resumed,1,'field continuation runs once')
    f.close()
  end
end
T.finish('GBA Groudon/Kyogre battle construction, level, script wait and outcome ownership')
