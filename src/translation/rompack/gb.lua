-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Translate display leaves only. Host identifiers remain stable: this fork
-- names a species SPECIES_001 and a script text TEXT_Sxx_xxxx.
local A={}
-- End-of-prose opcodes from a language cartridge are not textbox glyphs.
-- The US host still owns script flow, including waits and closing the box.
local function clean(s)return (s:gsub('\\u000[bB]','\v'):gsub('\\u000[cC]','\f'):gsub('{DONE}',''):gsub('{PROMPT}',''))end
function A.description(s)
 if type(s)~='string'then return s end
 return (clean(s):gsub('<NEXT>','\n'):gsub('<LINE>','\n'):gsub('<PARA>','\f'))
end
local function slug(s)
 return (tostring(s):upper():gsub('♀','_F'):gsub('♂','_M'):gsub('[%.\x27]',''):gsub('[^A-Z0-9]+','_'):gsub('_+$',''))
end
function A.apply(data,c,symbols,textAdapter)
 local report={dialogue=0,species=0,moves=0,items=0,trainers=0,strings=0,dex=0}
 local function address(bank,addr)return ('%02x:%04x'):format(bank,addr)end
 local byAddress={}
 local aliases={}
 local function source(s)return (s:gsub('\\u000[bB]','\v'):gsub('\\u000[cC]','\f'):gsub('[\r\n\v\f]+',' '):gsub('%s+',' '):gsub('^%s+',''):gsub('%s+$',''))end
 local function remember(original,target)
  local key=source(original)
  if aliases[key]==nil then aliases[key]=target elseif aliases[key]~=target then aliases[key]=false end
 end
 local originals={};for key,value in pairs(data.text or {})do if type(value)=='string'then originals[key]=value end end
 for key,value in pairs(c.dialogue or {})do byAddress[key:lower()]=value end
 for key,original in pairs(data.text or {})do
  local value=(c.dialogue or {})[key] or (c.rom_text or {})[key]
  local b,a=key:match('^TEXT_S(%x+)_(%x+)$')
  if b then value=byAddress[address(tonumber(b,16),tonumber(a,16))] or value end
  local sym=symbols and symbols[key]
  if sym then value=byAddress[address(sym[1],sym[2])] or value end
  if type(value)=='string' then
   value=clean(value)
   if textAdapter then value=textAdapter.rebind(value,original,(c.text_arguments or{})[key])end
   remember(original,value);data.text[key]=value;report.dialogue=report.dialogue+1
  end
 end
 data.strings=data.strings or {}
 for key,value in pairs(c.strings or {})do if type(value)=='string'then value=clean(value);remember(key,value);data.strings[key]=value;report.strings=report.strings+1 end end
 for _,name in ipairs({'runtime_ui','runtime_system','runtime_battle'})do
  for key,value in pairs(c[name] or {})do if type(key)=='string' and type(value)=='string'then value=clean(value);remember(key,value);data.strings[key]=value end end
 end
 for key,original in pairs(originals)do
  local translated=aliases[source(original)]
  if translated and data.text[key]==original then data.text[key]=translated;report.dialogue=report.dialogue+1 end
 end
 local function names(registry,cat,kind,extra)
  local aliases={};for key,value in pairs(c[cat] or {})do
   local normalized=slug(key):gsub('_','')
   if aliases[normalized]==nil then aliases[normalized]=value elseif aliases[normalized]~=value then aliases[normalized]=false end
  end
  for id,row in pairs(data[registry] or {})do if type(row)=='table'then
   local key=extra and extra(id,row) or id
   local value=(c[cat] or {})[key] or (c[cat] or {})[slug(row.name)] or aliases[slug(key):gsub('_','')] or aliases[slug(row.name):gsub('_','')]
   if value then row.translationSourceName=row.name;row.name=value;report[kind]=report[kind]+1 end
  end end
 end
 -- Resolve names before changing the English source name.
 local speciesKeys={}
 for id,row in pairs(data.pokemon or {})do speciesKeys[id]=slug(row.name)end
 names('pokemon','species_names','species',function(id)return speciesKeys[id]end)
 names('moves','move_names','moves')
 names('items','item_names','items',function(id,row)return row.key or id end)
 names('trainers','trainer_class_names','trainers',function(id)return id:gsub('^OPP_','')end)
 for _,row in pairs(data.moves or {})do row.description=A.description((c.move_descriptions or {})[row.id])or row.description end
 for id,row in pairs(data.items or {})do row.description=A.description((c.item_descriptions or {})[row.key or id])or row.description end
 for id,row in pairs(data.pokemon or {})do
  local dex=(c.dex_entries or {})[speciesKeys[id]]
  if not dex then for key,value in pairs(c.dex_entries or {})do if slug(key):gsub('_','')==speciesKeys[id]:gsub('_','')then dex=value;break end end end
  if dex and row.dexEntry then
   row.dexEntry.kind=dex.kind or row.dexEntry.kind
   local text=table.concat({dex.text or '',dex.text2 or ''},'\f'):gsub('<NEXT>','\n'):gsub('\f$','')
   if text~='' then
    local key='_ULA_DEX_'..id;data.text[key]=text;row.dexEntry.text=key
   end
   -- Existing imperial values are also read by Heavy Ball mechanics.
   row.dexEntry.heightM=dex.height and dex.height/10 or nil
   row.dexEntry.weightKg=dex.weight and dex.weight/10 or nil
   report.dex=report.dex+1
  end
  if row.dexEntry then
   row.dexEntry.kind=(c.dex_kinds or{})[speciesKeys[id]]or row.dexEntry.kind
   local metrics=(c.dex_metrics or{})[speciesKeys[id]]
   if metrics then row.dexEntry.heightM=metrics.heightM;row.dexEntry.weightKg=metrics.weightKg end
  end
 end
 for id,row in pairs(data.statuses or{})do
  local label=(c.status_labels or{})[id]
  if label then row.label=label;row.hudLabel=label;data.strings[id]=label end
 end
 local field=data.field or {}
 local function displayLeaves(row)
  for key,value in pairs(row or{})do
   if type(value)=='string'then row[key]=aliases[source(value)]or data.strings[value]or value
   elseif type(value)=='table'then displayLeaves(value)end
  end
 end
 displayLeaves(field.egg and field.egg.hatchText)
 displayLeaves(field.gen2Trades and field.gen2Trades.texts)
 if c.credits and field.credits and c.credits.screens then field.credits.screens=c.credits.screens end
 for key,name in pairs(c.trainer_names or{})do
  local class,index=key:match('^(.-):(%d+)$')
  local row=class and(data.trainers['OPP_'..class]or data.trainers[class])
  if row and row.partyNames then row.partyNames[tonumber(index)]=name end
 end
 -- Separate display copies used by the fork's script and NPC trade runners.
 local nativeStrings=c.script_strings or{}
 for _,commands in pairs(data.map_scripts and data.map_scripts.scripts or{})do
  for _,cmd in ipairs(commands)do if cmd[1]=='getstring'then cmd[2]=nativeStrings[cmd[2]]or cmd[2]end end
 end
 for _,commands in pairs(data.scripts or{})do if type(commands)=='table'then
  for _,cmd in ipairs(commands.commands or commands)do if type(cmd)=='table'then
   if cmd.op=='getstring'then cmd.string=nativeStrings[cmd.string]or cmd.string end
   if cmd.op=='givepoke'and tonumber(cmd.trainer or 0)~=0 then
    for _,key in ipairs({'name','otName'})do cmd[key]=nativeStrings[cmd[key]]or cmd[key]end
   end
  end end
 end end
 local trades=field.gen2Trades and field.gen2Trades.trades or field.trades
 for index,fields in pairs(c.mon_names and c.mon_names.trades or{})do
  local row=trades and trades[tonumber(index)or index]
  if row then for _,key in ipairs({'nickname','otName'})do
   local spec=fields[key]
   if type(spec)=='table'and row[key]==spec.from then row[key]=spec.to end
  end end
 end
 for _,row in pairs(data.type_chart and data.type_chart.types or {})do
  local translated=(c.type_names or {})[row.id] or (c.type_names or {})[slug(row.name)]
  if translated then data.strings[row.name]=translated end
 end
 for id,row in pairs(field.townMap and field.townMap.landmarks or {})do
  row.name=(c.landmark_names or {})[id] or (c.landmark_names or {})['LANDMARK_'..slug(row.name)] or (c.landmark_names or {})[slug(row.name)] or row.name
 end
 local gear=c.pokegear_radio_tilemap;local radio=field.pokegear and field.pokegear.cards and field.pokegear.cards.radio
 if gear and radio then for _,cell in ipairs(gear.cells or {})do radio[cell.y*(gear.width or 20)+cell.x+1]=cell.tile end end
 return report
end
return A
