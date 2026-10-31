local P=require('tools.windows-demo.Profile')
if os.getenv('RETRO_WINDOWS_CLOUD_SELFTEST')=='1'then return require('tools.windows-demo.SelfTest').install()end
local rows,notice,selected,scroll={},nil,1,0
local engineRun,titleFont,bodyFont
local function start(row,remember)
 assert(P.valid(row.identity),'Invalid Windows profile')
 if remember then P.remember(love.filesystem,row)end
 love.filesystem.setIdentity(row.identity)
 assert(love.filesystem.getIdentity()==row.identity,'Profile selection failed; existing data were not moved.')
 -- Use this exact existing directory. Never copy/merge legacy accounts on
 -- startup, nor install a stable payload over this preview bootstrap.
 local getenv=os.getenv
 os.getenv=function(key)
  if key=='POKEPORT_IDENTITY'then return row.identity end
  if key=='POKEPORT_SKIP_LEGACY_MIGRATION'or key=='POKEPORT_NOTIFY_ONLY_UPDATES'then return'1'end
  return getenv(key)
 end
 require('src.core.SaveIdentity').migrateLegacy=function()return 0 end
 require('src.update.Check').start=function()return false end
 assert(love.filesystem.load('tools/windows-demo/original-main.lua'))()
 engineRun=assert(love.run,'The engine frame loop is missing.')
end
function love.load()
 local saved=P.readChoice(love.filesystem)
 rows,notice=P.scan(love.filesystem)
 if rows then
  local row=P.choose(rows,saved)
  if row and os.getenv('RETRO_WINDOWS_CHOOSE_PROFILE')~='1'then start(row,true);return end
 else rows={}end
 local standard=false
 for _,row in ipairs(rows)do if row.identity=='Gen2Recomp'then standard=true end end
 if not standard then rows[#rows+1]={identity='Gen2Recomp',new=not notice}end
end
function love.draw()
 local g=love.graphics;local w,h=g.getDimensions();g.clear(.035,.05,.08)
 titleFont=titleFont or g.newFont(23);bodyFont=bodyFont or g.newFont(16)
 g.setFont(titleFont);g.setColor(.92,.95,1);g.printf('RetroRecomped · Bisherige Daten weiterverwenden',30,25,w-60)
 g.setFont(bodyFont);g.setColor(.7,.8,.9)
 g.printf(notice or 'Mehrere Profile gefunden. Wähle dein bisheriges Profil. ROM-Importe, Konten, Mods und Spielstände bleiben in ihrem bisherigen Ordner. Es wird nichts zusammengeführt oder gelöscht.',30,75,w-60)
 local top=150;local height=math.max(120,h-230);local visible=math.max(1,math.floor(height/75))
 scroll=math.max(0,math.min(scroll,math.max(0,#rows-visible)))
 for i=scroll+1,math.min(#rows,scroll+visible)do
  local row=rows[i];local y=top+(i-scroll-1)*75
  g.setColor(i==selected and .12 or .07,i==selected and .27 or .12,i==selected and .33 or .18);g.rectangle('fill',25,y,w-50,66,8)
  g.setColor(.9,.96,1);g.print(row.new and 'Neues Standardprofil · vorhandene Profile bleiben erhalten' or row.identity,40,y+8)
  g.setColor(.63,.74,.82);g.printf(row.path or '%APPDATA%/Gen2Recomp',40,y+33,w-80)
 end
 g.setColor(.4,.85,.9);g.printf('Enter / A: Profil öffnen     Pfeile / Steuerkreuz: Auswahl     Esc / B: Beenden',30,h-55,w-60)
end
local function move(delta)
 delta=delta>0 and 1 or delta<0 and -1 or 0
 selected=math.max(1,math.min(#rows,selected+delta));scroll=math.max(0,selected-2)
end
function love.keypressed(key)
 if key=='up'then move(-1)elseif key=='down'then move(1)
 elseif key=='return'and rows[selected]then start(rows[selected],true)
 elseif key=='escape'then love.event.quit()end
end
function love.gamepadpressed(_,button)
 if button=='dpup'then move(-1)elseif button=='dpdown'then move(1)
 elseif button=='a'and rows[selected]then start(rows[selected],true)
 elseif button=='b'then love.event.quit()end
end
function love.mousepressed(x,y,button)
 if button~=1 or x<25 or x>love.graphics.getWidth()-25 or y<150 or y>love.graphics.getHeight()-80 then return end
 local index=scroll+math.floor((y-150)/75)+1
 local visible=math.max(1,math.floor(math.max(120,love.graphics.getHeight()-230)/75))
 if index>scroll+visible or(y-150)%75>=66 then return end
 if rows[index]then selected=index;start(rows[index],true)end
end
function love.wheelmoved(_,dy)move(-dy)end
-- Defer the actual engine loop, rather than keeping a menu loop around the
-- game. Its pacing, frame compositor and cleanup remain the engine's own.
function love.run()
 love.load()
 local frame
 return function()
  if engineRun then frame=frame or engineRun();return frame()end
  love.event.pump()
  for name,a,b,c,d,e,f in love.event.poll()do
   if name=='quit'then return a or 0 end
   if love.handlers[name]then love.handlers[name](a,b,c,d,e,f)end
   if engineRun then break end
  end
  if not engineRun and love.graphics.isActive()then
   love.graphics.origin();love.draw();love.graphics.present()
  end
  love.timer.sleep(.01)
 end
end
