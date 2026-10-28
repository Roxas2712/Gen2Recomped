-- Check final module-page controls at narrow and wide content widths.
-- Contributions by Roxas2712.
package.path='./?.lua;'..package.path
love=require('tests.love_stub');local noop=function()end
package.loaded['src.import.LauncherLibrary']={paint={text=noop,surface=noop}}
package.loaded['src.import.LauncherHardware']={cartridge=noop}
local Page=require('src.import.LauncherPinballPage')
for _,width in ipairs{420,780,1400}do
 local buttons={};local ui={_s=1,_sb={back={x=0,y=-45,width=34,height=34,pinned=true}}}
 function ui:_chipButton(x,y,label,o)return{x=x,y=y,width=o.w,height=o.h,label=label}end
 function ui:_playButton(x,y,w,h)self.playButtonRect={x=x,y=y,width=w,height=h,label='play'}end
 local profile={};for i=1,5 do profile[i]={name='Language '..i,selected=i==1,saved=false,select=noop}end
 local actions={back=noop,play=noop,design=noop,import=noop,saveImport=noop,saveExport=noop,saved=true,profiles=profile}
 local height=Page.draw(ui,{palette=function()return{}end},0,0,width,{},false,actions,function(r)buttons[#buttons+1]=r end)
 assert(buttons[2].label=='play'and height>300,'shared header and primary Play remain first')
 for i,a in ipairs(buttons)do
  if not a.pinned then
   assert(a.x>=0 and a.x+a.width<=width+.01,'control exceeds viewport at '..width)
   for j,b in ipairs(buttons)do
    if j>i and not b.pinned then
     local overlap=a.x<b.x+b.width and b.x<a.x+a.width and a.y<b.y+b.height and b.y<a.y+a.height
     assert(not overlap,'overlapping controls at '..width..': '..tostring(a.label)..' / '..tostring(b.label))
    end
   end
  end
 end
end
print('Pinball page: shared header, primary Play, narrow stacking and non-overlapping controls passed')
