-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local F=require('tools.battle-source-runtime.fixture')
local Start=require('src.ui.Gen3StartMenu')
local Party=require('src.ui.Gen3PartyMenu')
local Sweep=require('src.world.Gen3FieldMove');local show=Sweep.show
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  local f=F.new(edition);f.fresh('TACKLE')
  local g=f.game;g.data.constants.gen3FieldMoves={FLASH={move=148}}
  g.data.constants.moveOrder[148]='FLASH'
  g.save.party[1].moves={{id='FLASH',pp=20}}
  local world={map={id='OWNED_DARK_CAVE',def={requiresFlash=true}},player={}}
  g.overworld=world;g.stack:push(world)
  local function open()
    local menu=Start.new(g);g.stack:push(menu)
    for _,row in ipairs(menu.rows)do if row.key=='pokemon'then menu:choose(row);return g.stack:top()end end
    error('No ordinary party row')
  end
  local p=open();T.eq(getmetatable(p),Party,'actual start menu opens actual GBA party')
  p:close();T.eq(getmetatable(g.stack:top()),Start,'ordinary cancellation reopens START')
  g.stack:pop()
  p=open();local selected
  Sweep.show=function(_,mon,done)selected=mon;done();return true end
  p:useFieldMove(g.save.party[1],'FLASH')
  T.eq(selected,g.save.party[1],'field action uses the selected party member')
  T.eq(g.save.flashLit,true,'real FLASH action lights the cave')
  local box=g.stack:top();T.eq(type(box.advance),'function','original field text is presented')
  box.done=true;box.preWait=0;box.holdFrames=0;box:advance()
  T.eq(g.stack:top(),world,'successful action returns straight to field after its text')
  T.eq(#g.stack.states,1,'START is not recreated below the field presentation')
  p:close();T.eq(g.stack:top(),world,'late duplicate close cannot remove the overworld')
  g.save.flashLit=nil;world.map.def.requiresFlash=false
  p=open();p:useFieldMove(g.save.party[1],'FLASH')
  T.eq(p.closed,nil,'unusable FLASH keeps the party open')
  local refusal=g.stack:top();refusal.done=true;refusal.preWait=0;refusal.holdFrames=0;refusal:advance()
  T.eq(g.stack:top(),p,'refusal returns to the same party menu')
  p:close();T.eq(getmetatable(g.stack:top()),Start,'cancelling after refusal keeps START navigation')
  f.close()
end
Sweep.show=show
T.finish('five-edition actual START/party field success, refusal, cancel and late callbacks')
