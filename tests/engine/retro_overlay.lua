package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local writes,reset,returned,exports=0,0,0,0
local failure=false
package.loaded['src.core.SaveData']={activeSlot=function() return 'running' end}
package.loaded['src.core.TouchControls']={reset=function() reset=reset+1 end}
package.loaded['src.cloud.Task']={reap=function() end,new=function(fn) return {cancel=function() end,poll=function() local a,b=fn();return {kind='done',first=a,second=b} end} end}
local upload
package.loaded['src.cloud.RetroCloud']={open=function() return {kind='retro'} end}
package.loaded['src.import.CloudSync']={syncOne=function(_,v,slot,pushOnly) upload={v,slot,pushOnly};return 'uploaded' end}
package.loaded['src.import.SaveFileIO']={exportActiveSlot=function() exports=exports+1;return true,'/demo/exports/game.sav' end}
local O=require('src.ui.RetroOverlay')
local world={isOverworld=true}
local game={save={player={}},stack={states={world}},overworld=world,
 input={reset=function() reset=reset+1 end},writeSave=function() writes=writes+1;return not failure end,
 returnToLauncher=function() returned=returned+1 end}
check(not O.update(game),'closed menu never pauses gameplay')
check(O.key(game,'escape') and O.game==game,'Escape opens the quick menu without an OS function-key shortcut')
O.key(game,'escape');reset=0
check(O.key(game,'f1') and O.game==game and reset==2,'F1 opens the menu and clears held touch and keyboard inputs')
check(O.update(game),'open menu pauses game logic')
O.action('save');check(writes==1 and O.notice:find('normal save slot',1,true),'ordinary saving writes the current registered slot')
O.action('export');check(writes==2 and exports==1 and O.exportPath,'battery export captures live progress first')
O.action('cloud');check(writes==3 and O.job,'cloud upload saves locally before starting network I/O')
O.close();check(O.game==game,'the game stays paused during an upload')
O.update(game);check(upload[2]=='running' and upload[3]==true and not O.job,'in-game sync protects the running slot against remote replacement')
O.action('library');check(returned==0 and O.confirm=='library','switching games asks before leaving live progress')
O.action('cancel');check(not O.confirm and returned==0,'cancelling a game switch keeps the current session')
failure=true;O.action('library');O.action('library')
check(returned==0 and O.game==game,'a failed save cannot discard the running session')
failure=false;O.action('library');check(returned==1 and not O.game,'a successful save returns through the normal library hook')
local before=writes;game.stack.states={{name='title'}};O.open(game);O.action('save')
check(writes==before and O.notice:find('Start or continue',1,true),'the title-screen new-game skeleton cannot overwrite an existing save')
O.action('library');O.action('library');check(returned==2 and writes==before,'returning from the title screen does not create a blank save')
O.open(game);check(O.key(game,'down') and O.selected==2,'keyboard navigation stays inside the overlay')
O.key(game,'escape');check(not O.game and reset>=4,'closing resets input before play resumes')
local persisted=0
game.save.options={speed=1,musicVol=5,sfxVol=3};game.writeOptions=function() persisted=persisted+1 end
package.loaded['src.core.Music']={applyOptions=function(o) MusicMuted=o.audioMuted end}
package.loaded['src.core.Sound']={applyOptions=function(o) SoundMuted=o.audioMuted end}
O.open(game);O.action('speed')
check(game.save.options.speed==2 and persisted==1,'quick speed changes use and persist the engine speed ladder')
game.speedLocked=function() return true end;O.action('speed');check(game.save.options.speed==2,'link or fixed-speed locks cannot be bypassed by the overlay')
O.action('mute');check(MusicMuted and SoundMuted and game.save.options.musicVol==5 and game.save.options.sfxVol==3,'mute keeps both stored volume levels intact')
O.action('mute');check(not MusicMuted and not SoundMuted,'unmute restores both buses without inventing new levels')
package.loaded['src.ui.OptionsMenu']={new=function() return {rows={{label='A mod option',value=function() return 'LIVE' end,step=function(g,dir) g.changed=dir;return true end}}} end}
O.action('options');O.action('option:1:-1')
check(game.changed==-1 and #O.actions()==1,'all settings reuse native option descriptors including mod-provided rows')
local count=writes;O.action('unknown');check(writes==count,'unknown menu actions cannot unexpectedly write a progress save')
O.action('home');O.action('saves');check(O.page=='saves' and O.actions()[1].id=='save','the large saves entry leads to the dedicated save and cloud menu')
local stencil,depth,mask=0,0,0
love.graphics.setStencilTest=function() stencil=stencil+1 end
love.graphics.setDepthMode=function() depth=depth+1 end
love.graphics.setColorMask=function(r,g,b,a) assert(r and g and b and a);mask=mask+1 end
O.draw(game);O.close();O.draw(game)
check(stencil==2 and depth==2 and mask==2,'both menu and closed handle clear inherited depth, stencil and color masks')
O.clear()
O.open(game);game.stack.states={world};O.action('cloud')
package.loaded['src.import.CloudSync'].syncOne=function()return nil,'Network unavailable'end
O.update(game)
check(O.retry and require('src.storage.SyncStatus').get().state=='error','failed uploads retain a retry and cannot claim cloud availability')
local written=writes
package.loaded['src.import.CloudSync'].syncOne=function()return 'uploaded'end
O.action('retryCloud');O.update(game)
check(writes==written and not O.retry and require('src.storage.SyncStatus').get().state=='available','retry uploads the existing saved copy without writing a different in-game state')
O.action('cloud');O.action('cancel')
check(not O.job and O.retry and require('src.storage.SyncStatus').get().state=='cancelled','cancel keeps a local copy and offers an explicit retry')
O.clear()
print('Retro overlay: '..n..' checks passed')
