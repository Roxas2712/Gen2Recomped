-- Exercise native SRAM routing/validation and recoverable replacement.
-- Contributions by Roxas2712.
package.path='./?.lua;'..package.path
local files={['/new.sav']=string.rep('N',32768),['/bad.sav']='wrong',['/player/solo-en-1.sav']=string.rep('O',32768)}
local original=io.open
io.open=function(path,mode)
 if mode=='rb'and not files[path]then return nil end
 local cursor=0;local f={}
 function f:seek(whence,at)if whence=='end'then cursor=#files[path]else cursor=at or 0 end;return cursor end
 function f:read(n)if n=='*a'then return files[path]end;local v=files[path]:sub(cursor+1,cursor+n);cursor=cursor+#v;return v end
 function f:write(value)files[path]=(files[path]or '')..value;return self end
 function f:close()return true end
 return f
end
local rename,time=os.rename,os.time
os.rename=function(a,b)files[b]=files[a];files[a]=nil;return true end;os.time=function()return 100 end
love={filesystem={createDirectory=function()return true end,getSaveDirectory=function()return '/profile'end,write=function(p,v)files['/profile/'..p]=v;return true end}}
local S=require('src.pinball.SaveFiles');local session={player='/player',locale='en'}
assert(S.exists(session));assert(not S.import(session,'/bad.sav'));assert(files[S.path(session)]==string.rep('O',32768))
assert(S.import(session,'/new.sav'));assert(files[S.path(session)]==string.rep('N',32768))
assert(files[S.path(session)..'.before-import-100.sav']==string.rep('O',32768))
assert(S.import(session,'/new.sav'));assert(files[S.path(session)..'.before-import-100-1.sav']==string.rep('N',32768))
local path=S.export(session);assert(files[path]==string.rep('N',32768))
assert(not S.exists({player='/player',locale='de'}));assert(not S.export({player='/player',locale='de'}))
io.open=original;os.rename=rename;os.time=time
print('Pinball saves: exact size, language separation, backups, repeated imports and export passed')
