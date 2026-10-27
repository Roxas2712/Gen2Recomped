-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Bind the host's battle vocabulary to the corresponding native ROM lines.
-- Install a template only when it keeps the caller's formatting arity.
local B={}
local lines={
 {'Wild %s\nappeared!','sText_WildPkmnAppeared','_WildMonAppearedText'},
 {'%s\nused %s!','sText_AttackerUsedX','_ItemUseText001'},
 {"%s's\nattack missed!",'sText_AttackMissed','_AttackMissedText'},
 {'A critical hit!','sText_CriticalHit'},
 {"It's super\neffective!",'sText_SuperEffective'},
 {"It's not very\neffective...",'sText_NotVeryEffective'},
 {'But, it failed!','sText_ButItFailed','_ButItFailedText'},
 {"But it failed!",'sText_ButItFailed'},
 {'%s\nfainted!','sText_TargetFainted'},
 {"Can't escape!",'sText_CantEscape','_CantEscapeText'},
 {'Got away safely!','sText_GotAwaySafely','_GotAwayText'},
 {'%s\nis fast asleep!','sText_PkmnFastAsleep','_FastAsleepText'},
 {'%s\nwoke up!','sText_PkmnWokeUp','_WokeUpText'},
 {'%s\nis frozen solid!','sText_PkmnIsFrozen','_IsFrozenText'},
 {'%s\nis confused!','sText_PkmnIsConfused','_IsConfusedText'},
 {'It hurt itself in\nits confusion!','sText_ItHurtConfusion','_HurtItselfText'},
 {'%s\nflinched!','sText_PkmnFlinched','_FlinchedText'},
 {'%s must\nrecharge!','sText_PkmnMustRecharge','_MustRechargeText'},
 {'%s\nis fully paralyzed!','sText_PkmnIsParalyzed'},
 {'%s is hurt\nby poison!','sText_PkmnHurtByPoison'},
 {'%s is hurt\nby its burn!','sText_PkmnHurtByBurn'},
 {'%s is hit\nwith recoil!','sText_PkmnHitWithRecoil'},
 {"%s's\nSUBSTITUTE broke!",'sText_SubstituteFaded','_SubstituteBrokeText'},
 {'The SUBSTITUTE\ntook damage for %s!','sText_SubstituteDamaged','_SubstituteTookDamageText'},
 {'%s gained\n%s EXP. Points!','sText_PkmnGainedEXP'},
 {'%s grew to\nlevel %s!','sText_PkmnGrewToLv'},
 {"Don't be a thief!",'sText_DontBeAThief'},
 {'%s was\ncaught!','sText_GotchaPkmnCaughtPlayer'},
}
-- Ruby/Sapphire use the older battle_message.c symbol names. These are
-- explicit semantic bindings, not matches against the displayed English.
local rsLabels={
 sText_AttackerUsedX='BattleText_Used1',
 sText_WildPkmnAppeared='BattleText_WildAppeared1',
 sText_AttackMissed='BattleText_AttackMissed',
 sText_CriticalHit='BattleText_Critical',
 sText_SuperEffective='BattleText_SuperEffective',
 sText_TargetFainted='BattleText_DefendingFainted',
}
-- Preserve the cartridge's CLEAR_TO column boundary before plain-text decoding
-- removes that layout control. This is independent of the host extractor.
function B.menu(ir,T)
 local cells,row,col={{''}},1,1
 local gap
 for _,node in ipairs(ir)do
  if node.t=='nl'then row=row+1;col=1;cells[row]={''}
  elseif node.t=='ext'and node.cmd==0x13 then col=col+1;cells[row][col]='';gap=gap or node.args[1]
  elseif node.t=='text'then cells[row][col]=cells[row][col]..T.plain({node},'emerald')end
 end
 if #cells==2 and #cells[1]==2 and #cells[2]==2 and gap and gap>0 then return {rows=cells,columnX=gap}end
end
function B.apply(data,c,T)
 local count=0
 -- The native battle code spells these labels differently from the GBA
 -- stat table (SPCL.ATK vs SP. ATK; EVADE vs evasiveness). Bind by stat ID.
 data.strings=data.strings or{}
 for source,index in pairs({ATTACK=1,DEFENSE=2,SPEED=3,
  ['SPCL.ATK']=4,['SPCL.DEF']=5,ACCURACY=6,EVADE=7,EVASION=7})do
  local value=c.named['gStatNamesTable['..index..']']
  if type(value)=='string'and value~=''then data.strings[source]=value end
 end
 local menu=data.constants and data.constants.gen3BattleMenu
 if menu and c.battleMenu then menu.rows=c.battleMenu.rows;menu.columnX=c.battleMenu.columnX end
 if menu and c.named.gText_WhatWillPkmnDo then
  local prompt=c.named.gText_WhatWillPkmnDo:gsub('{B_12}','{MON}')
  local a,b=prompt:match('^([^\n]+)\n([^\n]+)$')
  if a and b and b:find('{MON}',1,true)then menu.prompt={a,b}end
 end
 if menu and menu.rows then
  for i,key in ipairs({'FIGHT','ITEM','PKMN','RUN'})do local row=i<=2 and 1 or 2;local col=(i-1)%2+1
   -- Cartridge row order is FIGHT/BAG, POKEMON/RUN.
   data.strings[key]=menu.rows[row][col]
  end
 end
 if c.named.gText_ChoosePokemon then data.strings['Choose a POKéMON.']=c.named.gText_ChoosePokemon end

 local function arity(s)local n=0;for x in s:gmatch('%%(.)')do if x~='%'then n=n+1 end end;return n end
 for _,row in ipairs(lines)do
  local native=c.named[row[2]]or c.named[rsLabels[row[2]]]
  if native then
   local template=T.format(native)
   if arity(template)==arity(row[1])then
    data.strings[row[1]]=template;count=count+1
    if row[3]then data.text[row[3]]=native end
   end
  end
 end
 return count
end
return B
