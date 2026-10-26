-- Named IR placeholders occur only in compiled PT-BR FRLG text. The words
-- themselves live in this mod's text registries and disappear on unload.
return function()
 local dialect=require('src.core.game3.scripting.text_ir').DIALECTS.frlg
 dialect.GENDERED_LABELS=dialect.GENDERED_LABELS or {}
 for code=14,32 do
  local name='ULA_PTBR_GENDER_'..code
  dialect.GENDERED_LABELS[name]={male=name..'_male',female=name..'_female'}
 end
end
