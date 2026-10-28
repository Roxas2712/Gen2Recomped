package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local V=require('src.core.GameVersion');V.set('ruby')
local Fs=require('src.import.CacheFs')
local Writer=require('src.import.LuaWriter')
local SummaryAssets=require('src.import.Gen3RsSummaryAssets')
local oldRead,oldExists=Fs.read,Fs.exists
local manifests,exists={},{}
for _,sub in ipairs({'summary','summary_extras'})do
  local path='data/generated/gba/rse/'..sub..'/manifest.lua'
  local png='data/generated/gba/rse/'..sub..'/test.png'
  local man={layout='rs',game='ruby',files={png},egg=png,eggName='EGG',locations={},balls={}}
  for i=1,12 do man.balls[i]=png end
  manifests[path]=Writer.encode(man);exists[png]=true
end
Fs.read=function(p)return manifests[p]end;Fs.exists=function(p)return exists[p]end
T.eq(#SummaryAssets.missing('ruby'),0,'complete native summary resources are ready')
T.eq(#SummaryAssets.missing('sapphire'),2,'another edition cannot satisfy summary readiness')
exists['data/generated/gba/rse/summary/test.png']=nil
T.eq(#SummaryAssets.missing('ruby'),1,'missing page art invalidates the cache')
manifests['data/generated/gba/rse/summary_extras/manifest.lua']='return {game="ruby",layout="rs",files={"any"}}'
T.eq(#SummaryAssets.missing('ruby'),2,'old extras without native egg/location metadata are rejected')
Fs.read,Fs.exists=oldRead,oldExists
local nativePath='data/generated/gba/rse/summary/manifest.lua'
love.filesystem.load=function(path)
  if path==nativePath then return function()return {game='ruby',layout='rs',doubleBattleOrder={0,2,1,3,4,5},textColors={[13]={color=13,shadow=14,background=0}}}end end
  return loadfile(path)
end
local Menu=require('src.ui.Gen3SummaryMenu')
local function mon(id)
  return {species='TEST',nickname=id,gender='male',level=12,personality=0,ot='TEST',otId=9,
    hp=20,stats={hp=31,attack=18,defense=12,spatk=15,spdef=16,speed=17},
    moves={{id='SURF',pp=3,ppUps=2},{id='TACKLE',pp=11,ppUps=1}},exp=1728}
end
local first,egg,last=mon('FIRST'),mon('EGG'),mon('LAST');egg.isEgg=true
local game={data={pokemon={TEST={index=1,dex=1,name='TEST',types={'NORMAL','NORMAL'},growthRate='MEDIUM_FAST',abilities={'NONE'},
  baseStats={hp=40,attack=45,defense=35,speed=70,spatk=65,spdef=55},evYield={speed=1}}},
  moves={SURF={id='SURF',index=57,name='SURF',pp=15,type='WATER'},TACKLE={id='TACKLE',index=33,name='TACKLE',pp=35,type='NORMAL'},
    NEW={id='NEW',index=100,name='NEW',pp=10,type='NORMAL'}},
  type_chart={types={NORMAL={index=0},WATER={index=11}}},items={},audio={},
  constants={gen3RsSummary={format=1,version='ruby',text={},locations={[16]='ROUTE 101'},eggName='EGG',natureNames={}},
    gen3HoennDex={numbers={TEST=1}},natureOrder={'HARDY'},abilities={NONE={index=0,name='NONE'}},
    machines={{kind='HM',move='SURF'}}}},
  save={inventory={},options={},player={name='TEST',id=9},party={first,egg,last}},
  input={pressed={}}}
function game.input:wasPressed(key)return self.pressed[key]end
for i=1,25 do game.data.constants.gen3RsSummary.natureNames[i]='HARDY'end
local screen,pops,changes=nil,0,{}
game.stack={pop=function()pops=pops+1;if screen then screen:exit()end end}
local function open(opts)
  opts=opts or {};opts.mon=opts.mon or first
  screen=Menu.new(game,opts)
  T.check(screen.rsNative~=nil,'native RS summary is enabled by matching metadata')
  for _=1,20 do game.input.pressed={};screen:update(1/60)end
  return screen
end
local function press(key,settle)
  game.input.pressed={[key]=true};screen:update(1/60)
  for _=1,settle or 0 do game.input.pressed={};screen:update(1/60)end
end
open({party=game.save.party,partyIndex=1,onMonChange=function(i,m)changes[#changes+1]={i,m}end})
T.eq(screen:uiSize(),240,'native summary owns its GBA surface')
local textAdapter=screen.rsNative.load('src.core.game3.rom_text')
game.data.constants.gen3RsSummary.text.example='Example'
T.eq(select('#',textAdapter.plain('example')),1,'ROM text returns exactly one value, never a memo color argument')
first.gen3OtName='IMPORTED';first.secretId=77;first.gen3Markings=5
first.gen3Pokerus=1;first.gen3Language=2;first.statusWord=64;first.ball='ULTRA_BALL'
local presented=screen.rsNative.view(first)
T.eq(presented.otName,'IMPORTED','imported OT alias is displayed')
T.eq(presented.otSecretId,77,'imported secret ID is retained in the view')
T.eq(presented.markings,5,'imported markings are displayed')
T.eq(presented.pokerus,1,'imported Pokerus alias is displayed')
T.eq(presented.language,2,'imported language is retained')
T.eq(presented.status,64,'imported status word reaches native status logic')
T.eq(presented.pokeball,'ULTRA_BALL','imported ball retains its host item ID')
T.eq(first.otName,nil,'presentation aliases never enter the saved Pokemon')
T.eq(screen:wantsEdgeBleed(),false,'native summary forbids stretched margins')
press('left',24);T.eq(screen.page,1,'RS summary clamps at first page')
press('down',30);T.eq(screen.mon,egg,'INFO may display the party egg')
press('right',24);T.eq(screen.page,1,'egg stays on INFO')
press('up',30);T.eq(screen.mon,first,'party returns to original object')
press('right',24);T.eq(screen.page,2,'native page task reaches SKILLS')
press('a',30);T.eq(pops,0,'A on RS SKILLS is inert')
press('down',30);T.eq(screen.mon,last,'SKILLS skips the egg')
T.eq(changes[#changes][1],3,'party callback carries the real index')
T.eq(changes[#changes][2],last,'party callback retains the original Pokemon object')
press('down',30);T.eq(screen.mon,last,'party selection clamps at its end')
press('right',24);T.eq(screen.page,3,'native page task reaches BATTLE MOVES')
press('a',8);T.check(screen.moveSelect,'A opens native move detail')
press('a');press('down');press('a')
T.eq(last.moves[1].id,'TACKLE','move swap preserves host string IDs')
T.eq(last.moves[1].pp,11,'PP travels with the selected move')
T.eq(last.moves[1].ppUps,1,'PP Ups travel with the selected move')
T.eq(last.moves[2].id,'SURF','both original moves remain after swapping')
T.eq(last.moves[2].ppUps,2,'second move retains PP Ups')
press('b',8);T.eq(screen.moveSelect,false,'B leaves move detail')
press('right',24);T.eq(screen.page,4,'native page task reaches CONTEST MOVES')
press('right',24);T.eq(screen.page,4,'RS summary clamps at the final page')
press('b',80);T.eq(pops,1,'native fade exits once')
T.check(screen.rsNative.closed,'exit releases the native scene without recursive callbacks')

local selected='unanswered'
open({mon=first,choose={move='NEW',onChoose=function(i)selected=i end}})
T.eq(screen.page,3,'new-move chooser starts on BATTLE MOVES')
press('a',8);T.eq(screen.rsNative.scene._state,'notice','HM cannot be selected to forget')
T.eq(selected,'unanswered','HM rejection does not invoke the callback')
press('b',8);press('down');press('a',80)
T.eq(selected,2,'native chooser returns the original host slot index')
T.eq(first.moves[1].id,'SURF','choosing never replaces moves itself')
T.eq(first.moves[2].id,'TACKLE','host callback remains authoritative for learning')
selected='unanswered'
open({mon=first,choose={move='NEW',onChoose=function(i)selected=i end}})
press('b',80);T.eq(selected,nil,'native chooser cancels with nil')
T.eq(pops,3,'each native summary exit pops exactly one host state')
local beforeHP=first.hp
open({mon=first,party={[1]=first,[3]=last},partyIndex=1,context='box'})
press('down',40)
T.eq(screen.mon,last,'PC summary skips an actual empty slot in a sparse box')
T.eq(screen.partyIndex,3,'sparse PC slot index survives the native bridge')
T.eq(first.hp,beforeHP,'PC stat reconstruction does not write to stored Pokemon')
press('b',80);T.eq(pops,4,'PC summary exits once')
V.set('leafgreen')
T.eq(require('src.ui.Gen3RsSummary').available(game),false,'LeafGreen never selects RS summary')
T.finish('Native RS summary navigation, egg/party, HM and move callback contracts')
