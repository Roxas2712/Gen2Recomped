package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Gate=require('src.import.Gen3RsStarterAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local Native=require('src.ui.Gen3RsStarterSelect');local Host=require('src.ui.Gen3StarterSelect')
local oldGV=package.loaded['src.core.GameVersion'];local version='ruby'
package.loaded['src.core.GameVersion']={get=function()return version end}
local spec={format=1,version='ruby',species={{id='TREECKO'},{id='TORCHIC'},{id='MUDKIP'}},pics={},dex={},
  textIR={},resources={'hand.png'}}
for _,key in ipairs({'gOtherText_BirchInTrouble','gOtherText_DoYouChoosePoke','gOtherText_Poke','OtherText_Yes','OtherText_No'})do spec.textIR[key]={{t='text',s=key}}end
local game={data={constants={gen3RsStarter=spec}}}
T.eq(Native.available(game),spec,'matching RS scene is selected')
T.eq(Host.available(game),spec,'host choice route reaches native RS')
version='sapphire';T.check(not Native.available(game),'other edition cannot reuse native scene metadata')
version='emerald';local legacy={background='old.png',sprites='sheet.png',ballX={1,2,3},ballY={1,2,3}}
game.data.constants.gen3StarterSelect=legacy
T.eq(Host.available(game),legacy,'Emerald retains existing starter route')
local oldRead,oldExists=Fs.read,Fs.exists;local files={['hand.png']=true,['grass.png']=true};local bodies={}
bodies['data/generated/gba/starter_choose/manifest.lua']=Writer.encode({layout='rs',game='ruby',files={'grass.png'}})
local function constants()bodies['data/generated/constants.lua']=Writer.encode({gen3RsStarter=spec,
  gen3StartMenu={pokedexFlag='FLAG_G3_0801',pokenavFlag='FLAG_G3_0802',nativeGateSource='ROM:verified predicate'}})end
Fs.read=function(p)return bodies[p]end;Fs.exists=function(p)return files[p]end
constants();T.eq(#Gate.missing('ruby'),0,'complete native RS starter cache is ready')
T.eq(#Gate.missing('sapphire'),1,'wrong-version cache fails closed')
files['hand.png']=nil;T.eq(Gate.missing('ruby')[1],'hand.png','lost hand invalidates completed import')
files['hand.png']=true;spec.textIR.OtherText_No={};constants()
T.eq(Gate.missing('ruby')[1],'<rs:starter-text:OtherText_No>','missing NO text invalidates import')
Fs.read,Fs.exists=oldRead,oldExists;package.loaded['src.core.GameVersion']=oldGV
T.finish('Native RS starter readiness and unchanged Emerald routing')
