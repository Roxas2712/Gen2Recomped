package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub')
local T=require('tests.harness')
local X=require('src.import.RomExtractorGen3')
local Writer=require('src.import.LuaWriter')
local function fixture()
  return setmetatable({_maps={
    tunnel={objects={{smashable=true,flag=932},{smashable=true,flag=931}}},
    otherPuzzle={objects={{smashable=true,flag=32}}},
    ordinary={objects={{smashable=true,flag=1},{smashable=true,flag=2}}}
  },_scriptPool={scripts={EXIT={{'setvar',0x409A,6},{'setflag',199},{'return'}}},maps={tunnel={tables={{type=2,rows={
    {var=0x409A,value=5},{var=0x409A,value=4}
  }}}}}}},X)
end
local x=fixture();local before=Writer.encode({maps=x._maps,pool=x._scriptPool})
local rule=assert(x:rusturfTunnel(),'A single unrelated saved rock must not suppress the tunnel rule')
T.eq(rule.map,'tunnel');T.eq(rule.var,0x409A)
T.eq(rule.rocks[1],931);T.eq(rule.rocks[2],932)
T.eq(rule.states[1],4);T.eq(rule.states[2],5)
T.eq(rule.openedFlag,199);T.eq(rule.openedState,6)
T.eq(Writer.encode({maps=x._maps,pool=x._scriptPool}),before,'Derivation must not mutate extracted maps/scripts')
for _,flag in ipairs({0,1,31,32,33,1000})do
  x=fixture();x._maps.otherPuzzle.objects[1].flag=flag
  T.eq(x:rusturfTunnel().map,'tunnel','An unrelated single-rock puzzle cannot identify the two-rock scene')
end
x=fixture();x._maps.tunnel=nil;T.eq(x:rusturfTunnel(),nil,'A single saved rock is insufficient')
x=fixture();x._maps.otherPuzzle.objects[2]={smashable=true,flag=33}
T.eq(x:rusturfTunnel(),nil,'Ambiguous saved pairs must fail closed')
x=fixture();x._maps.tunnel.objects[2].smashable=false
T.eq(x:rusturfTunnel(),nil,'Only actual smashable objects can identify the scene')
x=fixture();x._scriptPool.maps.tunnel.tables[1].rows[2].var=0x409B
T.eq(x:rusturfTunnel(),nil,'The two frame conditions must name the same story variable')
x=fixture();x._scriptPool.maps.tunnel.tables[1].rows[2]=nil
T.eq(x:rusturfTunnel(),nil,'Incomplete native frame tables must not synthesize a state')
x=fixture();x._scriptPool.maps.tunnel.tables[1].type=1
T.eq(x:rusturfTunnel(),nil,'A transition callback cannot replace the native frame table')
x=fixture();x._scriptPool.scripts={}
T.eq(x:rusturfTunnel(),nil,'A native exit guard is required before publishing the rule')
x=fixture();x._scriptPool.scripts.OTHER={{'setvar',0x409A,7},{'setflag',200},{'return'}}
T.eq(x:rusturfTunnel(),nil,'Conflicting exit flags must fail closed')
local C=require('src.script.Gen3Commands')
for _,which in ipairs({1,2})do
  local flags={[('FLAG_G3_%04X'):format(rule.rocks[which])]=true}
  local spec={map=rule.map,var=rule.var,states=rule.states,openedFlag='FLAG_G3_00C7',
    rocks={'FLAG_G3_03A3','FLAG_G3_03A4'}}
  local save={flags=flags,gen3Vars={}}
  local ctx={save=save,game={data={constants={gen3Rusturf=spec}}},overworld={map={id=rule.map}}}
  T.eq(C.SPECIALS[300](ctx),1);T.eq(save.gen3Vars[rule.var],rule.states[which])
  flags[spec.openedFlag]=true;save.gen3Vars[rule.var]=6
  T.eq(C.SPECIALS[300](ctx),0,'The remaining rock cannot restart a completed scene')
  T.eq(save.gen3Vars[rule.var],6);T.eq(save.gen3Vars[0x800D],0)
end
T.finish('Rusturf two-rock scene discovery with unrelated saved-rock puzzles')
