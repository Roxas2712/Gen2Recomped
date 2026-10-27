-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Reuse the original mod's authored alphabet on the fork's native surfaces.
-- Coordinates belong to these surfaces, never to the upstream tile atlas.
return function(files,game,own,scenes)
 local prefix='assets/generated/'
 local function chars(s)return s:gmatch('[%z\1-\127\194-\244][\128-\191]*')end
 local bridge={chars=chars,base={read=function(_,p)
  return love.filesystem.read(require('src.core.GameVersion').cachePrefix()..p)
 end}}
 bridge.apply=function(paint)
  local function edit(path,fn)
   path=prefix..path
   if files[path]then local e=paint.edit(path);fn(e);e.save();return true end
  end
  local function caption(e,text,x,y,w,h,small,white)
   assert(x>=0 and y>=0 and x+w<=e.w and y+h<=e.h,'PT-BR caption geometry changed: '..e.path)
   e.small=small
   local bg=e.get(x+w-1,y+math.floor(h/2))
   paint.label(e,text,x,y,w,h,bg,e.color(white and 255 or 40),white and e.color(80)or nil)
  end
  if game=='emerald'then
   edit('ui/ula_type_badges.png',function(e)
    local names=own('ptbr_types.lua');local short={[7]='FANT.',[13]='ELÉTR.',[14]='PSÍQ.'};e.small=true
    for id=0,17 do
     local name=short[id]or assert(names[id]);local y=id*16
     paint.label(e,name,1,y+2,30,11,e.get(1,y+4),e.color(255),e.color(100))
    end
    -- Reuse the existing authored category names for the five contest frames.
    -- Condense their pixel columns when needed; never truncate the word.
    local authored=own('profiles/emerald_ptbr_authored.lua');local text=own('@host/gba_text.lua')
    for i,key in ipairs({'gText_Cool','gText_Beauty','gText_Cute','gText_Smart','gText_Tough'})do
     local label=text.plain(assert(authored[key]).target,'emerald');local count=0;for _ in chars(label)do count=count+1 end
     local width=math.max(30,count*4);local y=(17+i)*16
     local surface=setmetatable({small=true,set=function(x,yy,color)e.set(1+math.floor((x-1)*30/width),yy,color)end},{__index=e})
     paint.label(surface,label,1,y+2,width,11,e.get(1,y+4),e.color(255),e.color(100))
    end
   end)
   local title=scenes and scenes._overlays and scenes._overlays.title
   for _,sheet in ipairs(title and title.sheets or{})do
    if sheet.depth==8 and sheet.layout~='strip'and sheet.image then
     edit(sheet.image:sub(#prefix+1),function(e)
      assert(e.w>=96 and e.h>=32,'Native edition banner geometry changed')
      paint.clear(e,0,0,e.w,e.h,{0,0,0,0})
      paint.write(e,'VERSÃO',math.floor((e.w-29)/2),1,{1,1,1,1},{.4,.4,.4,1})
      local scale=2;local x=math.floor((e.w-88)/2)
      local large={path=e.path,set=function(px,py,color)
       for yy=0,scale-1 do for xx=0,scale-1 do e.set(x+px*scale+xx,16+py*scale+yy,color)end end
      end}
      paint.write(large,'ESMERALDA',0,0,{1,1,1,1},{.4,.4,.4,1})
     end)
    elseif sheet.layout=='strip'and sheet.pieces and sheet.pieces[1]then
     local image=sheet.pieces[1].image
     if image then edit(image:sub(#prefix+1),function(e)
      paint.clear(e,0,0,e.w,e.h,{0,0,0,0})
      assert(e.w>=60 and e.h>=8,'Native title prompt geometry changed')
      paint.write(e,'APERTE START',math.floor((e.w-59)/2),0,{1,1,1,1},{.4,.4,.4,1})
     end)end
    end
   end
   for _,name in ipairs({'info','info_alt'})do edit('ui/summary_'..name..'.png',function(e)
    caption(e,'PERFIL',96,24,88,8,false,true)
    caption(e,'HABILIDADE',96,64,96,8,false,true)
    caption(e,'MEMÓRIA',96,104,96,8,false,true)
   end)end
   edit('ui/summary_skills.png',function(e)
    caption(e,'ITEM',96,24,40,8,false,true);caption(e,'FITAS',176,24,56,8,false,true)
    caption(e,'ATRIBUTOS',96,48,120,8,false,true);caption(e,'EXP.',96,104,112,8,false,true)
   end)
   for _,page in ipairs({'battle_moves','contest_moves'})do edit('ui/summary_'..page..'.png',function(e)
    caption(e,'GOLPES',96,24,112,8,false,true)
    caption(e,'DESCRIÇÃO',96,104,112,8,false,true)
   end)end
   edit('ui/pokenav_buttons.png',function(e)
    assert(e.w==128 and e.h==208,'POKéNAV button atlas changed')
    for i,text in ipairs({'MAPA DE HOENN','CONDIÇÃO','CONTATOS','FITAS','DESLIGAR','EQUIPE','BUSCAR','VOLTAR','LEGAL','BELO','FOFO','ESPERTO','DURO'})do
     caption(e,text,14,(i-1)*16+2,110,12,false,true)
    end
   end)
   edit('ui/pokenav_menu.png',function(e)caption(e,'NAVEGADOR POKÉMON',20,0,168,16,false,true)end)
   edit('ui/trainer_card_front.png',function(e)
    caption(e,'TREINADOR',20,1,96,9,true,false)
    caption(e,'INSÍGNIAS',24,112,48,7,true,true)
   end)
   for path in pairs(files)do if path:match('^assets/generated/ui/pokedex/info_')then
    edit(path:sub(#prefix+1),function(e)
     caption(e,'ALT.',104,60,24,10,false,true)
     caption(e,'PESO',104,76,24,10,false,true)
     caption(e,'PÁG.',20,94,24,9,false,true)
    end)
   end end
   edit('slots/gen3_machine.png',function(e)
    if e.w>=240 and e.h>=160 then
     caption(e,'FICHAS',179,8,28,8,true,true)
     caption(e,'PRÊMIO',211,8,28,8,true,true)
     caption(e,'SAIR',196,149,25,8,false,true)
    end
   end)
  else
   for path in pairs(files)do if path:match('^assets/generated/trainer_card_frlg/front_')then
    edit(path:sub(#prefix+1),function(e)
     caption(e,path:find('girl',1,true)and'TREINADORA'or'TREINADOR',16,19,96,11,false,true)
     caption(e,'INSÍGNIAS',18,121,48,7,true,true)
    end)
   end end
  end
  local folder=game=='firered'and'naming_frlg/'or'naming_emerald/'
  edit(folder..'back.png',function(e)
   -- Keep the B-button prompt below the caption.
   caption(e,'APAGAR',4,3,e.w-8,10,true,false)
  end)
  for _,name in ipairs({'label_others','swap_others'})do edit(folder..name..'.png',function(e)
   caption(e,'OUTROS',0,0,e.w,math.min(12,e.h),true,false)
  end)end
  -- Sprite lettering in status badges uses three cells; geometry is native.
  for path in pairs(files)do if path:match('status.*%.png$')then
   edit(path:sub(#prefix+1),function(e)
    if e.w==32 and(e.h==56 or e.h==64)then
     for i,text in ipairs({'ENV','PAR','SON','CON','QUE','','DES'})do if text~=''then
      caption(e,text,8,(i-1)*8+1,16,6,true,true)
     end end
    end
   end)
  end end
 end
 return own('ptbr_pixel_labels.lua')(files,game,bridge)
end
