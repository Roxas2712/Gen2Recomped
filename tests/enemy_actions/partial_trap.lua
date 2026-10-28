local M={}
M.moves={{20,'BIND'},{35,'WRAP'},{83,'FIRE_SPIN'},{128,'CLAMP'},{250,'WHIRLPOOL'},{328,'SAND_TOMB'}}
function M.fixture(version)
  local moves=M.moves
  return require('tests.enemy_actions.fixture').new('.','gen2',version,3,'unified',function(data,_,ids)
    for _,row in ipairs(moves)do
      local number,id=unpack(row);ids[id]=id
      data.moves[id]={id=id,index=number,name=id,effect='TRAPPING_EFFECT',gen3Effect=42,
        power=15,type='NORMAL',accuracy=100,pp=10,target=0,flags=2,protectAffected=true}
    end
    ids.RAPID_SPIN='RAPID_SPIN'
    data.moves.RAPID_SPIN={id='RAPID_SPIN',index=229,name='RAPID SPIN',effect='RAPID_SPIN_EFFECT',
      gen3Effect=129,power=20,type='NORMAL',accuracy=100,pp=10,target=0,flags=2,protectAffected=true}
    data.pokemon.CHARMANDER.abilities={}
    data.type_chart.matchups[#data.type_chart.matchups+1]={attacker='NORMAL',defender='GHOST',multiplier=0}
    data.items.SMOKE_BALL={id='SMOKE_BALL',index=194,holdEffect='CAN_ALWAYS_RUN',gen3HoldEffect=37}
  end)
end
return M
