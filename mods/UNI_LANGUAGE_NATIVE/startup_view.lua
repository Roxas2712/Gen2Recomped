-- Drawn only before the game starts. Fonts and hit areas are local to this view.
return function(mod,state,requirements,locales,order)
 local G=love.graphics
 local fonts={}
 local family={ja='jp',ko='kr',['zh-Hans']='sc',['zh-Hant']='tc'}
 local ink={.10,.17,.24};local muted={.35,.43,.48};local cream={.97,.96,.90};local red={.83,.22,.25};local teal={.09,.48,.48}
 local disabled={.79,.81,.80};local disabledInk={.36,.39,.39}
 local function color(c) G.setColor(c[1],c[2],c[3],1) end
 local function font(size,locale)
  local f=family[locale or state.uiLanguage] or 'jp';local k=f..size
  if not fonts[k] then fonts[k]=G.newFont(love.filesystem.newFileData(assert(mod:read('fonts/ascendant-'..f..'.otf')),'ascendant-'..f..'.otf'),size) end
  G.setFont(fonts[k]);return fonts[k]
 end
 local function text(s,x,y,size,c,width,locale)
  local f=font(size,locale)
  if width then while f:getWidth(s)>width and size>10 do size=size-1;f=font(size,locale) end end
  color(c or ink);G.print(s,x,y)
 end
 local function wrapped(s,x,y,width,size,c,locale)
  font(size,locale);color(c or muted);G.printf(s,x,y,width)
 end
 local function panel(x,y,w,h,fill)
  color(ink);G.rectangle('fill',x,y+4,w,h,12,12)
  color(fill or cream);G.rectangle('fill',x,y,w,h,12,12)
  color(ink);G.setLineWidth(2);G.rectangle('line',x,y,w,h,12,12)
 end
 local function hit(x,y,w,h,action) state.hitboxes[#state.hitboxes+1]={x=x,y=y,w=w,h=h,action=action} end
 local function ball(x,y,r)
  color(cream);G.circle('fill',x,y,r)
  color(red);G.arc('fill','pie',x,y,r,math.pi,2*math.pi)
  color(ink);G.setLineWidth(3);G.circle('line',x,y,r);G.line(x-r,y,x+r,y)
  color(cream);G.circle('fill',x,y,r*.32);color(ink);G.circle('line',x,y,r*.32)
 end
 return function()
  local t=locales[state.uiLanguage] or locales.en
  G.push('all');G.origin();G.setCanvas();G.clear(.90,.92,.86,1)
  local w,h=G.getDimensions();local scale=math.min(w/960,h/650)
  G.translate((w-960*scale)/2,(h-650*scale)/2);G.scale(scale)
  color({.84,.87,.82});for x=0,960,24 do for y=0,650,24 do G.circle('fill',x,y,1) end end
  color(red);G.rectangle('fill',0,0,960,102)
  color(ink);G.rectangle('fill',0,98,960,5)
  ball(59,49,28)
  text('UNI-LANGUAGE',104,17,16,cream)
  text('ASCENDANT',102,35,34,cream)
  text(t.tagline,414,51,16,cream,280)
  panel(723,26,206,43,cream)
  text(t.menuLanguage..'  /  '..locales[state.uiLanguage].native,737,35,14,ink,178)
  state.hitboxes={};hit(723,26,206,43,function() if state.stage=='menu' or state.stage=='game' then state.stage='menu';state.noticeKey=nil end end)
  if state.stage=='notice' then
   text('Before you begin',32,126,30,ink,890,'en')
   panel(32,191,896,332,cream)
   wrapped('You can go back before starting the game. Use Back / Esc / B to correct a choice, or Reset profile to start setup again.',54,213,850,19,ink,'en')
   wrapped(mod.exports.host=='Gen2Recomped' and 'Gen2Recomped keeps your language profile and imported language ROMs in mod storage, including after uninstalling. Updates preserve your profile.' or 'Uninstalling this mod deletes its profile and imported language ROMs. Reinstalling starts fresh. Updates preserve your profile.',54,305,850,19,ink,'en')
   wrapped('Game saves and original ROM files are kept. Reset profile clears language choices and the intro status; it keeps imported ROMs.',54,397,850,18,muted,'en')
   panel(654,551,274,53,teal);text('Continue  >',675,560,22,cream,230,'en');hit(654,551,274,53,state.confirm)
   text('Enter / A',34,569,15,muted,500,'en')
   if state.noticeKey then wrapped(t[state.noticeKey],34,617,890,13,red) end
   G.pop();return
  elseif state.stage=='reset' then
   text(t.resetTitle,32,127,29,ink,890)
   panel(32,208,896,293,cream)
   wrapped(t.resetBody,58,238,841,23,ink)
   wrapped(mod.exports.host=='Gen2Recomped' and 'Use Reset profile here; Gen2Recomped keeps mod storage after uninstalling.' or 'Uninstalling + reinstalling also starts a fresh profile.',58,437,841,15,muted,'en')
   panel(32,548,280,54,state.resetIndex==1 and {.98,.86,.40} or cream)
   text(t.cancel,53,561,20,ink,235);hit(32,548,280,54,state.back)
   panel(468,548,460,54,state.resetIndex==2 and red or cream)
   text(t.resetConfirm,490,561,20,state.resetIndex==2 and cream or ink,415);hit(468,548,460,54,state.resetProfile)
   if state.noticeKey then wrapped(t[state.noticeKey],34,616,890,13,red) end
   G.pop();return
  end
  local menu=state.stage=='menu'
  text(menu and '01' or '02',32,119,32,red)
  text(menu and t.menuTitle or t.gameTitle,92,119,28,ink,810)
  text(menu and t.menuHint or t.beforeTitle,94,161,14,muted,(menu and #order>9 or not menu and #state.choices>3) and 610 or 810)
  if menu then
   local first=math.floor((state.uiIndex-1)/9)*9+1
   if #order>9 then
    local page=math.floor((state.uiIndex-1)/9)+1
    text(page..' / '..math.ceil(#order/9),752,161,14,muted,65,'en')
    for _,d in ipairs({{-1,824,'<'},{1,872,'>'}}) do
     local direction=d[1]
     panel(d[2],153,38,31,cream);text(d[3],d[2]+13,155,18)
     hit(d[2],153,38,31,function() state.pageMenu(direction) end)
    end
   end
   for i=first,math.min(first+8,#order) do
    local id=order[i]
    local x=32+((i-first)%3)*304;local y=204+math.floor((i-first)/3)*93
    local selected=i==state.uiIndex
    panel(x,y,288,77,selected and {.98,.86,.40} or cream)
    text(locales[id].native,x+20,y+12,24,ink,238,id)
    text(id:upper(),x+21,y+48,11,muted,220,'en')
    if selected then ball(x+256,y+40,12) end
    hit(x,y,288,77,function() state.uiIndex=i;state.previewLocale(id) end)
   end
   wrapped(t.uiOnly,34,498,880,15,muted)
   panel(654,547,274,53,teal);text(t.continue..'  >',675,558,21,cream,232)
   hit(654,547,274,53,state.confirm)
   if not state.noticeKey then text(t.menuControls,34,615,12,muted,890) end
  else
   local first=math.floor((state.index-1)/3)*3+1
   if #state.choices>3 then
    local page=math.floor((state.index-1)/3)+1
    local pages=math.ceil(#state.choices/3)
    text(page..' / '..pages,752,161,14,muted,65,'en')
    for _,d in ipairs({{-1,824,'<'},{1,872,'>'}}) do
     panel(d[2],153,38,31,cream);text(d[3],d[2]+13,155,18)
     local direction=d[1]
     hit(d[2],153,38,31,function()
      state.index=((page-1+direction)%pages)*3+1;state.noticeKey=nil
     end)
    end
   end
   for i=first,math.min(first+2,#state.choices) do
    local c=state.choices[i]
    local x=32+(i-first)*302
    panel(x,201,286,82,c.available and (i==state.index and {.98,.86,.40} or cream) or disabled)
    if i==state.index and not c.available then color(disabledInk);G.setLineWidth(3);G.rectangle('line',x+5,206,276,72,8,8) end
    text(c.id=='en' and t.english or c.id=='de' and t.german or c.name,x+18,212,24,c.available and ink or disabledInk,250,c.id)
    text(c.available and (c.id=='en' and t.baseReady or t.romReady) or (c.supported and t.romMissing or t.unavailableShort),x+18,249,13,c.available and teal or disabledInk,256)
    hit(x,201,286,82,function()state.index=i;state.noticeKey=nil end)
   end
   if #state.choices<=2 then wrapped(t.uiOnly,665,212,250,12,muted) end
   local current=state.choices[state.index]
   local choiceNotice=current.supported and current.noticeKey
   if choiceNotice then text(t[choiceNotice] or locales.en[choiceNotice],34,286,12,muted,890) end
   local row=requirements[state.page]
   panel(32,306,896,213,cream)
   text(t.romList..'  /  '..state.page..' / '..#requirements,50,317,15,teal,650)
   text(t.generation..' '..row.generation..' · '..(t['game_'..row.game] or row.name),50,342,20,ink,700)
   for _,d in ipairs({{-1,824,'<'},{1,872,'>'}}) do
    panel(d[2],320,38,30,{.88,.91,.86});text(d[3],d[2]+13,322,18)
    local direction=d[1];hit(d[2],320,38,30,function()state.page=(state.page-1+direction)%#requirements+1 end)
   end
   local function rom(label,r,y)
    text(label..'  ·  '..r.name..'  ·  '..r.version,50,y,13,ink,858)
    text('SHA-1   '..r.sha1,50,y+22,13,muted,855,'en')
   end
   rom(t.base,row.base,378)
   local wanted=state.choices[state.index].id
   local source=wanted=='en' and row.sources[1] or nil
   for _,r in ipairs(row.sources) do if r.language==wanted then source=r;break end end
   if source then rom(t.source,source,435)
   elseif wanted~='en' then wrapped(t.unavailable,50,435,850,16,muted) end
   text(t.exact,50,493,11,muted,850)
   panel(654,540,274,51,current.available and teal or disabled);text(t.start..'  >',675,549,21,current.available and cream or disabledInk,232)
   if current.available then hit(654,540,274,51,state.confirm) end
   wrapped(state.noticeKey and t[state.noticeKey] or t.switchHint,34,532,590,12,state.noticeKey and red or muted)
   text(t.controls,34,625,12,ink,894)
  end
  local buttonY=menu and 547 or 578
  panel(32,buttonY,140,35,cream);text('<  '..t.back,46,buttonY+5,15,ink,113);hit(32,buttonY,140,35,state.back)
  panel(188,buttonY,245,35,cream);text(t.resetProfile,204,buttonY+5,15,ink,210);hit(188,buttonY,245,35,state.requestReset)
  if menu and state.noticeKey then wrapped(t[state.noticeKey],34,610,894,13,red) end
  G.pop()
 end
end
