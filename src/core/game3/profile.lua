-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Read-only edition/font/layout facts from the native version registry.
-- This does not select a runtime, cache, save or gameplay capability set.
local Version=require('src.core.GameVersion')
local P={}
local cache={}
local function readonly(values)
 return setmetatable({},{__index=values,__newindex=function()
  error('native presentation profile is read-only',2)
 end,__pairs=function()return next,values,nil end,__metatable=false})
end
local font=readonly{module='src.ui.game3.frlg_font'}
local ordinary=readonly{}
local rs=readonly{battleSpriteLayout='rs'}
function P.isGame3Version(id)
 local info=type(id)=='string'and Version.info(id)
 return type(info)=='table'and info.generation==3
end
function P.resolveId(id)
 if id==nil or id==''then id=Version.get()end
 if not P.isGame3Version(id)then return nil,'no registered native GBA edition'end
 if not Version.layout(id)then return nil,'native GBA layout is unavailable'end
 return id
end
function P.of(id)
 local why;id,why=P.resolveId(id);if not id then return nil,why end
 local info=Version.info(id);local family=Version.layout(id)
 local special=id=='ruby'or id=='sapphire'
 local hit=cache[id]
 if hit and hit.info==info and hit.label==info.label and hit.family==family then return hit.view end
 local view=readonly{id=id,label=info.label,generation=info.generation,family=family,
  font=font,ui=special and rs or ordinary}
 cache[id]={info=info,label=info.label,family=family,view=view}
 return view
end
function P.active()return P.of(Version.get())end
function P.sessionVersion(session)
 if session==nil then return Version.get()end
 if type(session)~='table'then return nil,'profile session must be a table'end
 local version=session.version
 if version==nil or version==''then return Version.get()end
 if type(version)~='string'then return nil,'profile session edition must be a string'end
 return version
end
function P.forSession(session)
 local id,why=P.sessionVersion(session);if not id then return nil,why end
 return P.of(id)
end
function P.family(session)
 local row,why=P.forSession(session)
 if not row then return nil,why end
 return row.family
end
function P.reset()cache={}end
return P
