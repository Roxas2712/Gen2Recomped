package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3RsBattlePanelAssets')
local Panel=require('src.battle.Gen3RsBattlePanel');local Fs=require('src.import.CacheFs');local Writer=require('src.import.LuaWriter')
local oldV=package.loaded['src.core.GameVersion'];local version='ruby'
package.loaded['src.core.GameVersion']={get=function()return version end}
T.check(not Panel.available({data={}}),'missing constants cannot select an RS renderer')
local s={format=1,version='ruby',images={message='message.png',action='action.png',moves='moves.png'},palette={},pp='PP',switch='SWITCH WHICH?'}
for i=1,16 do s.palette[i]=i end
local battle={data={constants={gen3RsBattlePanel=s}}}
T.eq(Panel.available(battle),s,'matching native RS metadata selects the renderer')
version='sapphire';T.check(not Panel.available(battle),'wrong edition cannot reuse native panels')
version='emerald';T.check(not Panel.available(battle),'Emerald retains its own renderer')
local read,exists=Fs.read,Fs.exists;local bodies,files={},{}
for _,p in pairs(s.images)do files[p]=true end
local manifest='data/generated/gba/battle_panel/manifest.lua'
bodies[manifest]=Writer.encode({layout='rs',game='ruby',files={'message.png','action.png','moves.png'}})
local function constants()bodies['data/generated/constants.lua']=Writer.encode({gen3RsBattlePanel=s})end
Fs.read=function(p)return bodies[p]end;Fs.exists=function(p)return files[p]end;constants()
T.eq(#Assets.missing('ruby'),0,'complete native panel cache is ready')
T.eq(Assets.missing('sapphire')[1],'<rs:native-battle-panel>','other edition fails readiness')
files['moves.png']=nil;T.check(#Assets.missing('ruby')>0,'missing move art invalidates readiness')
files['moves.png']=true;s.palette[16]=nil;constants()
T.eq(Assets.missing('ruby')[1],'<rs:native-battle-panel>','incomplete native palette fails closed')
bodies['data/generated/constants.lua']='error("untrusted cache")'
T.eq(Assets.missing('ruby')[1],'<rs:native-battle-panel>','invalid constants cannot execute against the host')
Fs.read,Fs.exists=read,exists;package.loaded['src.core.GameVersion']=oldV
local P=require('src.core.Performance');local Frames=require('src.battle.Gen3BattleFrames')
local oldPanel,oldFrames,oldHandles=Frames.panel,Frames.rsFrames,Panel.handles
Frames.panel=function()end;Frames.rsFrames=function()end;Panel.handles=function()return true end
local trace,options={},{}
local panel=setmetatable({spec={switch='SWITCH',pp='PP'},menuColors={fg={1,1,1},shadow={},bg={}},
  messageColors={fg={.5,.5,.5},shadow={},bg={}},chrome={promptArrow=function()end},
  cursor={draw=function(x,y,w)trace[#trace+1]={'cursor',x,y,w}end},font={}},Panel)
panel.font.draw=function(value,x,y,opts)
  trace[#trace+1]={value,x,y,opts.colors.fg[1]};options[#options+1]=opts
end
panel.font.drawGlyph=function(code,x,y,opts)
  trace[#trace+1]={code,x,y,opts.colors.fg[1]};options[#options+1]=opts;return 5
end
local b={data={constants={},moves={TACKLE={name='TACKLE',pp=35}}},phase='moveSelect',
  player={name='TEST',curMoves={{id='TACKLE',pp=12}}},moveIndex=1,moveSwapIndex=1}
local function draw(enabled)
  P.rsBattlePaintCache=enabled;trace,options={},{};panel:draw(b);return trace,options
end
for _,phase in ipairs({'moveSelect','menu','messages','targetSelect'})do
  b.phase=phase;b.current=true;b.shown={{65,66,67}};b.targetChoices={{name='ALLY',isPlayer=true}};b.targetIndex=1
  local expected=draw(false);local actual=draw(true)
  T.same(actual,expected,'native panel cache preserves '..phase..' draw commands')
end
b.phase='messages';local _,first=draw(true);local _,second=draw(true)
T.eq(first[1],first[2],'a message reuses one glyph-paint record')
T.eq(first[1],second[1],'message paint survives subsequent frames')
b.phase='menu';b.rsWally={text=function(_,label)T.eq(label,'BattleText_WallyMenu');return'WALLY\nPROMPT'end}
draw(true)
Frames.panel,Frames.rsFrames,Panel.handles=oldPanel,oldFrames,oldHandles;P.rsBattlePaintCache=true
T.finish('RS battle panels: edition isolation, palette and cache completeness')
