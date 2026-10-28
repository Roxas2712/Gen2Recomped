-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local before=package.loaded['src.core.Game']
local service=package.loaded['src.translation.Service']
local Version=require('src.core.GameVersion');local version=Version.get()
local Types=require('src.core.game3.battle.types')
T.eq(package.loaded['src.core.Game'],before,'type names cannot bootstrap a game')
package.loaded['src.core.Game']=nil;T.eq(Types.name(0),nil)
for _,edition in ipairs{'firered','leafgreen','ruby','sapphire','emerald'}do
 Version.set(edition)
 local constants={typeOrder={'NORMAL','FIGHT','PSYCHC','ELECTR'},types={}}
 for i,key in ipairs(constants.typeOrder)do constants.types[key]={index=i-1,name=key}end
 local data={constants=constants,type_chart={types={PSYCHC={name='Native psychic'}}}}
 package.loaded['src.core.Game']={data=data}
 package.loaded['src.translation.Service']=nil
 T.eq(Types.name(0),'NORMAL','cartridge type zero is a real type')
 T.eq(Types.name(1),'FIGHT');T.eq(Types.name(2),'Native psychic');T.eq(Types.name('PSYCHC'),'Native psychic')
 T.eq(Types.name(3),'ELECTR');T.eq(Types.name(4),nil);T.eq(Types.name(-1),nil)
 T.eq(Types.name(.5),nil);T.eq(Types.name(0/0),nil);T.eq(Types.name(nil),nil)
 T.eq(Types.name('PSYCHIC'),nil,'do not substitute another edition\'s keys')
 package.loaded['src.translation.Service']={name=function(name)return 'translated '..name end}
 T.eq(Types.name(2),'translated Native psychic')
 package.loaded['src.translation.Service']=nil
 data.type_chart.types.PSYCHC.name='Changed registry name'
 T.eq(Types.name(2),'Changed registry name','native registry edits are visible immediately')
 constants.typeOrder={'CUSTOM','NORMAL'};constants.types={CUSTOM={name='Custom type'},NORMAL={name='New normal'}}
 T.eq(Types.name(0),'Custom type','replaced cartridge order invalidates the identifier cache')
 T.eq(Types.name(1),'New normal');T.eq(Types.name(2),nil)
 data.types={CUSTOM={name='Mod catalogue'},NORMAL={name='Mod normal'}}
 T.eq(Types.name(0),'Mod catalogue','merged native catalogue is authoritative')
 package.loaded['src.core.Game']={data={constants={typeOrder={'OTHER'},types={OTHER={name='Other dataset'}}}}}
 T.eq(Types.name(0),'Other dataset','a new session cannot reuse retired names')
 Types._service:releaseOwner('retired_owner');T.eq(Types.name(0),'Other dataset','owner retirement drops only the soft metadata cache')
 Types._service:release();T.eq(Types.name(0),'Other dataset','native session teardown permits fresh metadata admission')
 Version.set('gold');T.eq(Types.name(0),nil,'another generation keeps its own native service')
end
package.loaded['src.core.Game']=before;package.loaded['src.translation.Service']=service
Version.set(version)
T.finish('native GBA type names, cartridge order, translation and dataset replacement')
