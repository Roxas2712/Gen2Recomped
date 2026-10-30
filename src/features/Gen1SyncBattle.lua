-- Native entry to the portable cross-engine session protocol.
-- Contributions by Roxas2712; see NOTICE.md.
local Core=require('compat.gen1_session.Sync')
local Bundle=require('src.features.gen1_gsc.Bundle')
local M={REVISION=Core.REVISION,PROFILE=Core.PROFILE}
function M.new(options)return Core.new(options,Bundle.new{profile='g3u'})end
return M
