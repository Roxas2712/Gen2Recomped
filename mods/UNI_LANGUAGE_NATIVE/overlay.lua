-- In-memory reads only. The event owner and bus identity make this overlay
-- inactive immediately when the loader removes the mod or replaces its bus.
return function(mod,game,files,display,easyChatUI,materialize)
  local Cache=require('src.import.CacheFs')
  local Runtime=require('src.mods.Runtime')
  local Version=require('src.core.GameVersion')
  local marker='mod.german_rom_source.overlay'
  mod.events:on(marker,function() end)
  local state={bus=Runtime.events,game=game,files=files,display=display}
  Cache._germanROMOverlay=state
  local function active()
    local s=Cache._germanROMOverlay
    return s and Runtime.events==s.bus and Runtime.wants(marker) and Version.get()==s.game and s
  end
  local Font=require('src.ui.game3.frlg_font')
  if not Font._ulaROMGlyphId then
    local glyphId=Font.glyphId;Font._ulaROMGlyphId=glyphId
    Font.glyphId=function(ch)
      local s=Cache._germanROMOverlay
      local glyphs=s and s.display.glyphs
      local code=glyphs and glyphs[ch]
      if code and active() then return code end
      return glyphId(ch)
    end
  end
    local function imageBytes(path)
      local s=active()
      if not s or type(path)~='string' or not path:match('%.png$') then return nil end
      local prefix=s.game..'/'
      if path:sub(1,#prefix)==prefix then path=path:sub(#prefix+1) end
      return s.files[path]
    end
  if not Cache._germanROMRead then
    Cache._germanROMRead=Cache.readAt
    Cache.readAt=function(path,...)
      local s=active()
      if s and type(path)=='string' then
        local prefix=s.game..'/'
        if path:sub(1,#prefix)==prefix then
          local data=s.files[path:sub(#prefix+1)]
          if data then return data end
        end
      end
      return Cache._germanROMRead(path,...)
    end
    -- Native RS panels also read raw tile/map blobs directly. Their decoded
    -- overlay bytes must reach that path as well as the PNG/cache readers.
    local Blob=require('src.import.CacheBlob')
    local readFs=Blob.readFs
    Blob.readFs=function(path,...)
      local s=active()
      if s and type(path)=='string' then
        local relative=path
        local prefix=s.game..'/'
        if relative:sub(1,#prefix)==prefix then relative=relative:sub(#prefix+1) end
        if relative:sub(1,19)=='data/generated/gba/' and s.files[relative] then
          return s.files[relative]
        end
      end
      return readFs(path,...)
    end
    -- FRLG boot art also uses filename-based LÖVE reads. Resolve just the
    -- generated PNGs owned by this overlay, including those direct loads.
    local imageData=love.image.newImageData
    local newImage=love.graphics.newImage
    love.image.newImageData=function(path,...)
      local data=imageBytes(path)
      if data then return imageData(love.data.newByteData(data)) end
      return imageData(path,...)
    end
    love.graphics.newImage=function(path,...)
      local data=imageBytes(path)
      if data then return newImage(imageData(love.data.newByteData(data)),...) end
      return newImage(path,...)
    end
  end
  -- Native Game3 modules are replaced on session handoff; their UI hooks
  -- need a fresh installation independently of the process-wide readers.
  local Indexed=require('src.core.game3.indexed_png')
  if not Indexed.__ulaLanguageOverlayNative then
    Indexed.__ulaLanguageOverlayNative=true
    local indexedLoad=Indexed.load
    Indexed.load=function(path)
      local data=imageBytes(path)
      if data then return Indexed.decode(data,Indexed.loveInflate) end
      return indexedLoad(path)
    end
    local function manifest(path)
      local s=active()
      local source=s and s.files[path]
      if not source then return nil end
      s.tables=s.tables or {}
      if not s.tables[path] then s.tables[path]=assert(loadstring(source,'@german/'..path))() end
      return s.tables[path]
    end
    local Contest=require('src.ui.game3.rse.contest')
    local contestIR=Contest.ir
    Contest.ir=function(key)
      local s=active()
      if s and s.display.language=='pt-BR' and (s.game=='ruby' or s.game=='sapphire') then
        local man=manifest('data/generated/gba/rse/rs_contest_gfx/manifest.lua')
        if man and man.localizedTexts and man.localizedTexts[key] then return man.localizedTexts[key] end
      end
      return contestIR(key)
    end
    local contestManText=Contest.manText
    Contest.manText=function(self,entry)
      local s=active()
      if s and s.display.language=='pt-BR' and type(entry)=='table' and entry.localizedIR then return entry.localizedIR end
      return contestManText(self,entry)
    end
    local reflow=assert(loadstring(assert(mod:read('ptbr_text_layout.lua'))))()
    local contestStartText=Contest.startText
    Contest.startText=function(self,...)
      local result=contestStartText(self,...)
      local s=active()
      if s and s.display.language=='pt-BR' then
        local p=self.printer
        -- RS declares a 28-tile backing window, but the shared renderer's
        -- contestant panel covers everything after x=144. Visible text is
        -- the same 17-tile area as Emerald, beginning at x=8.
        local width=math.min(assert(self.man.windows[4]).width*8,136)
        p.toks=reflow(p.toks,width,function(text)return Font.measure(text)end)
        -- Native speed-zero text is rendered during construction. Restart
        -- that printer with the same expanded tokens and native timing.
        p.pos,p.lines,p.active,p.state,p.delay=1,{''},true,'char',0
        p.scrollY,p.paused,p.arrowIdx,p.arrowDelay=0,0,0,0
        p.arrowFrame,p.lastCmd=nil,nil
        if p.speed==0 then
          for _=1,4096 do if not p.active then break end;p:render({new={},held={}})end
        end
      end
      return result
    end
    local Hatch=require('src.ui.game3.rs.egg_hatch')
    local hatchText=Hatch.Scene.text
    Hatch.Scene.text=function(self,key,vars)
      local s=active()
      if s and s.display.language=='pt-BR' and self.man.localizedTexts then
        return assert(self.man.localizedTexts[key]),{stringVars=vars or {}}
      end
      return hatchText(self,key,vars)
    end
    -- The native hatch fade supplies a BGR555 integer to the menu shader,
    -- whose API expects three 5-bit channels. Convert only this scene's
    -- display value; the palette and its fade state remain native.
    local hatchDraw=Hatch.Scene.draw
    Hatch.Scene.draw=function(self,...)
      local s=active()
      local fx=self.displayFx and self.displayFx[14]
      if not (s and s.display.language=='pt-BR' and fx and type(fx.color)=='number') then return hatchDraw(self,...) end
      local copy={};for k,v in pairs(fx)do copy[k]=v end
      local c=fx.color;copy.color={c%32,math.floor(c/32)%32,math.floor(c/1024)%32}
      self.displayFx[14]=copy
      local result=hatchDraw(self,...)
      self.displayFx[14]=fx
      return result
    end
    -- Completion clears the native blender host from inside frame(). Hold
    -- the current scene locally so the same tick never dereferences nil.
    local Blender=require('src.ui.game3.rs.berry_blender')
    local blenderOpen=Blender.open
    Blender.open=function(...)
      local result=blenderOpen(...)
      local layer=require('src.ui.game3.stack').top()
      local host=layer and layer.id==Blender.STACK_ID and layer.mod
      if host and not host._ulaCompletionGuard then
        host._ulaCompletionGuard=true;local update=host.update
        host.update=function(dt)
          local s=active()
          if not (s and s.display.language=='pt-BR')then return update(dt)end
          local screen=host.screen
          if screen and not screen.hidden then
            host.stepper:run(dt,function(inp)
              screen:frame(inp)
              return screen.done or screen.hidden or host.screen~=screen or nil
            end)
          end
        end
      end
      return result
    end
    local RSMessage=require('src.core.game3.rs.easy_chat_message')
    local messageBuild=RSMessage.build
    RSMessage.build=function(session,kind,...)
      local result=messageBuild(session,kind,...)
      local s=active()
      if not result or not s or s.display.language~='pt-BR' then return result end
      local text=require('src.core.game3.easy_chat_text').phrase(session[result.field or ({[0]='easyChatProfile',[1]='easyChatBattleStart',[2]='easyChatBattleWon',[3]='easyChatBattleLost'})[kind]],result.columns,result.rows)
      text=Font.wrap(text,208,{font='native_3'})
      local bytes={}
      for ch in Font.utf8Chars(text)do
        local code=ch=='\n' and 254 or Font.glyphId(ch)
        assert(code and code>=0 and code<255,'Unencodable native RS message glyph')
        bytes[#bytes+1]=code
      end
      bytes[#bytes+1]=255
      result.nativeBytes=bytes;result.text=text
      result.ir=require('src.core.game3.scripting.text_ir').fromAscii(text)
      return result
    end
    local Help=require('src.ui.game3.help_system')
    local helpShow,helpClose=Help.show,Help.close
    Help.show=function(...)
      local own=manifest('data/generated/gba/help/pack.lua')
      if own then
        if Help.pack~=own then
          if not Help._ulaHasBasePack then Help._ulaBasePack=Help.pack;Help._ulaHasBasePack=true end
          Help.installPack(own)
        end
      elseif Help._ulaHasBasePack then Help.installPack(Help._ulaBasePack);Help._ulaBasePack=nil;Help._ulaHasBasePack=nil end
      return helpShow(...)
    end
    Help.close=function(...)
      local result=helpClose(...)
      if Help._ulaHasBasePack then Help.installPack(Help._ulaBasePack);Help._ulaBasePack=nil;Help._ulaHasBasePack=nil end
      return result
    end
    local Fame=require('src.ui.game3.fame_checker')
    local famePack,fameIcon=Fame.pack,Fame.iconDescription
    Fame.pack=function()return manifest('data/generated/gba/fame_checker/pack.lua') or famePack()end
    Fame.iconDescription=function(...)
      local location,object=fameIcon(...)
      local s=active()
      if s and s.display.language=='pt-BR' then
        local IR=require('src.core.game3.scripting.text_ir')
        local function expand(v)return v and IR.toPlain(IR.fromAscii(v),{})end
        return expand(location),expand(object)
      end
      return location,object
    end
    -- Naming's filesystem loader is outside the mod's filesystem facade.
    -- Its public data consumers can use the same scoped, decoded manifest.
    local Naming=require('src.ui.game3.naming')
    local namingTemplate,namingPages=Naming.templateFromManifest,Naming.pagesFromKeyboard
    Naming.templateFromManifest=function(man,name)
      return namingTemplate(manifest('data/generated/gba/naming/manifest.lua') or man,name)
    end
    Naming.pagesFromKeyboard=function(kb)
      local man=manifest('data/generated/gba/naming/manifest.lua')
      return namingPages(man and man.keyboard or kb)
    end
    local Machine=require('src.ui.game3.rse.gba_machine')
    local machineManifest=Machine.manifest
    Machine.manifest=function(self,path) return manifest(path) or machineManifest(self,path) end
    local Kit=require('src.ui.game3.rse.scene_kit')
    local kitLua=Kit.loadLua
    Kit.loadLua=function(path) return manifest(path) or kitLua(path) end
    -- pokeruby/src/title_screen.c, GERMAN: 64x64 banner, x=108/172,
    -- y goal=84 (the US runtime assumes x=98/162 and y=66).
    local Title=require('src.ui.game3.rs.title')
    for _,name in ipairs({'bannerLeftCb','bannerRightCb'}) do
      local callback=Title[name]
      Title[name]=function(self,s)
        local state=active()
        if not state or (state.game~='ruby' and state.game~='sapphire') or state.display.language~='de' then return callback(self,s) end
        if s._germanBanner then s.y=s.y-18 else s.x=s.x+10;s._germanBanner=true end
        callback(self,s)
        s.y=s.y+18
      end
    end
    local Pokemon=require('src.core.game3.pokemon')
    -- The native summary panels have different widths. ROM translations may
    -- retain line breaks for a patched font; reflow once with the actual font
    -- used by this renderer. Cache per overlay, never per frame or save file.
    local Summary=require('src.core.game3.summary_data')
    local moveDescription=Summary.moveDescription
    Summary.moveDescription=function(...)
      local text=moveDescription(...)
      local s=active()
      if not s or s.display.language~='pt-BR' then return text end
      s.moveLines=s.moveLines or {}
      if not s.moveLines[text] then
        local rs=s.game=='ruby' or s.game=='sapphire'
        local width=(s.game=='firered' or s.game=='leafgreen') and 112 or 152
        local opts=rs and {font='native_'..require('src.ui.game3.rs.summary_menu').manifest().nativeWindow.fontNum} or {}
        s.moveLines[text]=Font.wrap(text:gsub('\n',' '),width,opts)
      end
      return s.moveLines[text]
    end
    local original=Pokemon.abilityName
    Pokemon.abilityName=function(id,...)
      local s=active()
      return s and s.display.abilities[id] or original(id,...)
    end
    local Trainers=require('src.core.game3.scripting.trainers')
    local trainer=Trainers.get
    Trainers.get=function(id,...)
      local row=trainer(id,...)
      local s=active()
      if s and row then row.className=s.display.classes[row.class] or row.className end
      return row
    end
  end
  -- A worker has a separate Lua state and cannot see our scoped overlay.
  -- Route owned atlases through the cache-aware synchronous decoder.
  local dataset=require('src.core.game3.dataset').cache()
  if not dataset._languageWorkerSpec then
    dataset._languageWorkerSpec=dataset.assetWorkerSpec
    local write=dataset.write
    dataset.write=function(self,path,bytes)
      local s=active()
      local pairRoot=path:match('^(data/generated/gba/native/[^/]+)/')
      if s and pairRoot and s.files[pairRoot..'/mids.idx'] then
        s.files[path]=bytes
        return true
      end
      return write(self,path,bytes)
    end
    dataset.assetWorkerSpec=function(self,root,kind,key)
      local s=active()
      if s and s.files[root..'/'..tostring(key)..'/mids.idx'] then return nil end
      return self._languageWorkerSpec(self,root,kind,key)
    end
  end
  require('src.core.game3.tileset_native').invalidate()
  require('src.core.game3.gba_ppu').clearCache()
  require('src.ui.game3.rse.scene_kit').resetCaches()
  require('src.ui.game3.rse.mapsec').reset()
  require('src.ui.game3.fame_checker').reloadAssets()
  require('src.core.game3.rse.contest').reset()
  if easyChatUI then easyChatUI(active)end
  if materialize then
    -- Debuggers/other mods retain the complete assets-table interface. Normal
    -- play uses the internal on-demand table and does not expand unused art.
    setmetatable(mod.exports,{__index=function(t,key)
      if key=='assets' then local all=materialize();rawset(t,key,all);return all end
    end})
  else mod.exports.assets=files end
  return active
end
