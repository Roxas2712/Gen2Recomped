-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
local C={}
function C.wordSource(text)
 text=text:gsub('’',"'")
 if text=='PKRS'then return '{PK}RS'end
 if text=='POKéBLOCK'then return '{POKEBLOCK}'end
 return text
end
-- Word identity is group/index, not alphabetical position. Keep those IDs,
-- availability and numeric species/move references while changing the labels.
function C.easyChat(data,localized,language,own)
 local base=data.constants.gen3EasyChat
 if not base then return 0 end
 local names={[1]='TREINADOR',[2]='ESTADO',[3]='BATALHA',[4]='SAUDAÇÕES',[5]='PESSOAS',[6]='VOZES',[7]='FALA',[8]='CONECTIVOS',[9]='SENTIMENTOS',[10]='CONDIÇÕES',[11]='AÇÕES',[12]='COTIDIANO',[13]='PASSATEMPOS',[14]='TEMPO',[15]='DIVERSOS',[16]='ADJETIVOS',[17]='EVENTOS',[18]='GOLPES 1',[19]='GOLPES 2',[20]='EXPRESSÕES'}
 local vocabulary=language=='pt-BR'and own('ptbr_easy_chat_words.lua')
 if not vocabulary then
  assert(localized and localized.groups,'Localized Easy Chat word table missing')
  assert(#localized.groups==#base.groups,'Easy Chat group count differs')
  -- Validate every identity before committing any display change.
  for i,g in ipairs(base.groups)do
   local target=localized.groups[i]
   assert(target.kind==g.kind and target.count==g.count,'Easy Chat group identity differs: '..i)
   -- Species/move tables have a localized alphabetic order. Never transfer
   -- those numeric entries: the host already resolves their names by stable
   -- species/move ID, including words stored in existing saves.
  end
 end
 local count=0
 local patches={}
 for i,g in ipairs(base.groups)do
  local gid=i-1
  local name=vocabulary and(names[gid]or(gid==21 and'POKÉMON 2'or'POKÉMON'))or localized.groups[i].name
  patches[#patches+1]={row=g,name=name}
  if g.kind=='text'then for j,word in ipairs(g.words)do
   local text
   if vocabulary then
    if word.text==''then text=''else
     local key=love.data.encode('string','hex',love.data.hash('string','sha256',gid..'\0'..C.wordSource(word.text)))
     local target=assert(vocabulary[key],'Untranslated Easy Chat word: '..gid..':'..j)
     assert(target.group==gid,'Easy Chat authored group mismatch');text=target.target
    end
   else text=assert(localized.groups[i].words[j]).text end
   assert(type(text)=='string','Easy Chat label missing')
   patches[#patches+1]={row=word,text=text};count=count+1
  end end
 end
 for _,p in ipairs(patches)do if p.name then p.row.name=p.name else p.row.text=p.text end end
 return count
end
return C
