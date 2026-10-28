-- One setup for all games using the shared walker renderer. No network requests.
-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local M={};local C=require('src.pokewalker.minigames.Content')
local G=require('src.pokewalker.minigames.Gfx');local T=require('src.pokewalker.minigames.Locale')
local Saves=require('src.core.SaveData')
local function errorText(value)return tostring(value):match('^.-:%d+:%s*(.*)$')or tostring(value)end
function M.dispose(h)
 if h.contentArchive then pcall(love.filesystem.unmount,h.contentArchive);h.contentArchive=nil end
 h.contentJob=nil;h.contentReview=nil;h.contentPicker=nil
end
function M.open(h)
 M.dispose(h);h.settingContent=true;h.contentProfile=Saves.persistenceFs();h.contentFocus=1
 h.contentNotice=nil;h.contentChecked=false;h.contentSource=1;h.contentSources={};h.hits=nil;h.contentScroll=0;h.contentRead=false
 local A=require('src.pokewalker.WalkerArt');A.forget()
 for _,v in ipairs{'red','blue','yellow','gold','silver','crystal','polishedcrystal','prism','emerald','firered','platinum','heartgold','soulsilver','black','white'}do
  local ok,list=pcall(A.roster,v);if ok and #list>0 then h.contentSources[#h.contentSources+1]=v end
 end
end
local function valid(h)
 if h.closed or not h.settingContent or h.contentProfile~=Saves.persistenceFs()then h.contentNotice='The content profile changed. Reopen setup.';return false end
 return true
end
local function finish(h)
 M.dispose(h);h.settingContent=nil;h.hits=nil;h:_initialize()
end
function M.archive(h,bytes)
 if not valid(h)or h.contentJob then return end
 M.dispose(h)
 if type(bytes)~='string'or #bytes>C.MAX_TOTAL then h.contentNotice='Minigame content exceeds the size limit.';return end
 local data=love.filesystem.newFileData(bytes,'minigames.zip')
 local mount='minigame-content-'..tostring({}):gsub('[^%w]','')
 local ok,why=love.filesystem.mount(data,mount)
 if not ok then h.contentNotice=why or'Invalid minigame content archive.';return end
 h.contentArchive=data
 local r,err=C.review(love.filesystem,mount)
 if not r then M.dispose(h);h.contentNotice=err;return end
 h.contentReview=r;h.contentChecked=false;h.contentFocus=1;h.contentNotice=nil;h.contentScroll=0;h.contentRead=false
end
function M.file(h,file)
 if not valid(h)or h.contentJob then return false end
 local name=file:getFilename()or''
 if name:lower():sub(-7)~='.mgpack'then return false end
 local ok,why=pcall(function()
  assert(file:getSize()<=C.MAX_TOTAL,'Minigame content exceeds the size limit.')
  assert(file:open('r'));local bytes=assert(file:read(C.MAX_TOTAL+1));file:close();M.archive(h,bytes)
 end)
 if not ok then pcall(file.close,file);h.contentNotice=tostring(why)end
 return true
end
function M.choose(h)
 if not valid(h)or h.contentPicker or h.contentJob then return end
 local function selected(path)
  if not path or not valid(h)then return end
  local ok,why=pcall(function()
   local f=assert(io.open(path,'rb'));local size=f:seek('end')
   if not size or size>C.MAX_TOTAL then f:close();error('Minigame content exceeds the size limit.',0)end
   f:seek('set',0);local bytes=f:read(size);f:close();M.archive(h,bytes)
  end)
  if not ok then h.contentNotice=tostring(why)end
 end
 if love.window and love.window.showFileDialog then
  local token={};h.contentPicker=token
  local ok,why=pcall(love.window.showFileDialog,'openfile',function(files,_,err)
   if h.contentPicker~=token then return end;h.contentPicker=nil
   if err then h.contentNotice=tostring(err)elseif type(files)=='table'then selected(files[1])end
  end,{title=T('Import minigame content'),filters={['Minigame content (.mgpack)']='mgpack'},multiselect=false,attachtowindow=true})
  if not ok then h.contentPicker=nil;h.contentNotice=tostring(why)end
 else
  -- Files sharing/MTP fallback: same one-file pack, no directory assembly.
  local bytes=require('src.import.PackData').read(Saves.persistenceFs(),'minigames/import.mgpack')
  if bytes then M.archive(h,bytes)else h.contentNotice='Place your .mgpack file at minigames/import.mgpack, then choose Import again.'end
 end
