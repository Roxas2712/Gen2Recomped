package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0
local function check(v,m) assert(v,m);n=n+1 end
local now=0;local files={};local running=true;local replies={};local removed={}
love.timer={getTime=function() return now end}
love.filesystem={createDirectory=function() return true end,getSaveDirectory=function() return '/private-demo' end,getInfo=function(p) return files[p] and {size=files[p]} end,remove=function(p) removed[p]=true;files[p]=nil;return true end}
love.thread={newChannel=function() return {pop=function() return table.remove(replies,1) end} end,newThread=function() return {start=function() end,isRunning=function() return running end,getError=function() end} end}
local D=require('src.mods.ModDownload')
check(not D.start({zip={url='http://unsafe.test/a.zip'}}),'downloads require HTTPS')
check(not D.start({zip={url='https://example.test/a.zip',size=D.MAX_BYTES+1}}),'oversized packages are refused before a worker starts')
check(not D.start({zip={url='https://example.test/a.zip',sha256='wrong'}}),'invalid release digests are refused')
local job=assert(D.start({zip={url='https://example.test/a.zip',size=100}}));files[job.path]=45
local progress=job:poll();check(progress.kind=='progress' and progress.bytes==45 and progress.total==100,'UI progress reads the actual bytes written by the worker')
replies={{kind='done',path=job.path,bytes=100,verified=true}}
check(job:poll().kind=='done','completed downloads expose a local file, not another network request')
local cancelled=assert(D.start({zip={url='https://example.test/a.zip'}}));cancelled:cancel()
replies={{kind='done',path=cancelled.path,bytes=100}};check(cancelled:poll().kind=='cancelled','a late worker result can never install after cancellation')
running=false;D.reap();check(removed[cancelled.path],'cancelled files are cleaned only after their worker exits')
replies={};running=true
local timed=assert(D.start({zip={url='https://example.test/a.zip'}}));now=331
check(timed:poll().kind=='error','a stalled worker cannot hold the launcher indefinitely')
print('Mod download: '..n..' checks passed')
