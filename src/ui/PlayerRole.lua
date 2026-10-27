-- Display only: permissions are always enforced by the account service.
local R={}
function R.name(person)
  local role=type(person)=='table' and (person.display_role or person.permissions and person.permissions.role)
  if role=='superuser' then return 'SUPERUSER' elseif role=='admin' then return 'ADMIN' end
  return require('src.translation.Service').launcherLookup('PLAYER')
end
function R.label(name,person)
  if type(person)~='table' or not (person.display_role or person.permissions and person.permissions.role)then return tostring(name or '')end
  return tostring(name or '')..' ['..R.name(person)..']'
end
function R.short(person)
  local role=type(person)=='table' and person.display_role
  return role=='superuser' and ' [SU]' or role=='admin' and ' [ADM]' or ''
end
return R
