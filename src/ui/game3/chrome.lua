-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
local C={}
function C.dialogueWindow()
  local b=require('src.ui.Theme').textBox
  return b.tx,b.ty,b.tw,b.th
end
-- Source coordinates describe the content; native frame coordinates include
-- the one-tile border. Keep the cartridge's standard and selected user art.
function C.fixedStdFrame(tx,ty,tw,th)
 return require('src.render.Font').drawStandardBox(tx-1,ty-1,tw+2,th+2)
end
function C.userFrame(frameType,tx,ty,tw,th)
 return require('src.render.Font').drawBox(tx-1,ty-1,tw+2,th+2,
  frameType~=nil and frameType+1 or nil)
end
return C
