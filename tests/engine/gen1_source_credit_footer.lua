-- Native launcher draw and scroll owners; only the graphics device is stubbed.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit')
local run=T.sdk.loadNone({data=T.fixtures.fresh(),fs=T.sdk.memfs({})})
love.system=love.system or {}
love.system.getOS=function()return 'Unknown'end
local Importer=require('src.import.RomImporter')
local g=love.graphics
local dimensions,printf,setFont=g.getDimensions,g.printf,g.setFont
local width,height=960,720
g.getDimensions=function()return width,height end
local printed,currentFont={},nil
g.setFont=function(font)currentFont=font;return setFont(font)end
g.printf=function(text,x,y,w,...)
  if type(text)=='string'and text:find('Based on the Pokemon Gen 1',1,true)then
    printed[#printed+1]={text=text,x=x,y=y,width=w,font=currentFont}
  end
  return printf(text,x,y,w,...)
end
local ui=Importer.new(function()end)
for _,size in ipairs({{960,720},{480,360},{1280,960}})do
  width,height=size[1],size[2]
  for _,tab in ipairs({'red','gold','crystal','emerald'})do
    ui.tab=tab;printed={}
    local ok,why=pcall(ui.draw,ui)
    T.check(ok,'actual native launcher still draws with wrapped attribution: '..tostring(why))
    local line=printed[#printed]
    T.check(line~=nil,'native launcher renders the original project credit')
    if line then
      T.check(line.text:find('by BOIS CLUB GAMES, LLC',1,true)~=nil,'credit retains original rights holder')
      T.check(line.text:find('https://github.com/bryanthaboi/gen1recomp',1,true)~=nil,'credit retains source project link')
      local _,lines=line.font:getWrap(line.text,line.width)
      local bottom=line.y+math.max(1,#lines)*line.font:getHeight()
      for _,button in ipairs(ui.donateButtons or {})do
        T.check(button.y>=bottom,'native footer reserves the full wrapped credit before donation controls')
      end
    end
  end
end
g.getDimensions,g.printf,g.setFont=dimensions,printf,setFont
run.release()
T.finish('Gen1 source attribution through native launcher footer')
