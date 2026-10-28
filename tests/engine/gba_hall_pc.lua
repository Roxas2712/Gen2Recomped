-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local Assets=require('src.import.Gen3HallPcAssets')
local Loader=require('compat.gen1-rs.Loader');local Fs=require('src.import.CacheFs');local W=require('src.import.LuaWriter')
local originalLoad=love.filesystem.load;love.filesystem.load=function(path)return loadfile(path)end
local read=Fs.read
for _,version in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
 local spec={format=1,version=version,textIR={}}
 for _,key in ipairs(Assets.labels(version))do spec.textIR[key]={{t='text',s='OWN '..key}}end
 T.eq(Assets.valid(spec,version),true,'own Hall PC labels admitted: '..version)
 Fs.read=function()return W.encode({gen3HallPc=spec})end
 T.eq(#Assets.missing(version),0,'complete own metadata is ready')
 for _,key in ipairs(Assets.labels(version))do
  local ir=spec.textIR[key];spec.textIR[key]=nil
  T.eq(Assets.valid(spec,version),false,'original label is required: '..key);spec.textIR[key]=ir
 end
 spec.version='OTHER';T.eq(Assets.valid(spec,version),false,'cross-edition metadata refused');spec.version=version
 T.eq(Assets.valid(spec,'gold'),false,'Gen2 retains its own PC')
 local pushed,popped,cries,stops=0,0,{},0
 local font={STDPAL={[0]={},[1]={},[2]={}}}
 local load=Loader.new(version,{
  ['src.ui.game3.stack']={push=function(id)T.eq(id,'hall_of_fame_pc');pushed=pushed+1 end,
   pop=function(id)T.eq(id,'hall_of_fame_pc');popped=popped+1 end},
  ['src.ui.game3.window']={},['src.ui.game3.frlg_font']=font,
  ['src.core.game3.pokemon']={},['src.core.game3.rom_text']={},['src.ui.game3.hall_of_fame_gfx']={},
  ['src.core.game3.audio']={playCry=function(id)cries[#cries+1]=id end,stopCry=function()stops=stops+1 end},
  ['src.core.game3.pokedex_data']={isNationalUnlocked=function()return true end},
 })
 local pc=load('src.ui.game3.hall_of_fame_pc')
 local teams={{{species=1},{species=2},{species=3}},{{species=4},{species=412},{species=6}}}
 local session={version=version,hallOfFameTeams=teams,gameStats={[10]=53}}
 local before=require('src.core.SaveSerializer').encode(session)
 local function press(key)pc.handleInput({wasPressed=function(_,k)return key==k end})end
 pc.show({session=session});T.eq(pushed,1);T.eq(pc._team,2,'newest retained team appears first');T.eq(pc._number,53)
 T.eq(cries[#cries],4,'selected historical species uses its own cry')
 press('up');T.eq(pc._mon,1,'UP at first member cannot wrap')
 press('down');T.eq(pc._mon,2,'DOWN selects next saved member');T.eq(cries[#cries],4,'egg selection does not play a species cry')
 press('down');press('down');T.eq(pc._mon,3,'DOWN at last member cannot wrap');T.eq(cries[#cries],6)
 press('a');T.eq(pc._team,1,'A moves backward through actual retained teams');T.eq(pc._number,52);T.eq(pc._mon,1)
 press('b');T.eq(popped,1,'B restores owner once');T.eq(pc.open,false)
 press('b');T.eq(popped,1,'late input cannot close twice')
 T.eq(require('src.core.SaveSerializer').encode(session),before,'selection never changes saved team/session data')
 pc.show({session=session});press('a');press('a');T.eq(popped,2,'A at oldest team exits')
 pc.show({session={version=version,gameStats={[10]=7}}});T.eq(pc._corrupted,true,'count-only legacy saves show original missing/corrupt page')
 press('a');T.eq(popped,3,'original error-page exit remains reachable')
 T.check(stops>=3,'closing stops historical cries')
end
Fs.read=read;love.filesystem.load=originalLoad
-- Test both real script bindings with the existing owner/yield protocol.
local UI=require('src.ui.Gen3HallPc');local make=UI.new;local Commands=require('src.script.Gen3Commands')
for _,id in ipairs{266,0x1000+263}do
 local resumed,yielded,pushed=0,0,0;local done
 local game={stack={push=function()pushed=pushed+1 end}}
 UI.new=function(g,cb)T.eq(g,game);done=cb;return{}end
 local ctx={game=game,runner={resume=function()resumed=resumed+1 end,yield=function()yielded=yielded+1 end}}
 Commands.SPECIALS[id](ctx);T.eq(pushed,1,'script pushes actual PC owner');T.eq(yielded,1,'script waits for PC close')
 done();done();T.eq(resumed,1,'both script families resume their caller exactly once')
end
UI.new=make
T.finish('five-edition original Hall PC input, retained teams, cry ownership, metadata and real script callbacks')
