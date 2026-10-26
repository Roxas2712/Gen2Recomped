-- Private extractor instances: their require resolves the mod's ROM profile,
-- never changes the engine's selected edition or shared module tables.
return function(game, bytes, V, readSource, fallback, digest, world, glyphs)
  local modules = {}
  local function private(name)
    if name=='src.core.GameVersion' then
      local native=fallback(name)
      return setmetatable({forSha1=function(hash)
        if hash==digest then return game end
        return native.forSha1(hash)
      end},{__index=native})
    end
    if name=='src.import.gba.versions' then return V end
    if name=='src.import.gba.syms' then return {of=function() return V.SYMS end} end
    if name=='src.import.gba.extract_island1' then return {CACHE_ROOT='data/generated/gba'} end
    if modules[name] then return modules[name] end
    local source=readSource(name)
    if not source then return fallback(name) end
    local factory=assert(loadstring('return function(require)\n'..source..'\nend','@german/'..name))()
    local value=factory(private)
    modules[name]=value
    return value
  end
  local IR=private('src.core.game3.scripting.text_ir')
  for k,v in pairs(glyphs or {[0x15]='ß',[0xF1]='Ä',[0xF2]='Ö',[0xF3]='Ü',[0xF4]='ä',[0xF5]='ö',[0xF6]='ü'}) do IR.CHARMAP[k]=v end
  local rom={id=game,size=#bytes,_raw=bytes,data=bytes}
  function rom:ensureBuffer() return bytes end
  function rom:readString(off,len)
    assert(off>=0 and len>=0 and off+len<=#bytes,'German ROM read outside bounds')
    return bytes:sub(off+1,off+len)
  end
  function rom:get(off) assert(off>=0 and off<#bytes,'German ROM byte outside bounds');return bytes:byte(off+1) end
  function rom:u16(off) return self:get(off)+self:get(off+1)*256 end
  function rom:u32(off) return self:u16(off)+self:u16(off+2)*65536 end
  function rom:ptrOffset(ptr) if ptr>=0x08000000 and ptr<0x08000000+#bytes then return ptr-0x08000000 end end
  function rom:readBytes(off,len) local t={};for i=0,len-1 do t[i+1]=self:get(off+i) end;return t end
  local files={}
  local cache={write=function(_,path,data) assert(type(data)=='string');files[path]=data;return true end,
    read=function(_,path) return files[path] end,exists=function(_,path) return files[path]~=nil end}
  local common={'pokedex_entries_extract','battle_chrome_extract'}
  local tasks={
    leafgreen={'extract_intro','text_chrome_extract','summary_chrome_extract','pokedex_chrome_extract','map_sections_extract','party_chrome_extract','bag_chrome_extract','storage_chrome_extract','credits_extract'},
    ruby={'rs.extract_title','rs.text_chrome_extract','rs.extract_summary','rs.extract_common_ui','rs.extract_pokedex','rs.extract_pokedex_detail','rs.extract_region_map','rs.extract_naming','rs.extract_bag','rs.extract_party','rs.extract_storage','rs.extract_trainer_card','rs.extract_credits'},
    emerald={'rse.extract_title_rse','rse.text_chrome_extract','rse.summary_chrome_extract','rse.pokedex_chrome_extract','rse.map_sections_extract','rse.bag_chrome_extract','rse.shop_chrome_extract','rse.extract_naming_rse','party_chrome_extract','storage_chrome_extract','rse.trainer_card_extract','rse.credits_extract'},
  }
  tasks.firered=tasks.leafgreen
  tasks.sapphire=tasks.ruby
  for _,name in ipairs(common) do tasks[game][#tasks[game]+1]=name end
  for _,name in ipairs(tasks[game]) do
    local opts={game=game,cacheRoot='data/generated/gba',sha1=digest}
    if (game=='leafgreen' or game=='firered') and name=='party_chrome_extract' then opts.game=nil end
    local ok,err=pcall(private('src.import.gba.'..name).run,rom,cache,opts)
    assert(ok,name..': '..tostring(err))
  end
  if world then world(private,rom,files) end
  return files
end
