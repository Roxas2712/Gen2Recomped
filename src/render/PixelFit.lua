-- Native framebuffer fitting, extracted from Renderer.
-- Existing engine authors' rights/licences remain effective (NOTICE.md).
-- Integration contributions by Roxas2712; see LICENSE-ROXAS2712.md.
local Fit = {}

function Fit.scale(pixelW, pixelH, surfaceW, surfaceH)
  return math.max(1, math.floor(math.min(pixelW / surfaceW, pixelH / surfaceH)))
end

function Fit.origin(pixelW, pixelH, surfaceW, surfaceH, scale)
  return math.floor((pixelW - surfaceW * scale) / 2),
    math.floor((pixelH - surfaceH * scale) / 2)
end

return Fit
