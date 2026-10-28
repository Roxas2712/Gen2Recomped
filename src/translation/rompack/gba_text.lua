-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Keep dynamic fields as host tokens rather than resolving them at compile
-- time. Battle placeholders retain their semantic identity for the adapter.
local T={}
function T.plain(ir,game,slots)
 local out={}
 for _,seg in ipairs(ir)do
  local kind=seg.t
  if kind=='text'then out[#out+1]=seg.s
  elseif kind=='nl'then out[#out+1]='\n'
  elseif kind=='para'then out[#out+1]='\f'
  elseif kind=='scroll'then out[#out+1]='\v'
  elseif kind=='player'then out[#out+1]='{PLAYER}'
  elseif kind=='rival'then out[#out+1]='{RIVAL}'
  elseif kind=='strvar'then out[#out+1]='{VAR'..seg.n..'}'
  elseif kind=='bph'then out[#out+1]=('{B_%02X}'):format(seg.code)
  elseif kind=='ph'then
   local n=seg.code;local names={[0]='UNKNOWN',[1]='PLAYER',[2]='VAR1',[3]='VAR2',[4]='VAR3',[5]='KUN',[6]='RIVAL',[7]='VERSION',[8]='AQUA',[9]='MAGMA',[10]='ARCHIE',[11]='MAXIE',[12]='KYOGRE',[13]='GROUDON'}
   out[#out+1]=require('src.core.Gen3RsTextPlaceholders').token(n,game)or'{'..(names[n]or('ULA_GENDER_'..tostring(n)))..'}'
  elseif kind=='tag'then
   local tags={['{POKEBLOCK}']='POKéBLOCK',['{PK}']='PK',['{MN}']='MN',['{LV}']='Lv',['{LV_2}']='Lv',['{UNK_SPACER}']=' '}
   out[#out+1]=tags[seg.tag]or seg.tag
  elseif kind=='dynamic'then
   local slot=slots and slots[seg.n]
   if slot~=''then out[#out+1]='{'..(slot or'VAR'..(seg.n+1))..'}'end
  end
 end
 return table.concat(out)
end
function T.format(s)
 return (s:gsub('%%','%%%%'):gsub('%b{}',function(token)
  if token=='{KUN}'or token:match('^%{B_2[89A-D]%}$')then return ''end
  return '%s'
 end))
end
function T.source(s)return(s:gsub('’',"'"):gsub('[\n\r\v\f]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''))end
-- Six-dot cartridge alphabet (pret/pokefirered include/characters.h;
-- also used by the GPL upstream importer). Formatting bytes precede Emerald.
function T.braille(bytes,skip)
 local alphabet={[0]=' ',[1]='A',[3]='C',[4]=',',[5]='B',[6]='I',[7]='F',[9]='E',[11]='D',[12]=':',[13]='H',[14]='J',[15]='G',[16]="'",[17]='K',[18]='/',[19]='M',[20]=';',[21]='L',[22]='S',[23]='P',[25]='O',[27]='N',[28]='!',[29]='R',[30]='T',[31]='Q',[44]='.',[46]='W',[48]='-',[49]='U',[51]='X',[52]='?',[53]='V',[56]='"',[57]='Z',[58]='#',[59]='Y',[60]='('}
 local out={}
 for i=(skip or 0)+1,#bytes do
  local b=bytes:byte(i);if b==255 then return table.concat(out)end
  out[#out+1]=b==254 and '\n'or alphabet[b]or'?'
 end
 error('Unterminated Braille text')
end
return T
