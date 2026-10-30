-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Check the caller's IO boundary directly; host descheduling is not IO.
local M={};M.__index=M
function M.new()return setmetatable({inside=false,attempts=0},M)end
function M:watch(api,key,label)
 local original=api and api[key]
 if type(original)~='function'then return end
 api[key]=function(...)
  if self.inside then
   self.attempts=self.attempts+1
   error('poll attempted blocking IO: '..(label or key),2)
  end
  return original(...)
 end
end
function M:poll(fn,...)
 assert(not self.inside,'Nested poll guard')
 local before=self.attempts;self.inside=true
 local ok,result=pcall(fn,...)
 self.inside=false
 assert(self.attempts==before,'poll attempted blocking IO, even if its error was caught')
 assert(ok,result)
 return result
end
return M
