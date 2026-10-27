love=require('tests.love_stub');love.filesystem.load=loadfile
local checks=0
local function check(v,why)checks=checks+1;assert(v,why)end
local exists,writes,closed,startClosed,result=false,0,0,0,true
local palette={};for i=0,15 do palette[i]={0,0,0,1}end
local load=require('compat.gen1-rs.Loader').new('ruby',{
 ['src.ui.game3.stack']={push=function()end,pop=function()closed=closed+1 end},
 ['src.ui.game3.window']={},['src.ui.game3.chrome']={},
 ['src.ui.game3.frlg_font']={STDPAL=palette},['src.import.gba.map_sections_extract']={},
 ['src.core.Strings']=tostring,['src.core.game3.rom_text']={},
 ['src.core.game3.scripting.flags']={},['src.core.game3.dex']={},
 ['src.core.game3.profile']={forSession=function()return{ui={saveMenu='rs'}}end},
 ['src.core.SaveData']={load=function()return exists and{}or nil end},
 ['src.core.game3.runtime']={_game={saveGame=function()writes=writes+1;if result=='error'then error('own fixture refused write')end;return result end}},
 ['src.core.game3.bridge']={},['src.core.game3.rse.init']={call=function()end},
 ['src.core.game3.audio']={playSe=function()end},['src.core.game3.se_ids']={resolve=function()return 5 end},
 ['src.ui.game3.start_menu']={isOpen=function()return true end,close=function()startClosed=startClosed+1 end},
})
local S=load('src.ui.game3.save_menu')
local function open()S.show({session={version='ruby'}});check(S._phase=='confirm'and S.cursor==1,'Native SAVE starts at YES')end
open();S.cancel();check(closed==1 and writes==0 and startClosed==0,'B returns to menu without IO')
open();S.move(1);S.confirm();check(closed==2 and writes==0,'NO does not save')
open();S.confirm();check(S._phase=='saving_msg'and writes==0,'First save has no overwrite and defers IO')
S.confirm();S.cancel();check(S._phase=='saving_msg'and writes==0,'Saving message ignores A/B')
S.update();check(S._phase=='saved'and S._timer==60 and writes==1,'Successful confirmed write starts sixty-frame message')
for _=1,59 do S.update()end;check(S.open and S._timer==1,'Saved message remains through frame59')
S.cancel();check(S.open,'B cannot skip saved message')
S.update();check(not S.open and closed==3 and startClosed==1,'Original auto-close returns to field at sixty')
exists=true;open();S.confirm();check(S._phase=='overwrite'and writes==1,'Existing slot needs second explicit YES')
S.move(1);S.confirm();check(closed==4 and writes==1,'Overwrite NO preserves slot')
open();S.confirm();S.cancel();check(closed==5 and writes==1,'Overwrite B preserves slot')
for _,bad in ipairs({false,'error'})do
 result=bad;open();S.confirm();S.confirm();check(S._phase=='saving_msg','Failure attempt still renders saving message')
 S.update();check(S._phase=='save_failed'and S.open and type(S._error)=='string','Refusal/exception must never report saved')
 local n=closed;S.confirm();check(closed==n+1 and startClosed==1,'Failure returns to start menu')
end
result=true;open();S.confirm();S.confirm();S.update()
check(S._phase=='saved'and writes==4,'Successful overwrite writes exactly once')
local Gate=require('src.import.Gen3RsSaveAssets')
check(not Gate.valid({format=1,version='ruby',textIR={}},'ruby'),'Old incomplete import rejected')
package.loaded['src.core.SaveData']={}
require('src.core.GameVersion').set('ruby')
local View=require('src.ui.Gen3RsSaveMenu')
local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new('ruby'))
local id,var=C:flag('FLAG_SYS_NATIONAL_DEX'),C:var('VAR_NATIONAL_DEX')
local game={save={player={name='TEST'},flags={[('FLAG_G3_%04X'):format(id)]=true},gen3Vars={[var]=0x302},
  nationalDex=true,pokedex={owned={TREECKO=true,PIKACHU=true,MEWTWO=true}}},
  data={pokemon={TREECKO={index=277},PIKACHU={index=25},MEWTWO={index=150}}}}
local session=View.session(game)
check(session.store.flags==session.flags and session.store.vars==session.vars,'Native flag store retains variable view')
check(session.store.flags[id]and session.store.vars[var]==0x302,'Host named flags and numeric variables remain visible')
local L=require('compat.gen1-rs.Loader').new('ruby',{
 ['src.core.game3.constants']={of=function()return C end},
 ['src.core.game3.profile']={of=function()return{id='ruby',dex={regionalPack='hoenn',orderPack='order',
   national={flag='FLAG_SYS_NATIONAL_DEX',var='VAR_NATIONAL_DEX',value=0x302,magic=0xDA,requireAll=true}}}end},
})
local D=L('src.core.game3.dex')
D.packReader=function(_,path)
 return path=='hoenn'and'return{toHoenn={[277]=1,[25]=156}}'or'return{count=202,order={}}'
end
check(D.summaryCount(session)==3,'Complete native National gates include non-Hoenn species')
game.save.gen3Vars[var]=nil
check(D.summaryCount(session)==2,'National magic and flag alone cannot bypass original variable gate')
game.save.gen3Vars[var]=0x302;game.save.flags[('FLAG_G3_%04X'):format(id)]=nil
check(D.summaryCount(session)==2,'National magic and variable alone cannot bypass original flag gate')
print('RS_SAVE_CONTRACT_CHECKS',checks)
