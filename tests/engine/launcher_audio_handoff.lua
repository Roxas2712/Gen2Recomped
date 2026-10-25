package.path='./?.lua;'..package.path
love=require('tests.love_stub')
local n=0;local function check(v,m) assert(v,m);n=n+1 end
local sources={}
love.audio={newSource=function(file)
 local s={file=file,play=function(self) self.playing=true end,stop=function(self) self.playing=false end,
 pause=function(self) self.playing=false end,isPlaying=function(self) return self.playing end,
 setVolume=function(self,v) self.volume=v end,setLooping=function() end,setFilter=function() end}
 sources[#sources+1]=s;return s
end}
local Music=require('src.core.Music');local Sound=require('src.core.Sound')
local data={audio={songs={PREVIEW={file='preview.wav'},GAME={file='game.wav'}},sfx={Click={file='click.wav'}}}}
Music.play(data,'PREVIEW');Music.suspend()
local B=require('src.import.LauncherBackdrop')
package.loaded['src.import.CacheFs']={unmountVersion=function() end}
package.loaded['src.core.Data']={unloadGenerated=function() end}
B._state.game={data=data};B._state.current='red';B._state.paused=true
B.stop();local before=#sources
Music.play(data,'GAME');Music.update(data);Sound.play(data,'Click')
check(#sources>=before+2,'a preview paused by the intro cannot leave the next game music or effects suspended')
check(Music.current()=='GAME','hand-off does not re-cue the old preview song')
Music.applyOptions({audioMuted=true,musicVol=5});local song=sources[#sources-1]
check(song.volume==0,'master mute applies to the running music source')
Music.setVolumeLevel(7);check(song.volume==0,'changing music volume cannot bypass master mute')
Music.applyOptions({audioMuted=false,musicVol=5});check(song.volume>0,'unmute restores the chosen music level')
Music.fadeOut(1);Music.applyOptions({audioMuted=true,musicVol=5});Music.update(data)
check(song.volume==0,'a scripted fade cannot turn music back on after master mute')
Sound.applyOptions({audioMuted=true,sfxVol=5});Sound.play(data,'Click')
check(sources[#sources].volume==0,'master mute also silences already cached effects')
Sound.applyOptions({audioMuted=false,sfxVol=5});check(sources[#sources].volume>0,'unmute restores the saved effects level')
check(not require('src.import.CartridgeDownload').start('red',false),'original artwork requires explicit confirmation before any network request')
local g=love.graphics;local originalWidth,originalHeight=g.getWidth,g.getHeight
g.getWidth=function() return 1280 end;g.getHeight=function() return 720 end
local widthFn,heightFn=g.getWidth,g.getHeight;local pixelWidth=g.getPixelWidth
local savedRenderer=package.loaded['src.render.Renderer'];package.loaded['src.render.Renderer']={}
B._state.game={_draw=function()
 check(g.getWidth()==480 and g.getHeight()==432,'preview rendering sees its native aspect canvas')
 g.setCanvas()
end};B._state.current='red';B._state.canvas=nil;B._state.paused=false
check(B.draw(600,200,{x=100,y=20,w=348,h=200,fit='cover'}),'an offscreen preview renders without starting a game')
check(g.getWidth==widthFn and g.getHeight==heightFn and g.getWidth()==1280 and g.getHeight()==720,
 'preview cannot leave native canvas dimensions installed on the launcher window')
check(g.getPixelWidth==pixelWidth,'temporarily supplied graphics APIs are also restored when originally absent')
B._state.game=nil;B._state.current=nil;B._state.canvas=nil
package.loaded['src.render.Renderer']=savedRenderer;g.getWidth,g.getHeight=originalWidth,originalHeight
local L=require('src.import.LauncherLibrary');local calls={}
B.current=function() return 'red' end
B.draw=function(_,_,area) calls[#calls+1]=area;return true end
local rectangles,meshes=0,0;local originalRect,originalMesh=g.rectangle,g.newMesh
g.rectangle=function() rectangles=rectangles+1 end
g.newMesh=function(vertices) meshes=meshes+1;check(#vertices==4,'banner shade is a single interpolated quad');return {} end
check(L.preview({},'red',10,20,300,170) and calls[1].x==136 and calls[1].w==174 and calls[1].h==170 and calls[1].fit=='cover',
  'the preview covers the right side of the selected banner without stretching or hiding save actions')
check(rectangles==0 and meshes==1,'the preview shade has no overlapping strip edges')
check(not L.preview({},'crystal',0,0,300,170) and #calls==1,'another game never inherits the selected game preview')
g.rectangle,g.newMesh=originalRect,originalMesh
print('Launcher audio handoff: '..n..' checks passed')
