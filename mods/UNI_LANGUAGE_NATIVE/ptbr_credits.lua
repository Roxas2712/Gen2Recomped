-- Localize the actual ROM credit headings; preserve every credited name.
-- Ending lettering is authored pixel data, compiled once into the cache.
return function(files,game,rolesOnly)
 local editions={ruby='RUBI',sapphire='SAFIRA',emerald='ESMERALDA'}
 local titles={
  ['World Director']='Direção do mundo do jogo',['Lead Programmer']='Programação principal',
  ['Lead Graphic Artist']='Design gráfico principal',['Scenario Plot']='Enredo',['Scenario']='Roteiro',
  ['Battle Frontier Data']='Dados da Fronteira de Batalha',['Support Programmers']='Programação de apoio',
  ['NCL Product Testing']='Testes de produto da NCL',['Package & Manual Illustration']='Ilustrações da capa e do manual',
  ['-Tradução-']='Tradução',['NCL Coordinator']='Coordenação da NCL',['Graphic Designer']='Design gráfico',
  ['Artwork']='Ilustrações',['Credits']='Créditos',['Director']='Direção',['Art Director']='Direção de arte',
  ['Battle Director']='Direção de batalhas',['Battle System Programmer']='Programação das batalhas',
  ['Braille Code Check']='Revisão do braile',['Coordinators']='Coordenação',
  ['English Version Coordinators']='Coordenação da versão inglesa',
  ['Environment & Tool Programmers']='Programação de ferramentas',
  ['Executive Director']='Direção executiva',['Executive Producers']='Produção executiva',
  ['Game Designers']='Design do jogo',['Game Scenario']='Roteiro do jogo',
  ['Graphic Designers']='Design gráfico',['Information Supervisors']='Supervisão de informações',
  ['Main Graphic Designer']='Direção de design gráfico',['Main Programmer']='Programação principal',
  ['Map Data Designers']='Dados dos mapas',['Map Designers']='Design dos mapas',
  ['Music Composition']='Composição musical',['NOA Product Testing']='Testes de produto da NOA',
  ['POKéDEX Text']='Texto da POKéDEX',['POKéMON & Graphic Designers']='Design de POKéMON e gráficos',
  ['POKéMON Designers']='Design de POKéMON',['Parametric Designers']='Design de parâmetros',
  ['Plot Scenario']='Enredo',['Producers']='Produção',['Product Support']='Suporte ao produto',
  ['Product Testing']='Testes do produto',['Programmers']='Programação',
  ['Script Designers']='Design de scripts',['Sound Effects & POKéMON Voices']='Efeitos sonoros e vozes',
  ['Special Thanks']='Agradecimentos',['Task Managers']='Gestão de tarefas',
  ['Text Editor']='Edição de texto',['Translator']='Tradução',['Portuguese Version']='Versão em português',
 }
 if rolesOnly then return titles end
 if not editions[game] then return end
 local root='data/generated/gba/credits_rse/'
 local W=require('src.import.LuaWriter')
 local man=assert(loadstring(assert(files[root..'manifest.lua'])))()
 local count,unknown=0,{}
 for _,page in ipairs(man.pages) do for _,row in ipairs(page) do
  local source=row.text:match('^%s*(.-)%s*$')
  local text=titles[source]
  if source:match('^POKéMON .- VERSION$') or source=='POKéMON VERSÃO EMERALDA' then text='POKéMON VERSÃO '..editions[game] end
  if text then row.text=text;row.raw=nil;count=count+1
  elseif source~='' and (row.isTitle or row.raw and row.raw[1]==252 and (row.raw[2]==3 or row.raw[2]==5)) then
   local reviewed=false;for _,pt in pairs(titles) do if source==pt then reviewed=true end end
   if not reviewed then unknown[#unknown+1]=source else count=count+1 end
  end
 end end
 assert(#unknown==0,'Unreviewed native credit headings: '..table.concat(unknown,' | '))
 assert(count>=20,'Native credits headings were not recognized')
 files[root..'manifest.lua']=W.encode(man)
 local font={O={'01110','11011','11011','11011','11011','11011','01110'},
  F={'11111','11000','11000','11110','11000','11000','11000'},
  I={'11111','01110','01110','01110','01110','01110','11111'},
  M={'10001','11011','11111','10101','10101','10001','10001'}}
 local pixel={};for i=1,240*160 do pixel[i]=string.char(0,0,0,255) end
 local text,scale='O FIM',4
 local origin=math.floor((240-(#text*6-1)*scale)/2)
 local ink={}
 for n=1,#text do local ch=text:sub(n,n)
  if ch~=' ' then for y,row in ipairs(font[ch]) do for x=1,5 do if row:sub(x,x)=='1' then
   for dy=0,scale-1 do for dx=0,scale-1 do ink[#ink+1]={origin+(n-1)*6*scale+(x-1)*scale+dx,64+(y-1)*scale+dy} end end
  end end end end
 end
 for _,p in ipairs(ink) do pixel[(p[2]+3)*240+p[1]+4]=string.char(104,120,128,255) end
 for _,p in ipairs(ink) do pixel[p[2]*240+p[1]+1]=string.char(255,255,255,255) end
 files[root..assert(man.theEnd)]=table.concat(pixel)
 return count
end
