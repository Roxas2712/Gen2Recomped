-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local V=require('src.core.GameVersion');local old=V.get()
local E=require('src.import.RomExtractorGen2');local Importer=require('src.import.RomImporter')
local markerFor
for i=1,100 do local name,value=debug.getupvalue(Importer.readyReport,i);if name=='markerFor'then markerFor=value;break end;if not name then break end end
assert(markerFor)
local function fixture(version,edit)
 local raw=string.rep('\0',0x8000)
 local function put(at,bytes)raw=raw:sub(1,at)..bytes..raw:sub(at+#bytes+1)end
 local symbols={MomItems_1={1,0x4000},['MomItems_1.End']={1,0x4010},MomItems_2={1,0x4010},['MomItems_2.End']={1,0x4028},
  ['CheckBalance_MomItem2.check_have_2300']={1,0x4100},hMoneyTemp={0,0xff80},
  ['Mom_GetScriptPointer.ItemScript']={1,0x4200},['Mom_GetScriptPointer.DollScript']={1,0x4201},
  GotMoneyForWinningText={1,0x4300},SentSomeToMomText={1,0x4301},SentHalfToMomText={1,0x4302},SentAllToMomText={1,0x4303}}
 put(0x4000,string.char(0,0,0,0,0,3,1,17,0,0,0,0,0,5,1,18,
  0,0,100,0,0,20,1,17,0,0,200,0,0,70,2,14,0,1,244,0,0,30,1,18))
 put(0x4100,string.char(0x21,0x80,0xff,0x36,0,0x23,0x36,0,0x23,0x36,17))
 put(0x4200,string.char(0x91,0x91))
 if edit then edit(symbols,put)end
 local e=E.new(raw,version,{symbols=symbols});e._gen2ScriptTexts={}
 return e
end
local function pool()return{scripts={},queue={},movements={},instructions=0,desyncs=0,failures=0}end
for _,version in ipairs({'gold','silver','crystal'})do
 V.set(version);local e=fixture(version);local q=pool();local rows=e:gen2MomShopping(q)
 T.eq(rows.complete,true,version..' actual Mom importer accepts bounded native tables')
 T.eq(#rows.random,2,version..' random count comes from its end symbol')
 T.eq(#rows.ladder,3,version..' ladder count comes from its end symbol')
 T.eq(rows.ladder[3].trigger,500,version..' money trigger is a big-endian triple')
 T.eq(rows.ladder[2].kind,2,version..' kind distinguishes real DECO byte from native item')
 T.eq(rows.ladder[2].item,14,version..' row retains actual byte rather than a guessed species')
 T.eq(rows.step,17,version..' random threshold is read from actual instructions, not a retail literal')
 T.eq(#q.queue,2,version..' both original phone scripts enter native decode queue')
 T.check(e._gen2ScriptTexts[rows.rewardTexts[1]]~=nil,version..' native reward prose reaches shared text importer')
 e:gen2MomShopping(q);T.eq(#q.queue,2,version..' repeated import queues each script once')
 for _,job in ipairs(q.queue)do e:gen2DecodeScript(job[1],job[2],job[3],q)end
 T.eq(q.desyncs,0,version..' native queued scripts decode without desync')
 T.check(markerFor(version):find('gen2%-mom%-shopping%-native%-v1:')~=nil,version..' new cache requires purchase data')
 for _,edit in ipairs({
  function(s)s.MomItems_1=nil end,
  function(s)s['MomItems_2.End']=nil end,
  function(s)s['MomItems_1.End'][2]=0x4011 end,
  function(s)s['MomItems_1.End'][1]=2 end,
  function(s)s['MomItems_2.End'][2]=0x400f end,
  function(s,put)put(0x4000,string.char(255,255,255))end,
  function(s,put)put(0x4003,string.char(255,255,255))end,
  function(s,put)put(0x4006,string.char(3))end,
  function(s,put)put(0x4007,string.char(0))end,
  function(s,put)put(0x4104,string.char(0))put(0x4107,string.char(0))put(0x410a,string.char(0))end,
  function(s)s.hMoneyTemp[2]=0xff81 end,
  function(s)s['CheckBalance_MomItem2.check_have_2300']=nil end,
  function(s)s['Mom_GetScriptPointer.DollScript']=nil end,
  function(s)s['Mom_GetScriptPointer.ItemScript'][2]=0x100 end,
 })do
  local bad=fixture(version,edit);local q=pool();local result=bad:gen2MomShopping(q)
  T.eq(result.complete,false,version..' malformed or incomplete input cannot claim a native purchase binding')
  T.eq(result.random,nil,version..' malformed binding publishes no partial retail table')
  T.eq(#q.queue,0,version..' invalid binding does not partially mutate script queue')
 end
end
for _,version in ipairs({'red','emerald','prism','polishedcrystal'})do
 local q=pool();T.eq(fixture(version):gen2MomShopping(q),nil,version..' unreviewed layout has no inferred retail shopping')
 T.eq(#q.queue,0,version..' unrelated script queue stays unchanged')
 T.check(not markerFor(version):find('gen2%-mom%-shopping%-native%-v1:'),version..' unrelated cache remains unchanged')
end
V.set(old);T.finish('native Mom table boundaries, threshold instruction operands, script queues and cache revision')
