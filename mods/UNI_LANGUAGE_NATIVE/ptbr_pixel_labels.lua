-- Authored lettering for labels stored as pixels rather than text pointers.
-- Compiled once into the language cache. Coordinates refer to native assets;
-- the game continues to draw its own menus, sprites and transitions.
return function(files,game,bridge)
 local base,K,PNG,chars
 if bridge then base=bridge.base;chars=bridge.chars
 else
  base=require('src.core.game3.dataset').cache()
  K=require('src.import.gba.rse.boot_gfx')
  PNG=require('src.core.game3.indexed_png')
  chars=require('src.ui.game3.frlg_font').utf8Chars
 end
 local root='data/generated/gba/'
 local rs=game=='ruby' or game=='sapphire'
 local rse=rs or game=='emerald'
 local labels={}
 local font={
  A={'010','101','111','101','101'},B={'110','101','110','101','110'},
  C={'011','100','100','100','011'},D={'110','101','101','101','110'},
  E={'111','100','110','100','111'},F={'111','100','110','100','100'},
  G={'011','100','101','101','011'},H={'101','101','111','101','101'},
  I={'111','010','010','010','111'},J={'001','001','001','101','010'},
  K={'101','101','110','101','101'},L={'100','100','100','100','111'},
  M={'101','111','111','101','101'},N={'101','111','111','111','101'},
  O={'010','101','101','101','010'},P={'110','101','110','100','100'},
  Q={'010','101','101','111','011'},R={'110','101','110','101','101'},
  S={'011','100','010','001','110'},T={'111','010','010','010','010'},
  U={'101','101','101','101','111'},V={'101','101','101','101','010'},
  W={'101','101','111','111','101'},X={'101','101','010','101','101'},
  Y={'101','101','010','010','010'},Z={'111','001','010','100','111'},
  ['.']={'000','000','000','000','010'},['?']={'110','001','010','000','010'},
  ['(']={'010','100','100','100','010'},[')']={'010','001','001','001','010'},
  ['-']={'000','000','111','000','000'},[':']={'000','010','000','010','000'},
  ['Ã']={'101','010','101','111','101'},['Á']={'001','010','101','111','101'},
  ['Ê']={'010','101','111','110','111'},['É']={'001','010','111','110','111'},['Í']={'001','010','111','010','111'},
  ['Ó']={'001','010','101','101','010'},['Ç']={'011','100','100','011','010'},
 }
 local large={
  A={'0110','1001','1001','1111','1001','1001','1001'},
  B={'1110','1001','1001','1110','1001','1001','1110'},
  C={'0111','1000','1000','1000','1000','1000','0111'},
  D={'1110','1001','1001','1001','1001','1001','1110'},
  E={'1111','1000','1000','1110','1000','1000','1111'},
  F={'1111','1000','1000','1110','1000','1000','1000'},
  G={'0111','1000','1000','1011','1001','1001','0111'},
  H={'1001','1001','1001','1111','1001','1001','1001'},
  I={'1110','0100','0100','0100','0100','0100','1110'},
  L={'1000','1000','1000','1000','1000','1000','1111'},
  M={'1001','1111','1111','1001','1001','1001','1001'},
  O={'0110','1001','1001','1001','1001','1001','0110'},
  P={'1110','1001','1001','1110','1000','1000','1000'},
  R={'1110','1001','1001','1110','1010','1001','1001'},
  S={'0111','1000','1000','0110','0001','0001','1110'},
  T={'1111','0100','0100','0100','0100','0100','0100'},
  ['.']={'0000','0000','0000','0000','0000','0110','0110'},
  ['Ã']={'0101','1010','0110','1001','1111','1001','1001'},
  ['Ç']={'0111','1000','1000','1000','0111','0010','0100'},
  ['Ó']={'0010','0100','0110','1001','1001','1001','0110'},
 }
 large['!']={'0100','0100','0100','0100','0100','0000','0100'}
 large.J={'0001','0001','0001','0001','1001','1001','0110'}
 large.W={'1001','1001','1001','1001','1111','1111','1001'}
 large.Y={'1001','1001','0110','0110','0100','0100','0100'}
 large['-']={'0000','0000','0000','1111','0000','0000','0000'}
 large.Z={'1111','0001','0010','0100','1000','1000','1111'}
 large.K={'1001','1010','1100','1100','1010','1001','1001'}
 large['Ê']={'0110','1001','1111','1000','1110','1000','1111'}
 large.N={'1001','1101','1101','1011','1011','1001','1001'}
 large.Q={'0110','1001','1001','1001','1011','0110','0001'}
 large.U={'1001','1001','1001','1001','1001','1001','0110'}
 large.V={'1001','1001','1001','1001','1001','0110','0110'}
 large.X={'1001','1001','0110','0110','0110','1001','1001'}
 large['É']={'0010','0100','1111','1000','1110','1000','1111'}
 large['Á']={'0010','0100','0110','1001','1111','1001','1001'}
 large['Í']={'0010','0100','1110','0100','0100','0100','1110'}
 large['(']={'0010','0100','1000','1000','1000','0100','0010'}
 large[')']={'0100','0010','0001','0001','0001','0010','0100'}
 large[':']={'0000','0110','0110','0000','0110','0110','0000'}
 local function edit(path,w,h)
  local bytes=assert(files[path] or base:read(path),'Missing native label asset: '..path)
  local e={path=path}
  if not bridge and path:match('%.png$') and bytes:byte(26)==3 and bytes:byte(25)==8 then
   local d=PNG.decode(bytes,PNG.loveInflate);e.w,e.h=d.w,d.h;e.indexed=true
   e.get=function(x,y)return d.index[y*d.w+x+1] end
   e.rgb=function(c)return d.plte:byte(c*3+1,c*3+3)end
   e.set=function(x,y,c)assert(x>=0 and y>=0 and x<d.w and y<d.h,path);d.index[y*d.w+x+1]=c end
   e.color=function(level)
    local best,score
    for i=0,#d.plte/3-1 do if not d.trns or (d.trns:byte(i+1) or 255)>0 then
     local r,g,b=d.plte:byte(i*3+1,i*3+3);local n=(r-level)^2+(g-level)^2+(b-level)^2
     if not score or n<score then best,score=i,n end
    end end
    return best
   end
   e.save=function()
    local pal={};for i=0,#d.plte/3-1 do
     local r,g,b=d.plte:byte(i*3+1,i*3+3)
     pal[i]=math.floor(r*31/255+0.5)+32*math.floor(g*31/255+0.5)+1024*math.floor(b*31/255+0.5)
    end
    files[path]=K.encodeIndexed(d.w,d.h,d.index,pal,d.trns and d.trns:byte(1)==0)
   end
  else
   local d=path:match('%.rgba$') and love.image.newImageData(w,h,'rgba8',bytes)
     or love.image.newImageData(love.data.newByteData(bytes))
   e.w,e.h=d:getDimensions()
   e.get=function(x,y)return {d:getPixel(x,y)} end
   e.rgb=function(c)return math.floor(c[1]*255+0.5),math.floor(c[2]*255+0.5),math.floor(c[3]*255+0.5)end
   e.set=function(x,y,c)assert(x>=0 and y>=0 and x<e.w and y<e.h,path);d:setPixel(x,y,unpack(c)) end
   e.color=function(level)return {level/255,level/255,level/255,1} end
   e.save=function()files[path]=path:match('%.rgba$') and d:getString() or d:encode('png'):getString() end
  end
  return e
 end
 local function clear(e,x,y,w,h,bg)
  for yy=y,y+h-1 do for xx=x,x+w-1 do e.set(xx,yy,type(bg)=='function' and bg(yy) or bg) end end
 end
 local function write(e,text,x,y,fg,shadow)
  local ink={};local n=0;local glyphs=e.small and font or large;local step=e.small and 4 or 5
  for ch in chars(text) do
   if ch~=' ' then for row,bits in ipairs(assert(glyphs[ch],'Pixel glyph '..ch)) do
    for col=1,#bits do if bits:sub(col,col)=='1' then ink[#ink+1]={x+n*step+col-1,y+row-1} end end
   end end
   n=n+1
  end
  if shadow then for _,p in ipairs(ink)do e.set(p[1]+1,p[2]+1,shadow)end end
  for _,p in ipairs(ink)do e.set(p[1],p[2],fg)end
  labels[#labels+1]=e.path..':'..text
  return n*step-1
 end
 local function label(e,text,x,y,w,h,bg,fg,shadow)
  clear(e,x,y,w,h,bg)
  local count=0;for _ in chars(text)do count=count+1 end
  local step=e.small and 4 or 5;local height=e.small and 5 or 7
  assert(count*step-1+(shadow and 1 or 0)<=w,'Label too wide: '..text)
  write(e,text,x+math.floor((w-(count*step-1))/2),y+math.floor((h-height)/2),fg,shadow)
 end
 if bridge then
  bridge.apply({edit=edit,clear=clear,write=write,label=label},files,game)
  return labels
 end
 if rs then
  local e=edit(root..'rse/easy_chat_editor/indicator.png')
  label(e,'MODO',15,11,29,8,1,15,3)
  label(e,'GRUPO',3,35,41,8,1,15,3)
  label(e,'MODO',15,43,29,8,1,15,3);e.save()
  labels[#labels+1]='easy-chat: MODO / GRUPO'
 end
 if not rse then
  local e=edit(root..'fame_checker/bg.rgba',240,160)
  label(e,'BUSCA-FAMA',4,4,68,9,function(y)return e.get(75,y)end,{1,0.94,0.74,1},{0.76,0.46,0.20,1});e.save()
 end
 local function edit4bpp(path,width)
  local bytes=assert(files[path] or base:read(path));local data={};for i=1,#bytes do data[i]=bytes:byte(i)end
  local e={path=path,w=width,h=#bytes*2/width,indexed=true}
  local function address(x,y)
   assert(x>=0 and y>=0 and x<e.w and y<e.h,path)
   return (math.floor(y/8)*(width/8)+math.floor(x/8))*32+y%8*4+math.floor(x%8/2)+1
  end
  e.get=function(x,y)local b=data[address(x,y)];return x%2==0 and b%16 or math.floor(b/16)end
  e.set=function(x,y,c)local i=address(x,y);data[i]=x%2==0 and (data[i]-data[i]%16+c%16) or (data[i]%16+c%16*16)end
  e.save=function()local out={};for _,b in ipairs(data)do out[#out+1]=string.char(b)end;files[path]=table.concat(out)end
  return e
 end
 -- Tilemaps can reuse and flip glyph tiles. Give edited map cells their own
 -- tiles so replacing a caption cannot alter another part of the scene.
 local function editMap(man,mapKey,gfxKey,paletteKey,mapWidth)
  local gp,mp=man.gfx[gfxKey].path,man.maps[mapKey].path
  local gfx=assert(files[gp] or base:read(gp));local map=assert(files[mp] or base:read(mp))
  local tw=mapWidth or 32;local th=math.ceil(#map/2/tw)
  local pix,w,h=K.bakeText(gfx,map,tw,th,{linear=true,mapWidth=tw})
  local dirty={};local e={path=mp,w=w,h=h,indexed=true}
  e.get=function(x,y)return pix[y*w+x+1]end
  e.set=function(x,y,c)
   assert(x>=0 and x<w and y>=0 and y<h,mp)
   pix[y*w+x+1]=c;dirty[math.floor(y/8)*tw+math.floor(x/8)]=true
  end
  local pal=assert(man.palettes[paletteKey])
  e.rgb=function(c)
   local v=pal[c+1] or 0
   return math.floor(v%32*255/31+.5),math.floor(math.floor(v/32)%32*255/31+.5),math.floor(math.floor(v/1024)%32*255/31+.5)
  end
  e.color=function(level)
   local best,score
   for i=(e.bank or 0)*16+1,(e.bank or 0)*16+15 do
    local r,g,b=e.rgb(i);local n=(r-level)^2+(g-level)^2+(b-level)^2
    if not score or n<score then best,score=i,n end
   end;return best
  end
  e.save=function()
   local entries={};for i=1,#map do entries[i]=map:byte(i)end
   local chunks={gfx};local count=#gfx/32
   for cell=0,#map/2-1 do if dirty[cell] then
    assert(count<1024,'Native tile index exhausted')
    local x,y=cell%tw*8,math.floor(cell/tw)*8;local tile={}
    for yy=0,7 do for xx=0,7,2 do tile[#tile+1]=string.char(e.get(x+xx,y+yy)%16+16*(e.get(x+xx+1,y+yy)%16))end end
    chunks[#chunks+1]=table.concat(tile)
    local old=entries[cell*2+1]+256*entries[cell*2+2]
    local entry=count+math.floor(old/4096)*4096
    entries[cell*2+1]=entry%256;entries[cell*2+2]=math.floor(entry/256);count=count+1
   end end
   local bytes={};for _,v in ipairs(entries)do bytes[#bytes+1]=string.char(v)end
   files[gp]=table.concat(chunks);files[mp]=table.concat(bytes)
  end
  return e
 end
 if rse then
  local path=root..'rse/berry_tag/manifest.lua'
  local man=assert(loadstring(files[path] or base:read(path)))()
  local e=rs and edit(man.layers.body.png) or editMap(man,'tag','check','check')
  e.small=true
  for i,name in ipairs({'PICANTE','SECO','DOCE','AMARGO','AZEDO'})do
   local x=34+(i-1)*40;local bg=e.get(x,95);e.bank=math.floor(bg/16)
   label(e,name,x,95,36,9,bg,e.color(70))
  end;e.save()
  if rs then
   local e=edit(man.layers.title.png)
   label(e,'FRUTA',22,1,53,13,e.get(22,2),e.get(23,2));e.save()
  end
  local path=root..'rse/pokeblock/manifest.lua'
  local man=assert(loadstring(files[path] or base:read(path)))()
  local e=editMap(man,'menu','menu','menu');e.small=true
  local bg=e.get(56,138);e.bank=math.floor(bg/16)
  label(e,'TOQUE',56,137,27,13,bg,e.color(0));e.save()
 end
 if rse then
  do
   local e=edit(root..'rse_slot_machine/digital_0_0.png')
   clear(e,4,19,56,23,0)
   local dots={path=e.path,set=function(x,y,c)e.set(9+x*2,23+y*2,c)end}
   write(dots,'ROLOS',0,0,1);e.save()
  end
  for _,row in ipairs({{'digital_1_0','TEMPO'},{'digital_2_0','INSIRA'},{'digital_3_0','GANHOU'},{'digital_4','PERDEU'}})do
   local e=edit(root..'rse_slot_machine/'..row[1]..'.png')
   clear(e,0,0,e.w,e.h,0)
   local x=math.floor((e.w-(#row[2]*10-3))/2);local y=math.floor((e.h-13)/2)
   local dots={path=e.path,set=function(xx,yy,c)e.set(x+xx*2,y+yy*2,c)end}
   write(dots,row[2],0,0,1);e.save()
  end
  local e=edit(root..'rse_slot_machine/reel_symbols.png');e.small=true
  label(e,'REPETIR',2,204,28,7,1,3);e.save()
  local e=edit(root..'rse/berry_blender/start.png')
  clear(e,0,0,e.w,e.h,0)
  local big={path=e.path,set=function(x,y,c)
   for yy=0,2 do for xx=0,2 do e.set(2+x*3+xx,3+y*3+yy,c)end end
  end}
  write(big,'VAI!',0,0,12,15);e.save()
 end
 if rse then
  local e=edit(root..'rse_roulette/credit.png')
  label(e,'FICHAS',7,7,50,9,0,13,1);e.save()
 end
 if game=='emerald' then
  local man=assert(loadstring(files[root..'rse/frontier_pass/manifest.lua'] or base:read(root..'rse/frontier_pass/manifest.lua')))()
  local function miniature(e,x,y)
   e.small=true
   for _,r in ipairs({{0,1,42,5},{0,10,40,5},{0,18,41,18}})do
    clear(e,x+r[1],y+r[2],r[3],r[4],function(yy)return e.get(x+43,yy)end)
   end
   for _,r in ipairs({{'CARTÃO',1},{'NOME',10},{'GRANA',19},{'DEX',25},{'TEMPO',31}})do
    e.bank=math.floor(e.get(x+43,y+r[2])/16)
    write(e,r[1],x,y+r[2],e.color(0))
   end
  end
  local e=editMap(man,'bg','bg','bg');e.bank=0
  label(e,'PASSE DA FRONTEIRA',8,0,128,16,e.get(8,1),e.color(255));
  label(e,'VOLTAR',181,1,49,13,e.get(229,2),e.color(90));
  miniature(e,134,86);e.save()
  for _,key in ipairs({'cancel','cancelHi'})do
   local e=editMap(man,key,'bg','bg',9);local bg=e.get(61,2);e.bank=math.floor(bg/16)
   label(e,'VOLTAR',13,1,49,13,bg,e.color(90));e.save()
  end
  local e=editMap(man,'mapAndCard','bg','bg',12)
  miniature(e,6,118);miniature(e,6,174);e.save()
 end
 if rse then
  local path=root..'rse_slot_machine/manifest.lua'
  local man=assert(loadstring(files[path] or base:read(path)))()
  local temporary=root..'rse_slot_machine/__caption_map.bin'
  local bytes={};for _,entry in ipairs(man.tilemaps.menu)do bytes[#bytes+1]=string.char(entry%256,math.floor(entry/256))end
  files[temporary]=table.concat(bytes)
  local proxy={gfx={menu={path=man.menuTiles}},maps={menu={path=temporary}},palettes=man.palettes}
  local e=editMap(proxy,'menu','menu','menu');e.small=true
  for _,r in ipairs({{'FICHAS',179,8,28,8},{'PRÊMIO',211,8,28,8}})do
   local bg=e.get(r[2],r[3]);e.bank=math.floor(bg/16)
   label(e,r[1],r[2],r[3],r[4],r[5],bg,e.color(255))
  end
  e.small=false;e.bank=math.floor(e.get(231,150)/16)
  label(e,'SAIR',196,149,25,8,e.get(222,152),e.color(255),e.color(100));e.save()
  local out=files[temporary];files[temporary]=nil
  for i=1,#out/2 do local a,b=out:byte(i*2-1,i*2);man.tilemaps.menu[i]=a+b*256 end
  files[path]=require('src.import.LuaWriter').encode(man)
 end
 if rse then
  local path=root..'rse/'..(rs and 'rs_contest_gfx' or 'contest_gfx')..'/manifest.lua'
  local man=assert(loadstring(files[path] or base:read(path)))()
  local e=edit4bpp(man.gfx.interface.path,128)
  for _,r in ipairs({{'LEGAL',0,32,40,16},{'BELO',40,32,40,16},{'FOFO',80,32,40,16},{'ESPERTO',80,48,40,16},{'DURO',80,64,40,16},
   {'APELO',72,8,32,8},{'DANO',72,16,32,8},{'APLAUSO',56,80,40,8}})do
   local bg=e.get(r[2]+r[4]-1,r[3]+1)
   label(e,r[1],r[2],r[3],r[4],r[5],bg,(r[1]=='APELO' or r[1]=='DANO') and 10 or 1);end;e.save()
  local e=edit4bpp(man.gfx.applause.path,64)
  label(e,'APLAUSO',6,6,43,9,e.get(6,6),5);e.save()
  local e=edit4bpp(man.gfx.next_turn.path,64);e.small=true
  -- Tile six is replaced by the turn digit at runtime; keep that slot free.
  label(e,'PRÓX. VEZ',0,0,47,8,0,1);e.save()
  if rs then
   local e=editMap(man,'title_sheet','results','results')
   for _,r in ipairs({{'NÍVEL NORMAL',0,0,72},{'NÍVEL SUPER',72,0,64},{'NÍVEL HIPER',136,0,64},{'NÍVEL MESTRE',0,16,72},{'CONEXÃO',72,16,64},
    {'CONCURSO LEGAL',136,16,80},{'CONCURSO BELO',0,32,88},{'CONCURSO FOFO',88,32,80},{'CONCURSO ESPERTO',168,32,80},{'CONCURSO DURO',0,48,80}})do
    local bg=e.get(r[2]+r[4]-1,r[3]+15);e.bank=math.floor(bg/16)
    label(e,r[1],r[2],r[3],r[4],16,bg,e.color(255));end;e.save()
  else
  local names={title='CONCURSO',title_normal='NÍVEL NORMAL',title_super='NÍVEL SUPER',title_hyper='NÍVEL HIPER',title_master='NÍVEL MESTRE',title_link='CONEXÃO',title_cool='LEGAL',title_beauty='BELO',title_cute='FOFO',title_smart='ESPERTO',title_tough='DURO'}
  for key,text in pairs(names)do
   local e=editMap(man,key,'results','results',man.maps[key].entries/2)
   local bg=e.get(0,0);e.bank=math.floor(bg/16)
   label(e,text,0,0,e.w,e.h,bg,e.color(255),e.color(80));e.save()
  end
 end
 end
 -- Shared PC buttons and the left information header. FRLG's source patch
 -- already contains Portuguese art; these additions cover native Hoenn art.
 if rse then
  local folder=root..'pokemon/storage/'
  for _,row in ipairs({{'button_party','EQUIPE'},{'button_close','FECHAR CAIXA'}})do
   local e=edit(folder..row[1]..'.png');local bg=e.get(3,5)
   label(e,row[2],4,3,row[1]=='button_party' and 62 or 64,10,bg,e.color(255),e.color(100));e.save()
  end
  local e=edit(folder..(rs and 'header.png' or 'interface_frame.png'))
  label(e,'DADOS',14,3,52,11,e.get(13,4),e.color(255),e.color(100));e.save()
  if rs then
   local e=edit(folder..'party_drawer.png')
   label(e,'EQUIPE',4,163,62,10,e.get(3,165),e.color(255),e.color(100));e.save()
  end
 end
 -- Naming button names are literal controller labels only where appropriate
 -- (SELECT/START/OK); descriptive English is replaced on all three engines.
 local folder=root..'naming/'
 for _,row in ipairs({{'page_swap_lower','MIN.'},{'page_swap_upper','MAI.'},{'page_swap_others','SÍM.'}})do
  local e=edit(folder..row[1]..'.png')
  local bg=e.indexed and 0 or {0,0,0,0}
  label(e,row[2],0,0,e.w,e.h,bg,e.color(255),e.color(90));e.save()
 end
 local e=edit(folder..'back_button.png')
 label(e,'APAGAR',5,4,29,10,e.get(7,7),e.color(70))
 label(e,'B',1,15,38,8,e.get(1,15),e.color(70));e.save()
 if rs then
  local e=edit(folder..'bg.png')
  label(e,'A: SELECIONAR',30,142,102,10,e.get(30,142),e.color(255),e.color(80));e.save()
 end
 -- RS uses its own vertical type sprites, including the five contest types.
 if rse then
  local e=edit(root..'rse/summary/move_types.png')
  assert(e.w==32 and e.h==23*16,'Native RS type sheet changed');e.small=true
  local names={'NORMAL','LUTADOR','VOADOR','VENENO','TERRA','PEDRA','INSETO','FANT.','AÇO','???',
   'FOGO','ÁGUA','GRAMA','ELÉTR.','PSÍQ.','GELO','DRAGÃO','SOMBRIO','LEGAL','BELO','FOFO','ESPERTO','DURO'}
  for i,name in ipairs(names)do
   local y=(i-1)*16
   label(e,name,1,y+2,30,11,e.get(1,y+4),e.color(255),e.color(100))
  end
  e.save()
 end
 local statusLabels={'ENV','PAR','SON','CON','QUE',false,'DES'}
 for _,path in ipairs({root..'rse/summary/status.png',root..'rse/party/status.png',
  root..'pokemon/summary/status_icons.rgba',root..'pokemon/party/status_icons.rgba'})do
  if files[path] then
   local e=edit(path,32,64);e.small=true
   assert(e.w==32 and (e.h==56 or e.h==64),'Native status sheet changed')
   for i,name in ipairs(statusLabels)do if name then
    local y=(i-1)*8
    label(e,name,8,y+1,16,6,e.get(8,y+3),e.color(255))
   end end
   e.save()
  end
 end
 -- Trainer cards contain their headings/badge captions in the background.
 if game=='emerald' then
  for star=0,4 do for _,suffix in ipairs({'','_female'})do
   local e=edit(root..'rse/trainer_card/front_'..star..suffix..'.png')
   label(e,suffix=='' and 'TREINADOR' or 'TREINADORA',22,19,92,9,e.get(22,19),e.color(0))
   label(e,'INSÍGNIAS',24,112,48,7,function(y)return e.get(72,y)end,e.color(255));e.save()
  end end
 elseif not rse then
  for star=0,4 do for _,suffix in ipairs({'','_female'})do
   local e=edit(root..'trainer_card/front_'..star..suffix..'.rgba',240,160)
   label(e,suffix=='' and 'TREINADOR' or 'TREINADORA',16,19,96,11,e.get(14,20),e.color(255))
   label(e,'INSÍGNIAS',18,121,48,7,e.get(70,124),e.color(255));e.save()
  end end
 end
 -- Ruby/Sapphire Pokédex labels are 4bpp OBJ tiles, consumed directly by
 -- the native renderer. Preserve the number sprites and controller badges.
 if rs then
  local path=root..'rse/pokedex/interface.gfx';local gfx=assert(files[path])
  local function sprite(tile)
   local px={};for y=0,31 do for x=0,63 do
    local b=gfx:byte((tile+math.floor(y/8)*8+math.floor(x/8))*32+y%8*4+math.floor(x%8/2)+1)
    px[y*64+x+1]=math.floor(b/2^(4*(x%2)))%16
   end end
   return {path=path,w=64,h=32,get=function(x,y)return px[y*64+x+1]end,
    set=function(x,y,c)assert(x>=0 and x<64 and y>=0 and y<32);px[y*64+x+1]=c end,
    save=function()
     local bytes={};for ty=0,3 do for tx=0,7 do for y=0,7 do for x=0,7,2 do
      local at=(ty*8+y)*64+tx*8+x+1;bytes[#bytes+1]=string.char(px[at]+16*px[at+1])
     end end end end
     gfx=gfx:sub(1,tile*32)..table.concat(bytes)..gfx:sub((tile+32)*32+1)
    end}
  end
  local e=sprite(64);clear(e,0,0,64,32,0);write(e,'BUSCAR',16,3,1,15);e.save()
  for _,row in ipairs({{160,'VISTOS'},{192,'PEGOS'}})do
   local e=sprite(row[1]);clear(e,16,3,32,11,0);write(e,row[2],20,8,1,15);e.save()
  end
  files[path]=gfx
 end

 -- PokéNav labels are native sprite atlases, not registry strings. Edit their
 -- logical rows while preserving each sprite's original frame arrangement.
 if rse then
  local nav=root..'rse/pokenav/'
  local function at(path,text,x,y,w,h,bgx,bgy,small)
   local e=edit(path);e.small=small
   local shadow=not path:match('/header.png$') and e.color(80) or nil
   label(e,text,x,y,w,h,e.get(bgx,bgy),e.color(255),shadow);e.save()
  end
  local options=rs and {
   {'options_main',{'MAPA DE HOENN','CONDIÇÃO','TREINADORES','FITAS','DESLIGAR'}},
   {'options_condition',{'EQUIPE','BUSCAR','VOLTAR'}},
   {'options_search',{'LEGAL','BELO','FOFO','ESPERTO','DURO','VOLTAR'}},
  } or {{'options',{'MAPA DE HOENN','CONDIÇÃO','DESLIGAR','CONTATOS','FITAS',
   'EQUIPE','BUSCAR','VOLTAR','LEGAL','BELO','FOFO','ESPERTO','DURO'}}}
  for _,row in ipairs(options)do
   local e=edit(nav..row[1]..'.png')
   for i,name in ipairs(row[2])do
    local y=(i-1)*16;local bg=e.get(110,y+8)
    clear(e,14,y+2,110,12,bg);write(e,name,15,y+4,e.color(255),e.color(80))
   end;e.save()
  end
  local heads={main_menu='MENU PRINCIPAL',condition='CONDIÇÃO',ribbons='FITAS'}
  heads[rs and 'trainers_eyes' or 'match_call']=rs and 'TREINADORES' or 'CONTATOS'
  if not rs then
   for key,name in pairs({party='EQUIPE',search='BUSCAR',cool='LEGAL',beauty='BELO',cute='FOFO',smart='ESPERTO',tough='DURO'})do heads[key]=name end
  end
  for key,name in pairs(heads)do
   local e=edit(nav..'lh_'..key..'.png');local pw,ph=e.w,e.h/2
   local get,set=e.get,e.set
   -- First frame followed horizontally by the second (half-width on big headers).
   e.get=function(x,y)return get(x%pw,y+(x>=pw and ph or 0))end
   e.set=function(x,y,c)return set(x%pw,y+(x>=pw and ph or 0),c)end
   local width=pw==64 and 96 or 64
   label(e,name,1,ph==32 and 5 or 1,width-5,ph==32 and 18 or 14,e.get(2,ph==32 and 8 or 4),e.color(255),e.color(80))
   e.save()
  end
  local e=edit(nav..'lh_hoenn_map.png')
  for i,name in ipairs({'HOENN','GERAL','ZOOM'})do
   local y=(i-1)*32;label(e,name,1,y+5,60,17,e.get(2,y+8),e.color(255),e.color(80))
  end;e.save()
  local header=rs and root..'rse/pokenav_shell/header.png' or nav..'header.png'
  at(header,'NAVEGADOR POKÉMON',20,1,168,18,20,3)
  -- The second header row is shown after the menu scrolls upwards.
  at(header,'POKÉNAV',136,177,104,14,136,178,true)
  if rs then
   local smallHeaders={party='EQUIPE',search='BUSCAR',cool='LEGAL',beauty='BELO',cute='FOFO',smart='ESPERTO',tough='DURO'}
   for key,name in pairs(smallHeaders)do at(root..'rse/pokenav_condition/header_'..key..'.png',name,1,2,59,12,2,4)end
   local helps={[0]='A: CONDIÇÃO  B: VOLTAR',[1]='A: MARCAS  B: VOLTAR',[2]='A: MARCAS  B: VOLTAR',[3]='A: MARCAR  B: VOLTAR',
    [4]='A: FITAS  B: VOLTAR',[5]='A: VER  B: VOLTAR',[6]='',[7]='A: GERAL  B: VOLTAR',
    [8]='A: ZOOM  B: VOLTAR',[9]='A: VER  B: VOLTAR',[10]='B: VOLTAR',[11]='B: VOLTAR'}
   for i,text in pairs(helps)do if text~='' then
    local e=edit(root..'rse/pokenav_shell/help_'..i..'.png')
    label(e,text,0,1,136,14,e.get(135,1),e.color(255));e.save()
   end end
  end
  local condition=root..'rse/'..(rs and 'pokenav_condition/' or 'pokenav_cr/')
  for _,name in ipairs(rs and {'cancel_inactive','cancel_selected'} or {'cancel','cancel_lit'})do
   local e=edit(condition..name..'.png');e.small=true
   label(e,'VOLTAR',4,4,23,7,e.get(4,4),e.color(0));e.save()
  end
  -- Contest graph labels: keep the native pentagon, fill and stat markers.
  for _,name in ipairs(rs and {'party','search'} or {'cond_bg','cond_bg_search'})do
   local e=edit(condition..name..'.png');e.small=true
   local search=name:find('search',1,true)
   local bg=e.get(140,30)
   local boxes=rs and {{'LEGAL',146,43,164,49},{'DURO',104,65,126,71},{'BELO',183,65,208,71},
    {'ESPERTO',113,124,135,130},{'FOFO',176,124,192,130}}
    or {{'LEGAL',145,42,167,48},{'DURO',102,65,130,71},{'BELO',179,65,209,71},
     {'ESPERTO',109,125,137,131},{'FOFO',173,125,195,131}}
   for _,r in ipairs(boxes)do
    -- Erase the original glyphs only. Filling the bounding rectangle would
    -- cut holes into the panel border and the colored contest-stat markers.
    for y=r[3]-1,r[5]+1 do for x=r[2]-1,r[4]+1 do
     local red,green,blue=e.rgb(e.get(x,y))
     if (red==99 and green==99 and blue==115) or (red==247 and green==255 and blue==255) then e.set(x,y,bg)end
    end end
    local n=0;for _ in chars(r[1])do n=n+1 end
    write(e,r[1],math.floor((r[2]+r[4]-(n*4-2))/2),r[3]+1,e.color(100),e.color(255))
   end;e.save()
  end
  if not rs then
   -- Native Emerald stores the green stat fill preblended over the background.
   -- Rebuild that blend from the translated background to avoid ghost English
   -- letters when a maximum condition polygon reaches a caption.
   local backdrop=love.image.newImageData(love.data.newByteData(files[condition..'cond_bg.png']))
   local fill=love.image.newImageData(love.data.newByteData(files[condition..'graph_fill.png']))
   for y=0,fill:getHeight()-1 do for x=0,fill:getWidth()-1 do
    local r,g,b,a=backdrop:getPixel(x,y)
    if a==0 then r,g,b=0,0,0 end
    local function blend(c,green)return math.min(31,math.floor((11*green+4*math.floor(c*31+0.5))/16))/31 end
    local _,_,_,alpha=fill:getPixel(x,y)
    fill:setPixel(x,y,blend(r,0),blend(g,31),blend(b,0),alpha)
   end end
   files[condition..'graph_fill.png']=fill:encode('png'):getString()
   local e=edit(nav..'zoom_text.png');e.small=true
   for i,name in ipairs({'CENTRO POKÉMON','LOJA POKÉMON','TORRE DE BATALHA','TENDA DE BATALHA','SALÃO DE CONCURSOS'})do
    local x=(i-1)*96
    label(e,name,x+8,0,88,8,e.indexed and 0 or {0,0,0,0},e.color(255));
   end;e.save()
   local e=edit(condition..'markings_menu.png');e.small=true
   label(e,'VOLTAR',0,44,32,16,e.get(30,45),e.color(0));e.save()
  end
 end
 return labels
end
