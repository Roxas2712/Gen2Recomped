-- Language-neutral registry operations; only compiled PT-BR data is read here.
-- The ROM controls narrative text. Gameplay IDs and mechanics stay canonical.
return function(mod)
 local function catalog(name)
  local body=assert(mod:read('lang/'..name..'.lua'),'Missing PT-BR catalog: '..name)
  return assert(loadstring(body,'@ptbr/'..name))()
 end
 local counts={}
 local function names(cat,registry,field)
  local n=0
  for id,value in pairs(catalog(cat)) do
   if value~='' then registry:patch(id,{[field]=value});n=n+1 end
  end
  counts[cat]=n
 end
 for seq,code in pairs(catalog('charmap')) do
  mod.content.font:register('charmap:'..seq,{seq=seq,code=code})
 end
 mod.content.font:override('main',{image=mod.path..'/assets/fonts/font.png',base=0x80,glyphsPerRow=16})
 mod.content.font:register('font_battle_extra',{image=mod.path..'/assets/battle/font_battle_extra.png',base=0x62,glyphsPerRow=15})
 mod.content.font:register('ptbr_underscore',{image=mod.path..'/assets/fonts/underscore.png',base=0x100,glyphsPerRow=1})
 for id,value in pairs(catalog('dialogue')) do mod.content.text:override(id,value) end
 for source,value in pairs(catalog('strings')) do mod.content.strings:override(source,value) end
 names('species_names',mod.content.pokemon,'name')
 names('move_names',mod.content.moves,'name')
 names('item_names',mod.content.items,'name')
 names('trainer_names',mod.content.trainers,'name')
 names('type_names',mod.content.type_chart,'name')
 for id,value in pairs(catalog('status_labels')) do mod.content.statuses:patch(id,{label=value,hudLabel=value}) end
 for id,value in pairs(catalog('dex_kinds')) do
  mod.content.pokemon:patch(id,{dexEntry={kind=value}})
 end
 for id,value in pairs(catalog('dex_metrics')) do
  mod.content.pokemon:patch(id,{dexEntry=value})
 end
 if mod.edition~='yellow' then mod.content.field:patch('title',{versionRibbon=mod.path..'/assets/title/'..mod.edition..'_version.png'}) end

 -- Reflow a fully substituted battle sentence once when it enters the queue.
 -- Names and move names can exceed the cartridge's 18-glyph text box.
 -- No font/draw functions are replaced and inactive editions take the native path.
 local Battle=require('src.battle.BattleState')
 local Font=require('src.render.Font')
 local Runtime=require('src.mods.Runtime')
 local version=require('src.core.GameVersion')
 local bus=Runtime.events
 local marker='__ula_ptbr_gen1__'
 mod.content.strings:override(marker,'active')
 local function active()
  local strings=mod.game and mod.game.data and mod.game.data.strings
  return Runtime.events==bus and version.get()==mod.edition and strings and strings[marker]=='active'
 end
 local function wrap(text)
  local out={};local lineNo=0
  text=require('src.render.TextBox').strip(text)
  for line in (text..'\n'):gmatch('(.-)[\n\v\f]') do
   local spans=Font.split(line)
   while #spans>18 do
    local cut,nextSpan=18,19
    for i=18,2,-1 do if line:sub(spans[i].from,spans[i].to)==' ' then cut,nextSpan=i-1,i+1;break end end
    out[#out+1]=line:sub(1,spans[cut].to)
    line=line:sub(spans[nextSpan].from):gsub('^ +','');spans=Font.split(line)
   end
   out[#out+1]=line
  end
  local result={}
  for i,line in ipairs(out) do if i>1 then result[#result+1]=i==2 and '\n' or '\v' end;result[#result+1]=line end
  return table.concat(result)
 end
 local patch=Battle.__ulaPtbrText
 if not patch then
  patch={original=Battle.startMessage};Battle.__ulaPtbrText=patch
  Battle.startMessage=function(self,item)
   if patch.active and patch.active() and item and type(item.text)=='string' then
    local copy={};for k,v in pairs(item) do copy[k]=v end
    copy.text=patch.wrap(item.text);item=copy
   end
   return patch.original(self,item)
  end
 end
 patch.active,patch.wrap=active,wrap
 mod.exports.ptbrRegistries=counts
end
