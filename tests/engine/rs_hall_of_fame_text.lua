-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local X=require('src.import.RomExtractorGen3')
local function fixture(edition,name)
  -- Owned ASCII bytes and a synthetic pointer pool through the real decoder.
  local bytes={};for i=1,0x6000 do bytes[i]=0 end
  local labels={'Welcome to the HALL OF FAME!','CHAMPION','HALL OF FAME No.',
    'SAVING','No. ','Lv. ','IDNo.',name}
  for i,text in ipairs(labels) do
    local pos=0x4000+i*100;local pointer=0x08000000+pos
    for n=0,3 do bytes[0x1f00+(i-1)*4+n+1]=math.floor(pointer/2^(n*8))%256 end
    for n=1,#text do bytes[pos+n]=text:byte(n) end
    bytes[pos+#text+1]=255
  end
  local raw={};for i,b in ipairs(bytes) do raw[i]=string.char(b) end
  local chars={};for i=32,126 do chars[i]=string.char(i) end
  return X.new(table.concat(raw),edition,{charmap=chars})
end
for _,edition in ipairs{'ruby','sapphire'} do
  local x=fixture(edition,'NAME /');local text,why=x:hallOfFameText(0x2000)
  T.check(text~=nil,'RS ceremony must keep its original slash label: '..tostring(why))
  if text then T.eq(text.name,'NAME /');T.eq(text.level,'Lv. ');T.eq(text.dexNo,'No. ') end
  text,why=fixture(edition,'NAME'):hallOfFameText(0x2000)
  T.eq(text,nil,'RS must not substitute the other edition label')
  T.check(why and why:find('name',1,true)~=nil)
end
local text=assert(fixture('emerald','NAME'):hallOfFameText(0x2000))
T.eq(text.name,'NAME','Emerald keeps its original exact label')
T.eq(fixture('emerald','NAME /'):hallOfFameText(0x2000),nil,'RS matching cannot broaden Emerald admission')
for _,name in ipairs{'PLAYER NAME','NAME / EXTRA','', 'OTHER'} do
  T.eq(fixture('sapphire',name):hallOfFameText(0x2000),nil,'unrelated or incomplete text is rejected')
end
local function creditsFixture(edition,withPages)
  local bytes={};for i=1,0x4000 do bytes[i]=0 end
  local function word(at,value)
    for n=0,3 do bytes[at+n+1]=math.floor(value/2^(n*8))%256 end
  end
  for i=0,59 do
    local text='OWNED CREDIT PERSON '..i
    local at=0x1000+i*64
    for j=1,#text do bytes[at+j]=text:byte(j) end
    bytes[at+#text+1]=255
    bytes[0x100+i*8+1]=i%8 -- native RS's one-byte record, followed by padding
    word(0x100+i*8+4,0x08000000+at)
  end
  if withPages then
    for i=0,119 do word(0x600+i*4,0x08000000+0x100+(i%60)*8) end
  end
  local raw={};for i,b in ipairs(bytes) do raw[i]=string.char(b) end
  local chars={};for i=32,126 do chars[i]=string.char(i) end
  return X.new(table.concat(raw),edition,{charmap=chars})
end
for _,edition in ipairs{'ruby','sapphire'} do
  local got,why=creditsFixture(edition,true):creditsPages()
  T.check(got~=nil,'RS roll has no Emerald title byte: '..tostring(why))
  if got then
    T.eq(#got.entries,60);T.eq(#got.pages,24);T.eq(#got.pages[1],5)
    T.eq(got.pages[1][1].text,'OWNED CREDIT PERSON 0')
    T.eq(got.pages[13][1].text,got.pages[1][1].text,'repeated page pointers retain original order')
  end
  T.eq(creditsFixture(edition,false):creditsPages(),nil,'a record run without a closed page table is rejected')
end
T.eq(creditsFixture('emerald',true):creditsPages(),nil,'Emerald still requires its original heading records')
T.finish('RS Hall of Fame label and original credits records, closed page tables and Emerald isolation')
