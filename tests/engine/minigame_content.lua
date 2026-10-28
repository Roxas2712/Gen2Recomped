-- Local content publication, ownership boundaries and profile isolation.
-- Contributions by Roxas2712. Fixtures contain only generated shapes.
love=require('tests.love_stub')
local Data=require('src.import.PackData');local Writer=require('src.import.LuaWriter');local MD5=require('src.mods.StreamMD5')
local count=0;local function check(v,msg)assert(v,msg);count=count+1 end
local function mem()
 local files={};local api={}
 api.read=function(p)return files[p]end
 api.getInfo=function(p)return files[p]and{type='file',size=#files[p]}end
 api.write=function(p,b)files[p]=b;return true end
 api.rename=function(a,b)if not files[a]then return nil end;files[b]=files[a];files[a]=nil;return true end
 api.remove=function(p)files[p]=nil;return true end
 api.createDirectory=function()return true end
 return api,files
end
local a,files=mem();local b=mem();local active=a
package.loaded['src.core.SaveData']={persistenceFs=function()return active end}
local C=require('src.pokewalker.minigames.Content')
local function be(n)return string.char(0,0,math.floor(n/256),n%256)end
local image='\137PNG\13\10\26\10'..be(13)..'IHDR'..be(16)..be(32)..'fixture'
local digest=MD5.new():update(image):final()
-- Headless image decoder is pinned; native ZIP/PNG decoding has its own fixture.
love.filesystem.newFileData=function(bytes)return bytes end
love.image={newImageData=function(bytes)assert(bytes==image);return{getWidth=function()return 16 end,getHeight=function()return 32 end}end}
local m={format=1,name='Test shapes',source='Generated test image',credits='Roxas2712 test fixture',terms='Test-only generated fixture',entries={
 {key='front/25',file='images/front.png',size=#image,md5=digest,width=16,height=32},
 {key='walk/25',file='images/front.png',size=#image,md5=digest,width=16,height=32,frameWidth=16,frameHeight=16,facings={up={0,1},down={0,1},left={0,1},right={0,1}}}}}
local input,source=mem();source['minigames.lua']=Writer.encode(m);source['images/front.png']=image
local function review()return assert(C.review(input))end
local function drain(co)while coroutine.status(co)~='dead'do local ok,v=coroutine.resume(co);if not ok then return nil,v end end;return true end
check(not C.current(),'fresh profile needs explicit setup')
check(C.basic(a)and C.current().mode=='basic','basic graphics persist without image load')
local previous=files[C.FILE];local r=review()
check(files[C.FILE]==previous,'review never replaces the active choice')
check(not drain(C.install(r,false))and files[C.FILE]==previous,'unchecked permission cannot publish a pack')
local co=C.install(review(),true);assert(coroutine.resume(co))
check(files[C.FILE]==previous,'partial preparation preserves previous selection')
check(drain(co)and C.current().mode=='pack','complete package publishes after every object')
check(C.current().digest==r.digest,'selection pins exact reviewed package content')
local selected=files[C.FILE]
local rename=a.rename
a.rename=function(from,to)if to==C.FILE then return nil,'full'end;return rename(from,to)end
check(not drain(C.install(review(),true))and files[C.FILE]==selected,'failed final publication preserves the previous ready pack');a.rename=rename
co=C.install(review(),true);assert(coroutine.resume(co))
local E=require('src.pokewalker.minigames.Enrollment');E.VERSION=E.VERSION+1
check(not drain(co)and files[C.FILE]==selected,'revised notice during preparation cannot publish stale consent');E.VERSION=E.VERSION-1
source['images/front.png']=image:sub(1,-2)..'!'
check(not drain(C.install(review(),true))and files[C.FILE]==selected,'same-sized changed bytes are refused without losing prior selection')
source['images/front.png']=image
r=review();r.manifest.terms='changed'
check(not drain(C.install(r,true)),'reviewed terms cannot change after confirmation')
r=review();active=b
check(not drain(C.install(r,true))and not C.current(),'stale account cannot publish or inherit a selection')
check(not C.basic(a),'basic confirmation also rejects a changed profile');active=a
co=C.install(review(),true);assert(coroutine.resume(co));active=b
check(not drain(co)and not C.current(),'mid-copy profile switch cannot publish into destination profile');active=a
local bad=Data.copy(m);bad.entries[1].file='../escape.png'
check(not C.validate(bad),'path traversal rejected')
bad=Data.copy(m);bad.entries[1].file='/absolute.png';check(not C.validate(bad),'absolute paths rejected')
bad=Data.copy(m);bad.entries[1].file='images\\escape.png';check(not C.validate(bad),'backslash paths rejected')
bad=Data.copy(m);bad.entries[2].key='front/25';check(not C.validate(bad),'duplicate keys rejected')
bad=Data.copy(m);bad.entries[2].facings.left={99};check(not C.validate(bad),'out-of-bounds animation frame rejected')
bad=Data.copy(m);bad.entries[1].width=99999;check(not C.validate(bad),'oversized decoded images rejected')
bad=Data.copy(m);bad.entries={}
for i=1,5 do bad.entries[i]={key='front/'..i,file='image'..i..'.png',size=24,md5=digest,width=2048,height=2048}end
check(not C.validate(bad),'aggregate decoded pixel budget prevents a compressed-image memory bomb')
bad=Data.copy(m);bad.entries[1].size=Data.MAX_BYTES+1;check(not C.validate(bad),'per-file read cap enforced before image allocation')
bad=Data.copy(m);bad.entries[1].key='rewards/pokemon';check(not C.validate(bad),'pack cannot define rewards or gameplay')
bad=Data.copy(m);bad.credits='';check(not C.validate(bad),'source, terms and credits are mandatory')
bad=Data.copy(m);bad.name='invalid\255';check(not C.validate(bad),'invalid UTF-8 cannot crash the review renderer')
source['minigames.lua']='return os.execute("never execute")';check(not C.review(input),'executable manifest never runs')
source['minigames.lua']=Writer.encode(m)
files[C.ROOT..'/packs/'..C.current().digest..'.lua']='return {}'
check(not C.current(),'tampered active descriptor requires setup again')
assert(C.basic(a));E.VERSION=E.VERSION+1
check(not C.current(),'new notice version requires a new content selection');E.VERSION=E.VERSION-1
assert(C.basic(a));check(C.revoke()and not C.current(),'withdrawal clears active selection without removing originals')
-- Local source preparation uses only the chosen ROM and snapshots bytes in memory.
local calls={};local art={roster=function(v)check(v=='crystal','explicit source roster');return{{dex=25,name='Fixture'}}end,
 front=function(d,s,v)calls[#calls+1]=v;return{}end,walk=function(d,s,v)calls[#calls+1]=v;return{},16,16,m.entries[2].facings end,bytes=function()return image end}
co=C.prepare('crystal',art);local prepared
while coroutine.status(co)~='dead'do local ok,v=coroutine.resume(co);assert(ok,v);prepared=v end
check(prepared.manifest.entries[1].key=='front/25'and calls[1]=='crystal'and calls[2]=='crystal','local preparation never borrows another game media')
check(not C.current(),'local preparation still requires separate confirmation')
check(drain(C.install(prepared,true))and C.current(),'prepared imported bytes use the same validated installer')
print('Minigame content: '..count..' checks passed')
