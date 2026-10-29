-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Compile complete display catalogs and native assets without replacing the
-- fork's scripts, mechanics, save structures or stable record identifiers.
local G={}
function G.compile(mod,entry,own,data)
 local p=own(entry.profile);local info=assert(mod.imports:info(entry.sourceId or entry.id))
 assert(p.md5==info.md5 and p.sha1==info.sha1 and p.size==info.size,'ROM/profile mismatch')
 local baseInfo=assert(mod.imports:info(entry.game..'_en'),'Add the exact English USA 1.0 base ROM in the language menu once for full GBA localization')
 local english=assert(mod.imports:read(entry.game..'_en',0,baseInfo.size))
 local function hash(s)return love.data.encode('string','hex',love.data.hash('sha256',s))end
 local paths={'@host/gba.lua','@host/gba_dex.lua','@host/type_badges.lua','@host/gba_catalogs.lua','@host/gba_text.lua','@host/gba_world.lua','@host/gba_resources.lua','@host/gba_relocate.lua','@host/gba_battle.lua','@host/addresses/'..entry.game..'.lua','@host/addresses/'..entry.game..'_assets.lua','@host/addresses/'..entry.game..'_world.lua',entry.profile,entry.assets,entry.world,'compiler.lua','cache_codec.lua','gba/ui.lua','vendor/src/core/game3/scripting/text_ir.lua'}
 if entry.glyphsPath then paths[#paths+1]=entry.glyphsPath end
 if entry.authored then paths[#paths+1]=entry.authored end
 if entry.language=='pt-BR'then for _,path in ipairs({'@host/ptbr_graphics.lua','ptbr_pixel_labels.lua','ptbr_world_graphics.lua','ptbr_credits.lua','ptbr_scene_authored.lua','ptbr_easy_chat_words.lua','ptbr_items.lua','ptbr_item_descriptions.lua','ptbr_moves.lua','ptbr_move_descriptions.lua','ptbr_abilities.lua','ptbr_ability_descriptions.lua','ptbr_classes.lua','ptbr_types.lua'})do paths[#paths+1]=path end end
 local recipe={'native-rompack-gba-v1',mod.languageRecipe,entry.game,entry.language,p.sha1,baseInfo.sha1,hash(assert(love.filesystem.read('src/import/RomExtractorGen3.lua')))}
 for _,path in ipairs(paths)do recipe[#recipe+1]=path..':'..hash(assert(mod:read(path)))end
 for _,path in ipairs({'src/import/RomGba.lua','src/import/ImageWriter.lua'})do recipe[#recipe+1]=path..':'..hash(assert(love.filesystem.read(path)))end
 recipe[#recipe+1]=hash(assert(love.filesystem.read(require('src.core.GameVersion').info().manifest)))
 recipe[#recipe+1]=hash(require('src.core.SaveSerializer').encode(data.text))
 local key=hash(table.concat(recipe,'\n'))
 local proxy=setmetatable({content={strings={override=function()end}}},{__index=mod})
 local files,report=own('compiler.lua')(proxy,key,function()
  local bytes=assert(mod.imports:read(entry.sourceId or entry.id,0,info.size))
  -- Private GPL decoder: no shared charmap/provider mutation in either host.
  local IR=assert(loadstring(assert(mod:read('vendor/src/core/game3/scripting/text_ir.lua'))))()
  local originalIR=assert(loadstring(assert(mod:read('vendor/src/core/game3/scripting/text_ir.lua'))))()
  local T=own('@host/gba_text.lua');local dialect=(entry.game=='ruby'or entry.game=='sapphire')and'rs'or entry.game=='emerald'and'rse'or'frlg'
  local glyphs=entry.glyphsPath and own(entry.glyphsPath,entry.language)or entry.glyphs or{}
  for code,glyph in pairs(glyphs)do IR.CHARMAP[code]=glyph end
  for code,glyph in pairs(p.decodeGlyphs or{})do IR.CHARMAP[code]=glyph end
  local function decode(off,battle,limit,fragment,slots)
   assert(off>=0 and off<#bytes,'Text address outside source')
   local ir=IR.decode(bytes:sub(off+1,math.min(#bytes,off+(limit or 16384))),{dialect=dialect,battle=battle or nil})
   assert(fragment or ir[#ir]and ir[#ir].t=='eos','Unterminated localized text '..off)
   return T.plain(ir,entry.game,slots)
  end
  local function name(off,limit)return decode(off,false,limit)end
  local function pointer(off)
   local a,b,c,d=bytes:byte(off+1,off+4);assert(d,'Truncated pointer')
   local n=a+b*256+c*65536+d*16777216-0x08000000
   if n>=0 and n<#bytes then return n end
  end
  local c={dialogue={},named={},pairs={},strings=own('gba/ui.lua')[entry.language]or{},pokemon={},moves={},items={},trainers={},abilities={},classes={},types={},gender={}}
  local units={de={'GR.','GEW.'},es={'ALT.','PESO'},fr={'TAI.','PDS.'},it={'ALT.','PESO'},['pt-BR']={'ALT.','PESO'}}
  local unit=units[entry.language];if unit then c.strings.HT=unit[1];c.strings.WT=unit[2]end
  local addresses=own('@host/addresses/'..entry.game..'.lua');local count=0;local sourceFor,targetFor={},{}
  local keys={};for label in pairs(p.texts)do keys[#keys+1]=label end;table.sort(keys)
  for _,label in ipairs(keys)do
   local row=p.texts[label];local off=addresses[label]
   local raw=label:match('^g3:(%x+)$');if raw then off=tonumber(raw,16)-0x08000000 end
   local nativeId=off and ('TEXT_%06X'):format(off)
   local namedText=label:match('^gStatNamesTable%[%d+%]$')or label:match('^gContestEffectDescriptionPointers%[%d+%]$')or label:match('Text_')or label:match('_Text')or label:match('^Text_')or label:match('Names%[')or label:match('NamePointers%[')or label:match('EasyChatGroupName_')
   local memo=label:find('PokeSum_',1,true)or label:find('XNature',1,true)
   local memoSlots=memo and((entry.game=='firered'or entry.game=='leafgreen')and{[0]='NATURE',[1]='LEVEL',[2]='LOCATION'}or{[0]='',[1]='',[2]='NATURE',[3]='LEVEL',[4]='LOCATION',[5]=''})
   local relevant=namedText or nativeId and data.text[nativeId]~=nil
   local text
   if relevant and row[3]and row[3]:match('^braille')then
    local authored=entry.authored and own(entry.authored)[label]
    if authored then text=T.plain(authored.target,entry.game)
    else text=T.braille(bytes:sub(row[1]+1,row[1]+4096),row[3]=='braille'and 0 or 6)end
   elseif relevant then
    local bare=p.texts[label:match('([^:]+)$')or label]
    local ok,value=pcall(decode,row[1],row[2]or bare and bare[2],row[4],row[3]=='fragment',memoSlots)
    -- The address census also includes non-text objects (e.g. font widths).
    -- Reject them as decoder probes, just as the host's text census does.
    if ok then text=value end
   end
   if text then
    if namedText then c.named[label]=text end
    if off and off>=0 and off<#english and (namedText or relevant)then
     local bare=p.texts[label:match('([^:]+)$')or label]
     local ok,source=pcall(originalIR.decode,english:sub(off+1,math.min(#english,off+(row[4]or 4096))),{dialect=dialect,battle=row[2]or bare and bare[2]or nil})
     if ok and source[#source]and source[#source].t=='eos'then
      source=T.plain(source,entry.game,memoSlots)
      if #source<8192 and #text<8192 and source~=''then
       sourceFor[label]=source;targetFor[label]=text
      end
     end
    end
    if off and off>=0 and off<16*1024*1024 then
     local id=('TEXT_%06X'):format(off)
     if c.dialogue[id]==nil then c.dialogue[id]=text;count=count+1 end
    end
   end
  end
  if entry.authored then for label,row in pairs(own(entry.authored))do
   local text=T.plain(row.target,entry.game);c.named[label]=text
   targetFor[label]=text
   if addresses[label]then c.dialogue[('TEXT_%06X'):format(addresses[label])]=text end
  end end
  -- Authored corrections must reach embedded menu/scene copies as well as
  -- pointer-keyed dialogue. Resolve ambiguity after all corrections exist.
  for label,source in pairs(sourceFor)do
   local text=targetFor[label]
   if c.pairs[source]==nil then c.pairs[source]=text elseif c.pairs[source]~=text then c.pairs[source]=false end
  end
  for code,choices in pairs(p.genderPlaceholders or{})do
   c.gender[code]={male=decode(choices.male,false,64),female=decode(choices.female,false,64)}
  end
  local F=p.fields
  local function records(target,base,stride,count,nameOffset,limit,descriptionOffset)
   if not base then return end
   for index=0,count-1 do
    local row={name=name(base+index*stride+(nameOffset or 0),limit or stride)}
    if descriptionOffset then local ptr=pointer(base+index*stride+descriptionOffset);if ptr then row.description=decode(ptr,false,4096)end end
    c[target][index]=row
   end
  end
  records('pokemon',F.SPECIES_NAMES,F.SPECIES_NAME_LENGTH,F.NUM_SPECIES)
  records('moves',F.MOVE_NAMES,(F.MOVE_NAME_LENGTH or 12)+1,355)
  records('items',F.ITEMS,F.ITEM_STRIDE,F.ITEMS_COUNT,0,F.ITEM_NAME_LENGTH or 14,F.ITEM_DESCRIPTION_OFFSET or 20)
  records('trainers',F.TRAINERS_TABLE,F.TRAINER_STRIDE,F.TRAINERS_COUNT,4,12)
  records('abilities',F.ABILITY_NAMES,(F.ABILITY_NAME_LENGTH or 12)+1,F.ABILITIES_COUNT or 0)
  records('classes',F.TRAINER_CLASS_NAMES,F.TRAINER_CLASS_NAME_STRIDE,F.TRAINER_CLASS_COUNT or 0)
  records('types',F.TYPE_NAMES,(F.TYPE_NAME_LENGTH or 6)+1,F.TYPE_COUNT or 18)
  for index=0,17 do if c.named['gTypeNames['..index..']']then c.types[index]={name=c.named['gTypeNames['..index..']']}end end
  for index,row in pairs(c.moves)do if index>0 and F.MOVE_DESCRIPTIONS then local ptr=pointer(F.MOVE_DESCRIPTIONS+(index-1)*4);if ptr then row.description=decode(ptr,false,2048)end end end
  for index,row in pairs(c.abilities)do if F.ABILITY_DESCRIPTIONS then local ptr=pointer(F.ABILITY_DESCRIPTIONS+index*4);if ptr then row.description=decode(ptr,false,2048)end end end
  c.dex=own('@host/gba_dex.lua').read(F,pointer,name,decode)
  if entry.language=='pt-BR'then
   c.sceneAuthored=own('ptbr_scene_authored.lua')
   local names=own('ptbr_items.lua');local descriptions=own('ptbr_item_descriptions.lua')
   for id,row in pairs(c.items)do row.name=names[id]or row.name;row.description=descriptions[id]or row.description end
   for id,row in pairs(c.moves)do row.name=own('ptbr_moves.lua')[id]or row.name;row.description=own('ptbr_move_descriptions.lua')[id]or row.description end
   for id,row in pairs(c.abilities)do row.name=own('ptbr_abilities.lua')[id]or row.name;row.description=own('ptbr_ability_descriptions.lua')[id]or row.description end
   for id,row in pairs(own('ptbr_classes.lua')[entry.game])do c.classes[id]={name=row.target}end
   for id,name in pairs(own('ptbr_types.lua'))do c.types[id]={name=name}end
   for source,target in pairs(own('ptbr_credits.lua')(nil,entry.game,true))do c.strings[source]=target end
   c.strings['POKéMON EMERALD VERSION']='POKÉMON VERSÃO ESMERALDA'
  end
  local resources=own('@host/gba_resources.lua')(mod,entry,own,bytes,english)
  if entry.game=='emerald'then
   local badges=own('@host/type_badges.lua')
   local payload,spec=badges.compile(require('src.import.RomGba').new(bytes),own(entry.assets).symbols.off)
   resources.files[badges.path]=payload
   resources.tables.constants.gen3Summary.typeBadges=spec
  end
  if entry.language=='pt-BR'then resources.report.authoredPixelLabels=own('@host/ptbr_graphics.lua')(resources.files,entry.game,own,resources.tables.scenes)end
  local menuRow=p.texts.gText_BattleMenu
  if menuRow then c.battleMenu=own('@host/gba_battle.lua').menu(IR.decode(bytes:sub(menuRow[1]+1,menuRow[1]+256),{dialect=dialect}),T)end
  c.font=resources.tables.font;c.scenes=resources.tables.scenes;c.easyChat=resources.easyChat
  c.visual={}
  -- Transfer only render resources from the private decoder. Its regenerated
  -- gameplay tables, flags and trainer indices are deliberately not applied.
  for key,row in pairs(resources.tables.constants or{})do
   local render={}
   if type(row)=='table'then for _,field in ipairs({'images','pageArt','hearts','pagination','typeBadges'})do if row[field]then render[field]=row[field]end end end
   if next(render)then c.visual[key]=render end
  end
  local world=own('@host/gba_world.lua')
  c.world=world.compile(own,entry,bytes,english)
  if entry.language=='pt-BR'and entry.game=='emerald'then
   resources.report.authoredShopSigns=world.shopSigns(c.world,own('@host/addresses/emerald_world.lua'),data,english,own('ptbr_world_graphics.lua')(nil,'emerald',true))
  end
  local W=require('src.core.SaveSerializer');local out=resources.files
  out['lang/gba.lua']=W.encode(c)
  print('ULA_GBA_CATALOG_BYTES',entry.game,#out['lang/gba.lua'])
  return {files=out,report={dialogue=count,assets=resources.report.images,resources=resources.report,language=entry.language},operations={{registry='strings',method='override',key='__rom_language_source_gb__',value='active'}}}
 end)
 local c=assert(require('src.core.SaveSerializer').decode(files['lang/gba.lua'],{maxBytes=32*1024*1024,maxNodes=1000000,maxDepth=40}))
 return {files=files,catalogs=c,report=report,key=key,profile=p,english=english,language=entry.language}
end
function G.apply(data,c,own,compiled)
 local report={dialogue=0,pokemon=0,moves=0,items=0,trainers=0,strings=0,dex=0,abilities=0,world=0}
 local T=own('@host/gba_text.lua');local aliases,originals={},{}
 local function remember(a,b)
  if type(a)~='string'or type(b)~='string'or a==''then return end
  local key=T.source(a)
  if aliases[key]==nil then aliases[key]=b elseif aliases[key]~=b then aliases[key]=false end
 end
 for source,target in pairs(c.pairs)do if target then remember(source,target)end end
 for id,s in pairs(c.dialogue)do if type(data.text[id])=='string'then remember(data.text[id],s);report.dialogue=report.dialogue+1 end end
 for id,s in pairs(data.text)do originals[id]=s end
 for id,s in pairs(originals)do data.text[id]=c.dialogue[id]or aliases[T.source(s)]or s end
 data.strings=data.strings or{}
 for _,registry in ipairs({'pokemon','moves','items','trainers'})do
  for _,row in pairs(data[registry]or{})do
   local translated=c[registry][row.index]
   if translated then
    if not(compiled.language=='pt-BR'and registry=='pokemon')then remember(row.name,translated.name);row.translationSourceName=row.name;row.name=translated.name end
    remember(row.description,translated.description);row.description=translated.description or row.description
    if registry=='moves'and row.contestEffect~=nil then row.contestDescription=c.named['gContestEffectDescriptionPointers['..row.contestEffect..']']or row.contestDescription end
    report[registry]=report[registry]+1
   end
   if registry=='pokemon'then local d=c.dex[row.dex];if d then
    local text=d.text and(d.text..(d.text2 and'\f'..d.text2 or''))
    remember(row.category,d.category);remember(row.dexEntry,text);row.category=d.category;row.dexEntry=text or row.dexEntry;report.dex=report.dex+1
   end end
  end
 end
 for _,row in pairs(data.constants.abilities or{})do
  local translated=c.abilities[row.index]
  if translated then remember(row.name,translated.name);remember(row.description,translated.description);row.name=translated.name;row.description=translated.description or row.description;report.abilities=report.abilities+1 end
 end
 for id,row in pairs(data.type_chart.types or{})do
  local n=row.index or tonumber(id);local translated=c.types[n]
  if translated then remember(row.name,translated.name)end
 end
 for source,target in pairs(c.strings)do remember(source,target)end
 remember('NONE',c.named.gText_None or c.named.gText_PokeSum_Item_None)
 remember('TYPE/',c.named.gText_TypeSlash)
 for id,label in pairs({COOL='gText_Cool',BEAUTY='gText_Beauty',CUTE='gText_Cute',SMART='gText_Smart',TOUGH='gText_Tough'})do remember(id,c.named[label])end
 -- Host-only close-row explanation has no cartridge text identifier.
 local close={de='Beutel schließen.',es='Cerrar la MOCHILA.',fr='Fermer le SAC.',it='Chiudi lo ZAINO.',['pt-BR']='Fechar a MOCHILA.'}
 remember('Close the BAG.',close[compiled.language])
 -- Only substitute exact known display strings; table keys, IDs, booleans,
 -- numeric gameplay fields and paths are never translated by this walk.
 local textKeys={name=true,label=true,description=true,descriptions=true,describe=true,text=true,texts=true,labels=true,names=true,prompt=true,prompts=true,message=true,messages=true,caption=true,heading=true,headings=true,title=true,help=true,cancelLabel=true,hatchText=true}
 for _,key in ipairs({'body','question','answer','intro','footer','dialogue','greeting','farewell'})do textKeys[key]=true end
 local protected={name=true,id=true,key=true,op=true,kind=true,mode=true,source=true,path=true,image=true,png=true,symbol=true,window=true}
 local function translated(value)
  local text=aliases[T.source(value)]
  if not text and c.sceneAuthored then
   local encoded=require('src.import.LuaWriter').encode(value)
   local key=love.data.encode('string','hex',love.data.hash('sha256',encoded))
   local row=c.sceneAuthored[key]
   if row and type(row.target)=='string'then text=row.target end
  end
  return text or value
 end
 local function display(t,inText,seen)
  seen=seen or{};if seen[t]then return end;seen[t]=true
  for k,v in pairs(t)do
   local text=inText or textKeys[k]
   if not protected[k]then
    if type(v)=='string'and text then t[k]=translated(v)elseif type(v)=='table'then display(v,text,seen)end
   end
  end
 end
 -- Easy Chat is translated below by stable group/word identity. Its English
 -- labels must remain intact until the authored vocabulary has been resolved.
 for _,key in ipairs({'gen3Screens','gen3FRLGSummary','gen3FRLGPokedex','gen3FRLGRegionMap','gen3FRLGStorage','gen3FRLGNaming','gen3EmeraldNaming','gen3StartMenu','gen3Bag','gen3BagScreen','gen3ItemMenu','gen3ShopMenu','gen3BuyMenu','gen3PCMenu','gen3Options','gen3Multichoice','gen3Daycare','gen3Summary','gen3Pokenav','gen3Keyboard','gen3HallOfFame'})do
  local row=data.constants[key];if type(row)=='table'then display(row,false)end
 end
 if data.constants.gen3Summary then
  for key,value in pairs(data.constants.gen3Summary)do if type(value)=='string'and key~='source'and key~='artSource'then data.constants.gen3Summary[key]=aliases[T.source(value)]or value end end
  for _,key in ipairs({'words','stats','pages'})do display(data.constants.gen3Summary[key]or{},true)end
  local stats=data.constants.gen3Summary.stats
  if stats then for i,label in ipairs({'gText_Attack3','gText_Defense3','gText_SpAtk4','gText_SpDef4','gText_Speed2','gText_HP3'})do stats[i]=c.named[label]or stats[i]end end
 end
 if data.constants.gen3Screens then for _,screen in pairs(data.constants.gen3Screens)do if type(screen)=='table'and type(screen.items)=='table'then display(screen.items,true)end end end
 for _,key in ipairs({'gen3BattleMenu','gen3FRLGStorage','gen3StorageMenu'})do
  local row=data.constants[key];if row and row.rows then for k,v in pairs(row.rows)do if type(v)=='string'then row.rows[k]=aliases[T.source(v)]or v elseif type(v)=='table'then for i,s in pairs(v)do if type(i)=='number'and type(s)=='string'then v[i]=aliases[T.source(s)]or s end end end end end
 end
 for id,name in pairs(data.constants.trainerClasses or{})do local row=c.classes[id];if row then data.constants.trainerClasses[id]=row.name end end
 for _,row in pairs(data.constants.natures or{})do
  row.name=c.named['gNatureNamePointers['..row.index..']']or c.named['gNatureNames['..row.index..']']or row.name
 end
 own('@host/memo.lua').apply(data,c.named,compiled.profile.game)
 local memo=data.constants.gen3Memo
 if memo then
  for key,value in pairs(memo.templates or{})do memo.templates[key]=aliases[T.source(value)]or value end
  for key,value in pairs(memo.eggs or{})do memo.eggs[key]=aliases[T.source(value)]or value end
  if (compiled.profile.game=='firered'or compiled.profile.game=='leafgreen')and c.named.gText_PokeSum_Met then
   memo.templates.bare=c.named.gText_PokeSum_Met:match('^[^\n]*')
  elseif compiled.profile.game=='emerald'then
   local labels={bare='gText_XNature',met='gText_XNatureMetAtYZ',metSomewhere='gText_XNatureMetSomewhereAt',hatched='gText_XNatureHatchedAtYZ',hatchedSomewhere='gText_XNatureHatchedSomewhereAt',trade='gText_XNatureObtainedInTrade',probablyMet='gText_XNatureProbablyMetAt',fateful='gText_XNatureFatefulEncounter'}
   for key,label in pairs(labels)do memo.templates[key]=c.named[label]or memo.templates[key]end
  end
 end
 for id,name in pairs(data.constants.gen3MapSections or{})do data.constants.gen3MapSections[id]=aliases[T.source(name)]or name end
 display(data.landmarks or{},false);display(data.mapSections or{},false)
 for _,key in ipairs({'gen3Credits','gen3TradeText','gen3FrontierSpeech','gen3PokedexMenu','gen3StoragePanels','gen3HallOfFame','gen3PartyChoice','gen3FrontierDesk','gen3QuizLady','gen3FavorLady','gen3Storyteller'})do
  display(data.constants[key]or{},false)
 end
 for _,key in ipairs({'gen3Help','gen3HelpSystem','gen3FameChecker','gen3FrontierPass','gen3Decorations','gen3Contests','gen3Pokeblocks','gen3Roulette','gen3Daycare','gen3Trade'})do display(data.constants[key]or{},false)end
 local headers=data.constants.gen3Pokenav and data.constants.gen3Pokenav.matchCall and data.constants.gen3Pokenav.matchCall.headers
 for _,row in ipairs(headers or{})do if type(row.name)=='string'then row.name=translated(row.name)end end
 report.easyChat=own('@host/gba_catalogs.lua').easyChat(data,c.easyChat,compiled.language,own)
 for source,target in pairs(aliases)do if target then data.strings[source]=target;report.strings=report.strings+1 end end
 for source,target in pairs(c.strings)do data.strings[source]=target end
 if c.font then data.font=c.font end
 for key,render in pairs(c.visual or{})do
  if data.constants[key]then for field,value in pairs(render)do data.constants[key][field]=value end end
 end
 if c.scenes then for id,scene in pairs(c.scenes)do data.scenes[id]=scene end end
 report.world=own('@host/gba_world.lua').apply(data,c.world,compiled.english)
 own('@host/gba_battle.lua').apply(data,c,T)
 return report
end
return G
