-- Language-neutral registry adapter for compiled retail EU catalogs.
return function(mod)
 local function catalog(name)
  local body=mod:read('lang/'..name..'.lua')
  return body and assert(loadstring(body,'@european/'..name))() or {}
 end
 local generation=require('src.core.GameVersion').generation()
 local data=assert(mod.game.data)
 for seq,code in pairs(catalog('charmap')) do mod.content.font:register('charmap:ula-european:'..seq,{seq=seq,code=code}) end
 if mod:info('assets/fonts/font.png') then
  mod.content.font:override('main',{image=mod.path..'/assets/fonts/font.png',base=0x80,glyphsPerRow=16})
 end
 local fontPages=catalog('font_pages')
 local tallGlyphs={}
 for id,page in pairs(fontPages.pages or {}) do
  mod.content.font:register('ula-asian-'..id,{image=mod.path..'/'..page.path,base=page.base,glyphsPerRow=16})
  for code=page.base,page.base+510,2 do tallGlyphs[code]=true end
 end
 if fontPages.kana then
  local page=fontPages.kana
  mod.content.font:register('ula-asian-kana',{image=mod.path..'/'..page.path,base=page.base,glyphsPerRow=16})
 end
 for id,page in pairs(fontPages.singlePages or {})do
  mod.content.font:register('ula-asian-single-'..id,{image=mod.path..'/'..page.path,base=page.base,glyphsPerRow=16})
 end
 if generation==1 then
  mod.content.font:register('font_battle_extra',{image=mod.path..'/assets/battle/font_battle_extra.png',base=0x62,glyphsPerRow=15})
 end
 local strings=catalog('strings')
 local function overrideText(cat,registry)
  for key,value in pairs(catalog(cat))do
   -- Resolve source strings from the user's imported base, rather than
   -- distributing a second cartridge's extracted dialogue in the profile.
   local source=cat=='dialogue' and generation==2 and data.gen2Text or data.text
   local original=source and source[key]
   if fontPages.lookupDialogue and type(original)=='string' and original~='' and not strings[original] then strings[original]=value end
   registry:override(key,value)
  end
 end
 overrideText('dialogue',mod.content.text)
 if generation==2 then overrideText('rom_text',mod.content.rom_text)end
 local identities=catalog('mon_names')
 local Names=mod.shared.monNames
 if generation==1 then
  mod.exports.identityCoverage={trades=Names.patchTrades(data.field and data.field.trades,identities.trades)}
 else
  mod.exports.identityCoverage=Names.patchGen2Data(data,identities)
 end
 local patterns={}
 local function escaped(value)return (value:gsub('([%^%$%(%)%%%.%[%]%*%+%-%?])','%%%1'))end
 local token='%%[-+ #0-9%.]*[a-zA-Z]'
 for source,target in pairs(strings) do
  if source:find('%%') and not source:find('%%%%') then
   local pieces,at,fields={},1,0
   while true do
    local first,last=source:find(token,at)
    if not first then pieces[#pieces+1]=escaped(source:sub(at));break end
    pieces[#pieces+1]=escaped(source:sub(at,first-1))
    pieces[#pieces+1]=source:sub(last,last)=='s' and '(.-)' or '([%s%+%-]*%d+%.?%d*)'
    fields=fields+1;at=last+1
   end
   local letters=source:gsub(token,''):gsub('[^A-Za-z]','')
   if fields>0 and #letters>=3 then patterns[#patterns+1]={source=source,pattern='^'..table.concat(pieces)..'$',target=target,fields=fields} end
  end
 end
 table.sort(patterns,function(a,b)if #a.source==#b.source then return a.source<b.source end;return #a.source>#b.source end)
 local localized,count={},0
 local function remember(source,target)
  if count>=4096 then localized={};count=0 end
  localized[source]=target;count=count+1;return target
 end
 local function localize(text)
  if type(text)~='string' then return text end
  if strings[text] then return strings[text] end
  if localized[text] then return localized[text] end
  for _,row in ipairs(patterns) do
   local captures={text:match(row.pattern)}
   if #captures==row.fields then
    local index=0
    local rendered=row.target:gsub('%%(%d+)%$[-+ #0-9%.]*[a-zA-Z]',function(position)return captures[tonumber(position)] or ''end)
    if rendered==row.target then rendered=row.target:gsub(token,function()index=index+1;return captures[index] end)end
    return remember(text,rendered)
   end
  end
  return remember(text,text)
 end
 mod.exports.localizeUi=localize
 for key,value in pairs(strings) do mod.content.strings:override(key,value) end
 local function names(cat,registry,records)
  for key,value in pairs(catalog(cat)) do
   if not records or records[key] then registry:patch(key,{name=value}) end
  end
 end
 names('species_names',mod.content.pokemon,data.pokemon)
 names('move_names',mod.content.moves,data.moves)
 names('item_names',mod.content.items,data.items)
 names(generation==1 and 'trainer_names' or 'trainer_class_names',mod.content.trainers)
 names('type_names',mod.content.type_chart,data.type_chart and data.type_chart.types)
 if generation==2 then names('landmark_names',mod.content.landmarks) end
 for key,value in pairs(catalog('status_labels')) do mod.content.statuses:patch(key,{label=value,hudLabel=value}) end
 for key,value in pairs(catalog('dex_kinds')) do if data.pokemon[key] then mod.content.pokemon:patch(key,{dexEntry={kind=value}}) end end
 if generation==1 then
  for key,value in pairs(catalog('dex_metrics')) do if data.pokemon[key] then mod.content.pokemon:patch(key,{dexEntry=value}) end end
 else
  for _,cat in ipairs({'move_descriptions','item_descriptions'}) do
   local records=cat=='move_descriptions' and data.moves or data.items
   for key,value in pairs(catalog(cat)) do if records[key] then records[key].description=value end end
  end
  for key,value in pairs(catalog('dex_entries')) do
   local entry=data.gen2Pokedex and data.gen2Pokedex.entries[key]
   if entry then for _,field in ipairs({'kind','text','text2'}) do entry[field]=value[field] end end
  end
  for key,value in pairs(catalog('dex_metrics')) do
   local entry=data.gen2Pokedex and data.gen2Pokedex.entries[key]
   if entry then entry.heightM=value.heightM;entry.weightKg=value.weightKg end
  end
  if mod.game.oakSpeechData and mod.game.oakSpeechData.text then
   local named=catalog('rom_text')
   for i=1,7 do local label='_OakText'..i;if named[label] then mod.game.oakSpeechData.text[label]=named[label] end end
  end
  for key,value in pairs(catalog('trainer_names')) do
   local cls,index=key:match('^(.-):(%d+)$')
   local group=data.gen2Trainers and data.gen2Trainers.classes[cls]
   local trainer=group and group.trainers[tonumber(index)]
   if trainer then trainer.name=value end
  end
  local nativeStrings=catalog('script_strings')
  mod.exports.identityCoverage.scriptFields=0
  for _,commands in pairs(data.gen2Scripts or {}) do
   if type(commands)=='table' then for _,cmd in ipairs(commands) do
    if type(cmd)=='table' then
     if cmd.op=='getstring' then cmd.string=nativeStrings[cmd.string] or strings[cmd.string] or cmd.string end
     if cmd.op=='givepoke' and tonumber(cmd.trainer or 0)~=0 then
      for _,field in ipairs({'name','otName'})do
       if nativeStrings[cmd[field]]then
        cmd[field]=nativeStrings[cmd[field]]
        mod.exports.identityCoverage.scriptFields=mod.exports.identityCoverage.scriptFields+1
       end
      end
     end
    end
   end end
  end
 end
 -- Immediate-mode GB menus pass their authored English strings straight to
 -- Font.encode. Resolve catalog keys and authored printf templates only while
 -- this mod bus is active; captured names and numeric values remain intact.
 do
  local accent={es={'Á','É','Í','Ó','Ú','Ñ','Ü','¿','¡'},fr={'à','è','é','ù','ç','ë','ï','ê','î'},it={'À','È','É','Ì','Ò','Ù','à','è','ì'}}
  local fontmap=catalog('charmap')
  mod.hooks:wrap('ui.naming.grid',function(next,base,ctx)
   local grid=next(base,ctx)
   if mod.language=='ko' or mod.language=='ja' then return grid end
   local out={};for i,row in ipairs(grid) do out[i]={};for j,c in ipairs(row) do out[i][j]=c end end
   local chars=accent[mod.language]
   -- Keep a font-based fallback for development callers without a language.
   if not chars then
    if fontmap['ç'] then chars=accent.fr elseif fontmap['ñ'] then chars=accent.es else chars=accent.it end
   end
   out[4]={};for i,c in ipairs(chars) do out[4][i]=ctx.lower and (({['Á']='á',['É']='é',['Í']='í',['Ó']='ó',['Ú']='ú',['Ñ']='ñ',['Ü']='ü',['À']='à',['È']='è',['Ì']='ì',['Ò']='ò',['Ù']='ù'})[c] or c:lower()) or c end
   return out
  end)
 end
 -- Authored names live in the save and must survive language switches.
 -- Only inspect these small collections when a fallback would change text.
 local function savedName(text)
  if #text>32 then return false end
  local save=mod.game.save
  if not save then return false end
  for _,person in ipairs({'player','rival','mom'})do
   local row=save[person]
   if type(row)=='table' and row.name==text then return true end
   if row==text then return true end
  end
  for _,name in pairs(save.boxNames or {})do if name==text then return true end end
  local function contains(rows)
   for _,mon in pairs(rows or {})do
    if type(mon)=='table' and (mon.nickname==text or mon.ot==text or mon.otName==text)then return true end
   end
  end
  if contains(save.party) or contains(save.box)then return true end
  for _,box in pairs(save.boxes or {})do if contains(box)then return true end end
  return false
 end
 local Font=require('src.render.Font')
 local Runtime=require('src.mods.Runtime')
 local version=require('src.core.GameVersion')
 local bus=Runtime.events
 local marker='__ula_european_active__'
 mod.content.strings:override(marker,'active')
 local patch=Font.__ulaEuropeanStrings
 if not patch then
  patch={original=Font.encode,split=Font.split,drawCode=Font.drawCode};Font.__ulaEuropeanStrings=patch
  Font.split=function(text)
   local spans=patch.split(text)
   if patch.active and patch.active() and type(text)=='string' then
    for _,span in ipairs(spans) do
     local code=patch.fontmap[text:sub(span.from,span.to)]
     if code then span.code=code end
    end
   end
   return spans
  end
  Font.encode=function(text)
   if patch.active and patch.active() and type(text)=='string' then
    local translated=patch.localize(text)
    if translated~=text and not patch.savedName(text)then text=translated end
   end
   return patch.original(text)
  end
 end
 if not patch.asianDrawInstalled then
  patch.drawCode=Font.drawCode
  Font.drawCode=function(code,x,y)
   if patch.active and patch.active() and patch.tallGlyphs[code] then
    patch.drawCode(code,x,y-8);patch.drawCode(code+1,x,y)
   elseif patch.active and patch.active() and patch.composite[code] then
    local glyph=patch.composite[code]
    patch.drawCode(glyph.base,x,y);patch.drawCode(glyph.mark,x,y-8)
   else patch.drawCode(code,x,y) end
  end
  patch.asianDrawInstalled=true
 end
 patch.active=function() return Runtime.events==bus and version.get()==mod.edition and data.strings and data.strings[marker]=='active' end
 patch.strings=strings;patch.localize=localize;patch.fontmap=catalog('charmap');patch.savedName=savedName
 patch.tallGlyphs=tallGlyphs
 patch.composite=fontPages.composite or {}
 if generation==1 and identities.tradeOT then
  local TradeAnim=require('src.ui.TradeAnim')
  if not TradeAnim.__ulaNpcIdentity then
   TradeAnim.__ulaNpcIdentity=TradeAnim.new
   TradeAnim.new=function(game,opts)
    if patch.active and patch.active() and not game.linkSession and opts
        and opts.enemyName=='TRAINER' and opts.received and opts.sent
        and opts.received.ot=='TRAINER' and opts.received.traded then
     for _,row in ipairs(patch.data.field.trades)do
      if row.give==opts.sent.species and row.get==opts.received.species
          and row.nickname==opts.received.nickname then
       opts.received.ot=patch.tradeOT.to;opts.enemyName=patch.tradeOT.to;break
      end
     end
    end
    return TradeAnim.__ulaNpcIdentity(game,opts)
   end
  end
  patch.data=data;patch.tradeOT=identities.tradeOT
 end
 if generation==2 then
  mod.exports.identityCoverage.specials=Names.installGen2Specials(require('src.script.gen2.Specials'),identities,patch.active)
  -- Radio's own data view uses species strings as lookup keys and display
  -- values. Localize that view together with its inverse caught/dex lookups;
  -- canonical world, encounter and save identifiers stay untouched.
  local Gear=require('src.ui.gen2.Pokegear')
  if not Gear.__ulaRadioData then
   Gear.__ulaRadioData=Gear.radioData
   Gear.radioData=function(self)
    local source=Gear.__ulaRadioData(self)
    if not patch.active or not patch.active()then return source end
    if self.__ulaRadioSource==source then return self.__ulaRadioLocalized end
    local out,inverse={},{}
    for k,v in pairs(source)do out[k]=v end
    local function display(id)
     local row=patch.data.pokemon[id];local name=row and row.name or id
     inverse[name]=id;return name
    end
    out.species={};for i,id in pairs(source.species or {})do out.species[i]=display(id)end
    out.dex={};for id,row in pairs(source.dex or {})do out.dex[display(id)]=row end
    out.grass={}
    for id,times in pairs(source.grass or {})do
     out.grass[id]={}
     for time,slots in pairs(times)do
      local list={};out.grass[id][time]=list
      for i,species in pairs(slots)do list[i]=display(species)end
     end
    end
    out.caught=function(name)return source.caught(inverse[name] or name)end
    self.__ulaRadioSource=source;self.__ulaRadioLocalized=out
    return out
   end
  end
  patch.data=data
  if mod.language=='ja' or mod.language=='ko' then
   mod.shared.asianArguments(mod,catalog('text_arguments'),patch.active)
  end
 end
end
