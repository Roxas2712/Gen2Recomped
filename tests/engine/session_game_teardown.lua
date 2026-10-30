-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local Lifecycle=require('src.core.SessionLifecycle')
local Stack=require('src.core.StateStack')
local nativeGame=require('src.core.Game')
local stops,joins,exits,worldExits=0,0,0,0
local saved={}
for _,name in ipairs({'src.core.Music','src.core.Sound','src.core.ChipAudio'})do
  saved[name]=package.loaded[name]
  package.loaded[name]={stop=function()stops=stops+1 end,stopMusic=function()stops=stops+1 end,
    shutdown=function()joins=joins+1 end}
end
Lifecycle.registerProcessShutdown(function()joins=joins+1 end)
local stack=setmetatable({}, {__index=Stack});stack:init()
stack.states={{exit=function()exits=exits+1;error('exit probe')end},
 {exit=function()exits=exits+1 end}}
local game={stack=stack,save={sentinel='unchanged'}}
local world={exit=function()worldExits=worldExits+1 end}
stack.worldState=world;stack.worldOwner=game;game.world,game.overworld=world,world
T.check(pcall(Lifecycle.endGameSession,game),'faulty state cannot strand remaining owners')
T.eq(exits,2,'all native overlay exits reached')
T.eq(worldExits,1,'native persistent world retired once')
T.eq(#stack.states,0,'native overlays detached')
T.eq(stack.worldState,nil,'native world detached')
T.eq(game.overworld,nil,'legacy observation cannot retain old world')
T.eq(game.phase,'boot','native game leaves play phase')
T.eq(game.save.sentinel,'unchanged','game end never edits save data')
T.eq(stops,3,'loaded playback services stopped')
T.eq(joins,0,'game end never joins process workers')
T.eq(package.loaded['src.core.Game'],nativeGame,'native Game identity survives launcher return')
local reset=0
Lifecycle.endGameSession({reset=function()reset=reset+1 end})
T.eq(reset,1,'explicit game reset contract remains callable')
T.check(pcall(Lifecycle.endGameSession,nil),'missing game may be retired safely')
for name,module in pairs(saved)do package.loaded[name]=module end
T.finish('game session teardown without process shutdown')
