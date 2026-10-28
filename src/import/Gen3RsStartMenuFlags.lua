-- RS gates these rows on 0x801/0x802; Emerald's fallback is 0x861/0x862.
local M={}
function M.extract(x,load)
  local S=load('src.import.gba.syms').of(x.version)
  local C=require('compat.gen1-rs.Constants').new(load)
  local at=S.funcOff('BuildStartMenuActions_Normal');local get=S.funcOff('FlagGet')
  local menu=assert(x._constants.gen3StartMenu)
  for _,row in ipairs({{key='pokedexFlag',offset=2,id=0,name='FLAG_SYS_POKEDEX_GET'},
    {key='pokenavFlag',offset=0x32,id=3,name='FLAG_SYS_POKENAV_GET'}})do
    local p=at+row.offset;local flag=x:thumbLiteral(p)
    assert(flag==C:flag(row.name)and x:blTarget(p+2)==get,'RS start-menu FlagGet identity changed')
    assert(x.rom:u16(p+6)==0x0600 and x.rom:u16(p+8)==0x0E00
      and x.rom:u16(p+10)==0x2801 and x.rom:u16(p+12)==0xD102
      and x.rom:u16(p+14)==0x2000+row.id,'RS start-menu row predicate changed')
    menu[row.key]=('FLAG_G3_%04X'):format(flag)
  end
  menu.nativeGateSource=('ROM:RS BuildStartMenuActions_Normal %07X -> FlagGet %07X'):format(at,get)
end
return M
