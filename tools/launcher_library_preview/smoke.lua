-- Real RomImporter, real GPU layout and normal mouse dispatch, with fixture
-- readiness and a harmless boot callback supplied by the preview host.
local checks=0
local function check(value,message) assert(value,message);checks=checks+1 end
local function click(ui,r)
  assert(r,'missing hit target')
  ui:mousepressed(r.x+math.min(24,r.width/2),r.y+math.min(20,r.height/2),1)
end
local function find(rows,key,value)
  for _,r in ipairs(rows or {}) do if r[key]==value then return r end end
end
return function(ui,step,boots)
  if step==1 then
    check(ui.section=='games' and ui.gamesView=='consoles','library is the landing page')
    local initial=ui:_settings().launcherLogoCards==true
    click(ui,ui._sb.logoCards)
    check(ui:_settings().launcherLogoCards==not initial,'logo cards checkbox persists its selected mode')
    click(ui,ui._sb.logoCards)
    check(ui:_settings().launcherLogoCards==initial,'the same checkbox restores the previous label mode')
    click(ui,find(ui._sb.libraryFilters,'filter','ready'))
    check(ui.libraryFilter=='ready','ready filter uses mouse dispatch')
  elseif step==2 then
    check(#ui._sb.tiles==3,'ready filter shows only imported fixtures')
    click(ui,find(ui._sb.consoles,'console','gbc'))
    check(ui.gamesView=='consoles','system filtering stays in the library')
  elseif step==3 then
    check(#ui._sb.tiles==2,'system and ready filters compose')
    click(ui,find(ui._sb.tiles,'version','crystal'))
    check(ui.tab=='crystal' and ui.gamesView=='game','cartridge opens the correct game')
  elseif step==4 then
    click(ui,ui.playButtonRect)
    check(ui._launcherSequence and boots()==0,'play starts insertion before boot')
    ui:keypressed('return');ui:update(0)
    check(boots()==1 and ui._handedOff,'skip hands off exactly once through the original play method')
    ui:play('crystal');check(boots()==1,'duplicate play is inert')
    -- Simulate returning from the game, without ever loading one.
    ui._handedOff=nil;ui._sequenceInputGuard=0
    click(ui,find(ui._sb.nav,'id','tools'))
  elseif step==5 then
    check(#ui._sb.tools==#require('src.import.LauncherSidebar').TOOLS,'grouped tools retain every existing tool')
    click(ui,find(ui._sb.nav,'id','settings'))
  elseif step==6 then
    check(#ui._workspaceCards==7,'settings starts with its category hub')
    click(ui,find(ui._workspaceCards,'id','cloud'))
  elseif step==7 then
    local rows=ui._settingsRowCache
    check(find(rows,'action','sbCloudSyncAll')~=nil,'cloud category retains its sync action')
    check(ui:_sbBack(),'back exits the category')
  elseif step==8 then
    click(ui,find(ui._workspaceCards,'id','launcher'))
  elseif step==9 then
    local motion
    for _,entry in ipairs(ui._settingsRowCache or {}) do
      if entry.row and entry.row.id=='launcherAnimations' then motion=entry end
    end
    check(motion and motion.row.labels[true]=='ON' and motion.row.labels[false]=='OFF','animation preference has boolean labels')
    ui:_setSettingValue(motion,false)
    check(ui:_settings().launcherAnimations==false,'animation preference uses normal persistence')
    ui:_setSettingValue(motion,true)
    check(ui:_sbBack(),'launcher settings returns to category hub')
    ui:_sbGo('games');ui.gamesView='game';ui:_sbBack()
    check(ui.gamesView=='consoles','game detail returns straight to the library')
    ui:_openCartDesigner('crystal')
  elseif step==10 then
    click(ui,find(ui._cartControls,'id','name'))
    for _=1,48 do ui:keypressed('backspace') end
    ui:textinput('NACHT / KRIS');ui:keypressed('return')
    click(ui,find(ui._cartControls,'id','shellHex'))
    ui:textinput('9876DC');ui:keypressed('return')
    check(ui._cartDraft.style.shell[1]==152,'custom RGB input updates the draft')
    local data=love.image.newImageData(8,8)
    data:mapPixel(function() return 0.6,0.4,0.9,1 end)
    local image,why=ui:_cartImageBytes(data:encode('png'):getString())
    check(image and not why,'custom PNG artwork decodes')
    ui._cartDraft.image=image.image;ui._cartDraft.png=image.bytes
    click(ui,find(ui._cartControls,'id','save'))
    check(ui._cartDraft.notice:find('saved')~=nil,'save button commits the design')
    ui:_sbGo('games')
  elseif step==11 then
    local style=ui:_cartStyle('crystal')
    check(style.name=='NACHT / KRIS' and style.shell[1]==152,'design survives closing the studio')
    check(style.image~=nil and love.filesystem.getInfo(style.art),'custom artwork reloads from the saved PNG')
    check(ui:_cartImageBytes('not an image')==nil,'invalid artwork is rejected')
    ui:play('crystal');ui:keypressed('escape');ui:update(0.1)
    check(boots()==1,'custom launch cancellation does not boot a game')
    local SaveData=require('src.core.SaveData')
    local opts=SaveData.loadOptions();opts.launcherCartDesigns.crystal=nil;SaveData.saveOptions(opts)
    ui._settingsCache=nil;ui._cartStyleCache=nil
    print('Live launcher smoke: '..checks..' checks passed')
    love.event.quit(0)
  end
end
