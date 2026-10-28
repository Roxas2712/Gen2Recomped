package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local B=require('src.compat.gen1.ScriptBoundary')
local G=require('src.core.Game3')
local function pack(...)return {n=select('#',...),...}end
local function resume(co,...)
 local result=pack(coroutine.resume(co,...));T.eq(result[1],true,'owned coroutine resumes')
 return unpack(result,2,result.n)
end
local ok,why
local savedViews=package.loaded['src.compat.gen1.PokemonView']
local flushes=0
package.loaded['src.compat.gen1.PokemonView']={flush=function()flushes=flushes+1 end}
local ownerChild
G._withCallbackOwner('parent-owner',function()
  T.eq(G._callbackOwner(),'parent-owner')
  ownerChild=coroutine.create(function()
    T.eq(G._callbackOwner(),'parent-owner','direct child inherits active callback attribution')
    G._withCallbackOwner('child-owner',function()
      T.eq(G._callbackOwner(),'child-owner')
      coroutine.yield('owner held')
    end)
  end)
  T.eq(resume(ownerChild),'owner held')
  T.eq(G._callbackOwner(),'parent-owner','suspended child cannot replace caller attribution')
  G._withCallbackOwner(nil,function()T.eq(G._callbackOwner(),nil,'explicit nil shadows caller ownership')end)
  T.eq(G._callbackOwner(),'parent-owner','nil scope restores active parent ownership')
end)
local after=flushes
ok,why=coroutine.resume(ownerChild)
T.eq(ok,false,'retired callback source cannot return as an active owner')
T.check(tostring(why):find('retired',1,true)~=nil)
T.eq(flushes,after,'retired callback cannot flush pending Pokemon writes')
T.eq(G._callbackOwner(),nil,'retired child cannot restore expired parent attribution')
T.same(pack(G._withCallbackOwner('tuple',function()return nil,2,nil end)),{n=3,[2]=2})
ok=pcall(G._withCallbackOwner,'throws',function()error('owned callback failure')end)
T.eq(ok,false);T.eq(G._callbackOwner(),nil,'callback errors restore attribution')
-- A borrowed script body may retire a coroutine whose callback scope was
-- independently opened. Attribution and pending writes must also retire.
local cross
B.dispatch('cross-registry',function()coroutine.yield('cross held')end,function()
 cross=coroutine.create(function()
  G._withCallbackOwner('cross-owner',function()
   pcall(B.invoke,'cross-registry')
   T.eq(G._callbackOwner(),nil,'retired script borrower cannot retain callback attribution')
  end)
 end)
 T.eq(resume(cross),'cross held')
end)
after=flushes
G._withCallbackOwner('new-owner',function()
 local success,errorValue=coroutine.resume(cross)
 T.eq(success,false,'script retirement also retires the pending callback')
 T.check(tostring(errorValue):find('retired',1,true)~=nil)
 T.eq(G._callbackOwner(),'new-owner','a retired borrower cannot overwrite the new owner')
 T.eq(flushes,after,'cross-registry retirement cannot flush pending Pokemon writes')
end)
package.loaded['src.compat.gen1.PokemonView']=savedViews
local Version=require('src.core.GameVersion');local oldVersion=Version.get();Version.set('ruby')
local native={data=T.fixtures.fresh(),save={options={},player={}},stack={states={}}};local view=assert(G.forNative(native));local base=G.update
local oldGameChild,gameBodies
gameBodies=0
G.update=function(g)
  -- Retain the genuine options-write dispatch in a source-created child.
  oldGameChild=coroutine.create(function()
    return G._dispatch('writeOptions',native,function()gameBodies=gameBodies+1 end)
  end)
  resume(oldGameChild)
  return base(g,.25)
end
local optionsBase=G.writeOptions
G.writeOptions=function(g)coroutine.yield('game phase held');return optionsBase(g)end
local firstUpdates=0
T.eq(G._dispatch('update',native,function()firstUpdates=firstUpdates+1;return 9 end),9)
T.eq(firstUpdates,1,'native game update still executes once through its source wrapper')
local replacements=0
G.update=function(g)return base(g,.5)end
T.eq(G._dispatch('update',native,function()
  local resumed,errorValue=coroutine.resume(oldGameChild)
  T.eq(resumed,false,'old source game coroutine is retired with its parent dispatch')
  T.check(tostring(errorValue):find('retired',1,true)~=nil)
  replacements=replacements+1;return 10
end),10)
T.eq(replacements,1,'retired source game cleanup retains replacement native dispatch')
T.eq(gameBodies,0,'retired source game cannot perform its delayed options write')
G.update,G.writeOptions=base,optionsBase
G.release();Version.set(oldVersion)
T.finish('Native coroutine phase and callback ownership without suspended-scope leaks')
