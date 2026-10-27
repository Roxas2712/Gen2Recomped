return function(mod,profile,bytes,own)
  local metadata=own(profile.assetsPath or 'profiles/'..profile.game..'_assets.lua')
  local function methods(fields,calls)
    local out=fields or {}
    for method,values in pairs(calls or {}) do
      out[method]=function(a,b)
        local key=tostring(a)..(b~=nil and '\t'..tostring(b) or '')
        local row=assert(values[key],'German asset profile lacks '..method..' '..key)
        return row[1]
      end
    end
    return out
  end
  local V=methods(metadata.fields,metadata.calls)
  V.SYMS=methods({},metadata.symbols)
  V.forGame=function() return V end
  local index=own('vendor/index.lua')
  local files=own('extract.lua')(profile.game,bytes,V,function(name)
    if index[name] then return assert(mod:read('vendor/'..name:gsub('%.','/')..'.lua')) end
  end,require,profile.sha1,not profile.skipWorld and function(private,rom,out)
    own("world.lua")(private,rom,own(profile.worldPath or "profiles/"..profile.game.."_world.lua"),require("src.core.game3.dataset").cache(),out)
  end,profile.glyphs)
  local report={count=0,bytes=0}
  for _,data in pairs(files) do report.count=report.count+1;report.bytes=report.bytes+#data end
  return files,report
end
