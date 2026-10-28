-- Exact RS party chrome, menus and the icon forms omitted by the host table.
local M={}
local ROOT='data/generated/gba/rse/'
function M.extract(x,load,rom,cache)
  x:beginStage('Ruby/Sapphire native party')
  local A=load('src.import.gba.rs.assets')
  A.text=function(_,off)return x:readText(off)end
  for _,name in ipairs({'extract_party','extract_menus'})do
    assert(load('src.import.gba.rs.'..name).run(rom,cache))
  end
  local S=load('src.import.gba.syms').of(x.version)
  local policy=load('src.ui.game3.rs.party_menu_data')
  local texts={}
  local function text(key)texts[key]=assert(x:readText(S.off(key)),'Missing native party text '..key)end
  for _,key in ipairs(policy.actionLabels)do text(key)end
  for _,key in pairs(policy.extraLabels)do text(key)end
  for _,key in ipairs({'gOtherText_NotHoldingAnything','gOtherText_BagFullCannotRemoveItem',
    'gOtherText_ReceivedTheThingFrom','gOtherText_CancelWithTerminator'})do text(key)end
  local K=load('src.import.gba.rse.boot_gfx')
  local c=A.context(rom,cache,{},'rse/party_extras')
  local icons={}
  local tableAt,indexAt,pals=S.off('gMonIconTable'),S.off('gMonIconPaletteIndices'),S.off('gMonIconPaletteTable')
  assert(S.count('gMonIconTable',4)==440 and S.size('gMonIconPaletteIndices')==440 and S.count('gMonIconPaletteTable',8)==6)
  for i=412,439 do
    local palId=c:u8(indexAt+i);assert(palId<6)
    local pal=c:palAt(assert(c:ptr(pals+palId*8)),16)
    local gfx=rom:readString(assert(c:ptr(tableAt+i*4)),1024)
    icons[i]=c:png('icon_'..i..'.png',32,64,K.bakeSprite(gfx,32,64,0,4),pal,true)
  end
  -- Font 4 has two native mapped tiles per glyph. The host's legacy small
  -- face keeps only the lower tile, which shifts party text by eight pixels
  -- and loses accents. Keep the complete original glyph cell here.
  local fontLoad=require('compat.gen1-rs.Loader').new(x.version,{
    ['src.import.gba.rse.text_chrome_extract']={},
  })
  local V={SYMS=S};fontLoad('src.import.gba.games.rs.text_chrome')(V)
  local fontRom=setmetatable({},{__index=rom})
  function fontRom:ptrOffset(ptr)
    local off=ptr-0x08000000
    return off>=0 and off<x.rom.size and off or nil
  end
  local font=fontLoad('src.import.gba.rs.text_chrome_extract').extractFont(fontRom,4,'latin',V)
  local palette=c:pal('gFontDefaultPalette',16)
  local fixed={}
  for p=1,#font.idx do
    local i=font.idx:byte(p)
    if i>0 and i<14 then
      local word=assert(palette[i])
      fixed[p]=string.char(math.floor(word%32*255/31+.5),math.floor(math.floor(word/32)%32*255/31+.5),math.floor(math.floor(word/1024)%32*255/31+.5),255)
    else fixed[p]='\0\0\0\0'end
  end
  local font4={w=font.width,h=font.height,widths=font.widths,count=font.spec.glyphsCount,
    fg=c:write('font4-fg.rgba',font.fgRgba),shadow=c:write('font4-shadow.rgba',font.shRgba),
    fixed=c:write('font4-fixed.rgba',table.concat(fixed)),index=c:write('font4.idx',font.idx)}
  assert(A.finish(c,{screen='party_extras',icons=icons,font4=font4}))
  x._constants.gen3RsParty={version=x.version,format=1,party=ROOT..'party/manifest.lua',
    menus=ROOT..'menus/manifest.lua',extras=ROOT..'party_extras/manifest.lua',text=texts}
end
function M.missing(version)
  local Fs=require('src.import.CacheFs');local missing={}
  for _,sub in ipairs({'party','menus','party_extras'})do
    local path=ROOT..sub..'/manifest.lua';local raw=Fs.read(path)
    local chunk=raw and loadstring(raw,'@'..path);if chunk then setfenv(chunk,{})end
    local ok,man=false,nil;if chunk then ok,man=pcall(chunk)end
    if not ok or type(man)~='table' or man.game~=version or man.layout~='rs'
      or type(man.files)~='table' or (sub~='menus' and #man.files==0)
      or (sub=='menus' and (type(man.party)~='table' or type(man.party.cursorOptions)~='table' or type(man.party.fieldMoves)~='table'))
      or (sub=='party_extras' and (type(man.icons)~='table' or type(man.font4)~='table'
        or type(man.font4.widths)~='table' or type(man.font4.count)~='number')) then missing[#missing+1]=path
    else for _,file in ipairs(man.files)do
      if type(file)~='string' or not Fs.exists(file)then missing[#missing+1]=tostring(file)end
    end end
  end
  return missing
end
return M
