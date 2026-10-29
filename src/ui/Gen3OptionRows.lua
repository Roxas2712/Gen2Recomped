-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Preserve host/mod callbacks beneath each cartridge's native option rows.
local M={}
function M.withCart(owner,native,category)
 local rows={};for _,key in ipairs(require('src.core.Gen3RsOptionValues').keys)do rows[#rows+1]=assert(native[key])end
 local extras={}
 for _,row in ipairs(owner.rows)do if row.engine then
  local engine=row.engine
  extras[#extras+1]={label=row.label,value=function()return owner:valueText(row)end,
   step=engine.step and function(_,dir)return engine.step(owner.game,dir)end,
   activate=engine.activate and function()return engine.activate(owner.game)end}
 end end
 if#extras>0 then
  local label=require('src.core.Strings')('MORE OPTIONS')
  rows[#rows+1]={label=label,activate=function()category(label,extras)end}
 end
 return rows
end
return M
