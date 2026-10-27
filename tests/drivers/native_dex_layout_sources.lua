-- Actual optional cartridges, read only. No generated cache or save is used.
local mod,imports=...
local Dex=require('src.translation.rompack.gba_dex')
local IR=dofile(mod..'/mod/vendor/src/core/game3/scripting/text_ir.lua')
local Text=require('src.translation.rompack.gba_text')
for _,game in ipairs({'firered','leafgreen'})do
 local p=dofile(mod..'/mod/profiles/'..game..'_ptbr/profile.lua')
 local f=assert(io.open(imports..'/'..game..'_ptbr.gba','rb'))
 local bytes=f:read('*a');f:close();assert(#bytes==p.size)
 for code,glyph in pairs(assert(loadfile(mod..'/mod/latin_glyphs.lua'))('pt-BR'))do IR.CHARMAP[code]=glyph end
 for code,glyph in pairs(p.decodeGlyphs or{})do IR.CHARMAP[code]=glyph end
 local function pointer(at)
  local a,b,c,d=bytes:byte(at+1,at+4)
  local value=a+b*256+c*65536+d*16777216-0x08000000
  if value>=0 and value<#bytes then return value end
 end
 local function decode(at,_,limit)
  return Text.plain(IR.decode(bytes:sub(at+1,at+limit),{dialect='frlg'}),game)
 end
 local entries=Dex.read(p.fields,pointer,function(at,limit)
  return decode(at,false,limit)
 end,decode)
 for index=1,386 do
  -- Independent expanded FRLG layout, rather than the implementation's field.
  local at=p.fields.POKEDEX_ENTRIES+index*44
  for page,offset in ipairs({24,28})do
   local ptr=assert(pointer(at+offset),'Missing original source pointer')
   local expected=decode(ptr,false,4096)
   local actual=page==1 and entries[index].text or entries[index].text2
   assert((page==2 or expected~='')and actual==expected,'Wrong original description: '..game..' '..index..' '..page)
  end
 end
 print('NATIVE_DEX_ORIGINAL_SOURCE_OK',game,'386 entries; 772 original page pointers')
end
