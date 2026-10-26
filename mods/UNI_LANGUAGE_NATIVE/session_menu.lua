-- One optional Ascendant entry. KASC collects the shared descriptor; when it
-- is absent, the fallback hub also collects VASC's public descriptor.
return function(mod,S,own,live)
 local order={'en','de','fr','it','es','ja','ko','zh-Hans','zh-Hant','pt-BR'}
 local locales=own('locales.lua');local fonts={}
 local function kasc()
  if not mod.find then return end
  for _,id in ipairs({'kanto_ascendant','trainer_rematch'})do
   local h=mod.find(id);local m=h and h.exports and h.exports.ascendantMenu
   if m and type(m.collect)=='function' and type(m.open)=='function'then return h end
  end
 end
 local function origami()
  local h=mod.find and mod.find('ORIGAMI_ASCENDANT');local e=h and h.exports
  return e and e.gen3 and e.gen3.menu
 end
 local function rows()
  local t=function(k)return S:text(k)end;local out={}
  local function add(label,action,right,disabled,help,language)
   out[#out+1]={label=label,choose=action,right=right,disabled=disabled,help=help,language=language}
  end
  if S.page=='hub'then
   for _,row in ipairs(S.hubRows or {})do local r=row
    add(r.ascendantLabel or r.label,function()S:close();r.onSelect()end,nil,false,r.ascendantHelp or r.help)
   end
  elseif S.page=='discard'then
   add(S:text('confirmDiscard'),function()local ok,why=S:discardRecovery();if not ok then S.error=why end end)
   add(S:text('back'),function()S.page='home';S.index=1 end)
  elseif S.page=='game'then
   for _,choice in ipairs(S:choices())do local r=choice
    local right=r.id==mod.exports.language and t('current') or r.available and t('ready') or r.supported and t('needsRom') or t('unavailable')
    add(r.name,function()local ok,why=S:request(r.id);if not ok then S.error=why end end,right,not r.available,r.sha1 and ('SHA-1 '..r.sha1..' / '..r.revision) or t('unavailable'),r.id)
   end
  elseif S.page=='menu'then
   for _,id in ipairs(order)do local lang=id
    add(locales[lang].native,function()local ok,why=S:menuLanguage(lang);if not ok then S.error=why end end,lang==S.uiLanguage and t('current') or '',false,nil,lang)
   end
  elseif S.page=='requirements'then
   for _,row in ipairs(S:choices())do if row.supported then
    local r=row;add(r.name,function()S.notice=r.sha1 and ('SHA-1 '..r.sha1..' / '..r.revision) or t('base')end,r.available and t('ready') or t('needsRom'),false,r.rom and (r.rom..' / '..r.revision..' / SHA-1 '..r.sha1) or t('base'),r.id)
   end end
  else
   if S.recoveryAvailable then
    add(t('recovery'),function()local ok,why=S:recover();if not ok then S.error=why end end)
    add(t('discardRecovery'),function()S.page='discard';S.index=2 end)
   end
   add(t('game'),function()S.page='game';S.index=1 end,locales[mod.exports.language or 'en'].native,false,t('help'))
   add(t('menu'),function()S.page='menu';S.index=1 end,locales[S.uiLanguage].native)
   add(t('addRom'),function()S:pick()end,nil,false,t('chooseRom'))
   add(t('requirements'),function()S.page='requirements';S.index=1 end)
   add(t('close'),function()S:close()end)
  end
  return out
 end
 function S:back()
  if self.pending or self.picker then return end
  if self.page=='home' or self.page=='hub'then self:close()else self.page='home';self.index=1 end
 end
 function S:key(key)
  if self.pending or self.picker then return end
  local list=rows()
  if key=='escape' or key=='x' or key=='backspace'then return self:back()end
  if key=='down'then self.index=self.index%#list+1
  elseif key=='up'then self.index=(self.index-2)%#list+1
  elseif key=='return' or key=='z' or key=='space'then
   local r=list[self.index];if r and not r.disabled then r.choose()end
  end
 end
 function S:draw()
  local G=love.graphics;G.push('all')
  local w,h=G.getDimensions();local scale=math.min(w/960,h/650)
  G.translate((w-960*scale)/2,(h-650*scale)/2);G.scale(scale)
  local function color(r,g,b,a)G.setColor(r,g,b,a or 1)end
  local family={ja='jp',ko='kr',['zh-Hans']='sc',['zh-Hant']='tc'}
  local function font(size,language)
   local f=family[language or S.uiLanguage] or 'jp';local key=f..size
   if not fonts[key]then fonts[key]=G.newFont(love.filesystem.newFileData(assert(mod:read('fonts/ascendant-'..f..'.otf')),'ula-'..key..'.otf'),size)end
   G.setFont(fonts[key]);return fonts[key]
  end
  local function text(value,x,y,size,width,language)
   font(size,language);G.printf(tostring(value or ''),x,y,width or 820,'left')
  end
  color(.035,.08,.13,.97);G.rectangle('fill',0,0,960,650)
  color(.92,.24,.28);G.rectangle('fill',32,26,896,86,14,14)
  color(1,1,1);G.circle('fill',77,69,23)
  color(.83,.16,.20);G.arc('fill','pie',77,69,23,math.pi,2*math.pi)
  color(.1,.18,.24);G.setLineWidth(4);G.circle('line',77,69,23);G.line(54,69,100,69)
  G.circle('fill',77,69,9);color(1,1,1);G.circle('fill',77,69,5)
  color(1,1,1);text('UNI-LANGUAGE ASCENDANT',122,36,24,760);text(S:text('title')..'  ·  '..S.version:upper(),124,72,16,760)
  if S.pending then
   color(1,.85,.35);text(S:text('loading'),65,185,30,840);color(.75,.85,.88);text(S:text('help'),65,245,19,830)
  else
   local list=rows();S.index=math.max(1,math.min(S.index,#list));S.hitboxes={}
   local start=math.max(1,S.index-6);if #list<=7 then start=1 end
   for i=start,math.min(#list,start+6)do
    local row=list[i];local y=130+(i-start)*53
    if i==S.index then color(.1,.44,.48);G.rectangle('fill',44,y,872,47,8,8)end
    if row.disabled then color(.42,.49,.54)else color(.96,.97,.92)end
    text(row.label,64,y+8,21,420,row.language);text(row.right,498,y+11,16,390)
    S.hitboxes[#S.hitboxes+1]={x=44,y=y,w=872,h=47,index=i}
   end
   local r=list[S.index];color(.72,.83,.86);text(S.error or S.notice or (r and r.help) or S:text('help'),58,518,16,844)
  end
  if not S.pending then
   local function button(x,w,label,action)
    color(.12,.30,.37);G.rectangle('fill',x,598,w,44,8,8);color(.94,.97,.94);text(label,x+12,608,17,w-18)
    S.hitboxes[#S.hitboxes+1]={x=x,y=598,w=w,h=44,action=action}
   end
   if #rows()>7 then button(665,54,'↑',function()S:key('up')end);button(727,54,'↓',function()S:key('down')end)end
   button(795,120,S:text('back'),function()S:back()end)
  end
  color(.32,.48,.54);G.line(48,588,912,588)
  color(.86,.91,.91);text('↑ ↓   A / Enter   ·   B / Esc: '..S:text('back'),60,606,16,590)
  G.pop()
 end
 local function descriptor(game)
  return {label='LANGUAGES',ascendantMenu=true,ascendantKey='uni_language_ascendant',ascendantLabel='UNI-LANGUAGE',ascendantOrder=15,ascendantGroup='settings',ascendantHelp='GAME / MENU LANGUAGES. ROM IMPORT.',onSelect=function()local ok,why=S:open(game,true);if not ok then S.error=why end end}
 end
 mod.hooks:wrap('ui.start_menu.items',function(nextItems,game,items)
  local result=nextItems(game,items);if type(result)~='table'then return result end
  if origami()then return result end
  local out={};for _,r in ipairs(result)do out[#out+1]=r end
  out[#out+1]=descriptor(game);return out
 end,900)
 mod.hooks:wrap('ui.start_menu.items',function(nextItems,game,items)
  local result=nextItems(game,items)
  if kasc() or origami() or type(result)~='table'then return result end
  local ordinary,features={},{}
  for _,r in ipairs(result)do if r.ascendantMenu then features[#features+1]=r else ordinary[#ordinary+1]=r end end
  if #features==0 then return result end
  table.sort(features,function(a,b)return (a.ascendantOrder or 999)<(b.ascendantOrder or 999)end)
  local entry={label='ASCENDANT',onSelect=function()
   if S:open(game,true)then S.page='hub';S.hubRows=features;S.index=1 end
  end}
  local index=#ordinary+1;for i,r in ipairs(ordinary)do if r.label=='SAVE' or r.label=='SICHERN'then index=i;break end end
  table.insert(ordinary,index,entry);return ordinary
 end,1000)
 mod.hooks:wrap('input.key',function(nextFn,game,event)
  if live() and S.opened then if event.phase=='pressed'then S:key(event.key)end;return end
  return nextFn(game,event)
 end,2000)
 mod.hooks:wrap('input.gamepad',function(nextFn,game,event)
  if live() and S.opened then
   if event.phase=='pressed'then S:key(({dpup='up',dpdown='down',a='z',b='x',start='return'})[event.button] or event.button)end;return
  end
  return nextFn(game,event)
 end,2000)
 function S:attach(game)
  local update,draw=game.update,game.draw
  game.update=function(g,dt,...)
   if live() and self.opened then self:update(dt);return end
   return update(g,dt,...)
  end
  game.draw=function(g,...)
   if live() and self.opened then self:draw();return end
   return draw(g,...)
  end
  local click=game.mousepressed
  game.mousepressed=function(g,x,y,button,...)
   if live() and self.opened then
    if button==1 and not self.pending then
     local w,h=love.graphics.getDimensions();local scale=math.min(w/960,h/650)
     x=(x-(w-960*scale)/2)/scale;y=(y-(h-650*scale)/2)/scale
     for _,r in ipairs(self.hitboxes or {})do if x>=r.x and x<r.x+r.w and y>=r.y and y<r.y+r.h then if r.action then r.action()else self.index=r.index;self:key('return')end;break end end
    end;return
   end
   if click then return click(g,x,y,button,...)end
  end
  local wheel=game.wheelmoved
  game.wheelmoved=function(g,dx,dy,...)
   if live() and self.opened then self:key(dy>0 and 'up' or 'down');return end
   if wheel then return wheel(g,dx,dy,...)end
  end
  local touch=game.touchpressed
  game.touchpressed=function(g,id,x,y,...)
   if live() and self.opened then return g:mousepressed(x,y,1)end
   if touch then return touch(g,id,x,y,...)end
  end
  local shared=kasc();shared=shared and shared.exports.ascendantMenu
  if shared and type(shared.buildRoot)=='function'then
   local previous=shared.__ulaLanguageRoot
   local original=previous and shared.buildRoot==previous.wrapper and previous.original or shared.buildRoot
   local function build(items)
    local root=original(items);if not live()then return root end
    local language
    local function prune(rows)
     local out,changed={},false
     for _,row in ipairs(rows or {})do
      if row.ascendantKey=='uni_language_ascendant'then language=row;changed=true
      elseif row.children then
       local children,removed=prune(row.children)
       if removed then
        changed=true
        if #children>0 then local copy={};for k,v in pairs(row)do copy[k]=v end;copy.children=children;out[#out+1]=copy end
       else out[#out+1]=row end
      else out[#out+1]=row end
     end
     return out,changed
    end
    local out=prune(root)
    if not language then return root end
    local index=#out+1;for i,row in ipairs(out)do if row.ascendantKey=='options'then index=i;break end end
    table.insert(out,index,language);return out
   end
   shared.__ulaLanguageRoot={original=original,wrapper=build};shared.buildRoot=build
  end
  local host=origami()
  if host then
   local original=host.open
   host.open=function(g,section,...)
    local screen=original(g,section,...)
    if live() and not section and screen and screen.items then
     screen.items[#screen.items+1]={label='UNI-LANGUAGE',help='GAME / MENU LANGUAGES. ROM IMPORT.',choose=function()self:open(game,true)end}
    end
    return screen
   end
  end
 end
end
