-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The common Emerald menu uses its own labels, movie font and Hall frames.
local M={}
local labels={'gText_MainMenuNewGame','gText_MainMenuContinue','gText_MainMenuOption',
  'gText_MainMenuMysteryGift','gText_MainMenuMysteryGift2','gText_MainMenuMysteryEvents','gText_MenuExit',
  'gText_ContinueMenuPlayer','gText_ContinueMenuTime','gText_ContinueMenuPokedex','gText_ContinueMenuBadges',
  'gText_SaveFileErased','gText_SaveFileCorrupted','gText_BatteryRunDry',
  'gText_MysteryEventsCantUse','gText_WirelessNotConnected'}
function M.extract(x)
  assert(x.version=='emerald');x:beginStage('Emerald original main menu')
  local load=require('compat.gen1-rs.Loader').new('emerald')
  local S=load('src.import.gba.syms').of('emerald')
  local IR=load('src.core.game3.scripting.text_ir');local text={}
  for _,name in ipairs(labels)do
    local at=assert(S.off(name),'Missing Emerald main-menu symbol '..name);local raw={}
    for i=0,2047 do local b=x.rom:u8(at+i);raw[#raw+1]=b;if b==255 then break end end
    assert(raw[#raw]==255,'Unterminated Emerald main-menu label '..name)
    text[name]=IR.decode(raw,{dialect='rse'})
  end
  x._constants.gen3EmeraldMainMenu={format=1,version='emerald',textIR=text}
end
function M.valid(spec,version)
  if version~='emerald'or type(spec)~='table'or spec.format~=1 or spec.version~='emerald'
    or type(spec.textIR)~='table'then return false end
  for _,name in ipairs(labels)do if type(spec.textIR[name])~='table'or#spec.textIR[name]==0 then return false end end
  return true
end
function M.missing()
  local raw=require('src.import.CacheFs').read('data/generated/constants.lua')
  local f=raw and loadstring(raw);if f then setfenv(f,{})end
  local ok,c=false,nil;if f then ok,c=pcall(f)end
  if ok and type(c)=='table'and M.valid(c.gen3EmeraldMainMenu,'emerald')then return{}end
  return{'<emerald:native-main-menu>'}
end
return M
