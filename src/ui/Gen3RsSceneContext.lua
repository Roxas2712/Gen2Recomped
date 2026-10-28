-- Private ROM-text/font/audio context shared by native RS scenes.
local Loader=require('compat.gen1-rs.Loader')
local Music=require('src.core.Music');local Sound=require('src.core.Sound')
local C={}
local function readLua(path)
  local f=assert(love.filesystem.load(path),'Missing native RS scene resource '..path)
  setfenv(f,{});return f()
end
function C.new(game,opts)
  opts=opts or {}
  local self={game=game}
  local version=require('src.core.GameVersion').get();assert(version=='ruby'or version=='sapphire')
  local spec=game.data.constants.gen3RsBirch;local songs=game.data.constants.gen3RsPresentation.songIds
  self.version=version;self.intro=spec
  local gv={current=version,get=function()return version end}
  local fs={}
  function fs.readActive(path)return love.filesystem.read(path)end
  fs.read=fs.readActive;fs.loadActive=readLua
  local blob={readFs=fs.readActive,decode=function(_,bytes)return bytes end}
  local audio={}
  function audio.playSong(name,options)
    local id=tonumber(name)or assert(songs[name],'Missing native Birch cue '..tostring(name))
    if options and options.restart then Music.stop()end
    return Music.play(game.data,('SONG_%03X'):format(id))
  end
  function audio.playSe(id)return Sound.playId(game.data,id)end
  function audio.playCry(number)
    local id
    for key,row in pairs(game.data.pokemon)do if row.index==number then id=key;break end end
    assert(id,'Unknown native Birch Pokemon')
    self.cry=Sound.playCry(game.data,id)
    return self.cry
  end
  -- Completion belongs to the shared native audio clock. A device can keep
  -- reporting a queued source as playing after the recording has completed.
  function audio.isCryFinished()return Sound.isCryFinished()end
  audio.fadeOutBgm=Music.fadeOutM4a
  local profile={id=version,family='rs',ui={}}
  profile.ui.frames={nativeLayout='rs',manifest='data/generated/gba/chrome/rs_frames.lua',userCount=20,
    user='data/generated/gba/chrome/user_frame_%d.rgba',std='user',sign=false,fillColor=15,
    dialogue={path='data/generated/gba/chrome/message_box.rgba',layout='rs_dialogue'},
    dialogueWindow={left=2,top=15,width=26,height=4},
    arrow={path='data/generated/gba/chrome/fonts/down_arrow.rgba',delay=6,period=6,lastPage=false}}
  local packages={loaded={['src.core.GameVersion']=gv,['src.core.game3.runtime']={_game=game,session={version=version}}}}
  local profiles={forSession=function()return profile end}
  packages.loaded['src.core.game3.profile']=profiles
  for name,value in pairs(opts.packageLoaded or {})do packages.loaded[name]=value end
  local sprites={}
  local ow={avatarGraphicsId=function(_,female)return spec.namingIcons[female and 'girl'or 'boy']end}
  function ow.get(id)
    if not sprites[id]then
      local def=assert(game.data.sprites[id],'Missing native naming avatar '..tostring(id))
      local s=require('src.render.SpriteRenderer').new(def,id)
      assert(s.tileW==16 and s.tileH==32 and s.frames[6],'Native naming avatar needs both walk steps')
      -- Host sheets use the canonical down-step slots 3 and 6. Native RS
      -- naming asks for raw animation frames 3,0,4,0.
      sprites[id]={image=s.image,width=s.tileW,height=s.tileH,quads={[0]=s.frames[0],[3]=s.frames[3],[4]=s.frames[6]}}
    end
    return sprites[id]
  end
  function ow.pose(_,_,_,_,opts)return opts.frame end
  local text={}
  local load
  local function getText(key)return opts.textIR and opts.textIR[key]or spec.textIR[key]end
  local function ir(key)return assert(getText(key),'Missing native RS scene label '..tostring(key))end
  text.ir=ir;text.translate=function(value)return value end
  function text.plain(key,ctx)return load('src.core.game3.scripting.text_ir').toAscii(ir(key),ctx)end
  function text.at(key,index)
    local value=assert(spec.textLists[key]and spec.textLists[key][index],'Missing native RS Birch list row')
    return load('src.core.game3.scripting.text_ir').toAscii(value)
  end
  text.has=function(key)return getText(key)~=nil end
  local bindings={
    __package=packages,
    ['src.core.GameVersion']=gv,['src.core.Logger']=require('src.core.Logger'),
    ['src.mods.Runtime']=require('src.mods.Runtime'),['src.render.Font']=require('src.render.Font'),
    ['src.import.CacheFs']=fs,['src.import.CacheBlob']=blob,
    ['src.import.gba.versions']={active=function()return version end,BUILD=version},
    ['src.core.game3.profile']=profiles,['src.core.game3.audio']=audio,
    ['src.core.game3.se_ids']=songs,['src.core.game3.rom_text']=text,
    ['src.core.game3.song_ids']=songs,
    ['src.core.game3.display']={W=240,H=160,TILE=8,COLS=30,ROWS=20},
    -- Naming is embedded in Birch's own state machine; its local stack
    -- registration never pushes or pops the authoritative host world.
    ['src.ui.game3.stack']={push=function()end,pop=function()end},
    ['src.core.game3.ow_sprites']=ow,
    ['src.core.game3.constants']={of=function(v)
      assert(v==version);return {require=function(_,family,name)assert(family=='songs');return assert(songs[name])end}
    end},
  }
  for name,value in pairs(opts.bindings or {})do bindings[name]=value end
  load=Loader.new(version,bindings)
  self.load=load;profile.font=load('src.core.game3.profiles.rs.font')
  load('src.ui.game3.chrome').setFrameType(math.max(0,((game.save.options or {}).gen3Frame or 1)-1))
  load('src.core.game3.rng').SeedRng(os.time()%65536)
  self.canvas=love.graphics.newCanvas(240,160,{dpiscale=1});self.canvas:setFilter('nearest','nearest')
  return self
end
return C
