-- Native summary prose from the installed language ROM's own named strings.
-- Ruby/Sapphire assemble their memo from fragments; FRLG uses full templates.
local M={}
function M.apply(data,named,game)
 local frlg=game=='firered'or game=='leafgreen'
 local rs=game=='ruby'or game=='sapphire'
 if not(frlg or rs)then return end
 local record=data.constants.gen3Memo or{templates={},slots={nature='{NATURE}',level='{LEVEL}',location='{LOCATION}'}}
 local templates=record.templates or{};record.templates=templates
 if frlg then
  local labels={met='gText_PokeSum_Met',trade='gText_PokeSum_MetInATrade',probablyMet='gText_PokeSum_ApparentlyMet',fateful='gText_PokeSum_FatefulEncounterMet',hatched='gText_PokeSum_Hatched'}
  for key,label in pairs(labels)do templates[key]=named[label]or templates[key]end
  if templates.met then templates.bare=templates.met:match('^[^\n]*');templates.metSomewhere=templates.met end
  templates.hatchedSomewhere=templates.hatched or templates.hatchedSomewhere
  local eggs={}
  for _,key in ipairs({'DayCare','NicePlace','Trade','Spa','TravelingMan'})do
   eggs[#eggs+1]=named['gText_PokeSum_EggOrigin_'..key]
  end
  if #eggs==5 then record.eggs=eggs end
 elseif named.gOtherText_Nature then
  local bare=named.gOtherText_Nature..'{NATURE}'
  templates.bare=bare
  local level=named.gOtherText_Lv or named.gOtherText_Level3
  local met=named.gOtherText_Met
  if level and met then
   templates.met=bare..'\n'..'{LOCATION}\n'..level..'{LEVEL}'..met
   templates.metSomewhere=bare..'\n'..level..'{LEVEL}'..met
   templates.probablyMet=templates.met
   templates.fateful=templates.met
  end
  if named.gOtherText_ObtainedInTrade then templates.trade=bare..'\n'..named.gOtherText_ObtainedInTrade end
  -- RS does not have Emerald's eight-template origin narrative. Its native
  -- fragments display nature and the recorded place without claiming a
  -- different encounter, hatch or trade event.
  templates.hatched=bare..'\n{LOCATION}'
  templates.hatchedSomewhere=bare
  local eggs={}
  for _,label in ipairs({'gOtherText_EggDayCare','gOtherText_EggNicePlace','gOtherText_EggObtainedInTrade','gOtherText_EggHotSprings'})do
   if named[label]then eggs[#eggs+1]=named[label]end
  end
  if #eggs==4 then record.eggs=eggs end
 end
 if templates.bare then data.constants.gen3Memo=record end
end
return M
