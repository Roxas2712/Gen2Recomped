-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Text=require('src.core.game3.rom_text')
local oldGame,oldVersion,oldService=package.loaded['src.core.Game'],V.get(),package.loaded['src.translation.Service']
package.loaded['src.translation.Service']=nil
for _,edition in ipairs{'ruby','sapphire'}do
 V.set(edition)
 local row={plain='AP\nTYP/',nativePlain='native legacy',ir={{t='ext',cmd=1,args={5}},
  {t='text',s='AP'},{t='nl'},{t='text',s='TYP/'},{t='eos'}}}
 local catalog={schema=1,edition=edition,romSha1=V.info().sha1,
  named={BattleText_PP='PP',BattleText_SwitchWhich='SWITCH'},
  records={PP=row,SWITCH={plain='Tauschen\nwelche?',ir={{t='text',s='Tauschen'},{t='nl'},{t='text',s='welche?'},{t='eos'}}}}}
 local data={text={PP='native legacy'},text_pointers={namedIR=catalog}}
 package.loaded['src.core.Game']={data=data,save={player={name='QA'}}}
 T.eq(Text.has('gText_MoveInterfacePP'),true)
 T.eq(Text.plain('gText_MoveInterfacePP'),'AP\nTYP/','retain the actual two-line RS cartridge panel')
 local ir=Text.ir('gText_MoveInterfacePP');T.eq(ir[1].cmd,1);T.eq(ir[1].args[1],5);T.eq(ir[3].t,'nl')
 ir[1].args[1]=99;T.eq(row.ir[1].args[1],5,'borrowed IR is detached')
 T.eq(Text.plain('gText_BattleSwitchWhich'),'Tauschen\nwelche?')
 data.strings={['AP\nTYP/']='Localized panel'};T.eq(Text.plain('gText_MoveInterfacePP'),'Localized panel')
 T.eq(Text.ir('gText_MoveInterfacePP')[1].s,'Localized panel');data.strings=nil
 data.text.PP='Edited RS';T.eq(Text.plain('gText_MoveInterfacePP'),'Edited RS')
 data.text.gText_MoveInterfacePP='Explicit canonical';T.eq(Text.plain('gText_MoveInterfacePP'),'Explicit canonical')
 data.text.gText_MoveInterfacePP=nil;data.text.PP=nil
 T.eq(Text.has('gText_MoveInterfacePP'),false,'native record removal cannot resurrect original lettering')
 T.raises(function()Text.plain('gText_MoveInterfacePP')end,'unavailable')
 data.text.PP='native legacy'
 data._romTextGeneration=3;data.romText={};data._romTextTouched={gText_MoveInterfacePP=true}
 T.eq(Text.has('gText_MoveInterfacePP'),false,'explicit canonical prose removal wins over alternate label')
 data.romText.gText_MoveInterfacePP='Canonical prose';T.eq(Text.plain('gText_MoveInterfacePP'),'Canonical prose')
 data.romText={};data._romTextTouched={BattleText_PP=true}
 T.eq(Text.has('gText_MoveInterfacePP'),false,'alternate prose removal remains authoritative')
 data._romTextTouched={};data.romText.BattleText_PP='Edited prose';T.eq(Text.plain('gText_MoveInterfacePP'),'Edited prose')
 catalog.romSha1='wrong';T.eq(Text.has('gText_MoveInterfacePP'),false,'unverified catalogue cannot authorize aliases')
 package.loaded['src.core.Game']={data={text={}}};T.eq(Text.has('gText_MoveInterfacePP'),false,'no retired data retained')
end
for _,edition in ipairs{'firered','leafgreen','emerald','crystal'}do
 V.set(edition);package.loaded['src.core.Game']={data={text={BattleText_PP='other owner'}}}
 T.eq(Text.has('gText_MoveInterfacePP'),false,'RS aliases are edition bounded')
end
package.loaded['src.core.Game']=oldGame;package.loaded['src.translation.Service']=oldService;V.set(oldVersion)
T.finish('native RS complete PP panel and switch labels preserve edits, IR and current edition ownership')
