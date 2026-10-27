return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  local report={status='running',edition=require('src.core.GameVersion').get(),preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key,wait)
    game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(wait or 12)
  end
  persist();U.freshSave(game);U.teleport(game,'MAP_G00_N16',10,12,'up')
  local mon=require('src.pokemon.Pokemon').new(game.data,'TREECKO',20)
  mon.nickname='ABCDEFGHIJ';mon.moves={{id='CUT',pp=30},{id='ROCK_SMASH',pp=15},{id='ROCK_TOMB',pp=10},{id='LEAF_BLADE',pp=15}}
  game.save.party={mon}
  local screen=require('src.ui.Gen3SummaryMenu').new(game,{mon=mon,party=game.save.party,partyIndex=1})
  game.stack:push(screen);U.wait(30);press('right',30);press('right',30);press('a',15)
  assert(screen.rsNative and screen.moveSelect and screen.moveIndex==1)
  local Cache=require('src.import.CacheFs');local raw={}
  for _,path in ipairs({'data/generated/gba/rse/summary/move_select.png','data/generated/gba/rse/summary/manifest.lua'})do
    raw[path]=assert(Cache.read(path))
  end
  local function shot(name)
    -- Freeze only the prepared fixture's blink phase so both outlines are visible.
    screen.rsNative.scene._tick=0
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  shot('native-cursor-cut-30-of-30')
  local S=require('src.core.SaveSerializer');local before=S.encode(game.save);local rng=love.math.getRandomState()
  screen:draw();assert(S.encode(game.save)==before and love.math.getRandomState()==rng)
  press('a');press('down');shot('native-cursor-two-swap-outlines');press('a',15)
  assert(mon.moves[1].id=='ROCK_SMASH'and mon.moves[1].pp==15 and mon.moves[2].id=='CUT'and mon.moves[2].pp==30)
  shot('native-cursor-after-move-swap')
  press('b',15);press('b',60);assert(game.stack:top()==game.overworld)
  for path,bytes in pairs(raw)do assert(Cache.read(path)==bytes,'Native summary rewrote imported cursor assets')end
  report.sourceAssetsUnchanged=true;report.originalPpPreserved=true;report.drawSaveRngUnchanged=true
  report.status='pass';persist();print('PASS_RS_SUMMARY_CURSOR_FLIPS');love.event.quit(0)
end
