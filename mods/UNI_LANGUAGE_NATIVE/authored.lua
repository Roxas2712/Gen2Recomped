-- Apply authored supplements only to the exact base text reviewed by the author.
-- Validation finishes before any registry mutation is queued.
return function(mod,entries)
 local W=require('src.import.LuaWriter')
 local function controls(ir)
  local out={}
  for _,seg in ipairs(ir) do
   if seg.t~='text' and seg.t~='nl' and seg.t~='para' and seg.t~='scroll' and seg.t~='eos' then out[#out+1]=seg end
  end
  return W.encode(out)
 end
 local originals,pending,shortLabels={},{},{}
 for key,value in mod.content.text:each() do if entries[key] then originals[key]=value end end
 for key,row in pairs(entries) do
  local source=assert(originals[key],'Authored text missing from base: '..key)
  local digest=love.data.encode('string','hex',love.data.hash('string','sha256',W.encode(source)))
  assert(digest==row.sourceSha256,'Authored text base changed: '..key)
  assert(type(row.target)=='table' and row.target[#row.target].t=='eos','Authored text lacks EOS: '..key)
  assert(controls(source)==controls(row.target),'Authored text control mismatch: '..key)
  pending[#pending+1]={key,row.target}
  -- A few stock menus ask Strings directly instead of resolving a ROM key.
  -- Mirror only unambiguous short literal labels; dialogue and descriptions
  -- retain their context-specific IR and wrapping.
  local function literal(ir)
   local out={}
   for _,seg in ipairs(ir) do
    if seg.t=='text' then out[#out+1]=seg.s elseif seg.t~='eos' then return nil end
   end
   local text=table.concat(out)
   if #text>0 and #text<=32 then return text end
  end
  local before,after=literal(source),literal(row.target)
  if before and after then
   if shortLabels[before]~=nil and shortLabels[before]~=after then shortLabels[before]=false
   else shortLabels[before]=after end
  end
 end
 for _,row in ipairs(pending) do
  mod.content.text:override(row[1],row[2])
  mod.content.rom_text:override(row[1],row[2])
  -- Source-form fallback also tries trimmed variants. A translated fragment
  -- with an intentional separator must win by label before that lookup.
  local parts,pure={},true
  for _,seg in ipairs(row[2]) do
   if seg.t=='text' then parts[#parts+1]=seg.s
   elseif seg.t~='eos' then pure=false end
  end
  local text=table.concat(parts)
  if pure and mod.content.strings and (text:match('^%s') or text:match('%s$')) then
   mod.content.strings:override(row[1],text)
  end
 end
 if mod.content.strings then
  for source,target in pairs(shortLabels) do if target then mod.content.strings:override(source,target) end end
 end
 return #pending
end
