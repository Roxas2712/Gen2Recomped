package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local M=require('src.import.Gen3FrlgPresentation');local F=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter');local oldRead,oldExists=F.read,F.exists
local c={gen3SongNames={names={[321]='GAME_FREAK',[277]='INTRO_FIGHT',[278]='TITLE'}}}
for group,keys in pairs(M.IMAGES)do
  c[group]={images={}};for _,key in ipairs(keys)do c[group].images[key]='assets/generated/'..group..'/'..key..'.png'end
end
c.gen3FRLGTitle.nativeController='frlg-native-title-v1'
c.gen3FRLGTitle.cry='VENUSAUR';c.gen3FRLGTitle.effect='leaves'
c.gen3FRLGTitle.images.streak={path='assets/generated/streak.png'}
c.gen3FRLGOakSpeech.text={welcome='WELCOME!'}
c.gen3FRLGMainMenu.format=1;c.gen3FRLGMainMenu.version='leafgreen'
c.gen3FRLGMainMenu.text={continue='CONTINUE',newGame='NEW GAME',player='PLAYER',time='TIME',pokedex='POKéDEX',badges='BADGES'}
c.gen3FRLGMainMenu.bounce={frequency=8,multiplier=2,bounceDir=1}
c.gen3TrainerPresentation={format=1,version='leafgreen',classCount=107};c.trainerClasses={[106]='PLAYER'}
local font={
 dialogueFrame={source='ROM:gfx 041F004, gTextWindowPalettes[0] 04716C8',fill={1,1,1},image='assets/generated/fonts/frlg_dialogue.png'},
 signpostFrame={source='ROM:gfx 04703E8, gTextWindowPalettes[1] 04716E8',fill={1,1,1},image='assets/generated/fonts/frlg_signpost.png'},
 standardFrame={source='ROM:gStdTextWindow_Gfx 0471328, gTextWindowPalettes[3] 0471728',fill={1,1,1},image='assets/generated/fonts/frlg_standard_frame.png'},
}
F.read=function(path)return Writer.encode(path=='data/generated/font.lua'and font or c)end
F.exists=function()return true end
T.eq(#M.missing('leafgreen'),0,'complete native LeafGreen replaces generic boot/summary requirements')
T.eq(#M.missing('firered'),6,'wrong title, menu, trainer and three frame identities cannot be accepted as FireRed')
c.gen3FRLGTitle.images.streak=nil
T.eq(#M.missing('leafgreen'),1,'LeafGreen requires its own streak image')
c.gen3FRLGTitle.images.streak='assets/generated/streak.png'
F.exists=function(path)return path~='assets/generated/streak.png'end
T.eq(M.missing('leafgreen')[1],'assets/generated/streak.png','missing imported image remains a real cache failure')
F.exists=function()return true end
c.gen3FRLGIntro.images.scene3Nidorino=nil
T.eq(#M.missing('leafgreen'),1,'missing native intro actor cannot silently fall back')
c.gen3FRLGIntro.images.scene3Nidorino='assets/generated/nidorino.png'
c.gen3SongNames.names[321]=nil
T.eq(#M.missing('leafgreen'),1,'native GAME_FREAK cue identity is mandatory')
c.gen3SongNames.names[321]='GAME_FREAK';c.gen3FRLGOakSpeech.text.welcome=nil
T.eq(#M.missing('leafgreen'),1,'missing Oak introduction is a cache failure')
c.gen3FRLGOakSpeech.text.welcome='WELCOME!'
c.gen3FRLGMainMenu.text.player=nil
T.eq(#M.missing('leafgreen'),1,'main-menu native labels cannot silently fall back')
c.gen3FRLGMainMenu.text.player='PLAYER';c.gen3FRLGMainMenu.bounce.frequency=nil
T.eq(#M.missing('leafgreen'),1,'main-menu original arrow bounce is mandatory')
F.read=function()return 'return {}'end
T.check(#M.missing('leafgreen')>50,'empty metadata cannot satisfy native readiness')
F.read=function()return 'return {gen3FRLGTitle=true,gen3FRLGOakSpeech=7,gen3SongNames=false}'end
T.check(#M.missing('leafgreen')>50,'malformed metadata fails readiness without raising')
F.read=function()return 'this is not Lua'end
T.eq(M.missing('leafgreen')[1],'data/generated/constants.lua','unreadable metadata fails closed')
F.read,F.exists=oldRead,oldExists
local contract=require('src.import.RomImporter').datasetContract('leafgreen')
local legacy=false;for _,key in ipairs(contract.modules)do if key=='scenes'then legacy=true end end
T.eq(legacy,false,'LeafGreen no longer requests a classic scenes module')
T.eq(#M.missing('emerald'),0,'other families retain their own readiness policy')
T.finish('FRLG native boot and summary cache readiness')
