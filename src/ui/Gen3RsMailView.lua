-- Original RS reader/composer in an isolated font/resource/RNG scope.
local M={};M.__index=M;M.isOpaque=true;M.holdsUIAnchors=true
function M.available(game)
  return require('src.import.Gen3RsMailAssets').valid(game and game.data and game.data.constants
    and game.data.constants.gen3RsMail,require('src.core.GameVersion').get())
end
function M.context(game,extra)
  local data,save=game.data,game.save
  local version=require('src.core.GameVersion').get()
  local C=require('compat.gen1-rs.Constants').new(require('compat.gen1-rs.Loader').new(version))
  local species,moves={},{}
  for id,d in pairs(data.pokemon or{})do species[d.index]={id=id,def=d}end
  for id,d in pairs(data.moves or{})do moves[d.index]={id=id,def=d}end
  local quads={};local manifest
  local function icon(number)
    local img,height
    if number>=412 then
      if not manifest then local f=assert(love.filesystem.load('data/generated/gba/rse/party_extras/manifest.lua'));setfenv(f,{});manifest=f()end
      assert(manifest.game==version and manifest.layout=='rs')
      img=require('src.render.Assets').image(assert(manifest.icons[number]));height=32
    else
      img,height=require('src.ui.Gen3PartyMenu').iconFor({game=game},{species=assert(species[number]).id})
    end
    assert(img and height==32,'Native RS mail icon missing')
    if not quads[img]then quads[img]={};local w,h=img:getDimensions()
      for i=0,math.floor(h/32)-1 do quads[img][i]=love.graphics.newQuad(0,i*32,32,32,w,h)end
    end
    return{image=img,quads=quads[img],w=32,h=32}
  end
  local function flag(name)
    local n=C:flag(name);local flags=save.flags or{}
    local v=flags[n];if v==nil then v=flags[('FLAG_G3_%04X'):format(n)]end
    return v==true or v==1
  end
  local bindings={
    ['src.core.Strings']=require('src.core.Strings'),
    ['src.core.game3.pokemon']={name=function(n)return assert(species[n]).def.name end,
      moveName=function(n)return assert(moves[n]).def.name end,icon=icon},
    ['src.core.game3.rse.old_man']={isTrendySayingUnlocked=function(n)
      return require('src.script.EasyChat').knowsPhrase(save,n)
    end},
    ['src.core.game3.rse.init']={flag=flag,setFlag=function(name,value)
      assert(name=='FLAG_SYS_CHAT_USED');save.flags=save.flags or{}
      save.flags[('FLAG_G3_%04X'):format(C:flag(name))]=value==true
    end},
  }
  for k,v in pairs(extra or{})do bindings[k]=v end
  local labels={};for k,v in pairs(data.constants.gen3RsMail.textIR)do labels[k]=v end
  -- The mailbox names the first GIVE label, the party the second. Both
  -- supported cartridge hashes contain identical five bytes at these symbols.
  labels.OtherText_Give=labels.OtherText_Give or labels.OtherText_Give2
  local context=require('src.ui.Gen3RsSceneContext').new(game,{bindings=bindings,textIR=labels})
  local f=assert(love.filesystem.load('data/generated/gba/easy_chat/words.lua'));setfenv(f,{})
  local pack=f();assert(pack.build==version and pack.assetLayout=='rs')
  context.load('src.core.game3.easy_chat_text').install(pack)
  context.gates={flag=flag,seen=function(n)
    local row=species[n];return row and(save.pokedex or{}).seen and save.pokedex.seen[row.id]==true or false
  end,national=function()return save.nationalDex==true end}
  return context
end
function M.new(game,opts)
  assert(M.available(game));assert(opts.kind=='reader'or opts.kind=='composer')
  local self=setmetatable({game=game,opts=opts,screenId='Gen3RsMail'..opts.kind},M)
  local expected=opts.kind=='reader'and'rs_mail'or'rs_mail_composer'
  local context=M.context(game,{['src.ui.game3.stack']={
    push=function(id)assert(id==expected);self.started=true end,
    pop=function(id)assert(id==expected);if self.started and not self.exiting then self.finished=true end end}})
  self.load,self.canvas=context.load,context.canvas
  self.scene=self.load('src.ui.game3.rs.mail_'..(opts.kind=='reader'and'reader'or'composer'))
  local player=game.save.player or{}
  local session={version=require('src.core.GameVersion').get(),gender=player.gender=='girl'and'female'or'male'}
  local options={session=session,gates=context.gates,onClose=function(...)
    self.result={...};self.finished=true
  end}
  if opts.kind=='reader'then
    self.scene.read(assert(opts.record),options)
    -- pokeruby ItemMenu_ReadMail passes hasText=0 for unused stationery.
    -- Keep its selected design while suppressing text/signature parsing.
    if opts.hasText==false then
      self.scene._content.hasText=false;self.scene._content.rows={};self.scene._content.signature=nil
    end
  else self.scene.write(assert(opts.record),options)end
  self.step=self.load('src.ui.game3.rse.scene_kit').stepper()
  return self
end
function M:uiSize()return 240,160 end
function M:wantsFillScale()return true end
function M:wantsEdgeBleed()return false end
function M:sgbPalettes()return{require('src.render.PaletteFX').trueColorZone(0,0,29,19)}end
function M:update(dt)
  self.step:collect(self.game.input)
  local finished=self.step:run(dt,function(input)
    self.scene.handleInput({wasPressed=function(_,k)return input.new[k]end,isDown=function(_,k)return input.held[k]end})
    self.scene.update();return self.finished or nil
  end)
  if finished then
    local done,result=self.opts.onDone,self.result or{}
    self.opts.onDone=nil;self.game.stack:pop();if done then done(unpack(result))end
  end
end
function M:draw()
  local g=love.graphics
  local ok,why=require('src.render.GraphicsScope').call(function()
    g.setCanvas(self.canvas);g.origin();g.setScissor();g.setShader();g.clear(0,0,0,1);self.scene.draw()
  end)
  if not ok then error(why,0)end
  g.setColor(1,1,1,1);g.draw(self.canvas,0,0)
end
function M:exit()
  self.exiting=true;if self.scene then self.scene._onClose=nil;self.scene.reset()end
  if self.canvas then self.canvas:release()end
  self.scene,self.load,self.canvas,self.step=nil,nil,nil,nil
end
return M
