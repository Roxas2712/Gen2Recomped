package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local S=require('src.core.SaveSerializer')
love.data={hash=function(_,b)return b end,encode=function(_,_,b)return require('src.link.Fingerprint').digest(b):rep(4)end}
local account='1'
package.loaded['src.cloud.RetroCloud']={accountId=function()return account end,signedIn=function()return account~=nil end}
local Saves=require('src.core.SaveData');Saves.persistenceFs=function()return love.filesystem end
Saves.activeSlot=function()return 'slot1'end
require('src.core.GameVersion').set('red')
local W=require('src.link.FriendWager')
local id='11111111-1111-4111-8111-111111111111';local contract=string.rep('a',64)
local fail=false;local disk;local game={data={},save={meta={playthroughId='native-test'},money=1000,party={{species='UNCHANGED'}}},writeSave=function(self)
 if fail then return nil,'Disk is full'end;disk=S.encode(self.save);return true
end}
local offer={kind='money',edition='red',owner='1',amount=100,balance=1000,playthrough='native-test',slot='slot1'}
local wager={id=id,kind='money',contract=contract,offers={{account_id='1',offer=offer}}}
local doc=assert(W.remember(game,wager,'red'))
T.eq(game.save.money,1000,'choosing a stake does not withdraw money')
fail=true;T.check(not W.reserve(game,doc),'disk failure prevents an acknowledged reservation')
T.eq(game.save.money,900,'failed save retains one recoverable in-memory deduction')
fail=false;doc=W.read(id);T.check(W.reserve(game,doc),'reservation retries safely after disk recovers')
T.eq(game.save.money,900,'retry never deducts the stake twice')
local receipt={id=id,kind='money',reserved=true,winner=1,awards={offer,{kind='money',amount=200}}}
doc=W.read(id);fail=true;T.check(not W.apply(game,doc,receipt),'failed prize save keeps settlement pending')
T.eq(game.save.money,1200,'winner receives their own stake plus the opponent stake once')
fail=false;T.check(W.apply(game,W.read(id),receipt),'prize write can recover without a second credit')
T.eq(game.save.money,1200,'repeat payout keeps the same balance')
T.check(S.decode(disk).money==1200 and W.read(id).settled,'local prize is durably saved before server acknowledgement')
account='2';T.eq(W.read(id),nil,'another account cannot open this stake journal');account='1'
game.save.money=777;T.check(not W.apply(game,W.read(id),receipt),'divergent normal money is preserved for manual recovery')
T.eq(game.save.money,777,'divergent balance is never overwritten')
local mon={species='PIKACHU',level=25,ot='ORIGINAL OT',item='LEFTOVERS',moves={{id='THUNDERSHOCK',pp=30}}}
local monid='22222222-2222-4222-8222-222222222222';game.save.boxes={{mon}};game.save.money=1200
local entry={schema=1,mon=mon,source={version='red',saveId='native-test',place='Box 1 / 1'},canonical={moves={}}}
local pokemon={kind='pokemon',owner='1',edition='red',playthrough='native-test',slot='slot1',box=1,index=1,entry=entry}
local mw={id=monid,kind='pokemon',contract=contract,offers={{account_id='1',offer=pokemon}}}
local md=assert(W.remember(game,mw,'red'));T.check(W.reserve(game,md),'box stake is persisted as a reservation')
T.eq(game.save.boxes[1][1],nil,'only the selected box Pokémon leaves the save')
T.eq(game.save.party[1].species,'UNCHANGED','stake reservation never edits the combat party')
local kept={};package.loaded['src.storage.PokemonBank']={keep=function(value)local key=S.encode(value);kept[key]=value;return 'saved'end}
local pr={id=monid,kind='pokemon',reserved=true,winner=1,awards={pokemon}}
T.check(W.apply(game,W.read(monid),pr),'complete Pokémon prizes are delivered to the account Bank')
T.check(W.apply(game,W.read(monid),pr),'repeated delivery reuses immutable Bank identity')
local count=0;for _,value in pairs(kept)do count=count+1;T.eq(value.mon.ot,'ORIGINAL OT','original trainer survives settlement');T.eq(value.mon.item,'LEFTOVERS','held item survives settlement')end
T.eq(count,1,'receipt retry never creates a second Bank prize')
local refundid='33333333-3333-4333-8333-333333333333';game.save.money=1000
local rw={id=refundid,kind='money',contract=contract,offers={{account_id='1',offer=offer}}};local rd=assert(W.remember(game,rw,'red'));T.check(W.reserve(game,rd),'third fixture reserves once')
T.check(W.apply(game,W.read(refundid),{id=refundid,kind='money',reserved=false,awards={}}),'a cancelled reservation whose server ACK was lost is compensated from the local journal')
T.eq(game.save.money,1000,'lost reservation ACK cannot lose the original money')
T.finish('Durable friend stakes')
