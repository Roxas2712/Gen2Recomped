-- Unicode-safe naming, scoped to the active Asian language profile.
-- Hangul composition follows Unicode syllable arithmetic. Unsupported retail
-- glyphs leave the previous input intact; no replacement or truncation occurs.
local M={}
local function chars(text)
 local out={};for ch in text:gmatch('[%z\1-\127\194-\244][\128-\191]*')do out[#out+1]=ch end;return out
end
local function cp(ch)
 local a,b,c=ch:byte(1,3)
 if a<128 then return a elseif a<224 then return (a-192)*64+b-128 end
 return (a-224)*4096+(b-128)*64+c-128
end
local function utf(n)return string.char(224+math.floor(n/4096),128+math.floor(n/64)%64,128+n%64)end
local initial=chars('ㄱㄲㄴㄷㄸㄹㅁㅂㅃㅅㅆㅇㅈㅉㅊㅋㅌㅍㅎ')
local vowel=chars('ㅏㅐㅑㅒㅓㅔㅕㅖㅗㅘㅙㅚㅛㅜㅝㅞㅟㅠㅡㅢㅣ')
local final=chars(' ㄱㄲㄳㄴㄵㄶㄷㄹㄺㄻㄼㄽㄾㄿㅀㅁㅂㅄㅅㅆㅇㅈㅊㅋㅌㅍㅎ')
local function indexes(rows)local out={};for i,ch in ipairs(rows)do out[ch]=i-1 end;return out end
local L,V,T=indexes(initial),indexes(vowel),indexes(final)
local doubleV={['ㅗㅏ']='ㅘ',['ㅗㅐ']='ㅙ',['ㅗㅣ']='ㅚ',['ㅜㅓ']='ㅝ',['ㅜㅔ']='ㅞ',['ㅜㅣ']='ㅟ',['ㅡㅣ']='ㅢ'}
local doubleT={['ㄱㅅ']='ㄳ',['ㄴㅈ']='ㄵ',['ㄴㅎ']='ㄶ',['ㄹㄱ']='ㄺ',['ㄹㅁ']='ㄻ',['ㄹㅂ']='ㄼ',['ㄹㅅ']='ㄽ',['ㄹㅌ']='ㄾ',['ㄹㅍ']='ㄿ',['ㄹㅎ']='ㅀ',['ㅂㅅ']='ㅄ'}
local splitT={};for pair,ch in pairs(doubleT)do splitT[ch]=chars(pair)end
function M.add(text,ch,korean,maxLength,supported)
 local rows=chars(text);local last=rows[#rows];local candidate
 if korean and last then
  local l,v,t;local n=cp(last)-0xac00
  if n>=0 and n<11172 then l=math.floor(n/588);v=math.floor(n/28)%21;t=n%28 end
  if L[last] and V[ch] then candidate=utf(0xac00+L[last]*588+V[ch]*28)
  elseif l and t==0 and V[ch] and doubleV[vowel[v+1]..ch]then candidate=utf(0xac00+l*588+V[doubleV[vowel[v+1]..ch]]*28)
  elseif l and t==0 and T[ch] and T[ch]>0 then candidate=utf(0xac00+l*588+v*28+T[ch])
  elseif l and t>0 and T[ch] and doubleT[final[t+1]..ch]then candidate=utf(0xac00+l*588+v*28+T[doubleT[final[t+1]..ch]])
  elseif l and t>0 and V[ch] then
   local pair=splitT[final[t+1]];local lead=pair and pair[2] or final[t+1]
   if L[lead] and #rows<maxLength then
    local a=utf(0xac00+l*588+v*28+(pair and T[pair[1]] or 0));local b=utf(0xac00+L[lead]*588+V[ch]*28)
    if supported(a) and supported(b) then rows[#rows]=a;rows[#rows+1]=b;return table.concat(rows)end
   end
   return text
  end
 end
 if candidate then
  if supported(candidate) then rows[#rows]=candidate;return table.concat(rows)end
  -- A retail font may omit an intermediate syllable (e.g. 슽). Keep
  -- its consonant pending as a visible jamo so the next vowel can form 트.
  if #rows<maxLength and supported(ch)then return text..ch end
  return text
 end
 if #rows<maxLength and supported(ch)then return text..ch end
 return text
end
function M.delete(text,korean)
 local rows=chars(text);local ch=rows[#rows];if not ch then return text end
 local n=cp(ch)-0xac00
 if korean and n>=0 and n<11172 then
  local l=math.floor(n/588);local v=math.floor(n/28)%21;local t=n%28
  if t>0 then local pair=splitT[final[t+1]];rows[#rows]=utf(0xac00+l*588+v*28+(pair and T[pair[1]] or 0))
  else rows[#rows]=initial[l+1]end
 else rows[#rows]=nil end
 return table.concat(rows)
end
function M.install(mod,patch,fontOnly)
 local Naming=require('src.ui.gen2.NamingScreen');local Font=require('src.render.Font')
 local state=Naming.__ulaAsianInput
 if not state then
  state={rows=Naming.rows,add=Naming.addCharacter,delete=Naming.deleteCharacter,toggle=Naming.toggleCase,draw=Naming.drawEntry,clear=Naming.clearPanel,cursor=Naming.drawCursorBox};Naming.__ulaAsianInput=state
  Naming.clearPanel=function(self,x,y,w,h)
   if state.active()and not state.fontOnly and(y==self:keyboardTop()or y==16)then y=y-1;h=h+1 end
   return state.clear(self,x,y,w,h)
  end
  Naming.drawCursorBox=function(self,x,y,width)
   if not state.active()or state.fontOnly then return state.cursor(self,x,y,width)end
   local G=love.graphics;G.setColor(0,0,0,1);G.setLineWidth(1)
   G.rectangle('line',x*8-1.5,(y-1)*8-1.5,(width or 1)*8+3,19)
   G.setColor(1,1,1,1)
  end
  Naming.rows=function(self)if state.active()and not state.fontOnly then return state.pages[((self.ulaPage or 0)%#state.pages)+1]else return state.rows(self)end end
  Naming.toggleCase=function(self)if state.active()and not state.fontOnly then self.ulaPage=((self.ulaPage or 0)+1)%#state.pages else return state.toggle(self)end end
  Naming.addCharacter=function(self,ch)
   if not state.active()then return state.add(self,ch)end
   if ch then self.text=M.add(self.text,ch,state.korean,state.fontOnly and self.maxLength or math.min(self.maxLength,5),function(c)return c:byte()<128 or state.fontmap[c]~=nil or ((Font.split(c)[1] or {}).code or 0x7f)~=0x7f end)end
  end
  Naming.deleteCharacter=function(self)if state.active()then self.text=M.delete(self.text,state.korean)else return state.delete(self)end end
  Naming.drawEntry=function(self,tx,ty)
   if not state.active()then return state.draw(self,tx,ty)end
   local G=love.graphics;local rows=chars(self.text);G.setColor(0,0,0,1)
   for i=1,(state.fontOnly and self.maxLength or math.min(self.maxLength,math.max(5,#rows)))do
    local x=(tx+i-1)*8
    if rows[i]then Font.draw(rows[i],x,ty*8)
    else G.rectangle('fill',x+1,ty*8+(i==#rows+1 and 7 or 4),6,1)end
   end
   G.setColor(1,1,1,1)
  end
 end
 local pages={}
 local function page(text)
  local all={};for _,c in ipairs(chars(text))do if c:byte()<128 or patch.fontmap[c]then all[#all+1]=c end end
  for begin=1,#all,36 do local rows={};for y=1,4 do rows[y]={};for x=1,9 do rows[y][x]=all[begin+(y-1)*9+x-1] or ' 'end end;pages[#pages+1]=rows end
 end
 if mod.language=='ko'then
  page('ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆㅉㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣㅐㅒㅔㅖㅘㅙㅚㅝㅞㅟㅢ!?-0123456789')
 else
  page('あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんぁぃぅぇぉゃゅょっがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー')
  page('アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンァィゥェォャュョッガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポー')
 end
 page('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789');page('abcdefghijklmnopqrstuvwxyz!?-.,     ')
 state.active=patch.active;state.korean=not fontOnly and mod.language=='ko';state.fontOnly=fontOnly;state.fontmap=patch.fontmap;state.pages=pages
end
return M
