package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local V=require('src.core.GameVersion')
local Localization=require('src.mods.Localization')
local original=V.get()
for _,game in ipairs({'red','blue','yellow','gold','silver','crystal','firered','leafgreen','ruby','sapphire','emerald'}) do
 V.set(game)
 local run=T.sdk.loadMod('mods/language_capability',{
  data=T.fixtures.fresh(),
  fs=T.sdk.memfs({
   ['mods/language_capability/manifest.json']=[[{"id":"language_capability","name":"Language capability","version":"1.0.0","api":2,"games":["all"],"generations":[1,2,3],"entry":"main.lua"}]],
   ['mods/language_capability/main.lua']=[[return function(mod)
    mod.exports.native=mod:supports('localization','rom-language-v1')
    mod.exports.format=mod.localization.format
    mod.exports.unrelated=mod:supports('localization','unknown-format')
    mod.exports.strings=mod:supports('content','strings')
   end]],
  }),
 })
 T.eq(#run.errors,0,game..' public language discovery loads')
 local exports=assert(run.loader.exports.language_capability)
 T.eq(exports.native,true,game..' exposes the native language protocol')
 T.eq(exports.format,'rom-language-v1',game..' publishes its format')
 T.eq(exports.unrelated,false,'unknown formats do not pass discovery')
 T.eq(exports.strings,true,'existing content capabilities still work')
 run.release()
end
for _,game in ipairs({'prism','polishedcrystal','platinum','heartgold','black'}) do
 T.eq(Localization.supports(game,'rom-language-v1'),false,'unprofiled game is unavailable')
end

-- Exercise sandbox separation and one-install ownership without a cartridge.
local main=package.loaded['src.translation.rompack.main']
local ls=love.filesystem
local api={gameVersion='gold',exports={},supports=function()return false end,read=function(_,path)return 'MOD:'..path end}
love.filesystem={getDirectoryItems=function()return{}end,read=function(path)return 'HOST:'..path end}
package.loaded['src.translation.rompack.main']=function(proxy)
 T.eq(proxy:read('profile.lua'),'MOD:profile.lua','ordinary recipes stay inside the mod')
 T.eq(proxy:read('@host/identity.lua'),'HOST:src/translation/rompack/identity.lua','native helpers are read from the engine')
 T.eq(pcall(proxy.read,proxy,'@host/../core/Game.lua'),false,'host recipe traversal is refused')
 proxy.exports.installed=true
 return true
end
Localization.install({}, {manifest={}},api)
T.eq(api.localization:install(),true,'public installation dispatches to native code')
T.eq(api.exports.installed,true,'native provider retains the mod export identity')
T.eq(pcall(api.localization.install,api.localization),false,'double installation is refused')
local ds={gameVersion='platinum',supports=function()return false end}
Localization.install({}, {manifest={}},ds)
T.eq(pcall(ds.localization.install,ds.localization),false,'unsupported native game cannot install a pack')
package.loaded['src.translation.rompack.main']=main;love.filesystem=ls

-- Actual central Assets APIs resolve in-memory native resources without
-- intercepting LOVE. Retired sessions cannot supply files to the next game.
local Assets=require('src.render.Assets')
local oldImageModule=love.image
local oldDataModule=love.data
love.image=love.image or{}
love.data=love.data or{}
local image,imageData=love.graphics.newImage,love.image.newImageData
local byteData=love.data.newByteData
local active=true
local layer={files={['native-test/title.png']='PNG'},paths={['assets/generated/native-test.png']='native-test/title.png'}}
love.data.newByteData=function(bytes)return{bytes=bytes}end
love.image.newImageData=function(source)
 assert(type(source)=='table'and source.bytes=='PNG','native pixels did not reach decoder')
 return{decoded=true}
end
love.graphics.newImage=function(source)assert(source.decoded);return{nativeImage=true}end
local constructor=love.graphics.newImage
Assets.languageLayer('native-test',layer,function()return active end)
T.eq(Assets.resolve('assets/generated/native-test.png'),'native-test/title.png','native route resolves')
T.eq(Assets.exists('native-test/title.png'),true,'virtual source is discoverable')
T.eq(Assets.image('assets/generated/native-test.png').nativeImage,true,'native renderer decodes virtual PNG')
T.eq(Assets.imageData('assets/generated/native-test.png').decoded,true,'native pixel readers use virtual PNG')
T.eq(love.graphics.newImage,constructor,'LOVE constructor is not patched')
active=false
T.eq(Assets.resolve('assets/generated/native-test.png'),'assets/generated/native-test.png','retired layer stops resolving')
T.eq(Assets.exists('native-test/title.png'),false,'retired source is hidden')
love.graphics.newImage=image;love.image.newImageData=imageData;love.data.newByteData=byteData
love.image=oldImageModule
love.data=oldDataModule
Assets.invalidate();V.set(original)
local Memo=require('src.translation.rompack.memo')
local leaf={constants={}}
Memo.apply(leaf,{gText_PokeSum_Met='Wesen: {NATURE}\n{LOCATION} Lv{LEVEL}',gText_PokeSum_MetInATrade='Wesen: {NATURE}\nTausch',gText_PokeSum_Hatched='Wesen: {NATURE}\nEi'},'leafgreen')
T.eq(leaf.constants.gen3Memo.templates.bare,'Wesen: {NATURE}','LeafGreen creates a native display record when the old importer omitted it')
T.eq(leaf.constants.gen3Memo.templates.trade,'Wesen: {NATURE}\nTausch','FRLG trade retains the exact localized cartridge template')
local ruby={constants={}}
Memo.apply(ruby,{gOtherText_Nature='Wesen: ',gOtherText_Lv='Lv.',gOtherText_Met=' (gef.)',gOtherText_ObtainedInTrade='im Tausch erhalten.'},'ruby')
T.eq(ruby.constants.gen3Memo.templates.bare,'Wesen: {NATURE}','RS nature uses its own localized prefix')
T.eq(ruby.constants.gen3Memo.templates.trade,'Wesen: {NATURE}\nim Tausch erhalten.','RS trade retains its native fragment')
T.check(not ruby.constants.gen3Memo.templates.hatched:find('gef.',1,true),'RS hatch does not claim an ordinary capture')
T.eq(ruby.constants.gen3Memo.templates.met,'Wesen: {NATURE}\n{LOCATION}\nLv.{LEVEL} (gef.)','RS memo composes source fragments around semantic native slots')
local Battle=require('src.translation.rompack.gba_battle')
local Plain=require('src.translation.rompack.gba_text')
local battle={constants={},text={},strings={}}
Battle.apply(battle,{named={BattleText_Used1='{B_20} setzt\n{B_13} ein!'}},Plain)
T.eq(battle.strings['%s\nused %s!'],'%s setzt\n%s ein!','RS battle labels bind to the native two-argument message')
local original=battle.strings['%s\nused %s!']
Battle.apply(battle,{named={BattleText_Used1='{B_20} {B_13} {B_19}'}},Plain)
T.eq(battle.strings['%s\nused %s!'],original,'mismatched battle argument roles cannot replace the native message')
local GB=require('src.translation.rompack.gb');local gb={text={hello='Hello'},strings={}}
GB.apply(gb,{dialogue={hello='Olá!{DONE}{PROMPT}'}})
T.eq(gb.text.hello,'Olá!','language-cartridge ending metadata never becomes visible text on the US host')
local GBA=require('src.translation.rompack.gba')
local chat={groups={{kind='text',count=1,words={{text='HELLO',id=42,enabled=true}}}}}
local gd={text={},constants={gen3EasyChat=chat},type_chart={types={}}}
local catalogs={pairs={HELLO='OLÁ'},dialogue={},strings={},named={}}
local own=function(path)
 if path=='@host/gba_catalogs.lua'then return{easyChat=function(data)
  T.eq(data.constants.gen3EasyChat.groups[1].words[1].text,'HELLO','generic aliases leave Easy Chat source labels intact until stable-ID resolution')
  data.constants.gen3EasyChat.groups[1].words[1].text='OLÁ';return 1
 end}end
 if path=='@host/gba_world.lua'then return{apply=function()return 0 end}end
 return require('src.translation.rompack.'..assert(path:match('^@host/(.+)%.lua$')))
end
GBA.apply(gd,catalogs,own,{language='pt-BR',profile={game='emerald'}})
T.eq(chat.groups[1].words[1].id,42,'Easy Chat retains saved word IDs')
T.eq(chat.groups[1].words[1].enabled,true,'Easy Chat retains word availability')
-- PT-BR FireRed/LeafGreen expanded the category to 20 bytes and moved both
-- description pointers. All 386 entries must retain both original pages.
local Dex=require('src.translation.rompack.gba_dex')
for _,layout in ipairs({{size=44,category=20,desc=24,second=true},
                       {size=36,category=12,desc=16,second=true},
                       {size=32,category=12,desc=16,second=false}})do
 local fields={POKEDEX_ENTRIES=1024,POKEDEX_ENTRY_SIZE=layout.size,
  POKEDEX_NAME_LENGTH=layout.category,POKEDEX_TEXT_OFFSET=layout.size==44 and 24 or nil}
 local pointers={}
 for index=1,386 do
  local at=1024+index*layout.size
  pointers[at+layout.desc]=0x100000+index*16
  if layout.second then pointers[at+layout.desc+4]=0x200000+index*16 end
 end
 local entries=Dex.read(fields,function(at)return pointers[at]end,
  function(at,limit)assert(limit==layout.category);return 'category:'..at end,
  function(at,battle,limit)assert(battle==false and limit==4096);return 'ROM:'..at end)
 T.eq(#entries,386,'every national dex record is decoded')
 for index=1,386 do
  T.eq(entries[index].text,'ROM:'..(0x100000+index*16),'profile selects the first original page')
  T.eq(entries[index].text2,layout.second and 'ROM:'..(0x200000+index*16)or nil,'profile selects the second original page')
 end
end
T.eq(next(Dex.read({},function()error('no table')end)),nil,'absent dex table stays absent')
-- Display arguments must use the localized record, while gameplay IDs and
-- nicknames keep their identities. Marker fixtures are not dialogue evidence.
local Strings=require('src.core.Strings')
local State=require('src.battle.BattleState')
local Effects=require('src.battle.MoveEffects')
local localized={strings={ATTACK='STAT_FROM_ROM'},
 constants={abilities={DROUGHT={name='ABILITY_FROM_ROM'}}}}
T.eq(State.abilityLabel('DROUGHT',localized),'ABILITY_FROM_ROM','ability display reads the localized native record')
T.eq(State.abilityLabel('WATER_ABSORB'),'WATER ABSORB','ordinary English ability label is preserved')
Strings.load(localized)
local actor={name='ATTACK',isPlayer=true,stages={}}
local changed=Effects.changeStage({data=localized},actor,'attack',1,false)
T.eq(actor.stages.attack,1,'typed display names do not change battle stages')
T.eq(changed[1],"ATTACK's\nSTAT_FROM_ROM rose!",'only the stat argument is localized; nickname is unchanged')
local spoken={}
local state={data=localized,field={},sayNext=function(_,text)spoken[#spoken+1]=text end}
State.abilitySwitchInEffect(state,{name='DROUGHT',isPlayer=true},
 {kind='weather',weather='SUN',permanent=true,ability='DROUGHT'})
T.eq(spoken[1],"DROUGHT's\nABILITY_FROM_ROM!",'actual local ability caller reads the ROM name')
T.eq(state.field.weather,'SUN','weather gameplay identity remains native')
Strings.load(nil)
local UiText=require('src.translation.rompack.ui_text')
local captions={strings={['LEVEL UP']='LEVEL UP'}}
UiText.apply(captions,'de',{named={gText_TrainerCardTime='TIME_FROM_ROM'}})
T.eq(captions.strings['LEVEL UP'],'LEVEL UP','an original German caption is not rewritten as a guessed translation')
T.eq(captions.strings.TIME,'TIME_FROM_ROM','trainer card duration uses its own source caption')
T.eq(captions.strings['QUIT GAME'],nil,'missing original wording is not invented')
T.eq(captions.strings['Choose a POKéMON.'],nil,'absent party source is not guessed')
local statData={strings={}}
Battle.apply(statData,{named={['gStatNamesTable[4]']='SPECIAL_ATTACK_FROM_ROM',
 ['gStatNamesTable[7]']='EVASION_FROM_ROM'}},Plain)
T.eq(statData.strings['SPCL.ATK'],'SPECIAL_ATTACK_FROM_ROM','native stat spelling resolves the original semantic table slot')
T.eq(statData.strings.EVADE,'EVASION_FROM_ROM','native evasion spelling uses its original stat ID')
local baseline={strings={NAME='NAME'}}
UiText.apply(baseline,'en')
T.eq(baseline.strings['NAME/'],nil,'English restoration does not alter the baseline catalog')
T.eq(pcall(require('src.translation.rompack.pc_labels').apply,nil,nil),true,'English baseline without a string catalog restores safely')
T.finish('native ROM language protocol, ownership, sandbox and rendering')
