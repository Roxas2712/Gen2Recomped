-- Pinned RS menu presentation over the host's save slots and callbacks.
local M={};M.__index=M
local KEYS={continue='CONTINUE',newGame='NEW_GAME',option='OPTION',exit='EXIT'}
local LABELS={continue='CONTINUE',newGame='NEW GAME',option='OPTION',exit='EXIT GAME'}
function M.available(owner)
  local version=require('src.core.GameVersion').get()
  if not require('src.import.Gen3RsMainMenuAssets').valid(
    (owner.game.data.constants or{}).gen3RsMainMenu,version)then return false end
  -- A mod owns its custom rows/labels and retains the host's menu contract.
  -- Never silently drop a row because the cartridge has no matching action.
  local seen={}
  for _,item in ipairs(owner.items)do
    if not KEYS[item.key]or seen[item.key]or item.onSelect
      or item.label~=require('src.core.Strings')(LABELS[item.key])then return false end
    seen[item.key]=true
  end
  return seen.newGame and seen.option and seen.exit or false
end
function M.snapshot(game,save)
  if type(save)~='table'then return nil end
  local data=game.data;local player=save.player or{}
  local load=require('compat.gen1-rs.Loader').new(require('src.core.GameVersion').get())
  local C=require('compat.gen1-rs.Constants').new(load)
  local flags=save.flags or{};local vars=save.gen3Vars or{}
  local function flag(n)local v=flags[n];if v==nil then v=flags[('FLAG_G3_%04X'):format(n)]end;return v==true or v==1 end
  local dex=save.pokedex or{}
  local magic=dex.nationalMagic or(save.nationalDex==true and 0xDA or nil)
  local national=tonumber(magic)==0xDA and vars[C:var('VAR_NATIONAL_DEX')]==0x302
    and flag(C:flag('FLAG_SYS_NATIONAL_DEX'))
  local indices,byDex={},{}
  for id,def in pairs(data.pokemon)do
    if def.index then indices[def.index]=id end
    if def.dex then byDex[def.dex]=id end
  end
  local regional=assert(data.constants.gen3HoennDex.numbers)
  local count,seen=0,{}
  local function owned(id)
    local h=id and regional[id]
    if id and not seen[id]and(national or(h and h>=1 and h<=202))then seen[id]=true;count=count+1 end
  end
  for _,kind in ipairs({'caught','owned'})do
    for key,on in pairs(dex[kind]or{})do
      local id=data.pokemon[key]and key or indices[tonumber(key)]
      if on and on~=0 then owned(id)end
    end
  end
  local imported=save.modData and save.modData.cartImport
  for _,n in ipairs(imported and imported.dexOwned or{})do owned(byDex[tonumber(n)])end
  local seconds=math.floor(require('src.core.SaveData').playSeconds(save))
  return{name=player.name or'',gender=player.gender=='girl'and 1 or 0,
    hours=math.floor(seconds/3600),minutes=math.floor(seconds/60)%60,
    dexCount=count,badges=require('src.inventory.Badges').count(data,save),
    frameType=math.max(0,math.min(19,math.floor(tonumber((save.options or{}).gen3Frame)or 1)-1))}
end
function M.new(owner)
  assert(M.available(owner))
  local self=setmetatable({owner=owner,game=owner.game},M)
  local save
  for _,item in ipairs(owner.items)do if item.key=='continue'then
    save=require('src.core.SaveData').load(require('src.core.GameVersion').get());break
  end end
  self.saved=save
  local context=require('src.ui.Gen3RsSceneContext').new(self.game,{
    textIR=self.game.data.constants.gen3RsMainMenu.textIR,
    bindings={
      -- Host RTC is provided by the platform clock, without a cartridge battery.
      ['src.core.game3.rtc']={ERR={FLAG_MASK=255},errorStatus=function()return 0 end},
      ['src.core.game3.scripting.flags']={},
      ['src.ui.game3.screens']={},['src.ui.game3.stack']={top=function()return nil end},
    },
  })
  self.load,self.canvas=context.load,context.canvas
  local info=M.snapshot(self.game,save)
  self.scene=self.load('src.ui.game3.rs.main_menu').new({hasContinue=save~=nil,
    continueInfo=info,textSpeed=(save and save.options or self.game.save.options or{}).textSpeed})
  self.scene.items={}
  for _,item in ipairs(owner.items)do self.scene.items[#self.scene.items+1]=KEYS[item.key]end
  self.scene._openOptions=function(scene)
    self.waitingOptions=true;scene.state='host_options'
    owner:choose({key='option'})
  end
  self:setFrame(info and info.frameType or 0)
  return self
end
function M:setFrame(frame)
  self.load('src.ui.game3.chrome').setFrameType(frame)
end
function M:update(dt)
  local scene=self.scene;local owner=self.owner
  if self.waitingOptions then
    if self.game.stack:top()~=owner then return end
    self.waitingOptions=nil
    self:setFrame(math.max(0,math.min(19,((self.game.save.options or{}).gen3Frame or 1)-1)))
    scene.state='check_save'
    local Pal=self.load('src.core.game3.pal_fade')
    scene.pal:beginFade(Pal.ALL,0,16,0,Pal.BLACK)
    return
  end
  local result=scene:update(self.game.input,dt or 1/60)
  owner.index=scene.cursor
  if result=='title'then return owner:close()end
  if result=='newGame'then return owner:choose({key='newGame'})end
  if type(result)=='table'and result.action=='exit'then return owner:choose({key='exit'})end
  if type(result)=='table'and result.action=='continue'then
    -- The original window already displays stats; A loads the active host slot.
    if owner.onContinue then return owner.onContinue()end
  end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene:draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  if self.scene then self.scene:destroy()end
  if self.canvas then self.canvas:release()end
  self.load,self.canvas,self.scene=nil,nil,nil
end
return M
