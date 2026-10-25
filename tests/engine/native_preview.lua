package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.harness');local getenv=os.getenv
local P=require('src.core.NativePreview')
for _,osName in ipairs({'Windows','OS X','Linux','iOS','Android','NX'}) do
  T.check(P.runtimeSupported(osName,12,0),osName..' accepts preview 12 runtime')
  T.eq(P.runtimeSupported(osName,11,5),osName=='Android' or osName=='NX',osName..' stable port policy')
  T.check(not P.runtimeSupported(osName,11,4),osName..' old runtime refused')
end
T.check(not P.runtimeSupported('NX',nil,5),'invalid version refused')
T.check(not pcall(P.activate,'Gen2Recomp'),'normal player identity refused')
P.activate('Gen2Recomp-NativePreview-20261024-1')
T.eq(os.getenv('POKEPORT_IDENTITY'),P.identity,'preview owns a dedicated namespace')
T.eq(os.getenv('POKEPORT_NO_MODS'),'0','mods can load in the dedicated preview profile')
T.eq(os.getenv('POKEPORT_NOTIFY_ONLY_UPDATES'),'1','no automatic installation')
T.eq(_G.POKEPORT_NOTIFY_ONLY_UPDATES,true,'native updater override')
T.eq(os.getenv('PATH'),getenv('PATH'),'unrelated process environment unchanged')
T.check(not pcall(P.activate,'Gen2Recomp-NativePreview-20261024-2'),'profile cannot change after activation')
local id,changes=P.identity,0;local legacyCalls=0;local portable,external
love={filesystem={getIdentity=function()return id end,setIdentity=function(value)changes=changes+1;id=value end}}
package.loaded['src.core.SaveIdentity']={migrateLegacy=function()legacyCalls=legacyCalls+1 end}
package.loaded['src.core.SaveData']={portableBaseDir=function()return portable end}
package.loaded['src.import.CacheFs']={root=function()return external end}
P.prepare()
T.eq(require('src.core.SaveIdentity').migrateLegacy(),0,'legacy migration bypassed before engine boot')
T.eq(legacyCalls,0,'legacy reader never called')
T.check(not pcall(love.filesystem.setIdentity,'pokemon-love2d'),'legacy namespace forbidden')
T.check(not pcall(love.filesystem.setIdentity,'Gen2Recomp'),'player namespace forbidden')
T.eq(changes,0,'rejected switches never reach filesystem')
love.filesystem.setIdentity(P.identity);T.eq(changes,1,'own namespace still available')
portable='/outside';T.check(not pcall(P.prepare),'portable root rejected');portable=nil
external='/outside';T.check(not pcall(P.prepare),'external cache root rejected');external=nil
os.getenv=getenv
T.finish('Native preview profile isolation')
