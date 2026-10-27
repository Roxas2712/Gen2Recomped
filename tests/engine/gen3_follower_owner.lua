-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
love=require('tests.love_stub')
local Version=require('src.core.GameVersion');Version.set('firered')
local G=require('src.core.Game3')
local n=0
local function check(v,label)n=n+1;assert(v,label)end
G._observeActorMod('follower')
check(G._usesCallbacks('follower'),'native actor import receives resource attribution')
local game,world={},{}
local a,b,c=G._invokeHook('follower',function(nextFn,g,w)
  check(g==game and w==world,'actor callbacks keep native handles')
  check(G._callbackOwner()=='follower','presentation has importing mod owner')
  local value=nextFn(g,w)
  check(G._callbackOwner()=='follower','nested native continuation restores mod owner')
  return value,nil,42
end,function(g,w)
  check(g==game and w==world,'continuation keeps native handles')
  check(G._callbackOwner()==nil,'native continuation cannot inherit mod resources')
  return true
end,game,world)
check(a==true and b==nil and c==42,'hook preserves nil-bearing multiple returns')
check(G._callbackOwner()==nil,'successful hook clears owner')
local ok=pcall(G._invokeHook,'follower',function()error('owned failure')end,function()end)
check(not ok and G._callbackOwner()==nil,'failing hook clears owner')
G._withCallbackOwner('outer',function()
  G._invokeHook('follower',function()check(G._callbackOwner()=='follower','nested mod owner')end,function()end)
  check(G._callbackOwner()=='outer','outer owner restored')
end)
G._retireMod('follower')
check(not G._usesCallbacks('follower'),'retire removes actor ownership')
G._observeActorMod('follower');G.release()
check(not G._usesCallbacks('follower'),'release removes actor ownership')
print('GEN3_FOLLOWER_OWNER_PASS '..n..' checks')
