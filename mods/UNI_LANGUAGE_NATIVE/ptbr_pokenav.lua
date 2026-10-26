-- Native PokéNav packs contain private copies of text and raster labels.
-- Bring them into the language cache; the unmodified game's own scenes use it.
return function(game,files,mod,operations,trainers)
 if game~='ruby' and game~='sapphire' and game~='emerald' then return {} end
 local base=require('src.core.game3.dataset').cache()
 local W=require('src.import.LuaWriter')
 local IR=require('src.core.game3.scripting.text_ir')
 local rs=game~='emerald'
 local folders=rs and {'pokenav','pokenav_shell','pokenav_detail','pokenav_condition','pokenav_ribbons'} or {'pokenav','pokenav_cr'}
 local inputs,manifests={},{}
 local function collect(value)
  if type(value)=='table' then for _,v in pairs(value)do collect(v)end
  elseif type(value)=='string' and value:match('^data/generated/gba/rse/pokenav[^/]*/[^/]+%.[a-z]+$') then
   inputs[value]=assert(base:read(value),'Missing PokéNav asset '..value)
  end
 end
 for _,folder in ipairs(folders)do
  local path='data/generated/gba/rse/'..folder..'/manifest.lua'
  inputs[path]=assert(base:read(path));manifests[path]=assert(loadstring(inputs[path]))()
  collect(manifests[path])
 end
 if not files then return inputs end
 if not operations then for path,bytes in pairs(inputs)do files[path]=bytes end;return end
 if rs then
  local man=manifests['data/generated/gba/rse/pokenav_detail/manifest.lua']
  for _,row in ipairs(assert(trainers))do
   local src=assert(man.descriptions[row.id])
   local hash=love.data.encode('string','hex',love.data.hash('string','sha256',table.concat(src,'\n')))
   assert(hash==row.sourceSha256,'Trainer Eyes source changed: '..row.symbol)
   man.descriptions[row.id]=row.lines
  end
  -- The stock RS pack's text background entry is black. Match the native
  -- condition-panel background while retaining the existing text palette.
  local cond=manifests['data/generated/gba/rse/pokenav_condition/manifest.lua']
  local data=love.image.newImageData(love.data.newByteData(files[cond.layers.party.png]))
  local r,g,b=data:getPixel(140,30)
  cond.palettes.condition[192]=math.floor(r*31+0.5)+32*math.floor(g*31+0.5)+1024*math.floor(b*31+0.5)
 end
 local original,translated={},{}
 for key,row in mod.content.text:each()do original[key]=row end
 for _,op in ipairs(operations)do if op.registry=='text' and op.method=='override' then translated[op.key]=op.value end end
 local lookup,ambiguous={},{}
 local pure={text=true,tag=true,nl=true,para=true,scroll=true,eos=true,ext=true}
 local function static(row)for _,seg in ipairs(row)do if not pure[seg.t]then return false end end;return true end
 for key,row in pairs(translated)do if original[key] and static(original[key]) and static(row) then
  local a,src=pcall(IR.toPlain,original[key],{});local b,dst=pcall(IR.toPlain,row,{})
  if a and b and src~=dst and src~='' and not ambiguous[src] then
   if lookup[src] and lookup[src]~=dst then lookup[src]=nil;ambiguous[src]=true else lookup[src]=dst end
  end
 end end
 local overrides={
  ['IN PARTY']='NA EQUIPE',['No. ']='Nº ',['RIBBONS']='FITAS',
  ['No. of battles']='Nº de batalhas',['No. registered']='Nº de registros',
  ['SELF-INTRODUCTION']='APRESENTAÇÃO',['STRATEGY']='ESTRATÉGIA',["TRAINER'S POKéMON"]='POKÉMON DO TREINADOR',
  ['Check party POKéMON in detail.']='Veja os POKÉMON da equipe.',
  ['Check all POKéMON in detail.']='Veja todos os POKÉMON.',
  ['Return to the POKéNAV menu.']='Voltar ao menu do POKÉNAV.',
  ['Check the map of the HOENN region.']='Veja o mapa de HOENN.',
  ['Check POKéMON in detail.']='Veja detalhes dos POKÉMON.',
  ['Check TRAINER information.']='Veja dados dos TREINADORES.',
  ['Check obtained RIBBONS.']='Veja as FITAS conquistadas.',
  ['Put away the POKéNAV.']='Guardar o POKÉNAV.',
  ['There are no RIBBON winners.']='Nenhum POKÉMON ganhou FITAS.',
  ['No TRAINERS are registered.']='Nenhum TREINADOR registrado.',
  ['Find cool POKéMON.']='Busque POKÉMON legais.',
  ['Find beautiful POKéMON.']='Busque POKÉMON belos.',
  ['Find cute POKéMON.']='Busque POKÉMON fofos.',
  ['Find smart POKéMON.']='Busque POKÉMON espertos.',
  ['Find tough POKéMON.']='Busque POKÉMON durões.',
  ['Return to the CONDITION menu.']='Voltar ao menu de CONDIÇÃO.',
 }
 local authored={};for _,row in ipairs(trainers or {})do for _,s in ipairs(row.lines)do authored[s]=true end end
 local unresolved={}
 local function replace(value,key)
  if type(value)=='table' then for k,v in pairs(value)do value[k]=replace(v,k)end;return value end
  if type(value)=='string' then
   local replacement=overrides[value] or lookup[value]
   if replacement then return replacement end
   if not authored[value] and value:find(' ') and not value:find('data/generated/',1,true) then unresolved[value]=true end
  end
  return value
 end
 for path,man in pairs(manifests)do files[path]=W.encode(replace(man))end
 return unresolved
end
