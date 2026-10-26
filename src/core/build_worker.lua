-- W1 -- the build pool's thread script.  Everything is in build_worker_loop
-- so a check can drive the same code without a thread.  The modules a
-- handler may need that are love-side (love.data for ByteData, love.image
-- for ImageData, love.filesystem to read an archive) are required here,
-- once, in the worker's own state; love.graphics is never available on a
-- thread and no handler may ask for it.
require("love.thread")
require("love.data")
require("love.image")
require("love.filesystem")
require("love.timer")
local jobs, results = ...
local Loop = require("src.core.build_worker_loop")
Loop.serve(jobs, results)
