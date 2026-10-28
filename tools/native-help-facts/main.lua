-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
io.stdout:setvbuf('no')
local root=assert(os.getenv('NATIVE_TEXT_ENGINE'))
package.path=root..'/?.lua;'..root..'/?/init.lua;'..package.path
function love.errorhandler(err)print(debug.traceback(tostring(err),2));return function()return 1 end end
local function read(path)local f=assert(io.open(path,'rb'));local value=f:read('*a');f:close();return value end
function love.load()
 assert(love.graphics==nil,'native Help import must remain windowless')
 local J=require('src.link.Json');local V=require('src.core.GameVersion')
 local F=require('src.import.Gen3HelpFacts');local X=require('src.import.RomExtractorGen3')
 local inputs=J.decode(read(assert(os.getenv('NATIVE_TEXT_INPUTS'))))
 local result={editions={},gpu=false,playerProfilesUsed=false,fullGameplay=false}
 for _,edition in ipairs{'firered','leafgreen','emerald','ruby','sapphire'}do
  V.set(edition);require('src.import.CacheFs').prefix=edition..'/'
  local raw=read(assert(inputs[edition]));local info=V.info()
  assert(require('src.import.RomVerification').sha1(raw)==info.sha1,'exact native cartridge required')
  local manifest=J.decode(read(root..'/'..info.manifest));local x=X.new(raw,info,manifest)
  local worker=coroutine.create(function()x:extractConstants()end)
  repeat local ok,why=coroutine.resume(worker);assert(ok,why)until coroutine.status(worker)=='dead'
  local help=x._constants.gen3Help
  if F.supports(edition)then
   assert(help and help.schema==1 and help.edition==edition and help.romSha1==info.sha1)
   local catalog=assert(require('src.import.Gen3TextCatalog').extract(x,{}))
   local labels={help.greeting,help.cancel,help.heading}
   for _,topic in ipairs(help.topics)do labels[#labels+1]=topic.label;labels[#labels+1]=topic.description end
   local counts={}
   for topic,entries in ipairs(help.entries)do
    counts[topic]=#entries
    for _,entry in ipairs(entries)do labels[#labels+1]=entry.question;labels[#labels+1]=entry.answer end
   end
   for _,name in ipairs{'gString_Help','gText_HelpSystemControls_A_Next','gText_HelpSystemControls_AorBtoCancel',
    'gText_HelpSystemControls_PickOkEnd','gText_HelpSystemControls_PickOkCancel'}do labels[#labels+1]=name end
   local nodeKinds,commands,placeholders={},{},{}
   for _,name in ipairs(labels)do
    local row=catalog.records[assert(catalog.named[name],'native Help label missing: '..name)]
    assert(row and type(row.plain)=='string'and type(row.ir)=='table','native Help text lost its IR')
    for _,node in ipairs(row.ir)do
     nodeKinds[node.t]=(nodeKinds[node.t]or 0)+1
     if node.t=='ext'then local key=tostring(node.cmd);commands[key]=(commands[key]or 0)+1 end
     if node.t=='ph'then local key=tostring(node.code);placeholders[key]=(placeholders[key]or 0)+1 end
    end
   end
   local contextEntries=0
   for context=0,35 do
    local row=assert(help.contexts[context])
    for topic,list in ipairs(row)do for _,id in ipairs(list)do
     assert(help.entries[topic][id]);contextEntries=contextEntries+1
    end end
   end
   assert(#help.frame.tiles==288 and #help.frame.palette==16)
   assert(#help.keypad.tiles==2048 and #help.keypad.regions==13)
   result.editions[edition]={sha1=info.sha1,counts=counts,contexts=36,contextEntries=contextEntries,textReferences=#labels,
    nodeKinds=nodeKinds,commands=commands,placeholders=placeholders}
   print('NATIVE_HELP_EDITION',edition,table.concat(counts,','),contextEntries,#labels)
  else
   assert(help==nil,'Hoenn acquired an invented Help resource')
   result.editions[edition]={sha1=info.sha1,absent=true};print('NATIVE_HELP_ABSENT',edition)
  end
 end
 result.pass=true;local f=assert(io.open(assert(os.getenv('NATIVE_TEXT_RESULT')),'wb'));f:write(J.encode(result));f:close()
 print('NATIVE_HELP_FACTS_OK');love.event.quit(0)
end
