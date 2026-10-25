io.stdout:setvbuf('no')
local root=assert(os.getenv('OBJECT_SHEETS_ENGINE'))
local mode=assert(os.getenv('OBJECT_SHEETS_MODE'))
local code=mode=='source' and assert(os.getenv('OBJECT_SHEETS_REFERENCE'))
  or mode=='baseline' and assert(os.getenv('OBJECT_SHEETS_BASELINE')) or root
package.path=code..'/?.lua;'..code..'/?/init.lua;'..package.path
function love.errorhandler(e) print(debug.traceback(tostring(e),2)); return function() return 1 end end
local function read(path) local f=assert(io.open(path,'rb'));local s=f:read('*a');f:close();return s end
local function hash(s) return love.data.hash('sha256',s):gsub('.',function(c)return('%02x'):format(c:byte())end) end
local function paletteHash(p)
  if not p then return nil end
  local words={};for i=0,15 do local n=p[i] or 0;words[i+1]=string.char(n%256,math.floor(n/256)%256) end
  return hash(table.concat(words))
end
local function canonical(v)
  if type(v)~='table' then return type(v)..':'..tostring(v) end
  local keys={};for k in pairs(v) do keys[#keys+1]=k end
  table.sort(keys,function(a,b)return type(a)==type(b) and a<b or type(a)<type(b)end)
  local out={};for _,k in ipairs(keys) do out[#out+1]=canonical(k)..'='..canonical(v[k])..';' end
  return '{'..table.concat(out)..'}'
end
function love.load()
  local J=require('src.link.Json');local V=require('src.core.GameVersion')
  local inputs=J.decode(read(assert(os.getenv('OBJECT_SHEETS_INPUTS'))))
  local out=assert(os.getenv('OBJECT_SHEETS_OUT'))
  local expected=mode=='native' and J.decode(read(out..'/source.json')) or nil
  local baseline=mode=='native' and J.decode(read(out..'/baseline.json')) or nil
  local report={mode=mode,editions={},gpu=false,playerProfilesUsed=false}
  for _,edition in ipairs({'firered','leafgreen','emerald','ruby','sapphire'}) do
    V.set(edition)
    local manifest=J.decode(read(root..'/tools/rom_manifest_'..edition..'.json'))
    local raw=read(inputs[edition]);local sha=love.data.hash('sha1',raw):gsub('.',function(c)return('%02x'):format(c:byte())end)
    assert(sha==manifest.romSha1,'wrong immutable cartridge')
    local count=manifest.layout.objectEventGfxCount
    local result={objects={},missing={},additionalNative={},differences={},sheets=0,frames=0,pixels=0}
    local rom,version,extractor,pals,reflect,native
    if mode=='source' then
      local Versions=require('src.import.gba.versions');Versions.select(sha);version=assert(Versions.lookup(sha))
      rom=setmetatable({_raw=raw,size=#raw,sha1=sha},require('src.import.gba.rom'))
      extractor=require('src.import.gba.ow_extract');pals=extractor.loadPaletteTable(rom,version)
      reflect=extractor.loadReflectionMappings(rom,version.ow_reflection)
    else
      extractor=require('src.import.RomExtractorGen3').new(raw,V.info(edition),manifest)
      local generated={};extractor.write=function(_,name,value)generated[name]=value end
      extractor.objectGfxSheet=function()return nil end
      local checkpoints=0;extractor.checkpoint=function()checkpoints=checkpoints+1 end
      extractor:extractOverworldSprites()
      result.nativeSprites=hash(canonical(assert(generated.sprites)))
      if mode=='native' then
        native=assert(generated.gen3_object_sheets,'actual sprite import did not emit original sheets')
        assert(checkpoints>0,'original sheet import omitted cooperative checkpoints')
        result.cooperativeCheckpoints=checkpoints
        assert(result.nativeSprites==baseline.editions[edition].nativeSprites,'normalized native sprite output changed')
        local text=require('src.import.LuaWriter').encodeSplit(native)
        local decoded=assert((loadstring or load)(text,'@generated/gen3_object_sheets.lua'))()
        assert(hash(canonical(decoded))==hash(canonical(native)),'generated cache module did not round-trip')
        result.cacheRoundTrip=true;result.cacheModuleBytes=#text
      end
    end
    for id=0,(mode=='baseline' and 0 or count)-1 do
      local record,indexed,rgba
      if mode=='source' then
        record=extractor.extractOne(rom,id,pals,version,reflect)
        if record then
          local frames={}
          for fi=1,record.frameCount do
            local rows={}
            for y=0,record.height-1 do
              local row={};for x=0,record.width-1 do row[x+1]=string.char(record.frames[fi][y*record.width+x+1] or 0) end
              rows[y+1]=table.concat(row)
            end
            frames[fi]=table.concat(rows)
          end
          indexed=table.concat(frames);rgba=extractor.bakeRgba(record)
        end
      else
        record=native.objects[id]
        if record then indexed=record.indexed;rgba=require('src.import.Gen3ObjectSheets').rgba(record) end
      end
      local key=tostring(id)
      if record then
        local summary={width=record.width,height=record.height,frames=record.frameCount,
          inanimate=record.inanimate,drawOffX=record.drawOffX,drawOffY=record.drawOffY,
          paletteTag=record.paletteTag,reflectionPaletteTag=record.reflectionPaletteTag,
          palette=paletteHash(record.palette),reflectionPalette=paletteHash(record.reflectionPalette),mappedPalette=paletteHash(record.mappedReflectionPalette),
          mappedReflection=record.reflectionPaletteMappedTag,indexed=hash(indexed),rgba=hash(rgba)}
        result.objects[key]=summary;result.sheets=result.sheets+1;result.frames=result.frames+record.frameCount
        result.pixels=result.pixels+#indexed
        if expected then
          local prior=expected.editions[edition].objects[key]
          if not prior then result.additionalNative[#result.additionalNative+1]=id
          else
            for _,field in ipairs({'width','height','frames','inanimate','drawOffX','drawOffY','paletteTag','reflectionPaletteTag','mappedReflection','palette','reflectionPalette','mappedPalette','indexed','rgba'}) do
              if prior[field]~=summary[field] then result.differences[#result.differences+1]={id=id,field=field,source=prior[field],native=summary[field]} end
            end
          end
        end
      elseif expected and expected.editions[edition].objects[key] then result.missing[#result.missing+1]=id end
      if id%32==31 then print('OBJECT_SHEET_PROGRESS',mode,edition,id+1,count,#result.differences) end
      collectgarbage('step',128)
    end
    report.editions[edition]=result
    local f=assert(io.open(out..'/'..mode..'.json','w'));f:write(J.encode(report));f:close()
    print('OBJECT_SHEET_EDITION',mode,edition,result.sheets,result.frames,result.pixels,#result.differences,#result.missing)
  end
  report.status='pass'
  if expected then for _,r in pairs(report.editions) do if #r.differences>0 or #r.missing>0 then report.status='different' end end end
  local f=assert(io.open(out..'/'..mode..'.json','w'));f:write(J.encode(report));f:close()
  love.event.quit(report.status=='pass' and 0 or 1)
end
