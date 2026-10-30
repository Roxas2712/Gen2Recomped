-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Own-cartridge sale prose and the small graphics used over the bag.
local M={ROOT='data/generated/gba/bag_sale/'}
function M.supports(v)return v=='emerald'or v=='firered'or v=='leafgreen'end
function M.labels(v)
  if v=='emerald'then return{prompt='gText_HowManyToSell',confirm='gText_ICanPayVar1',
    done='gText_TurnedOverVar1ForVar2',cant='gText_CantBuyKeyItem',money='gText_PokedollarVar1',
    count='gText_xVar1',yes='gText_Yes',no='gText_No'}end
  return{prompt='gText_HowManyWouldYouLikeToSell',confirm='gText_ICanPayThisMuch_WouldThatBeOkay',
    done='gText_TurnedOverItemsWorthYen',cant='gText_OhNoICantBuyThat',money='gText_PokedollarVar1',
    count='gText_TimesStrVar1',yes='gText_Yes',no='gText_No',label='gText_TrainerCardMoney'}
end
function M.resource(v)return M.ROOT..(v=='emerald'and'money_label.rgba'or'arrows.rgba')end
function M.extract(x)
  if not M.supports(x.version)then return end
  local load=require('compat.gen1-rs.Loader').new(x.version,{
    ['src.core.GameVersion']=require('src.core.GameVersion'),__package={loaded={}}})
  local IR=load('src.core.game3.scripting.text_ir');local S,labels
  if x.version=='emerald'then S=load('src.import.gba.syms').of(x.version)
  else labels=require('src.import.gba.text_labels.'..x.version)end
  local text={}
  for key,name in pairs(M.labels(x.version))do
    local at=assert(S and S.off(name)or labels[name],'Missing native sale text '..name);local raw={}
    for i=0,2047 do local b=x.rom:u8(at+i);raw[#raw+1]=b;if b==255 then break end end
    assert(raw[#raw]==255,'Unterminated native sale text '..name)
    text[key]=IR.decode(raw,{dialect=x.version=='emerald'and'rse'or'frlg'})
  end
  local Lz=load('src.import.gba.lz77');local Bake=load('src.import.gba.bg_bake')
  local function lz(at)return Lz.decompress(function(i)return x.rom:u8(i)end,assert(at))end
  local bytes
  if S then
    local palette=Bake.loadPalBanks(lz(S.off('gShopMenu_Pal')),1)[0]
    bytes=Bake.bakeSpriteRgba(lz(S.off('gShopMenuMoney_Gfx')),palette,0,32,16,false,false)
  else
    local V=load('src.import.gba.versions_frlg');V.select(x.version)
    local palette={};for i=0,15 do palette[i]=x.rom:u16(V.RED_ARROW_PAL+i*2)end
    bytes=Bake.bakeSpriteRgba(lz(V.RED_ARROW_OTHER_GFX),palette,0,16,32,false,false)
  end
  assert(#bytes==2048,'Native sale graphic has the wrong dimensions')
  local path=M.resource(x.version);local ok,why=require('src.import.CacheFs').write(path,bytes);assert(ok,why)
  x._constants.gen3BagSale={format=1,version=x.version,textIR=text,graphic=path}
  x:write('constants',x._constants)
end
function M.valid(s,v)
  if not(M.supports(v)and type(s)=='table'and s.format==1 and s.version==v
    and type(s.textIR)=='table'and s.graphic==M.resource(v))then return false end
  for key in pairs(M.labels(v))do if type(s.textIR[key])~='table'or#s.textIR[key]==0 then return false end end
  return true
end
function M.missing(v)
  if not M.supports(v)then return{}end
  local Fs=require('src.import.CacheFs');local raw=Fs.read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  local s=ok and type(c)=='table'and c.gen3BagSale
  local graphic=M.valid(s,v)and Fs.read(s.graphic)
  if type(graphic)=='string'and#graphic==2048 then return{}end
  return{'<'..v..':native-bag-sale>'}
end
return M
