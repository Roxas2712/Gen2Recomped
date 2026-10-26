-- ROM identities, including the host's canonical Crystal cache revision.
local I={}
function I.acceptsForkBase(version,expected,marker)
  if type(expected)~='string' or type(marker)~='string' then return false end
  local first=marker:match('^[^\r\n]*')
  local actual=first and first:match('([%da-fA-F]+)$')
  if not actual or #actual~=40 then return false end
  actual=actual:lower()
  return actual==expected or version=='crystal'
    and expected=='f4cd194bdee0d04ca4eac29e09b8e4e9d818c133'
    and actual=='f2f52230b536214ef7c9924f483392993e226cfb'
end
return I
