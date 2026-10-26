-- Preserve readable Asian player/nicknames after selecting another language.
-- This imports only font pages; it never applies dialogue/name translations.
return function(mod,version,own,language)
 local selected,profile,info
 for _,entry in ipairs(own('catalog.lua'))do
  if entry.game==version and entry.generation==2 and(entry.language=='ja'or entry.language=='ko')then
   local imported=mod.imports:info(entry.id)
   if imported then selected=entry;profile=own(entry.profile);info=imported;break end
  end
 end
 if not selected or language==selected.language then return end
 assert(info.md5==profile.md5 and info.size==profile.size,'Asian font ROM/profile mismatch')
 local function hash(bytes,kind)return love.data.encode('string','hex',love.data.hash('string',kind or 'sha256',bytes))end
 local paths={selected.profile,selected.root..'font_pages.lua',selected.root..'assets.lua','gb/compile.lua','gb/overlay.lua','gb/runtime/asian_fallback.lua','gb/runtime/asian_input.lua','gb/runtime/asian_layout.lua','compiler.lua','cache_codec.lua'}
 local recipe={'asian-font-fallback-v1',profile.sha1};for _,path in ipairs(paths)do recipe[#recipe+1]=hash((assert(mod:read(path))))end
 local key=hash(table.concat(recipe,'\n'))
 local fontProfile={};for k,v in pairs(profile)do fontProfile[k]=v end;fontProfile.catalogs={'font_pages.lua'}
 local function fontOwn(path)
  local value=own(path)
  if path==selected.root..'assets.lua'then local out={};for k,v in pairs(value)do if k:match('^assets/fonts/')then out[k]=v end end;return out end
  return value
 end
 local files=own('compiler.lua')(mod,key,function()
  local rom=assert(mod.imports:read(selected.id,0,info.size));assert(hash(rom,'sha1')==profile.sha1,'Asian font checksum mismatch')
  return own('gb/compile.lua')(rom,fontProfile,selected.root,fontOwn)
 end)
 local prefix='rom-language-fonts/'..key;own('gb/overlay.lua')(mod,version,prefix,files)
 local S=require('src.core.SaveSerializer');local pages=assert(S.decode(files['lang/font_pages.lua']));local map={};local tall={}
 for char,code in pairs(profile.fontmap)do
  if char:byte()>127 then map[char]=code;mod.content.font:register('charmap:ula-fallback:'..char,{seq=char,code=code})end
 end
 for id,page in pairs(pages.pages or {})do
  mod.content.font:register('ula-fallback-'..id,{image=prefix..'/'..page.path,base=page.base,glyphsPerRow=16})
  for code=page.base,page.base+510,2 do tall[code]=true end
 end
 for id,page in pairs(pages.singlePages or {})do mod.content.font:register('ula-fallback-'..id,{image=prefix..'/'..page.path,base=page.base,glyphsPerRow=16})end
 local Font=require('src.render.Font');local Runtime=require('src.mods.Runtime');local V=require('src.core.GameVersion')
 local marker='mod.german_rom_source.asian-fonts';mod.events:on(marker,function()end);local bus=Runtime.events
 local patch=Font.__ulaAsianFallback
 if not patch then
  patch={draw=Font.drawCode,split=Font.split};Font.__ulaAsianFallback=patch
  Font.drawCode=function(code,x,y)
   if patch.active()and patch.tall[code]then patch.draw(code,x,y-8);patch.draw(code+1,x,y)
   elseif patch.active()and patch.composite[code]then local c=patch.composite[code];patch.draw(c.base,x,y);patch.draw(c.mark,x,y-8)
   else patch.draw(code,x,y)end
  end
  Font.split=function(text)
   local spans=patch.split(text)
   if patch.active()and type(text)=='string'then for _,span in ipairs(spans)do span.code=patch.fontmap[text:sub(span.from,span.to)]or span.code end end
   return spans
  end
 end
 patch.active=function()return Runtime.events==bus and Runtime.wants(marker)and V.get()==version end
 patch.fontmap=map;patch.tall=tall;patch.composite=pages.composite or {}
 local proxy=setmetatable({language=language},{__index=mod})
 own('gb/runtime/asian_input.lua').install(proxy,patch,true)
 own('gb/runtime/asian_layout.lua')(proxy,profile.encoding,patch)
 mod.exports.asianNameFont=selected.language
end
