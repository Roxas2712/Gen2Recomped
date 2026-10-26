-- PT-BR catalogs for the stock Gen-2 engine. Only display data is patched.
return function(mod)
 local function catalog(name)
  local body=assert(mod:read('lang/'..name..'.lua'),'Missing PT-BR catalog: '..name)
  return assert(loadstring(body,'@ptbr/'..name))()
 end
 local data=assert(mod.game.data)
 for seq,code in pairs(catalog('charmap')) do
  mod.content.font:register('charmap:ptbr:'..seq,{seq=seq,code=code})
 end
 for id,text in pairs(catalog('dialogue')) do mod.content.text:override(id,text) end
 local strings=catalog('strings')
 for source,text in pairs(strings) do mod.content.strings:override(source,text) end
 local function names(name,registry,field)
  for id,text in pairs(catalog(name)) do registry:patch(id,{[field or 'name']=text}) end
 end
 names('species_names',mod.content.pokemon)
 names('item_names',mod.content.items)
 names('trainer_class_names',mod.content.trainers)
 names('type_names',mod.content.type_chart)
 names('landmark_names',mod.content.landmarks)
 for id,text in pairs(catalog('move_names')) do assert(data.moves[id],id).name=text end
 for _,pair in ipairs({{'move_descriptions','moves'},{'item_descriptions','items'}}) do
  for id,text in pairs(catalog(pair[1])) do if data[pair[2]][id] then data[pair[2]][id].description=text end end
 end
 for id,text in pairs(catalog('status_labels')) do mod.content.statuses:patch(id,{label=text,hudLabel=text}) end
 for id,row in pairs(catalog('dex_entries')) do
  local entry=assert(data.gen2Pokedex.entries[id],id)
  for _,field in ipairs({'kind','text','text2'}) do entry[field]=row[field] end
 end
 -- Verified metric facts from the retail German Gen-2 cartridges. Keep
 -- the original packed imperial fields intact (Heavy Ball uses weight).
 local metrics=assert(mod.shared.dexMetrics)
 for id,entry in pairs(data.gen2Pokedex.entries) do
  local row=assert(metrics[id],'Missing metric record: '..id)
  entry.heightM,entry.weightKg=assert(row.heightM),assert(row.weightKg)
 end
 -- Oak speech owns a separate copy, outside the general dialogue registry.
 local dialogue=catalog('dialogue')
 if mod.game.oakSpeechData and mod.game.oakSpeechData.text then
  for key in pairs(mod.game.oakSpeechData.text) do
   if dialogue[key] then mod.game.oakSpeechData.text[key]=dialogue[key] end
  end
 end
 local Runtime=require('src.mods.Runtime')
 local Version=require('src.core.GameVersion')
 local bus=Runtime.events
 local marker='__ula_ptbr_gen2__'
 mod.content.strings:override(marker,'active')
 local function active()
  return Runtime.events==bus and Version.get()==mod.edition and data.strings and data.strings[marker]=='active'
 end
 -- Older Gen-2 menus have literal labels. Translate them before measurement
 -- and pagination, using exact strings only; no global word substitutions.
 local function localize(text) return strings[text] or text end
 local Font=require('src.render.Font')
 local Chrome=require('src.ui.gen2.Chrome')
 local TextBox=require('src.render.TextBox')
 local patch=Font.__ulaPtbrGen2
 if not patch then
  patch={encode=Font.encode,print=Chrome.print,wrap=Chrome.wrap,textBox=TextBox.new}
  Font.__ulaPtbrGen2=patch
  Font.encode=function(text)
   return patch.encode(patch.active() and patch.localize(text) or text)
  end
  Chrome.wrap=function(text,...)
   return patch.wrap(patch.active() and patch.localize(text) or text,...)
  end
  TextBox.new=function(game,text,...)
   return patch.textBox(game,patch.active() and patch.localize(text) or text,...)
  end
 end
 patch.active,patch.localize=active,localize
 mod.exports.ptbrGen2={active=active}
end
