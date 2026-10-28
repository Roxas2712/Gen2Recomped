-- Save-side GSC progress queries. The native credits/script owners continue
-- to record inductions; this module never runs a second credits sequence.
local H = {}
function H.hasEntered(save)
  if type(save) ~= 'table' then return false end
  if type(save.hallOfFame) == 'table' then
    if save.hallOfFame.entered == true or (tonumber(save.hallOfFame.count) or 0) > 0
        or #save.hallOfFame > 0 then return true end
  elseif (tonumber(save.hallOfFame) or 0) > 0 then return true end
  return (tonumber(save.hallOfFameCount) or 0) > 0
end
return H
