-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- The fork has one naming controller for all GB/GBC games. Reuse the reviewed
-- Hangul arithmetic, while adapting its glyph array and keyboard interface.
local M={}
function M.chars(text)
 local out={};for c in text:gmatch('[%z\1-\127\194-\244][\128-\191]*')do out[#out+1]=c end;return out
end
function M.pages(language,fontmap)
 local pages={}
 local function add(text)
  local all={};for _,c in ipairs(M.chars(text))do if c:byte()<128 or fontmap[c]then all[#all+1]=c end end
  for first=1,#all,32 do
   local rows={}
   for r=1,4 do rows[r]={};for col=1,8 do rows[r][col]=all[first+(r-1)*8+col-1]or' 'end end
   rows[5]={'ED'};rows[6]={'lower case'};pages[#pages+1]=rows
  end
 end
 if language=='ko'then
  add('ㄱㄴㄷㄹㅁㅂㅅㅇㅈㅊㅋㅌㅍㅎㄲㄸㅃㅆㅉㅏㅑㅓㅕㅗㅛㅜㅠㅡㅣㅐㅒㅔㅖㅘㅙㅚㅝㅞㅟㅢ')
 else
  add('あいうえおかきくけこさしすせそたちつてとなにぬねのはひふへほまみむめもやゆよらりるれろわをんぁぃぅぇぉゃゅょっがぎぐげござじずぜぞだぢづでどばびぶべぼぱぴぷぺぽー')
  add('アイウエオカキクケコサシスセソタチツテトナニヌネノハヒフヘホマミムメモヤユヨラリルレロワヲンァィゥェォャュョッガギグゲゴザジズゼゾダヂヅデドバビブベボパピプペポー')
 end
 add('ABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789!?-.,');add('abcdefghijklmnopqrstuvwxyz')
 return pages
end
function M.install(mod,own)
 local Naming=require('src.ui.NamingScreen');local Runtime=require('src.mods.Runtime')
 local marker='ula.fork.asian-input';mod.events:on(marker,function()end)
 local state=Naming.__ulaForkAsianInput
 if not state then
  state={new=Naming.new,grid=Naming.grid,flip=Naming.flipPage,update=Naming.update};Naming.__ulaForkAsianInput=state
  local function active(self)return state.live and state.live()and(state.language=='ja'or state.language=='ko')and not(self and self.pages)end
  Naming.new=function(game,opts)
   local self=state.new(game,opts)
   if active(self)then self.maxLen=math.min(self.maxLen,5)end
   return self
  end
  Naming.grid=function(self)
   if active(self)then return state.pages[((self.ulaPage or 0)%#state.pages)+1]end
   return state.grid(self)
  end
  Naming.flipPage=function(self)
   if not active(self)then return state.flip(self)end
   self.ulaPage=((self.ulaPage or 0)+1)%#state.pages;self.row=math.min(self.row,6);self.col=math.min(self.col,#self:grid()[self.row])
  end
  Naming.update=function(self,dt)
   if not active(self)or state.language~='ko'then return state.update(self,dt)end
   local input=self.game.input
   if input:wasPressed('b')then self.glyphs=M.chars(state.arithmetic.delete(table.concat(self.glyphs),true));return end
   if input:wasPressed('a')and self.row<=4 and not input:wasPressed('start')and not input:wasPressed('select')then
    local c=self:grid()[self.row][self.col]
    self.glyphs=M.chars(state.arithmetic.add(table.concat(self.glyphs),c,true,self.maxLen,function(ch)return ch:byte()<128 or state.fontmap[ch]~=nil end))
    return
   end
   return state.update(self,dt)
  end
 end
 local bus=Runtime.events;state.live=function()return Runtime.events==bus and Runtime.wants(marker)end
 state.arithmetic=own('gb/runtime/asian_input.lua')
 return {set=function(_,language,profile)
  state.language=language;state.fontmap=profile and profile.fontmap or{};state.pages=M.pages(language,state.fontmap)
 end}
end
return M
