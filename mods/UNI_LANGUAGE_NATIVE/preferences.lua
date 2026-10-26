-- The launcher preserves baseroms/ on updates and removes it on uninstall.
-- Store only personal mod preferences here, not in the retained compile cache.
-- A small data-only format avoids evaluating any user-writable Lua.
return function(mod)
 local relative='baseroms/.uni-language-profile'
 local bytes=mod:read(relative)
 local values={};local valid=type(bytes)=='string' and #bytes<65536 and bytes:sub(1,5)=='ULA1\n'
 if valid then
  for line in bytes:sub(6):gmatch('[^\n]+') do
   local k,v=line:match('^([%w_/%.%-]+)=([%w_%-]+)$')
   if not k then valid=false;break end
   values[k]=v
  end
 end
 if not valid then values={} end
 local self={fresh=not valid}
 local function save(nextValues)
  local lines={'ULA1'};local keys={}
  for k,v in pairs(nextValues) do
   assert(k:match('^[%w_/%.%-]+$') and v:match('^[%w_%-]+$'),'Invalid preference')
   keys[#keys+1]=k
  end
  table.sort(keys);for _,k in ipairs(keys)do lines[#lines+1]=k..'='..nextValues[k]end
  local Cache=require('src.import.CacheFs');local previous=Cache.prefix;Cache.prefix=''
  local called,ok,err=pcall(Cache.write,mod.path..'/'..relative,table.concat(lines,'\n')..'\n')
  Cache.prefix=previous
  if not called then return nil,ok end
  if not ok then return nil,err end
  values=nextValues;return true
 end
 function self:read(key)return values[key]end
 function self:write(key,value)
  local nextValues={};for k,v in pairs(values)do nextValues[k]=v end
  nextValues[key]=value;return save(nextValues)
 end
 function self:clearOptions()
  local Save=require('src.core.SaveData');local opts=Save.loadOptions() or Save.defaultOptions()
  opts.modOptions=opts.modOptions or {};opts.modOptions[mod.id]={language='auto',showPicker=true}
  local ok,err=Save.saveOptions(opts);if not ok then return nil,err end
  local game=mod.game
  if game.mods then game.mods.modOptions[mod.id]=opts.modOptions[mod.id] end
  for _,o in ipairs({game.options,game.save and game.save.options})do if o then o.modOptions=opts.modOptions end end
  return true
 end
 function self:reset()
  local ok,err=self:clearOptions();if not ok then return nil,err end
  return save({})
 end
 if self.fresh then
  local ok,err=self:clearOptions()
  if not ok then mod.log:warn('Could not reset stale launcher language options: %s',tostring(err)) end
 end
 return self
end
