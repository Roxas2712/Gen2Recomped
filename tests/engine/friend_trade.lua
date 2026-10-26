package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local data=T.fixtures.load();local n=0
local function check(v,m)assert(v,m);n=n+1 end
local account='1';package.loaded['src.cloud.RetroCloud']={accountId=function()return account end,signedIn=function()return account~=nil end}
package.loaded['src.cloud.Task']={new=function(fn)return {poll=function()local a,b=fn();return {kind='done',first=a,second=b}end,cancel=function()end}end}
local saves=require('src.core.SaveData');saves.persistenceFs=function()return love.filesystem end
local slot='slot1';saves.activeSlot=function()return slot end
require('src.core.GameVersion').set('red')
local P=require('src.link.Protocol');local Pokemon=require('src.pokemon.Pokemon')
local receipt,acks= nil,0;package.loaded['src.cloud.Play']={request=function(_,path)
 if path:match('/acknowledge$')then acks=acks+1;return {acknowledged=true}end
 return {state='committed',receipt=receipt}
end}
package.loaded['src.link.ArenaProof']={same=function(a,b)local S=require('src.core.SaveSerializer');return S.encode(a)==S.encode(b)end}
local J=require('src.link.FriendTrade');local id='11111111-1111-4111-8111-111111111111'
local a=Pokemon.new(data,'FIXMON_A',25);local b=Pokemon.new(data,'FIXMON_B',25)
local fail=false;local writes=0;local persisted
local game={data=data,save={party={a},pokedex={seen={},owned={}},player={name='Fixture'}},writeSave=function(self)
 writes=writes+1;if fail then return nil,'fixture disk full'end
 persisted=require('src.core.SaveSerializer').encode(self.save);return true
end}
check(not J.keep(game,'../../outside'),'invalid identifiers cannot become journal paths')
check(J.keep(game,id),'confirmation journals the original party before sending')
receipt={edition='red',slot_index=1,before=P.packParty({a}),received=P.packMon(b)}
account='2';check(not J.read(id),'another account cannot read a pending trade journal');account='1'
local mismatched={edition='red',slot_index=1,before={},received=P.packMon(b)}
check(not J.prepare(game,id,mismatched),'server receipt must match the exact recorded party')
check(J.prepare(game,id,receipt) and game.save.party[1].species=='FIXMON_A','preparation validates on a copy and does not replace the live party')
slot='slot2';check(not J.tick(game) and J.pending(),'a different save slot cannot consume the receipt');slot='slot1'
fail=true;J.tick(game);J.tick(game)
check(game.save.party[1].species=='FIXMON_B' and J.pending() and acks==0 and not persisted,'a failed disk write keeps recovery pending and never acknowledges completion')
fail=false;for _=1,5 do J.tick(game)end
check(persisted and not J.pending() and acks==1,'recovery retries the disk write even when the received party is already in memory')
check(game.save.pokedex.owned.FIXMON_B,'recovery preserves the native Pokédex side effect')
local before=writes;for _=1,5 do J.tick(game)end
check(writes==before and acks==1,'an acknowledged receipt cannot exchange or save the party a second time')
-- A divergent local party must remain untouched.
local nextid='22222222-2222-4222-8222-222222222222';game.save.party={a};check(J.keep(game,nextid),'second fixture records its party')
game.save.party={Pokemon.new(data,'FIXMON_C',30)};receipt.before=P.packParty({a})
J.tick(game);J.tick(game)
check(game.save.party[1].species=='FIXMON_C' and J.pending() and acks==1,'a changed save is retained for manual recovery rather than overwritten')
print('Durable friend trade recovery: '..n..' checks passed')
