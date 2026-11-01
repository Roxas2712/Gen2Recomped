-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared own-ROM trainer qualification; no ordinary campaign credit.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Native=require('src.battle.BattleState')
  local Pokemon=require('src.pokemon.Pokemon');local version=require('src.core.GameVersion').get()
  local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..version..'%-'))
  local f=assert(io.open(assert(os.getenv('GBA_TRAINER_ORACLE')),'rb'))
  local oracle=J.decode(f:read('*a'));f:close()
  assert(oracle.edition==version and oracle.schema==1)
  assert(require('src.import.RomImporter').readyReport(version).ok)
  -- Data adds compatibility aliases (FRLG's OPP_RIVAL3) after loading the
  -- strictly checked cache. Compare its original cartridge registry only.
  local imported={}
  for _,id in pairs(game.data.constants.trainerOrder)do
    imported[id]=assert(game.data.trainers[id])
  end
  assert(require('src.import.Gen3TrainerBirth').valid(version,game.data.constants,imported))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  local p=game.save.player;U.teleport(game,p.map,p.x,p.y,p.facing);U.wait(60)
  local report={edition=version,status='running',preparedTrainerBirthFixture=true,
    continuousStory=false,trainerCount=0,partyMembers=0,formats={},captures={},cases={}}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()
  end
  local before=Save.encode(game.save)
  local samples={}
  for _,row in ipairs(oracle.trainers)do
    local id=assert(game.data.constants.trainerOrder[row.index])
    local trainer=assert(game.data.trainers[id]);local party=Native.buildTrainerParty(game,id,1,trainer.parties[1])
    assert(#party==#row.party,'Original trainer party size mismatch')
    report.trainerCount=report.trainerCount+1
    report.formats[tostring(row.flags)]=(report.formats[tostring(row.flags)]or 0)+1
    if #party>0 and not samples[row.flags]then samples[row.flags]={id=id,expected=row}end
    for i,expected in ipairs(row.party)do
      local mon=party[i]
      assert(game.data.pokemon[mon.species].index==expected.species,'Wrong original species')
      assert(mon.level==expected.level and mon.personality==expected.personality,'Original fixed trainer identity mismatch')
      assert(mon.nature==game.data.constants.natureOrder[expected.personality%25+1],'Original trainer nature mismatch')
      assert(not Pokemon.isShiny(mon),'Original trainer must not be shiny')
      assert(Pokemon.genderOf(game.data,mon)==expected.gender,'Original trainer gender mismatch')
      assert(mon.abilitySlot==1 or mon.abilitySlot==nil,'Original even PID ability mismatch')
      for key,value in pairs(expected.stats)do
        assert(mon.stats[key]==value,'Original trainer stat mismatch: '..id..'/'..i..'/'..key)
        assert(mon.ivs[key]==expected.fixedIV and mon.evs[key]==0,'Original fixed trainer genes mismatch')
      end
      assert(mon.hp==expected.stats.hp,'Original full trainer HP mismatch')
      if expected.item==0 then assert(mon.item==nil,'Unexpected trainer held item')
      else assert(game.data.items[mon.item].index==expected.item,'Missing original trainer held item')end
      if expected.moves then
        assert(#mon.moves==#expected.moves,'Custom trainer move count mismatch')
        for n,number in ipairs(expected.moves)do
          assert(game.data.moves[mon.moves[n].id].index==number,'Custom trainer move slot mismatch')
          assert(mon.moves[n].pp==game.data.moves[mon.moves[n].id].pp,'Custom trainer PP mismatch')
        end
      end
      report.partyMembers=report.partyMembers+1
    end
  end
  assert(before==Save.encode(game.save),'Trainer creation changed the complete player save')
  report.fullPlayerSavePreservedDuringConstruction=true
  assert(report.trainerCount==oracle.trainerCount and report.partyMembers==oracle.partyMembers)
  for flags=0,3 do assert(samples[flags],'Missing original trainer party format')end
  game.save.party={Pokemon.new(game.data,'BULBASAUR',50),Pokemon.new(game.data,'SQUIRTLE',50)}
  for flags=0,3 do
    local sample=samples[flags]
    local battle=Native.newTrainer(game,sample.id,1);game.stack:push(battle)
    for n=1,1000 do
      if battle.phase=='menu' and not battle.current then break end
      game.input:overlayPressed('b');U.wait(1);game.input:overlayReleased('b');U.wait(12)
    end
    assert(game.stack:top()==battle and battle.phase=='menu','Prepared original trainer intro did not reach menu')
    -- The logical decision precedes the last native throw/send-out frames.
    -- Capture the settled player/healthboxes rather than that transition.
    U.wait(240)
    assert(game.stack:top()==battle and battle.phase=='menu','Native trainer menu did not remain stable')
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(battle.draw,battle))
    assert(bytes==Save.encode(game.save)and rng==love.math.getRandomState(),'Trainer draw changed save/RNG')
    local name='native-trainer-format-'..flags
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name
    report.cases[name]={passed=true,trainerIndex=sample.expected.index,partySize=#battle.enemyParty}
    game.stack:pop();persist()
  end
  report.drawSaveAndRngPreserved=true;report.status='pass';persist()
  print('PASS_GBA_NATIVE_TRAINER_BIRTH',version,report.trainerCount,report.partyMembers)
  love.event.quit(0)
end
