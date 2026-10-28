-- Public, ROM-free acceptance in the actual mobile app and its thread VM.
local config = require('config')
local Json = require('src.link.Json')
local function publish(value)
  value.capacity, value.identity, value.schema = config.capacity, config.identity, 2
  local report = os.getenv('ROXAS_RUNTIME_REPORT')
  if report then
    local file=assert(io.open(report,'wb'))
    assert(file:write(Json.encode(value)))
    assert(file:close())
  else
    assert(love.filesystem.write('runtime-capacity-result.json', Json.encode(value)))
  end
end
function love.load()
  local major, minor = love.getVersion()
  assert((config.platform == 'android' and major == 11 and minor == 5) or
    (config.platform == 'ios' and major == 12), 'unexpected mobile LOVE version')
  assert(love.filesystem.getIdentity() == config.identity)
  assert(jit.arch == config.arch, 'wrong target architecture: ' .. jit.arch)
  assert(jit.status() == config.jit, 'unexpected JIT availability')
  local closureReport
  print('MOBILE_RUNTIME_PHASE', 'closures', config.capacity, jit.arch)
  local previousPrint, previousArg = print, arg
  print = function(line, ...)
    if type(line) == 'string' and line:sub(1,17) == 'RUNTIME_UPVALUES ' then
      closureReport = Json.decode(line:sub(18))
    end
    return previousPrint(line, ...)
  end
  arg = {tostring(config.capacity), config.platform == 'ios' and 'interpreter-only' or nil}
  local ok, why = pcall(assert(love.filesystem.load('check.lua')))
  print, arg = previousPrint, previousArg
  assert(ok, why)
  assert(closureReport and closureReport.passed and closureReport.minimum == config.capacity)
  print('MOBILE_RUNTIME_PHASE', 'c-api')
  local callbackJit = jit.status()
  -- FFI callbacks must enter from an interpreter frame, including callers.
  if callbackJit then jit.off(); jit.flush() end
  assert(love.filesystem.load('host-c-api.lua'))()(config.capacity, config.platform)
  local ffi = require('ffi')
  local callbackPassed,callbackUnavailable=false,false
  if config.platform == 'ios' then
    local available, why = pcall(ffi.cast, 'double(*)(double)', function(value) return value + .5 end)
    if available then why:free() end
    assert(not available and tostring(why):find('callbacks',1,true), 'iOS callback restriction changed')
    callbackUnavailable=true
  else
    local callback = ffi.cast('double(*)(double)', function(value) return value + .5 end)
    assert(callback(2.25) == 2.75, 'actual host FFI callback failed')
    callback:free()
    callbackPassed=true
  end
  if callbackJit then jit.on() end
  print('MOBILE_RUNTIME_PHASE', 'thread')
  local channel = love.thread.newChannel()
  local worker = love.thread.newThread('thread.lua')
  worker:start(channel, config.capacity)
  local result = channel:demand(30)
  assert(result and result.ok and result.capacity == config.capacity,
    worker:getError() or 'actual host thread VM did not complete')
  worker:wait()
  assert(not worker:getError(), worker:getError())
  print('MOBILE_RUNTIME_PHASE', 'filesystem')
  assert(love.filesystem.write('filesystem-probe.txt', config.identity))
  assert(love.filesystem.read('filesystem-probe.txt') == config.identity)
  publish({passed=true, loveVersion={major,minor}, arch=jit.arch, jitActive=jit.status(),
    cApiPassed=true, ffiCallsPassed=true, ffiCallbackPassed=callbackPassed,
    ffiCallbackUnavailable=callbackUnavailable, threadVmPassed=true,
    filesystemPassed=true, closureReport=closureReport})
  print('MOBILE_LOVE_RUNTIME_ABI_PASS', config.capacity, jit.arch)
  love.event.quit(0)
end
function love.errorhandler(why)
  local message = debug.traceback(tostring(why), 2)
  pcall(publish, {passed=false,error=message})
  io.stderr:write(message .. '\n')
  return function() if love.timer then love.timer.sleep(.05) end end
end
