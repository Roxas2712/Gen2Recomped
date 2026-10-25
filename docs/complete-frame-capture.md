# Capture the completed window frame

Use `require('src.render.WindowFrame').capture(callback)` to request the next
completed window image. It returns false plus a reason when the bounded
16-request queue is full. Requests queued before a draw share one current
independent readback. Requests made from a draw/capture callback are delivered
on the following draw. Shutdown cancels requests that have not been delivered.

The callback receives `(imageData, frameInfo)`. The RGBA image is borrowed for
that callback only; encode it or copy it there, and do not release or retain
it. This is the same owned final target delivered to the window, including
native UI and mod HUDs. Observed/captured frames drain asynchronous GL recovery
and use current pixels. Healthy direct backends retain native capture ordering.

```lua
local Frame = require('src.render.WindowFrame')
assert(Frame.capture(function(data)
  assert(love.filesystem.write('capture.png', data:encode('png')))
end))
```

On macOS with an undefined OpenGL system framebuffer, a raw
`love.graphics.captureScreenshot` can encode an inverted/channel-swapped system
image even while the Cocoa recovery layer displays the correct RGBA frame.
Capturing the completed target avoids that invalid source; it does not flip or
recolour an exported picture. Existing native `Game.capturePath` captures use
the same current-frame route. No screenshot is inferred from a previous frame.

The CPU lifecycle/ordering tests cover queued/coalesced/reentrant/direct
requests, queue bounds, shutdown and callback-error image lifetime. Actual GPU
and owned OS-window evidence are a separate acceptance surface.
