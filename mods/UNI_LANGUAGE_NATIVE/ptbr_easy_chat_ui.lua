-- Sort display lists by the selected language without changing saved word IDs,
-- unlock rules, duplicate-word semantics, or the underlying gameplay tables.
return function(active)
 local Easy=require('src.core.game3.easy_chat_text')
 local UI=require('src.ui.game3.easy_chat')
 if UI._ulaWordOrder then return end
 UI._ulaWordOrder=true
 local function enabled()local s=active();return s and s.display.language=='pt-BR'end
 local accents={['Á']='A',['À']='A',['Â']='A',['Ã']='A',['É']='E',['Ê']='E',['Í']='I',['Ó']='O',['Ô']='O',['Õ']='O',['Ú']='U',['Ü']='U',['Ç']='C'}
 local function key(id)
  local value=Easy.word(id)
  for from,to in pairs(accents)do value=value:gsub(from,to)end
  return value
 end
 local function sorted(list)
  local out={};for _,w in ipairs(list)do out[#out+1]=w end
  table.sort(out,function(a,b)local x,y=key(a.id),key(b.id);return x==y and a.id<b.id or x<y end)
  return out
 end
 local function groups(rows)
  local out={}
  for _,g in ipairs(rows)do
   local copy={};for k,v in pairs(g)do copy[k]=v end
   copy.words=sorted(g.words);out[#out+1]=copy
  end
  return out
 end
 local populate=UI.populateGroups
 UI.populateGroups=function(...)
  local rows=populate(...);return enabled() and groups(rows) or rows
 end
 local Picker=require('src.ui.game3.rs.mail_composer_policy')
 local oldGroup=Picker.groupWords
 Picker.groupWords=function(...)
  local rows=oldGroup(...);return enabled() and sorted(rows) or rows
 end
 local oldAlpha=Picker.alphabetWords
 local function alphabet(letter,man,session,gates)
  if not enabled()then return oldAlpha(letter,man,session,gates)end
  local out,seen={},{}
  -- Preserve the native alternative-word selection before regrouping by
  -- translated initial. Accented initials belong to their Latin letter.
  for original=0,26 do for _,w in ipairs(oldAlpha(original,man,session,gates))do
   local initial=key(w.id):byte(1);local index=initial and initial>=65 and initial<=90 and initial-64 or 0
   if index==letter and not seen[w.id]then out[#out+1]=w;seen[w.id]=true end
  end end
  return sorted(out)
 end
 Picker.alphabetWords=alphabet
 for _,name in ipairs({'trendy_phrase_policy','easy_chat_editor_policy'})do
  require('src.ui.game3.rs.'..name).alphabetWords=alphabet
 end
end
