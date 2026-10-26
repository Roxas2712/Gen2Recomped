-- One process-wide wrapper; multiple layers on the current bus let the
-- language artwork and saved-name font fallback coexist without retaining
-- byte strings from previous sessions.
return function(mod,version,prefix,files)
 local A=require('src.render.Assets');local Runtime=require('src.mods.Runtime');local V=require('src.core.GameVersion')
 local marker='mod.german_rom_source.gb';mod.events:on(marker,function()end)
 local state=A.__ulaGBOverlay
 if not state then
  state={paths={},layers={}};A.__ulaGBOverlay=state
  local imageData,image=love.image.newImageData,love.graphics.newImage
  local exists,resolve=A.exists,A.resolve
  local function active()return Runtime.events==state.bus and Runtime.wants(marker) and V.get()==state.version end
  local function bytes(path)
   if active() and type(path)=='string'then
    for i=#state.layers,1,-1 do local layer=state.layers[i]
     if path:sub(1,#layer.prefix+1)==layer.prefix..'/'then return layer.files[path:sub(#layer.prefix+2)]end
    end
   end
  end
  A.exists=function(path)return bytes(path)~=nil or exists(path)end
  love.image.newImageData=function(path,...)local b=bytes(path);return imageData(b and love.data.newByteData(b) or path,...)end
  love.graphics.newImage=function(path,...)local b=bytes(path);return image(b and imageData(love.data.newByteData(b)) or path,...)end
  A.resolve=function(path)
   local resolved=resolve(path)
   local tile=type(path)=='string' and path:match('^assets/[^/]+/tilesets/([^/]+%.png)$')
   if active() and path==resolved and tile then
    for i=#state.layers,1,-1 do local layer=state.layers[i]
     if layer.files['assets/tilesets/'..tile]then return layer.prefix..'/assets/tilesets/'..tile end
    end
   end
   return resolved
  end
  state.imageData=imageData
  function state.clear()
   for _,p in ipairs(state.paths)do A.compose(p,nil)end
   state.paths={};state.layers={};state.bus=nil
  end
 end
 if state.bus~=Runtime.events then state.clear()end
 state.version=version;state.bus=Runtime.events
 for i=#state.layers,1,-1 do if state.layers[i].prefix==prefix then table.remove(state.layers,i)end end
 state.layers[#state.layers+1]={prefix=prefix,files=files}
 for path,data in pairs(files)do if path:match('%.png$')then
  local full=prefix..'/'..path;state.paths[#state.paths+1]=full
  A.compose(full,function()return state.imageData(love.data.newByteData(data))end)
 end end
end
