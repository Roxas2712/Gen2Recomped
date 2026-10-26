-- Translate exact embedded copies of registered text at compile time.
-- Numeric records, script keys, assets and gameplay data remain intact.
return function(files,paths,mod,operations,authored,bindings)
 local W=require('src.import.LuaWriter')
 local IR=require('src.core.game3.scripting.text_ir')
 local base=require('src.core.game3.dataset').cache()
 local original,byKey,byIR,byString={},{},{},{}
 local irConflicts,stringConflicts={},{}
 local function unique(map,conflicts,key,value)
  if conflicts[key] then return end
  if map[key]~=nil and W.encode(map[key])~=W.encode(value) then map[key]=nil;conflicts[key]=true
  else map[key]=value end
 end
 local pure={text=true,tag=true,nl=true,para=true,scroll=true,eos=true,ext=true}
 local function static(row)
  for _,seg in ipairs(row)do if not pure[seg.t] then return false end end;return true
 end
 for key,row in mod.content.text:each()do original[key]=row end
 for _,op in ipairs(operations)do if op.registry=='text' and op.method=='override' then byKey[op.key]=op.value end end
 -- Native packs keep placeholders as literal tokens. Render only their
 -- documented operand formats, never a dynamic field value.
 local function packedText(row,help)
  local out={}
  for _,seg in ipairs(row)do
   if seg.t=='text' then out[#out+1]=seg.s
   elseif seg.t=='nl' then out[#out+1]='\n'
   elseif seg.t=='para' then out[#out+1]=help and '\n' or '\\p'
   elseif seg.t=='scroll' then out[#out+1]=help and '\n' or '\\l'
   elseif seg.t=='player' then out[#out+1]='{PLAYER}'
   elseif seg.t=='rival' then out[#out+1]='{RIVAL}'
   elseif not help and seg.t=='ph' and seg.name and seg.name:match('^ULA_PTBR_GENDER_%d+$') then out[#out+1]='{'..seg.name..'}'
   elseif seg.t=='tag' then out[#out+1]=help and seg.tag=='{PLUS}' and '+' or seg.tag
   elseif seg.t=='strvar' and (not help or seg.n==1) then out[#out+1]=help and '{PC_OWNER}' or '{STR_VAR_'..seg.n..'}'
   elseif seg.t~='eos' and seg.t~='ext' then return nil end
  end
  return table.concat(out)
 end
 for key,row in pairs(byKey)do if original[key] then
  unique(byIR,irConflicts,W.encode(original[key]),row)
  for _,help in ipairs({false,true})do
   local a,b=packedText(original[key],help),packedText(row,help)
   if a and b and a~='' and a~=b then unique(byString,stringConflicts,a,b)end
  end
  if static(original[key]) and static(row) then
  for _,render in ipairs({IR.toPlain,IR.toAscii})do
   local ok,a=pcall(render,original[key],{});local valid,b=pcall(render,row,{})
   if ok and valid and a~=b and a~='' then unique(byString,stringConflicts,a,b) end
  end
  end
 end end
 local report={ir=0,strings=0,authored=0,unmatched={}}
 local function sha(value)return love.data.encode('string','hex',love.data.hash('string','sha256',W.encode(value)))end
 local function operands(ir)
  local out={};for _,seg in ipairs(ir)do
   if seg.t~='text' and seg.t~='nl' and seg.t~='para' and seg.t~='scroll' and seg.t~='eos' then out[#out+1]=seg end
  end;return W.encode(out)
 end
 local function rewrite(v,path,field)
  if field=='key' or field=='path' or field=='png' or field=='screen' or field=='build' or field=='symbol' or field=='name' and type(v)=='string' and byKey[v] then return v end
  if type(v)=='string' and bindings and bindings[path] then
   local key=bindings[path]
   assert(original[key] and packedText(original[key],true)==v,'Native Help source changed: '..path)
   local target=byKey[key] and packedText(byKey[key],true)
   assert(target,'Missing native Help translation: '..key)
   report.strings=report.strings+1;return target
  end
  if type(v)=='string' then
   local p=path:match('fame_checker/pack.lua.quotes%.(%d+)$')
   local key=p and ('sFameCheckerNameAndQuotesPointers['..(16+tonumber(p))..']')
   p=path:match('fame_checker/pack.lua.names%.(%d+)$')
   key=key or p and ('sFameCheckerNameAndQuotesPointers['..p..']')
   local person,slot=path:match('fame_checker/pack.lua.flavorText%.(%d+)%.(%d+)$')
   key=key or person and ('sFameCheckerFlavorTextPointers['..(tonumber(person)*6+tonumber(slot))..']')
   if key then
    assert(original[key] and packedText(original[key],false)==v,'Native Fame Checker source changed: '..path)
    local target=byKey[key] and packedText(byKey[key],false)
    assert(target,'Missing native Fame Checker translation: '..key)
    report.strings=report.strings+1;return target
   end
  end
  if (type(v)=='string' or (type(v)=='table' and type(v[1])=='table' and v[1].t)) then
   local row=authored and authored[sha(v)]
   if row then
    assert(type(row.target)==type(v),'Scene text kind changed')
    if type(v)=='table' then assert(operands(v)==operands(row.target),'Scene text operands changed')end
    report.authored=report.authored+1;return row.target
   end
  end
  if type(v)=='table' then
   if type(v[1])=='table' and v[1].t then
    local target=byIR[W.encode(v)]
    if target then report.ir=report.ir+1;return target end
    report.unmatched[path]=v;return v
   end
   if type(v.ir)=='table' and (byKey[v.name] or byKey[v.key]) then
    v.ir=byKey[v.name] or byKey[v.key];report.ir=report.ir+1
   end
   for k,x in pairs(v)do if k~='ir' or not (byKey[v.name] or byKey[v.key]) then v[k]=rewrite(x,path..'.'..tostring(k),k)end end
  elseif type(v)=='string' then
   -- Identifier fields are never interpreted as display labels.
   if path:find('.alphabetText.',1,true) then return (v:gsub('others','outros')) end
   if byString[v] then report.strings=report.strings+1;return byString[v] end
   if v:match('%a %a') and not v:find('data/generated/',1,true) then report.unmatched[path]=v end
  end
  return v
 end
 for _,path in ipairs(paths)do
  -- Map packs from fan ROMs can retain individual English locations. Apply
  -- exact corrections to those imported labels as well as base-only packs.
  if not files[path] or path=='data/generated/gba/region_map/map_sections.lua' then
   local bytes=files[path] or assert(base:read(path),'Missing UI text pack '..path)
   local pack=assert(loadstring(bytes))()
   if path=='data/generated/gba/easy_chat/words.lua' then
    -- Saved word identities and raw vocabulary stay untouched. Only the
    -- UI template copies need the ordinary registered text translations.
    pack.templates=rewrite(pack.templates,path..'.templates')
   else pack=rewrite(pack,path) end
   if path=='data/generated/gba/secret_base/manifest.lua' and pack.assetLayout=='rs' then
    -- RS native menu uses entries 1/8/15 for ink/shadow/background.
    -- Its imported palette has white ink on a white decoration window.
    pack.menuPalette[2]=0x318c;pack.menuPalette[9]=0x56b5;pack.menuPalette[16]=0x7fff
   end
   files[path]=W.encode(pack)
  end
 end
 return report
end
