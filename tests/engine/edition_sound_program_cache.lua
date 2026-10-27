package.path='./?.lua;./?/init.lua;'..package.path
love=require('tests.love_stub');local T=require('tests.harness')
local active='emerald/'
package.loaded['src.core.GameVersion']={cachePrefix=function()return active end}
local images={
 ['emerald/program.bin']=string.char(0xB1)..string.rep('E',0x3FFF),
 ['sapphire/program.bin']=string.char(0x81,0xB1)..string.rep('S',0x3FFE),
 ['ruby/program.bin']=string.char(0x82,0xB1)..string.rep('R',0x3FFE),
}
local reads={}
love.filesystem.read=function(path)
 reads[#reads+1]=path
 return images[path]or images[active..path]
end
local Fs=require('src.core.WorkerFs')
local M4A=require('src.core.M4ASynth');local Chip=require('src.core.ChipSynth')
local data={audio={gen3={file='program.bin',base=0},programFile='program.bin',bankOrder={1}}}
local song={tracks={0}};local chip={chip={blob='',waves={},channels={}}}
local durations={}
for _,prefix in ipairs({'emerald/','sapphire/','ruby/','emerald/'})do
 active=prefix
 T.eq(Fs.prefix(),prefix,'desktop workers retain the originating cartridge prefix')
 local m=M4A.newEngine(data,song,{allowLoops=false})
 T.eq(m.image,images[prefix..'program.bin'],'M4A does not reuse another cartridge image')
 local g=Chip.newEngine(data,chip)
 T.eq(g.banks[1],images[prefix..'program.bin'],'GB/GSC programs also remain edition-scoped')
 local before=#reads
 T.eq(M4A.newEngine(data,song).image,m.image,'same-edition M4A cache is retained')
 T.eq(Chip.newEngine(data,chip).banks[1],g.banks[1],'same-edition GB cache is retained')
 T.eq(#reads,before,'same edition does not reread the program')
 for frame=1,100 do
  if m.tracks[1].ended then durations[prefix]=frame;break end
  m:frame()
 end
 T.check(durations[prefix]~=nil,'finite song finishes in its own image')
end
T.check(durations['sapphire/']>durations['emerald/'],'stale Emerald bytes cannot shorten Sapphire title duration')
active='sapphire/';data.audio.programPrefix='emerald/'
T.eq(M4A.newEngine(data,song).image,images['emerald/program.bin'],'worker snapshot keeps its explicit origin after the host switches')
T.eq(Chip.newEngine(data,chip).banks[1],images['emerald/program.bin'],'explicit GB origin also wins over current edition')
T.eq(data.audio.programPrefix,'emerald/','synthesis does not rewrite audio metadata')
T.finish('Cartridge-isolated sound program caches')
