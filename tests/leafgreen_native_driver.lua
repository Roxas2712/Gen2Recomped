-- Native rendered smoke after an actual ROM import, with all mods disabled.
return function()
  local G = require('src.core.Game')
  local V = require('src.core.GameVersion')
  local function frames(n) for _=1,n do coroutine.yield() end end
  assert(V.get() == 'leafgreen')
  assert(G.data.constants.gen == 3 or G.data.constants.gen3Bag)
  local title = assert(G.data.constants.gen3FRLGTitle)
  assert(title.effect == 'leaves' and title.cry == 'VENUSAUR')
  assert(#title.streakY == 8)
  assert(title.images.flames.frames == 11)
  assert(G.data.pokemon.BULBASAUR and G.data.pokemon.VENUSAUR)
  assert(G.data.maps and next(G.data.maps))
  print('[driver] LeafGreen imported native dataset and title')
  frames(220)
  love.graphics.captureScreenshot('leafgreen-title.png')
  frames(3)
  local result={status='pass',edition=V.get(),stage='native-import-and-title',
    allModsDisabled=true,physicalIOSDeviceTested=false,fullStoryTested=false}
  love.filesystem.write('edition-result.json',require('src.link.Json').encode(result))
  print('[driver] PASS LeafGreen native import and rendered title')
  love.event.quit(0)
end
