-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Menu=require('src.ui.Gen3StartMenu')
local Screens=require('src.ui.Screens')
local V=require('src.core.GameVersion')
local Save=require('src.core.SaveSerializer')
local originalPush=Screens.push
love.math=love.math or{}
love.math.getRandomState=love.math.getRandomState or function()return'unchanged'end
for _,edition in ipairs{'ruby','sapphire','emerald','firered','leafgreen'}do
  V.set(edition)
  local frlg=edition=='firered'or edition=='leafgreen'
  local game={data={constants={gen3StartMenu={layout=frlg and'frlg'or'rse',pokedexFlag='DEX'}},
    field={boot={}},pokemon={}},save={party={},options={},flags={DEX=true},player={name='TEST'}}}
  game.stack=setmetatable({},{__index=require('src.core.StateStack')});game.stack:init()
  local world={};game.stack:push(world)
  Screens.push=function(g,id,opts)
    local state
    if id=='Gen3StartMenu'then state=Menu.new(g,opts)
    else state={id=id,onCancel=assert(opts.onCancel)}end
    g.stack:push(state);return state
  end
  for _,key in ipairs{'bag','option'}do
    local menu=Menu.new(game);game.stack:push(menu)
    for i,row in ipairs(menu.rows)do if row.key==key then menu.index=i;break end end
    local wanted=menu.index
    T.check(wanted>1 and menu.rows[wanted].key==key,'Actual submenu row must be selected')
    local bytes=Save.encode(game.save);local rng=love.math.getRandomState()
    menu:choose(menu.rows[wanted]);local child=game.stack:top()
    T.check(child~=menu and type(child.onCancel)=='function','The actual action must install its return callback')
    game.stack:pop();child.onCancel()
    local restored=game.stack:top()
    T.eq(getmetatable(restored),Menu)
    T.eq(restored.index,wanted,'Returning through the real action callback retains the selected row')
    T.eq(restored.rows[restored.index].key,key,'The restored cursor must identify the same action')
    local first,last=restored:visibleRange()
    T.check(first<=wanted and wanted<=last,'The restored cursor must be visible')
    T.eq(Save.encode(game.save),bytes,'Submenu cancellation must not mutate the save')
    T.eq(love.math.getRandomState(),rng,'Cursor restoration must not use gameplay randomness')
    game.stack:pop();T.eq(game.stack:top(),world)
    local fieldReopened=Menu.new(game)
    T.eq(fieldReopened.index,wanted,'A fresh field START also retains the native EWRAM cursor')
    T.eq(Save.encode(game.save),bytes,'Remembering the field cursor must not add save fields')
  end
  local pending=Menu.new(game);game.stack:push(pending)
  for i,row in ipairs(pending.rows)do if row.key=='bag'then pending.index=i;break end end
  pending:choose(pending.rows[pending.index]);local child=game.stack:top()
  game.save=assert(Save.decode(Save.encode(game.save)))
  game.stack:pop();child.onCancel()
  T.eq(game.stack:top().index,1,'A delayed old callback must not inject its cursor into a replaced save')
  game.stack:pop()
  local originalSave=game.save
  game.save=assert(Save.decode(Save.encode(game.save)))
  T.eq(Menu.new(game).index,1,'A new/continued save object resets the native RAM cursor')
  game.save=originalSave
  T.eq(Menu.new(game).index,1,'A replaced context cannot revive an abandoned cursor')
  local menu=Menu.new(game,{index=999});game.stack:push(menu);menu:close()
  T.eq(Menu.new(game).index,#menu.rows,'Explicit and remembered positions are bounded by the current action list')
  local originalData=game.data
  local otherData={};for key,value in pairs(originalData)do otherData[key]=value end
  game.data=otherData;T.eq(Menu.new(game).index,1,'A replaced cartridge dataset resets the UI cursor')
  game.data=originalData;T.eq(Menu.new(game).index,1,'The old dataset cannot revive a stale cursor')
  local menu=Menu.new(game,{index=5});game.stack:push(menu);menu:close()
  V.set(edition=='ruby'and'sapphire'or'ruby')
  T.eq(Menu.new(game).index,1,'Another cartridge cannot inherit the preceding cursor')
  V.set(edition);T.eq(Menu.new(game).index,1,'Returning to the earlier edition cannot revive a stale cursor')
end
-- Keep the preexisting fallback contract when another generation explicitly
-- invokes this class. The FRLG source-record override also remains supported.
local received
Screens.push=function(_,id,opts)received={id=id,opts=opts}end
for _,edition in ipairs{'red','gold','silver','crystal'}do
  V.set(edition)
  local menu=setmetatable({game={data={constants={}}},index=5},Menu)
  menu:reopen();T.eq(received.id,'Gen3StartMenu');T.eq(received.opts,nil)
  menu.game.data.constants.gen3StartMenu={layout='frlg'}
  menu:reopen();T.eq(received.opts.index,5,'The existing FRLG source-record override is unchanged')
end
Screens.push=originalPush
T.finish('five-edition native submenu cursor restoration and unchanged other-generation fallbacks')
