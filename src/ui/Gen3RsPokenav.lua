-- Native RS navigation controller in its own module/font/cache scope.
-- The host remains the owner of saves, stable IDs, flags and Pokemon.
local M={};M.__index=M
M.screenId='Gen3RsPokenav';M.holdsUIAnchors=true
function M.available(game)
  local v=require('src.core.GameVersion').get()
  local s=game and game.data and game.data.constants and game.data.constants.gen3RsPokenav
  return (v=='ruby'or v=='sapphire')and type(s)=='table'and s.version==v and s.format==1
end
function M.new(game,opts)
  assert(M.available(game));opts=opts or {}
  local data,save=game.data,game.save
  local mapKit=require('src.ui.Gen3RsMapKit').new(game)
  local session,C=mapKit.session,mapKit.constants
  -- Share the wall-map adapter's compatibility view of legacy visit records.
  -- These are temporary native flag aliases, never writes to save.flags.
  mapKit.visitedFlags={}
  local firstVisit=C:flag('FLAG_VISITED_LITTLEROOT_TOWN')
  for id,visited in pairs(save.visited or {})do
    local def=data.maps[id];local section=def and def.regionMapSection
    if (visited==true or visited==1)and section and section>=0 and section<=15 then
      mapKit.visitedFlags[firstVisit+section]=true
    end
  end
  session.party=save.party or {};session.storage={boxes={}}
  for i=1,14 do
    local box=(save.boxes or {})[i]or {}
    session.storage.boxes[i]={name=(save.boxNames or {})[i]or ('BOX '..i),mons=box.mons or box}
  end
  session.regionMapZoom=save.gen3PokenavZoom==true
  session.trainerRematches=save.rematches or {}
  session.gameStats=save.gen3Stats or {};session.giftRibbons=save.gen3GiftRibbons or {}
  local maps={};for id,raw in pairs(data.maps)do maps[id]=mapKit.mapView(raw)end
  local proxyGame={data={maps=maps}}
  local species,trainers={},{ }
  for id,def in pairs(data.pokemon)do species[def.index]={id=id,def=def}end
  for _,row in pairs(data.trainers or {})do trainers[row.index]=row end
  local Pokemon=require('src.pokemon.Pokemon')
  local function row(id)return assert(species[tonumber(id)],'Unknown native PokeNav species '..tostring(id))end
  local function speciesOf(mon)return mon and data.pokemon[mon.species]and data.pokemon[mon.species].index or 0 end
  local function picture(mon)
    local path=require('src.pokemon.Sprites').path(data,mon.species,'front',{mon=mon,kind='summary'})
    return path and {image=require('src.render.Assets').image(path)}or nil
  end
  local context
  local bindings={
    ['src.core.game3.constants']={of=function()return C end},
    ['src.core.game3.scripting.flags']={getFlag=function(_,_,id)return session.flags[id]end,
      getVar=function(_,_,id)return session.vars[id]end},
    ['src.core.game3.rse.init']={mapGroupNum=function(id)
      local def=data.maps[id];return def and def.group,def and def.number
    end,missing=function(_,name)error('Native RS PokeNav feature unavailable: '..tostring(name))end},
    ['src.core.game3.pokemon']={speciesOf=speciesOf,isEgg=function(mon)return mon.isEgg==true or mon.egg==true end,
      displayName=function(mon)return mon.nickname or data.pokemon[mon.species].name end,
      name=function(id)return row(id).def.name end,monFrontPic=picture,
      growthRate=function(id)return row(id).def.growthRate end,
      gender=function(id,pid)
        local g=Pokemon.genderOf(data,{species=row(id).id,personality=pid})
        return g=='male'and 'M'or g=='female'and 'F'or 'U'
      end},
    ['src.core.game3.summary_data']={expForLevel=function(growth,level)
      return require('src.pokemon.Growth').expForLevel(growth,level,data.growth_rates)
    end},
    ['src.core.game3.scripting.trainers']={get=function(id)return trainers[id]end},
    ['src.core.game3.trainer_pic']={front=function(path)
      return path and {image=require('src.render.Assets').image(path)}or nil
    end},
    ['src.core.game3.dataset']={cache=function()return {read=function(_,path)
      local man=assert(session._markingsManifest)
      local file=path:find('gPokenavConditionMenuMisc_Gfx',1,true)and man.tiles
        or path:find('gUnknown_08E966B8',1,true)and man.palette
      return file and love.filesystem.read(file)
    end}end},
    ['src.ui.game3.window']={template=function(x,y,w,h)return {x=x,y=y,w=w,h=h}end,
      userFrame=function(win)return context.load('src.ui.game3.chrome').stdFrame(win.x,win.y,win.w,win.h)end},
    ['src.ui.game3.fade']={clear=function()end,begin=function()end,MODE={FROM_BLACK=1}},
  }
  local self=setmetatable(require('src.ui.Gen3RsSceneContext').new(game,{
    bindings=bindings,packageLoaded={
      ['src.core.game3.scripting.space']=false,
      ['src.core.game3.map']={currentDef=function()return maps[session.map]end},
      ['src.core.game3.player']=setmetatable({},{__index=function(_,key)
        return key=='cellX'and session.x or key=='cellY'and session.y or nil
      end}),
    },
  }),M)
  context=self
  self.session=session;self.mapKit=mapKit;self.onCancel=opts.onCancel
  session._markingsManifest=self.load('src.ui.game3.rse.scene_kit').manifest('rse/pokenav_markings')
  self.scene=self.load('src.ui.game3.rs.pokenav.init')
  self.state=self.scene.show({session=session,game=proxyGame,onClose=function()
    if session.regionMapZoom~=(save.gen3PokenavZoom==true)then save.gen3PokenavZoom=session.regionMapZoom end
    local done=self.onCancel;game.stack:pop();if done then done()end
  end})
  self.isOpaque=false
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return {require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  if self.closed then return end
  self.scene.Host.handleInput(self.game.input)
  self.scene.Host.update(dt or 1/60)
  self.isOpaque=not self.closed and self.state.phase~='field'
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,0)
    self.scene.Host.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.closed=true;if self.scene then self.scene.reset()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas=nil,nil,nil
end
return M
