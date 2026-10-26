-- Semantic move IDs are shared by the original Gen 1–3 games. Change only
-- display names; engine keys, ROM lookup names and battle mechanics stay intact.
return function(mod,names,maximum)
 local pending,seen={},{}
 for key,row in mod.content.moves:each() do
  local id=tonumber(row.index)
  if id and id>=1 and id<=maximum then
   assert(not seen[id],'Duplicate move ID: '..id)
   local name=assert(names[id],'Missing PT-BR move name: '..id)
   assert(type(name)=='string' and name~='' and not name:find('[\r\n]'),'Invalid move name: '..id)
   pending[#pending+1]={key,name};seen[id]=true
  end
 end
 for id=1,maximum do assert(seen[id],'Base move registry missing ID: '..id) end
 for _,row in ipairs(pending) do mod.content.moves:patch(row[1],{name=row[2]}) end
 return #pending
end
