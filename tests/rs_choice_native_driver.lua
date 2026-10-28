-- Prepared script choice coverage, not ordinary story progression.
return function(game)
  local U=require('tests.drivers.util');local J=require('src.link.Json')
  local Save=require('src.core.SaveSerializer');local Native=require('src.ui.Gen3RsChoice')
  local Commands=require('src.script.Commands');local VM=require('src.script.Gen3ScriptVM')
  local edition=require('src.core.GameVersion').get();local out=assert(os.getenv('EDITION_QA_OUT'))
  assert(Native.available(game));assert(require('src.import.RomImporter').readyReport(edition).ok)
  local report={edition=edition,status='running',preparedChoiceFixture=true,continuousStory=false,
    captures={},cases={},callbacksReturned=0,drawSaveAndRngPreserved=true}
  local function persist()local f=assert(io.open(out..'/result.json','w'));f:write(J.encode(report));f:close()end
  persist();U.freshSave(game);U.teleport(game,'MAP_G00_N11',11,9,'right');U.wait(120)
  local world=game.stack:top();local lists=game.data.constants.gen3Multichoice
  local brineyId,gridId
  for i,row in ipairs(lists)do
    if row[1]=='PETALBURG'and row[2]=='SLATEPORT'and row[3]=='CANCEL'then brineyId=i-1 end
    if #row==5 and not gridId then gridId=i-1 end
  end
  assert(brineyId and gridId,'Native cartridge menu lists missing')
  local ctx={game=game,save=game.save,runner={}}
  local yielded,resumed=0,0
  function ctx.runner:yield()yielded=yielded+1 end
  function ctx.runner:resume()resumed=resumed+1;report.callbacksReturned=report.callbacksReturned+1 end
  local function shot(name)
    local before=Save.encode(game.save);local rng=love.math.getRandomState()
    assert(require('src.render.GraphicsScope').call(function()game.stack:top():draw()end))
    assert(before==Save.encode(game.save)and rng==love.math.getRandomState(),'Choice draw mutated save/RNG')
    assert(U.shot(game,out..'/'..name..'.png'));report.captures[#report.captures+1]=name;persist()
  end
  local function press(key)
    game.input:overlayPressed(key);U.wait(3);game.input:overlayReleased(key);U.wait(30)
  end
  local function open(ir)
    assert(game.stack:top()==world)
    local s={out={}};VM.LOWERING[ir[1]](ir,s);local row=s.out[1]
    Commands[row[1]](ctx,unpack(row,2));U.wait(60)
    local screen=game.stack:top();assert(getmetatable(screen)==Native)
    assert(yielded==resumed+1 and screen.scene.active)
    return screen
  end
  local function closed(expected)
    assert(game.stack:top()==world and yielded==resumed,'Choice did not resume its caller once')
    assert(require('src.script.Gen3Commands').getVar(game.save,0x800D)==expected)
  end
  local s=open({'multichoice',0,0,brineyId,0})
  assert(s.scene.left==1 and s.scene.top==1 and s.scene.cols==1 and s.index==1)
  shot('choice-native-briney-first');press('down');assert(s.index==2)
  shot('choice-native-briney-slateport');press('a');closed(1)
  report.cases.brineyPositionAndAnswer=true
  s=open({'multichoicedefault',17,5,brineyId,2,0})
  assert(s.index==3 and s.scene.left==18 and s.scene.top==6)
  shot('choice-native-default-cancel');press('a');closed(2);report.cases.defaultSelection=true
  s=open({'multichoice',0,0,brineyId,1});local count=resumed
  press('b');assert(game.stack:top()==s and s.scene.active and resumed==count)
  shot('choice-native-ignore-b');press('down');press('a');closed(1);report.cases.ignoreBDoesNotHang=true
  s=open({'multichoice',0,0,brineyId,0});press('b');closed(127)
  shot('choice-native-cancel-return');report.cases.cancelReturnsNative127=true
  s=open({'multichoicegrid',2,3,gridId,2,0})
  assert(s.scene.left==3 and s.scene.top==4 and s.scene.cols==2)
  press('right');assert(s.index==2);press('down');assert(s.index==4)
  shot('choice-native-grid-two-columns');press('down');assert(s.index==5)
  shot('choice-native-grid-incomplete-last-row');press('a');closed(4);report.cases.gridColumnsAndLastRow=true
  s=open({'multichoice',27,0,brineyId,0})
  local g=s.scene.rsMultiGeometry(s.scene.options,s.scene.left,s.scene.top,1)
  assert(g.frame[1]+g.frame[3]==29)
  shot('choice-native-right-edge-clamp');press('b');closed(127);report.cases.rightEdgeClamp=true
  assert(report.callbacksReturned==6)
  report.status='pass';persist();love.event.quit(0)
end