end
function M.action(h,a)
 if a=='back'or a=='pause'then
  if h.contentReview or h.contentJob then M.open(h)else h:close(true)end
  return true
 end
 if not valid(h)or h.contentJob then return true end
 local n=h.contentReview and 3 or 5
 if h.contentReview and(a=='left'or a=='right')then
  h.contentScroll=math.max(0,math.min((h.contentLineCount or 0)-(h.contentVisible or 1),(h.contentScroll or 0)+(a=='left'and-1 or 1)*(h.contentVisible or 1)))
 elseif a=='up'then h.contentFocus=(h.contentFocus-2)%n+1
 elseif a=='down'then h.contentFocus=h.contentFocus%n+1
 elseif (a=='left'or a=='right')and not h.contentReview then
  local count=#h.contentSources;if count>0 then h.contentSource=(h.contentSource-1+(a=='left'and-1 or 1))%count+1 end
 elseif a=='a'then
  local i=h.contentFocus
  if h.contentReview then
   if i==1 then h.contentChecked=not h.contentChecked
   elseif i==2 then
    if not h.contentRead then h.contentNotice='Read all source, credits and usage notices before continuing.'
    elseif not h.contentChecked then h.contentNotice='Confirm permission before preparing additional content.'
    else h.contentJob=C.install(h.contentReview,true);h.contentJobKind='install';h.contentNotice=nil end
   else M.open(h)end
  elseif i==1 then
   local ok,why=C.basic(h.contentProfile);if ok then finish(h)else h.contentNotice=why end
  elseif i==2 then
   if #h.contentSources>0 then h.contentSource=h.contentSource%#h.contentSources+1 end
  elseif i==3 then
   local v=h.contentSources[h.contentSource]
   if not v then h.contentNotice='Import a game first, or use basic graphics.'
   else h.contentJob=C.prepare(v);h.contentJobKind='prepare';h.contentNotice=nil end
  elseif i==4 then M.choose(h)
  else h:close(true)end
 end
 return true
end
function M.update(h)
 if not valid(h)then M.dispose(h);return end
 if not h.contentJob then return end
 local ok,value=coroutine.resume(h.contentJob)
 if not ok then h.contentJob=nil;h.contentNotice=errorText(value);return end
 if coroutine.status(h.contentJob)=='dead'then
  h.contentJob=nil
  if h.contentJobKind=='install'then finish(h)
  else h.contentReview=value;h.contentChecked=false;h.contentFocus=1;h.contentProgress=nil;h.contentScroll=0;h.contentRead=false end
 else h.contentProgress=value end
end
function M.draw(h,x,y,w,height)
 local g=love.graphics;local pw=math.min(w-24,760);local px=x+(w-pw)/2;local py=y+12;local ph=height-24
 G.card(px,py,pw,ph,16,G.CARD,1)
 local f=G.fonts(1);local width=pw-32;local top=py+16
 G.setc(G.GOLD);G.fit(T('MINIGAMES · CONTENT SETUP'),px+16,top,width,f.head,'left');top=top+32
 h.hits=G.newHits()
 local review=h.contentReview
 local desc=review and table.concat({review.manifest.name,review.manifest.source,T(review.manifest.credits),T(review.manifest.terms)},'\n\n')
  or T('Set up once, then play directly. Game rules and progress stay together. Additional graphics are prepared only on this device; nothing is downloaded or uploaded.')
 -- Keep every source/credit/term visible: long reviews scroll in their own area.
 local labels=review and{'I am permitted to use this content for the intended purpose.','PREPARE & USE CONTENT','CHOOSE DIFFERENT CONTENT'}
  or{'USE BASIC GRAPHICS','SOURCE: %s','PREPARE IMPORTED GRAPHICS','IMPORT CONTENT PACK','Back'}
 local bh=review and 46 or 38;local gap=8;local controls=#labels*(bh+gap)-gap
 local by=py+ph-16-controls-24
 local dh=by-top-12
 local _,lines=f.small:getWrap(desc,width)
 local lineH=f.small:getHeight();local visible=math.max(1,math.floor(dh/lineH))
 h.contentLineCount=#lines;h.contentVisible=visible
 h.contentScroll=math.max(0,math.min(h.contentScroll or 0,math.max(0,#lines-visible)))
 g.setFont(f.small);G.setc(G.INK)
 for i=h.contentScroll+1,math.min(#lines,h.contentScroll+visible)do g.print(lines[i],px+16,top+(i-h.contentScroll-1)*lineH)end
 if #lines>visible then
  -- Explicit tap/controller scroll controls; reaching the end is required.
  G.button(h.hits,px+16,by-20,width/2-4,18,T('SCROLL UP'),function()h.contentScroll=math.max(0,h.contentScroll-visible)end,nil,f.small)
  G.button(h.hits,px+20+width/2,by-20,width/2-4,18,T('SCROLL DOWN'),function()h.contentScroll=math.min(#lines-visible,h.contentScroll+visible)end,nil,f.small)
 end
 if review and h.contentScroll+visible>=#lines then h.contentRead=true end
 for i,label in ipairs(labels)do
  if not review and i==2 then
   local v=h.contentSources[h.contentSource];local info=v and require('src.core.GameVersion').info(v)
   label=T(label,info and T(info.label)or T('No imported game'))
  else label=T(label)end
  if review and i==1 then label=(h.contentChecked and'[x] 'or'[ ] ')..label end
  local yy=by+(i-1)*(bh+gap)
  G.button(h.hits,px+16,yy,width,bh,'',function()h.contentFocus=i;M.action(h,'a')end,i==1 and'accent'or nil,f.body,h.keyed and h.contentFocus==i)
  G.setc(G.INK);G.fit(label,px+24,yy+(bh-f.body:getHeight())/2,width-16,f.body,'center')
 end
 if h.contentJob then
  local p=h.contentProgress or{done=0,total=1}
  G.setc(G.GOLD);G.fit(T('Preparing content: %d / %d',p.done,p.total),px+16,py+ph-30,width,f.small,'left')
 elseif h.contentNotice then G.setc(G.RED);G.fit(T(h.contentNotice),px+16,py+ph-30,width,f.small,'left')end
 h.contentLayout={top=top,descriptionBottom=top+visible*lineH,controlsTop=by,panelBottom=py+ph}
end
return M
