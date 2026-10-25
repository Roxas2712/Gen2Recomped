-- Pure, bounded catalogue search. Never infer target games from a mod title.
local S={}
local Targets=require('src.mods.ModTargets')
local Versions=require('src.core.GameVersion')
local function norm(v)
  local s=tostring(v or ''):lower()
  for a,b in pairs({['Ä']='a',['ä']='a',['Ö']='o',['ö']='o',['Ü']='u',['ü']='u',['ß']='ss',['é']='e',['É']='e',['è']='e',['á']='a',['ó']='o'}) do s=s:gsub(a,b) end
  return s:gsub('%s+',' ')
end
function S.generations(entry)
  local seen={}
  for _,id in ipairs(Targets.normalize(entry.games or {})) do seen[Versions.generation(id)]=true end
  for _,n in ipairs(entry.supportedGens or {}) do if type(n)=='number' then seen[n]=true end end
  if not next(seen) then
    for _,claim in ipairs(entry.compatibility or {}) do if type(claim)=='table' and claim.engine=='g1r' then seen[1]=true end end
  end
  return seen
end
local function tokens(query)
  local out={};query=norm(query):sub(1,512)
  -- Quoted phrases remain one term; other words may occur in different fields.
  for phrase in query:gmatch('"([^"]+)"') do out[#out+1]=phrase end
  query=query:gsub('"[^"]*"',' ')
  for term in query:gmatch('%S+') do if #out<16 then out[#out+1]=term end end
  return out
end
local function near(a,b)
  if math.abs(#a-#b)>1 or #a<4 then return false end
  local i,j,edits=1,1,0
  while i<=#a and j<=#b do
    if a:sub(i,i)==b:sub(j,j) then i=i+1;j=j+1
    else
      edits=edits+1;if edits>1 then return false end
      if #a>=#b then i=i+1 end
      if #b>=#a then j=j+1 end
    end
  end
  return edits+math.max(#a-i+1,#b-j+1)<=1
end
function S.filter(entries,filters)
  filters=filters or {};local terms=tokens(filters.query);local ranked={}
  for index,e in ipairs(entries or {}) do
    local keep=not filters.generation or S.generations(e)[filters.generation]
    if keep and filters.category then
      keep=false;for _,cat in ipairs(e.categories or {}) do if cat==filters.category then keep=true end end
    end
    if keep then
      local title=norm(e.title or e.name or e.id)
      local fields=norm(table.concat({e.id or '',e.author or '',e.summary or '',e.description or '',
        table.concat(e.tags or {},' '),table.concat(e.categories or {},' ')},' '))
      local score=0;local fuzzy=false
      for _,term in ipairs(terms) do
        if title==term then score=score+100
        elseif title:sub(1,#term)==term then score=score+65
        elseif title:find(term,1,true) then score=score+45
        elseif fields:find(term,1,true) then score=score+10
        else
          local typo=false
          if not term:find(' ',1,true) then for word in title:gmatch('[%w_]+') do if near(term,word) then typo=true;break end end end
          if typo then score=score+1;fuzzy=true else keep=false;break end
        end
      end
      if keep then ranked[#ranked+1]={entry=e,score=score,index=index,fuzzy=fuzzy} end
    end
  end
  table.sort(ranked,function(a,b) if a.score==b.score then return a.index<b.index end;return a.score>b.score end)
  local out,approximate={},0
  for _,row in ipairs(ranked) do out[#out+1]=row.entry;if row.fuzzy then approximate=approximate+1 end end
  return out,approximate
end
return S
