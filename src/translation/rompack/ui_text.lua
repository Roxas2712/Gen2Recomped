-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Bind existing cartridge captions; do not manufacture missing game wording.
local U={}
local original={
 ['Choose a POKéMON.']='gText_ChoosePokemon',
 ['EXP POINTS']='gText_PokeSum_ExpPoints',
 ['LEVEL UP']='gText_PokeSum_NextLv',
 TIME='gText_TrainerCardTime',
}
function U.apply(data,language,catalogs)
 if language=='en'then return end
 local s=data.strings or{};data.strings=s
 local named=catalogs and catalogs.named or{}
 for key,label in pairs(original)do
  if not s[key]and type(named[label])=='string'and named[label]~=''then s[key]=named[label]end
 end
 -- Equivalent spellings share an already source-bound caption.
 for alias,key in pairs({['EXP. POINTS']='EXP POINTS',['NAME/%s']='NAME/',[' do?']='to do?'})do
  if not s[alias]and s[key]then s[alias]=alias=='NAME/%s'and s[key]..'%s'or s[key]end
 end
 if not s['NAME/']and s.NAME then s['NAME/']=s.NAME..'/'end
end
return U
