local function L(value) return require('src.translation.Service').launcherLookup(value) end
-- Shared native prize editor for Account staff tools and tournament setup.
local D={}
local S=require('src.core.SaveSerializer')
local V=require('src.core.GameVersion')
local fields={ot='giftOT',tid='giftTID',sid='giftSID',nickname='giftNickname',nature='giftNature',gender='giftGender',
 ability_slot='giftAbility',pid='giftPID',held_item='giftHeld',ball='giftBall',friendship='giftFriendship',met_level='giftMetLevel',met_location='giftMetLocation',language='giftLanguage'}
local stats={'hp','attack','defense','speed','spatk','spdef'}
local function pack(values,order) if not values then return '' end;local out={};for _,k in ipairs(order) do out[#out+1]=tostring(values[k] or 0) end;return table.concat(out,', ') end
function D.init(f,reward)
 local r=reward or {};local p=r.pokemon or {}
 f.giftGeneration=f.giftGeneration or V.generation(f.edition or 'crystal')
 f.giftKind=r.kind or 'pokemon';f.giftPreset=r.preset;f.giftTab='Generate';f.giftSearch=''
 f.giftDex=tostring(r.dex or 25);f.giftLevel=tostring(r.level or 5);f.giftEgg=r.egg==true;f.giftShiny=r.shiny==true
 f.giftMoves=table.concat(r.moves or {},', ');f.giftItem=r.item or 'RARECANDY';f.giftQuantity=tostring(r.quantity or 1)
 for k,id in pairs(fields) do f[id]=p[k]~=nil and tostring(p[k]) or '' end
 f.giftIVs=pack(p.ivs,stats);f.giftEVs=pack(p.evs,stats);f.giftDVs=pack(p.dvs,{'attack','defense','speed','special'})
 f.giftTraining=pack(p.stat_exp,{'hp','attack','defense','speed','special'});f.giftFateful=p.fateful==true;f.giftOTFemale=p.ot_female==true
 return f
end
function D.action(f,id)
 if id:match('^giftGen:') then
  local gen=tonumber(id:match(':(%d+)$'));local edition=({'red','crystal','emerald','platinum','black'})[gen]
  if edition then f.giftGeneration=gen;if f.giftSelected then f.giftSelected={[edition]=true} elseif f.edition then f.edition=edition end end
  return true
 elseif id:match('^giftRoll:') then
  local kind=id:sub(10);local egg=kind:find('Egg',1,true)~=nil
  local reward,why=require('src.storage.GiftGenerator').roll(f.giftGeneration or 2,kind:find('legendary',1,true)==1,egg)
  if not reward then f.giftError=why;return true end
  D.init(f,reward);f.giftError=nil;f.giftTab='General';if f.giftTitle=='' then f.giftTitle='Gen '..f.giftGeneration..(egg and ' egg' or ' companion') end
  return true
 elseif id:match('^giftTab:') then f.giftTab=id:sub(9);return true
 elseif id:match('^giftKind:') then f.giftKind=id:sub(10);f.giftPreset=nil;f.giftTab='General';return true
 elseif id:match('^giftPreset:') then
  f.giftPreset=id:sub(12);local ev=require('src.pokewalker.WalkerEvents').get(f.giftPreset);f.giftKind=ev and ev.kind=='mon' and 'pokemon' or 'event';if ev and f.giftTitle=='' then f.giftTitle=ev.name end;f.giftTab='General';return true
 elseif id=='giftCustom' then f.giftPreset=nil;f.giftKind='pokemon';return true
 elseif id=='giftEgg' or id=='giftShiny' or id=='giftFateful' or id=='giftOTFemale' then f[id]=not f[id];return true end
end
local function numbers(value,order,max)
 if not value or value=='' then return nil end
 local out={};local n=0
 for part in (value..','):gmatch('(.-),') do
  n=n+1;local number=tonumber(part)
  if not number or number%1~=0 or number<0 or number>max or not order[n] then return nil,'Enter '..#order..' comma-separated values from 0 to '..max..'.' end
  out[order[n]]=number
 end
 if n~=#order then return nil,'Enter all '..#order..' values.' end
 return out
end
function D.payload(f)
 if f.giftPreset then return {preset=f.giftPreset} end
 if f.giftKind=='none' then return nil end
 if f.giftKind=='item' then
  if not tonumber(f.giftQuantity) then return nil,'Enter a valid quantity.' end
  return {kind='item',item=f.giftItem:upper():gsub('[^A-Z0-9]',''),quantity=tonumber(f.giftQuantity)}
 end
 if not tonumber(f.giftDex) or not tonumber(f.giftLevel) then return nil,'Enter a valid species and level.' end
 local p={};for key,id in pairs(fields) do
  local value=f[id]
  if value and value~='' then
   if key=='ot' or key=='nickname' or key=='gender' then p[key]=value
   elseif key=='held_item' or key=='ball' then p[key]=value:upper():gsub('[^A-Z0-9]','')
   else p[key]=tonumber(value);if not p[key] then return nil,'Enter a valid number for '..key..'.' end end
  end
 end
 for _,row in ipairs({{'giftIVs','ivs',stats,31},{'giftEVs','evs',stats,255},{'giftDVs','dvs',{'attack','defense','speed','special'},15},{'giftTraining','stat_exp',{'hp','attack','defense','speed','special'},65535}}) do
  local value,why=numbers(f[row[1]],row[3],row[4]);if why then return nil,why end;p[row[2]]=value
 end
 if f.giftFateful then p.fateful=true end;if f.giftOTFemale then p.ot_female=true end
 local moves={};for move in (f.giftMoves or ''):gmatch('[^,]+') do local name=move:upper():gsub('[^A-Z0-9]','');if name~='' then moves[#moves+1]=name end end
 return {kind='pokemon',dex=tonumber(f.giftDex),level=tonumber(f.giftLevel),egg=f.giftEgg==true,shiny=f.giftShiny==true,moves=moves,pokemon=next(p) and p or nil}
end
function D.describe(r)
 if not r then return 'Achievement only' end
 if r.preset then local ev=require('src.pokewalker.WalkerEvents').get(r.preset);return ev and ev.name..' · '..(ev.event or 'Event unlock') or r.preset end
 if r.kind=='item' then return tostring(r.quantity or 1)..' × '..tostring(r.item) end
 return '# '..tostring(r.dex)..' · Lv '..tostring(r.level or 5)..(r.egg and ' · EGG' or '')..(r.shiny and ' · SHINY' or '')
end
function D.draw(f,editions,ui)
 local text,row,field=ui.text,ui.row,ui.field
 text(L('PRIZE STUDIO · ')..table.concat(editions,', '):upper(),true)
 text(D.describe(f.giftPreset and {preset=f.giftPreset} or {kind=f.giftKind,dex=f.giftDex,level=f.giftLevel,egg=f.giftEgg,shiny=f.giftShiny,item=f.giftItem,quantity=f.giftQuantity}),true)
 for _,tab in ipairs({'Generate','General','Trainer','Stats','Moves','Encounter','Presets'}) do if ui.tab then ui.tab(tab,'giftTab:'..tab,f.giftTab==tab) end end
 if not ui.tab then row(L('SECTION · ')..f.giftTab..L(' · NEXT'),'giftTab:'..({Generate='General',General='Trainer',Trainer='Stats',Stats='Moves',Moves='Encounter',Encounter='Presets',Presets='Generate'})[f.giftTab]) end
 if f.giftTab=='Presets' then
  field('Search historical distributions and island unlocks','giftSearch')
  text('Recreations from historical templates. These are not new official distributions. Unreleased Azure Flute is excluded.')
  local query=(f.giftSearch or ''):lower();local n=0
  for _,ev in ipairs(require('src.pokewalker.WalkerEvents').EVENTS) do
   local valid=ev.id~='azure_flute'
   for _,v in ipairs(editions) do local found=false;for _,supported in ipairs(ev.games) do if supported==v then found=true end end;if not found then valid=false end end
   if valid and (ev.name..' '..(ev.event or '')..' '..(ev.about or '')):lower():find(query,1,true) then
    row(ev.name..' · '..(ev.event or ev.about or ev.id),'giftPreset:'..ev.id);n=n+1
   end
  end
  if n==0 then text('No preset for the selected edition(s).') end
 elseif f.giftPreset then
  local ev=require('src.pokewalker.WalkerEvents').get(f.giftPreset)
  text(ev and (ev.src or '') or 'Unknown preset');text(ev and (ev.about or '') or '')
  text('Fixed historical identity. Switch to Custom for your own Pokémon. Native event tickets include their event unlock flags.')
  row('CUSTOM POKÉMON','giftCustom')
 elseif f.giftTab=='Generate' then
  text(L('QUICK GENERATOR · GEN ')..tostring(f.giftGeneration or 2),true)
  if ui.choices and f.giftSelected then
   local choices={};for gen=1,5 do choices[#choices+1]={'Gen '..gen,'giftGen:'..gen,gen==f.giftGeneration} end;ui.choices(choices)
  elseif f.edition then f.giftGeneration=V.generation(f.edition);text('Uses the tournament edition. Change Edition above to generate another generation.') end
  row('GENERATE LEGENDARY / MYTHICAL','giftRoll:legendary');row('GENERATE NON-LEGENDARY','giftRoll:ordinary')
  if (f.giftGeneration or 2)>=2 then
   row('GENERATE LEGENDARY EGG · ADMIN SPECIAL','giftRoll:legendaryEgg');row('GENERATE NON-LEGENDARY EGG','giftRoll:ordinaryEgg')
   text('Legendary eggs are admin-created special gifts, not a claim of natural breeding or verified battle legality.')
  end
  if f.giftError then text(f.giftError) end
 elseif f.giftTab=='General' then
  row('POKÉMON','giftKind:pokemon');row('ITEM','giftKind:item');if ui.allowNone then row('ACHIEVEMENT ONLY','giftKind:none') end
  if f.giftKind=='item' then field('Item identifier · e.g. RARECANDY, LEFTOVERS','giftItem');field('Quantity · 1–99','giftQuantity');text('Use Presets for event tickets; ordinary items do not unlock events.')
  elseif f.giftKind=='pokemon' then
   field('National species number','giftDex');field('Level · eggs use the edition’s hatch level','giftLevel')
   row((f.giftEgg and '[x]' or '[ ]')..L(' Egg · Gen 2+'),'giftEgg');row((f.giftShiny and '[x]' or '[ ]')..L(' Shiny · Gen 2+'),'giftShiny')
  end
 elseif f.giftKind~='pokemon' then text('Choose Pokémon to edit identity and stats, or select an event preset.')
 elseif f.giftTab=='Trainer' then
  field('OT · maximum 7 characters; blank uses RetroRecomp','giftOT');field('Trainer ID · 0–65535','giftTID');field('Secret ID · Gen 3+','giftSID');field('Nickname · maximum 10 characters','giftNickname')
  row((f.giftOTFemale and '[x]' or '[ ]')..L(' Female OT · Gen 3+'),'giftOTFemale')
 elseif f.giftTab=='Stats' then
  text('Leave blank for deterministic native values. Order: HP, Attack, Defense, Speed, Sp. Atk, Sp. Def.')
  field('IVs · six values 0–31 · Gen 3+','giftIVs');field('EVs · six values 0–255; total ≤510 · Gen 3+','giftEVs')
  field('DVs · Attack, Defense, Speed, Special · 0–15 · Gen 1–2','giftDVs');field('Stat experience · HP, Attack, Defense, Speed, Special · Gen 1–2','giftTraining')
  field('Nature index · 0–24 · Gen 3+','giftNature');field('Ability slot · 1–2; 3 hidden only Gen 5','giftAbility');field('Gender · male / female / unknown · Gen 2+','giftGender');field('PID · optional exact 32-bit identity · Gen 3+','giftPID')
 elseif f.giftTab=='Moves' then
  field('Up to four moves · comma separated; blank uses native learnset','giftMoves');field('Held item · Gen 2+','giftHeld')
  text('Moves must exist in the receiving generation. A special event move does not imply battle legality.')
 elseif f.giftTab=='Encounter' then
  field('Ball · POKEBALL / GREATBALL / ULTRABALL / MASTERBALL','giftBall');field('Friendship · 0–255 · Gen 2+','giftFriendship')
  field('Met level · 0–100 · Gen 3+','giftMetLevel');field('Met location ID · edition-specific · Gen 3+','giftMetLocation');field('Language ID · 1–7 · Gen 3+','giftLanguage')
  row((f.giftFateful and '[x]' or '[ ]')..L(' Fateful encounter · Gen 3+'),'giftFateful')
 end
 text('Admin-created gifts retain their provenance. Structural validation does not certify tournament legality.')
end
return D
