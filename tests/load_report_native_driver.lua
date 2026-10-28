-- Exercise the host load notice with the actual cartridge font and renderer.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Font=require('src.render.Font');local Serialize=require('src.core.SaveSerializer')
  local Report=require('src.ui.QuarantineReport')
  local edition=require('src.core.GameVersion').get()
  assert(love.filesystem.getIdentity():match('^oasc%-edition%-qa%-'..edition..'%-'))
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local result={edition=edition,status='running',preparedReportFixture=true,
    continuousStory=false,captures={},cases={}}
  local function persist()
    local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(result));f:close()
  end
  for _,event in ipairs({'keypressed','keyreleased','mousepressed','mousereleased'})do
    love[event]=function()end
  end
  game.input:reset()
  local parent=game.stack:top()
  local report={recovered='bak',lostMail={{why='Invalid letter from Pokémon'}},lostItems={}}
  for i=1,20 do report.lostItems[i]={id='LONG_ITEM_'..i..'_'..string.rep('W',60),count=i}end
  local screen=Report.new(game,report);game.stack:push(screen);U.wait(5)
  local m=screen.metrics
  assert(m.glyph==Font.glyphHeight()and m.step>=m.glyph)
  assert(m.first>=8+m.glyph and m.first+(m.visible-1)*m.step+m.glyph<=m.footer-4)
  assert(m.footer+m.glyph<=m.height-6)
  for _,line in ipairs(screen.lines)do
    assert(Font.width(line)<=m.textWidth,'Report text exceeds its actual pixel width')
  end
  assert(table.concat(screen.lines):find('Invalid letter from Pokémon',1,true),'UTF-8 text was clipped')
  assert(screen:maxOffset()>0)
  local function shot(name)
    local save=Serialize.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()screen:draw()end))
    assert(save==Serialize.encode(game.save)and rng==love.math.getRandomState())
    assert(U.shot(game,out..'/'..name..'.png'));result.captures[#result.captures+1]=name;persist()
  end
  shot('load-report-first-page')
  for _=1,screen:maxOffset()+2 do U.tap(game,'down');U.wait(1)end
  assert(screen.offset==screen:maxOffset());shot('load-report-final-page')
  U.tap(game,'up');U.wait(1);assert(screen.offset==screen:maxOffset()-1)
  U.tap(game,'a');U.wait(1);assert(game.stack:top()==parent)
  screen=Report.new(game,{});game.stack:push(screen);U.wait(2)
  assert(screen:maxOffset()==0);shot('load-report-empty')
  U.tap(game,'b');U.wait(1);assert(game.stack:top()==parent)
  result.metrics=m;result.cases={nonoverlappingRows=true,pixelWidthWrapping=true,
    unicodeRetained=true,scrollAndClamp=true,emptyReport=true,returnToParent=true,
    drawSaveAndRngImmutable=true}
  result.status='pass';persist();print('PASS_LOAD_REPORT_NATIVE '..edition);love.event.quit(0)
end
