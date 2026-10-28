-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Prepared field text fixtures; original text keys, normal input and renderer.
return function(game)
  local U,J=require('tests.drivers.util'),require('src.link.Json')
  local S=require('src.core.SaveSerializer');local Box=require('src.render.TextBox')
  local edition=require('src.core.GameVersion').get();assert(edition=='ruby'or edition=='sapphire')
  local out=assert(os.getenv('EDITION_QA_OUT'))
  for _,event in ipairs{'keypressed','keyreleased','textinput','gamepadpressed','gamepadreleased',
    'joystickpressed','joystickreleased','joystickaxis','joystickhat','touchpressed','touchreleased',
    'touchmoved','mousepressed','mousereleased'}do love[event]=function()end end
  game.input:reset();U.freshSave(game)
  game.save.party={require('src.pokemon.Pokemon').new(game.data,'TREECKO',10)}
  require('src.core.SaveData').validate(game.save,game.data)
  U.teleport(game,'MAP_G24_N11',26,24,'up');U.wait(60)
  local values=assert(game.data.constants.gen3RsPlaceholders).values
  assert(values.VERSION==(edition=='ruby'and'RUBY'or'SAPPHIRE'))
  assert(values.EVIL_TEAM==(edition=='ruby'and'MAGMA'or'AQUA'))
  assert(values.EVIL_LEADER==(edition=='ruby'and'MAXIE'or'ARCHIE'))
  assert(values.EVIL_LEGENDARY==(edition=='ruby'and'GROUDON'or'KYOGRE'))
  assert(Box.substitute(game,'{AQUA}/{MAGMA}')=='AQUA/MAGMA','Explicit literal names must never swap')
  local report={status='running',edition=edition,preparedFixture=true,continuousStory=false,captures={}}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  local function press(key)game.input:overlayPressed(key);U.wait(1);game.input:overlayReleased(key);U.wait(12)end
  local function shot(name)
    local before=S.encode(game.save);local rng=love.math.getRandomState();local top=game.stack:top()
    assert(require('src.render.GraphicsScope').call(top.draw,top))
    assert(before==S.encode(game.save)and rng==love.math.getRandomState(),'Dialogue draw changed save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function close(box)
    for _=1,80 do if game.stack:top()~=box then break end;press('a');U.wait(15)end
    assert(game.stack:top()==game.overworld,'Text did not return to its field owner')
  end
  local key,text
  for k,v in pairs(game.data.text)do
    if type(v)=='string'and v:find('No one who crosses TEAM ',1,true)then assert(not key,'Ambiguous native forest dialogue');key,text=k,v end
  end
  assert(key and text:find('{EVIL_TEAM}',1,true),'Actual imported forest text lost its native role')
  local callbacks=0;local box=Box.new(game,text,function()callbacks=callbacks+1 end);game.stack:push(box)
  local target
  for page,lines in ipairs(box.pages)do if table.concat(lines,' '):find('TEAM '..values.EVIL_TEAM,1,true)then target=page end end
  assert(target,'Rendered forest dialogue has the wrong team')
  for _=1,100 do if box.pageIndex==target and box.waiting then break end;U.wait(40);if box.pageIndex<target then press('a')end end
  assert(box.pageIndex==target and box.waiting);shot('native-rs-forest-own-team');close(box);assert(callbacks==1)
  local roleText='{EVIL_TEAM}/{EVIL_LEADER}/{EVIL_LEGENDARY}\n{GOOD_TEAM}/{GOOD_LEADER}/{GOOD_LEGENDARY}'
  local rendered=Box.substitute(game,roleText)
  assert(rendered==values.EVIL_TEAM..'/'..values.EVIL_LEADER..'/'..values.EVIL_LEGENDARY..'\n'..values.GOOD_TEAM..'/'..values.GOOD_LEADER..'/'..values.GOOD_LEGENDARY)
  box=Box.new(game,roleText);game.stack:push(box);U.wait(160);shot('native-rs-opposing-roles');close(box)
  for _,gender in ipairs{'boy','girl'}do
    game.save.player.gender=gender
    local suffix=gender=='girl'and'_FEMALE'or'_MALE'
    assert(Box.substitute(game,'{RIVAL}{KUN}')==values['RIVAL'..suffix]..values['KUN'..suffix])
    box=Box.new(game,'{VERSION}\n{RIVAL}{KUN}');game.stack:push(box);U.wait(100)
    shot('native-rs-version-rival-'..gender);close(box)
  end
  report.status='pass';report.actualForestTextKey=key;report.evilTeam=values.EVIL_TEAM
  report.evilLeader=values.EVIL_LEADER;report.evilLegendary=values.EVIL_LEGENDARY
  report.version=values.VERSION;report.bothPlayerGenders=true;report.drawPreservesSaveRng=true
  report.nativeCallbackOnce=true;report.literalNamesUnchanged=true;persist()
  print('PASS_NATIVE_RS_PLACEHOLDER_IDENTITY');love.event.quit(0)
end
