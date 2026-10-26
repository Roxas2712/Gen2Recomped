-- Translate presentation labels only. Word IDs, saved phrases, availability,
-- passwords and the source game's group context retain their original meaning.
return function(mod,words,moves)
 local base=require('src.core.game3.dataset').cache()
 local pack=assert(loadstring(assert(base:read('data/generated/gba/easy_chat/words.lua'))))()
 local names={[1]='TREINADOR',[2]='ESTADO',[3]='BATALHA',[4]='SAUDAÇÕES',[5]='PESSOAS',[6]='VOZES',[7]='FALA',[8]='CONECTIVOS',[9]='SENTIMENTOS',[10]='CONDIÇÕES',[11]='AÇÕES',[12]='COTIDIANO',[13]='PASSATEMPOS',[14]='TEMPO',[15]='DIVERSOS',[16]='ADJETIVOS',[17]='EVENTOS',[18]='GOLPES 1',[19]='GOLPES 2',[20]='EXPRESSÕES'}
 local labels={};local count=0
 for gid,group in pairs(pack.groups)do
  local name=names[gid] or (group.name:find('2',1,true) and 'POKÉMON 2' or 'POKÉMON')
  mod.content.strings:override('easyChat.group['..gid..']',name)
  for _,word in ipairs(group.words)do
   local target
   if gid==0 or gid==21 then target=word.text
   elseif gid==18 or gid==19 then target=assert(moves[word.value],'Unknown Easy Chat move ID')
   else
    local hash=love.data.encode('string','hex',love.data.hash('string','sha256',gid..'\0'..word.text))
    local row=assert(words[hash],'Untranslated Easy Chat word '..gid..':'..word.id)
    assert(row.group==gid);target=row.target
   end
   mod.content.strings:override('easyChat.word['..word.id..']',target)
   labels[word.id]=target;count=count+1
  end
 end
 return {count=count,labels=labels}
end
