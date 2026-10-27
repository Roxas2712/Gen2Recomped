package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local SaveData=require('src.core.SaveData')
local Badges=require('src.inventory.Badges')
local Version=require('src.core.GameVersion')
local Writer=require('src.import.LuaWriter')
local checks=0
local function check(value,why)checks=checks+1;assert(value,why)end
-- Native system flags differ between Hoenn's original pair, Emerald and
-- Kanto's remakes. Include unrelated flags from the other editions to catch
-- an accidental global-version lookup after switching cartridges.
local cases={
  {'ruby',0x807,'STONEBADGE'}, {'sapphire',0x807,'STONEBADGE'},
  {'emerald',0x867,'STONEBADGE'}, {'firered',0x820,'BOULDERBADGE'},
  {'leafgreen',0x820,'BOULDERBADGE'},
}
for _,case in ipairs(cases)do
  local version,first,id=unpack(case)
  Version.set(version=='ruby'and'leafgreen'or'ruby')
  local save={player={name='ORDINARY'},playTime=61*3600+13*60,
    pokedex={owned={TREECKO=true,NUMEL=true}},flags={}}
  for _,base in ipairs({0x807,0x820,0x867})do
    for i=0,7 do save.flags[('FLAG_G3_%04X'):format(base+i)]=base==first and i<3 or nil end
  end
  local before=Writer.encode(save)
  local name,summary=SaveData.slotSummary(save,version)
  check(name=='ORDINARY'and summary.badges==3,version..' must preview its three earned native badges')
  check(summary.timeText=='61:13'and summary.dexCount==2,'Other save summary fields must survive')
  check(Writer.encode(save)==before,'Reading the launcher card must not migrate or change a save')
  local list=Badges.list(nil,version)
  check(list[1].id==id and list[8].flag==first+7,'Keep edition badge identity and order')
  save.flags={};check(select(2,SaveData.slotSummary(save,version)).badges==0,'Empty badge block')
  for i=0,7 do save.flags[('FLAG_G3_%04X'):format(first+i)]=true end
  check(select(2,SaveData.slotSummary(save,version)).badges==8,'All eight native badge flags')
  Version.set(version)
  check(Badges.count(nil,save)==8,'Omitted version follows the currently selected cartridge')
end
local mod={{id='CUSTOMBADGE',item='CUSTOM_FLAG'}}
check(Badges.list({constants={badges=mod}},'sapphire')==mod,'Loaded mod badge data remains authoritative')
check(Badges.count(nil,{inventory={BOULDERBADGE=1}},'red')==1,'Kanto GB badge items remain supported')
check(Badges.count(nil,{flags={ZEPHYRBADGE=true}},'gold')==1,'Johto native badge flags remain supported')
print('PASS_LAUNCHER_GEN3_BADGES '..checks)
