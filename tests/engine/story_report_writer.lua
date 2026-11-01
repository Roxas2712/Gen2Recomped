-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
package.path='./?.lua;./?/init.lua;'..package.path
local T=require('tests.modkit');local J=require('src.link.Json')
local W=require('tests.drivers.story_report_writer')
local directory=assert(os.getenv('STORY_WRITER_TEST_DIR'),'Set owned STORY_WRITER_TEST_DIR')
local path=directory..'/story-writer-'..tostring({}):gsub('[^%w]','')..'.json'
local function bytes()
 local f=assert(io.open(path,'rb'));local value=f:read('*a');f:close();return value
end
local committed, encodedBytes, calls, fail=0,0,0,false
local function encode(value)
 local f=io.open(path,'rb')
 if f then
  local previous=J.decode(f:read('*a'));f:close()
  T.eq(#previous.commands,committed,'readers retain complete prior JSON during publication')
 end
 if fail and value.seq then error('intentional encoder failure')end
 local encoded=J.encode(value);encodedBytes=encodedBytes+#encoded;calls=calls+1
 return encoded
end
local writer=W.new(path,encode);local report={commands={},status='running',edition='emerald'}
writer:write(report);T.eq(#J.decode(bytes()).commands,0)
local payload=string.rep('trace',400)
for index=1,100 do
 report.commands[index]={seq=index,input={op='press',button='a'},
  before={hp=index,text='Poké\n\000"\\'..payload},after={hp=index-1},ordinaryInputs={{key='a',heldFrames=1}}}
 writer:write(report);committed=index
end
local decoded=J.decode(bytes())
T.eq(#decoded.commands,100,'complete history remains available without a sidecar reader')
T.eq(decoded.commands[1].before.text,report.commands[1].before.text,'UTF-8 and escaped control bytes survive copying')
T.eq(decoded.commands[100].after.hp,99)
T.check(encodedBytes<400000,'encoding work follows newly committed rows rather than the growing history')
T.eq(calls,201,'each append encodes its new row and current metadata only')
report.commands[1].before.hp=999
report.status='pass';writer:write(report)
decoded=J.decode(bytes());T.eq(decoded.commands[1].before.hp,1,'a later mutation cannot rewrite an already observed input')
T.eq(decoded.status,'pass','terminal metadata is updated without rebuilding past inputs')
local before=bytes()
report.commands[101]={seq=101,input={op='wait'},after={hp=4}}
fail=true;T.eq(pcall(writer.write,writer,report),false)
T.eq(bytes(),before,'a failed encoding never exposes an incomplete replacement')
fail=false;writer:write(report);committed=101
T.eq(#J.decode(bytes()).commands,101,'retry commits exactly one retained row')
before=bytes();report.commands[102]={seq=103};T.eq(pcall(writer.write,writer,report),false)
T.eq(bytes(),before,'a sequence gap cannot replace the accepted report')
report.commands[102]=nil;report.commands[101]=nil
T.eq(pcall(writer.write,writer,report),false,'committed history cannot be shortened')
T.eq(bytes(),before)
T.eq(pcall(W.new,path,J.encode),false,'an existing report cannot be silently overwritten')
os.remove(path);os.remove(path..'.tmp')
T.finish('Atomic complete story reports, immutable committed rows, lossless retry and bounded encoding work')
