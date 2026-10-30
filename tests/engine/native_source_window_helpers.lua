local calls={}
package.loaded['src.ui.Gen3StartMenu']={CURSOR_WIDTH=8}
package.loaded['src.render.Font']={drawStandardBox=function(...)calls.std={...}end,drawBox=function(...)calls.user={...}end}
package.loaded['src.ui.game3.frlg_font']={draw=function(...)calls.text={...};return 17 end}
local C=require('src.ui.game3.chrome');local W=require('src.ui.game3.window')
C.fixedStdFrame(1,1,28,3);assert(table.concat(calls.std,',')=='0,0,30,5')
W.userFrame(W.template(1,5,28,14),0);assert(table.concat(calls.user,',')=='0,4,30,16,1')
W.userFrame({tilemapLeft=2,tilemapTop=3,w=4,h=5},2);assert(table.concat(calls.user,',')=='1,2,6,7,3')
local opts={maxWidth=48,colors={fg={1,0,0,1}}};assert(W.printPx('label',180,45,opts)==17);assert(calls.text[1]=='label' and calls.text[2]==180 and calls.text[3]==45 and calls.text[4]==opts)
print('PASS native window content geometry, zero-based frame conversion and text options')
