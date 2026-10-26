-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Bind complete localized title surfaces instead of forcing them through
-- the English atlas geometry. Native input, music and animation stay intact.
local T={}
function T.bind(data,compiled,prefix,version,virtualFiles)
 local title=data.field and data.field.title
 if not(title and compiled)then return{}end
 local bound={}
 local function use(field,path,w,h)
  local bytes=compiled.files[path];if not bytes then return end
  local pixels=love.image.newImageData(love.data.newByteData(bytes))
  local iw,ih=pixels:getDimensions()
  assert(iw==w and ih==h,'Unexpected localized title geometry: '..path)
  if field=='background'then
   local sky=compiled.catalogs.layouts and compiled.catalogs.layouts.title and compiled.catalogs.layouts.title.sky
   if not sky then
    local original=type(title.background)=='table'and title.background.path or title.background
    local base=require('src.render.Assets').imageData(assert(original))
    local r,g,b=base:getPixel(0,0);base:release();sky={r,g,b}
   end
   assert(#sky==3 and sky[1]>=0 and sky[1]<=1 and sky[2]>=0 and sky[2]<=1 and sky[3]>=0 and sky[3]<=1,'Invalid title backdrop')
   -- These portable recipe sheets leave palette colour 0 transparent. The
   -- native title expects an opaque BG, including Crystal's black backdrop.
   pixels:mapPixel(function(_,_,r,g,b,a)return r*a+sky[1]*(1-a),g*a+sky[2]*(1-a),b*a+sky[3]*(1-a),1 end)
   assert(virtualFiles,'Title backdrop needs a session asset store')[prefix..path]=pixels:encode('png'):getString()
  end
  pixels:release()
  title[field]=prefix..path;bound[field]=path
 end
 if version=='red'or version=='blue'then
  use('versionRibbon','assets/title/'..version..'_version.png',80,8)
  title.ulaContinuousRibbon=bound.versionRibbon~=nil
 elseif version=='yellow'then
  use('logo','assets/title/pokemon_logo.png',128,56)
  use('pikaBubble','assets/title/pika_bubble.png',56,40)
 elseif version=='gold'or version=='silver'or version=='crystal'then
  use('background','assets/title/'..(version=='crystal'and'crystal_screen'or'title_screen')..'.png',160,144)
  title.ulaTitleWindow=bound.background~=nil
 end
 return bound
end
function T.install(live)
 local Title=require('src.ui.TitleState');local state=Title.__ulaWholeTitle
 if state then state.live=live;return end
 state={live=live};Title.__ulaWholeTitle=state
 local draw=Title.draw
 Title.draw=function(self,...)
  if not state.live()then return draw(self,...)end
  local ribbon=self.title.ulaContinuousRibbon and self.version
  local window=self.title.ulaTitleWindow and self.gen2Background
  if not(ribbon or window)then return draw(self,...)end
  if ribbon then self.version=nil end
  local ok,result=pcall(draw,self,...)
  if ribbon then self.version=ribbon end
  if not ok then error(result,0)end
  local g=love.graphics;g.push('all');g.setColor(1,1,1,1)
  if ribbon then g.draw(ribbon,math.floor((160-ribbon:getWidth())/2),64)end
  if window then
   -- The cartridge window is above BG/OAM. In particular, Suicune must not
   -- cover Crystal's copyright line when its frame reaches the bottom row.
   local w,h=window:getDimensions()
   g.draw(window,g.newQuad(0,136,160,8,w,h),0,136)
  end
  g.pop();return result
 end
end
return T
