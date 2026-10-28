package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Assets=require('src.import.Gen3RsBirchAssets')
local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local oldRead,oldExists=Fs.read,Fs.exists
local spec={version='ruby',format=1,azurillSpecies=350,namingIcons={boy='SPRITE_G3_100',girl='SPRITE_G3_105'},
  textIR={},textLists={gMenuYesNoItems={[0]={{t='text',s='YES'}},[1]={{t='text',s='NO'}}}},resources={'fonts.rgba'}}
for _,key in ipairs({'gBirchSpeech_Welcome','gBirchSpeech_ThisIsPokemon','gSystemText_NewPara',
  'gBirchSpeech_WorldInhabitedByPokemon','gBirchSpeech_AndYouAre','gBirchSpeech_AreYouBoyOrGirl',
  'gBirchSpeech_WhatsYourName','gBirchSpeech_SoItsPlayer','gBirchSpeech_AhOkayYouArePlayer',
  'gBirchSpeech_AreYouReady','gBirchText_Boy','gBirchText_Girl'})do spec.textIR[key]={{t='text',s=key}}end
local bodies,files={}, {['fonts.rgba']=true,['birch.png']=true,['naming.png']=true}
for _,sub in ipairs({'birch','naming'})do
  bodies['data/generated/gba/'..sub..'/manifest.lua']=Writer.encode({layout='rs',game='ruby',files={sub..'.png'}})
end
local function constants()bodies['data/generated/constants.lua']=Writer.encode({gen3RsBirch=spec})end
Fs.read=function(path)return bodies[path]end;Fs.exists=function(path)return files[path]end
constants();T.eq(#Assets.missing('ruby'),0,'complete matching RS scene is ready')
T.eq(#Assets.missing('sapphire'),1,'Ruby scene cannot satisfy Sapphire gate')
files['fonts.rgba']=nil;T.eq(Assets.missing('ruby')[1],'fonts.rgba','missing native font invalidates cache')
files['fonts.rgba']=true;spec.textIR.gBirchText_Girl={};constants()
T.eq(Assets.missing('ruby')[1],'<rs:birch-text:gBirchText_Girl>','missing native label invalidates cache')
spec.textLists.gMenuYesNoItems[0]=nil;constants()
T.eq(Assets.missing('ruby')[1],'<rs:native-birch-and-naming>','zero-based YES row is mandatory')
bodies['data/generated/constants.lua']='error("untrusted cache")'
T.eq(Assets.missing('ruby')[1],'<rs:native-birch-and-naming>','invalid constants fail closed in sandbox')
Fs.read,Fs.exists=oldRead,oldExists
T.finish('RS Birch cache identity, text and native resource readiness')
