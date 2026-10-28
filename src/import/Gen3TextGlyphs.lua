-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- The native summary reader already identifies these cartridge controls.
-- Keep a small import-only lookup independent of optional UI/language code.
local icons={[0]='A_BUTTON',[1]='B_BUTTON',[6]='DPAD_UP',[7]='DPAD_DOWN',
 [8]='DPAD_LEFT',[9]='DPAD_RIGHT',[10]='DPAD_UPDOWN',[11]='DPAD_LEFTRIGHT',[12]='DPAD_ANY'}
local symbols={[5]='Lv',[6]='PP',[7]='ID',[8]='№'}
-- English character facts in pret's pinned GBA charmaps. These punctuation
-- slots are absent from some native manifests; ordinary scan gates stay strict.
local punctuation={[0x5B]='%',[0x5C]='(',[0x5D]=')'}
local M={}
function M.literal(code)return punctuation[code]end
function M.read(kind,id)
 if kind==0xF8 and icons[id]then
  local token='{'..icons[id]..'}';return token,token
 end
 if kind==0xF9 then return symbols[id],symbols[id]end
end
return M
