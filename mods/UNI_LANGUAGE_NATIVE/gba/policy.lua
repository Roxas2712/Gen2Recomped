-- These US registry entries have no corresponding regional ROM address.
-- Do not call retained credits or absent English-only code "translations".
return function(game,ui)
 local rules={}
 local function retain(keys)
  for _,key in ipairs(keys) do rules[key]={kind='retainedProperNames'} end
 end
 if game=='firered' or game=='leafgreen' then
  -- pokefirered/src/{scrcmd,pokemon_jump}.c compile these suffixes only for
  -- LANGUAGE_ENGLISH. runtime.lua applies the regional CopyItemName branch.
  for _,key in ipairs({'sPluralTxt','sText_IES','sText_S'}) do rules[key]={kind='inapplicable'} end
 elseif game=='emerald' then
  retain({'sCreditsText_NicolaPrattBarlow','sCreditsText_RoyalNewZealandFederationBlind'})
 elseif game=='ruby' or game=='sapphire' then
  retain({'Text_ABA','Text_Fujihara','Text_Hertzog','Text_Howitt','Text_Lillygren',
   'Text_Maurer','Text_McMahill','Text_NFotB','Text_Ogasawara','Text_Okada',
   'Text_RNZFotB','Text_Ridgeway','Text_Tilden'})
  local labels={Text_Version=game=='ruby' and 'POKéMON RUBY VERSION' or 'POKéMON SAPPHIRE VERSION',
   Category_EnglishVersionCoordinators='English Version Coordinators',
   Category_NOAProductTesting='NOA Product Testing',Category_Translator='Translator'}
  for key,source in pairs(labels) do rules[key]={kind='authored',value=assert(ui[source])} end
 end
 return rules
end
