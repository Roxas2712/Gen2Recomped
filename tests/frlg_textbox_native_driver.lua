-- Prepared real-renderer dialogue probes; no ordinary-story claim.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');local Text=require('src.render.TextBox')
 local S=require('src.core.SaveSerializer');local out=assert(os.getenv('EDITION_QA_OUT'))
 local Assets=require('src.render.Assets');local RG=require('src.import.RomGba')
 assert(V.isFRLG() and love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'))
 local r={edition=V.get(),status='running',preparedTextFixture=true,captures={},boxes={}}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(r));f:close()end
 U.freshSave(game);U.teleport(game,'MAP_G04_N00',4,6,'up');U.wait(90)
 local world=game.stack:top()
 local f=assert(io.open(assert(os.getenv('POKEPORT_IMPORT_ROM')),'rb'));local raw=f:read('*a');f:close()
 local manifest=J.decode(assert(love.filesystem.read('tools/rom_manifest_'..V.get()..'.json')))
 local pixels=0
 for _,row in ipairs({{'dialogueFrame','gMenuMessageWindow_Gfx',0,18},
   {'signpostFrame','gSignpostWindow_Gfx',1,19},{'standardFrame','gStdTextWindow_Gfx',3,9}})do
  local record=assert(game.data.font[row[1]])
  local at=assert(manifest.symbols[row[2]]);local pal=assert(manifest.symbols.gTextWindowPalettes)+row[3]*32
  local palette=RG.palette({raw:byte(pal+1,pal+32)});local image=love.image.newImageData(Assets.resolve(record.image))
  assert(image:getWidth()==row[4]*8 and image:getHeight()==8)
  for tile=0,row[4]-1 do for y=0,7 do for x=0,7 do
   local byte=raw:byte(at+tile*32+y*4+math.floor(x/2)+1);local index=math.floor(byte/16^(x%2))%16
   local r,g,b,a=image:getPixel(tile*8+x,y)
   assert(math.floor(a*255+.5)==(index==0 and 0 or 255),'Frame alpha differs from ROM')
   if index~=0 then local color=palette[index+1]
    assert(math.floor(r*255+.5)==color[1] and math.floor(g*255+.5)==color[2] and math.floor(b*255+.5)==color[3],'Frame pixels differ from ROM')
   end
   pixels=pixels+1
  end end end
 end
 assert(pixels==2944);r.nativeFramePixelChecks=pixels
 local P=require('src.import.Gen3FrlgPresentation');local Fs=require('src.import.CacheFs')
 assert(#P.textMissing(V.get(),Fs)==0)
 local fontRaw=assert(Fs.read('data/generated/font.lua'))
 local wrong=fontRaw:gsub('ROM:gfx %x+, gTextWindowPalettes%[0%] %x+','ROM:gfx 0000000, gTextWindowPalettes[0] 0000000')
 assert(wrong~=fontRaw)
 assert(#P.textMissing(V.get(),{read=function()return wrong end,exists=Fs.exists})>0)
 r.rejectsWrongEditionFrame=true
 local function shot(name,box)
  local save=S.encode(game.save);local rng=love.math.getRandomState()
  local ok,why=require('src.render.GraphicsScope').call(box.draw,box);assert(ok,why)
  assert(save==S.encode(game.save)and rng==love.math.getRandomState())
  assert(U.shot(game,out..'/'..name..'.png'));r.captures[#r.captures+1]=name
  r.boxes[name]={tx=box.boxTx,ty=box.boxTy,tw=box.boxTw,th=box.boxTh,textX=box.textX,line1Y=box.line1Y,line2Y=box.line2Y,maxPixels=box.maxPixels}
  persist()
 end
 local function press(k,n)game.input:overlayPressed(k);U.wait(1);game.input:overlayReleased(k);U.wait(n or 18)end
 local function open(text,opts)local box=Text.new(game,text,nil,opts);game.stack:push(box);for _=1,1200 do U.wait(1);if box.done or box.waiting then break end end;return box end
 persist()
 local b=open('Hello, there! Glad to meet you!\nWelcome to the world of POKéMON!')
 shot('field-dialogue',b)
 press('a',90);shot('field-dialogue-next',b)
 while game.stack:top()~=world do press('b',30)end
 b=open('This is a sign.\nPALLET TOWN',{signpost=true});shot('field-signpost',b)
 while game.stack:top()~=world do press('b',30)end
 b=open('A second line of conversation.\nA third line follows here.\vThe final line stays readable.')
 shot('field-scroll-before',b);press('a',120);shot('field-scroll-after',b)
 while game.stack:top()~=world do press('b',30)end
 r.status='pass';persist();print('PASS_FRLG_NATIVE_TEXT_PROBE');love.event.quit()
end
