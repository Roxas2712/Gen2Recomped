-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared title/audio lifecycle acceptance, separate from campaign saves.
return function(game)
 local U=require('tests.drivers.util');local J=require('src.link.Json')
 local V=require('src.core.GameVersion');assert(V.isFRLG())
 local Title=require('src.ui.Gen3TitleFRLG');local Music=require('src.core.Music')
 local out=assert(os.getenv('EDITION_QA_OUT'))
 for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
  'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
  'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
 game.input:reset()
 local report={edition=V.get(),preparedFixture=true,continuousStory=false,status='running'}
 local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
 local function waitFor(fn,frames,message)
  for _=1,frames do if fn()then return end;U.wait(1)end
  error(message)
 end
 U.tap(game,'b');U.wait(10);U.tap(game,'b')
 waitFor(function()local top=game.stack:top();return getmetatable(top)==Title and top.phase=='run'end,2000,'Original title did not reach its run scene')
 -- Recreate the existing native BGM service that remains after field/credits.
 Music.nativeCommand(game.data,'playbgm',278)
 local title=game.stack:top()
 waitFor(function()return title.state.title.scene==4 end,3200,'Original idle-title restart was not reached')
 report.originalRestartObserved=true;persist()
 assert(U.shot(game,out..'/native-title-restart-start.png'))
 waitFor(function()
  if Music.current()==nil then report.nativeSongReleased=true end
  return game.stack:top()~=title
 end,800,'Title restart remained parked after the native music fade')
 assert(report.nativeSongReleased,'Title restart never released its native song')
 report.originalRestartCompleted=true;persist()
 assert(U.shot(game,out..'/native-title-restart-completed.png'))
 report.status='pass';persist();print('PASS_NATIVE_FRLG_TITLE_MUSIC '..V.get());love.event.quit(0)
end
