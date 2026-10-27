-- J1 -- ROOM FOR THE JIT TO KEEP ITS TRACES.
--
-- LuaJIT compiles hot loops into traces and keeps them in a machine-code
-- area whose size is a startup parameter.  The defaults were chosen for
-- scripts, not for a game of this size: 1,000 traces at most, 512 KB of
-- machine code, 4,000 recorded instructions a trace, 100 side traces a root.
-- A frame here passes through the script VM, two or three renderers, the
-- audio mixer and the mod hook chains -- far more hot loops than fit -- so
-- the compiler keeps throwing finished traces away to make room ("trace
-- flush", visible with -jv), and the code those covered falls back to the
-- interpreter until it is hot enough to be compiled again.  On a handheld
-- that is the difference between a loop that runs at C speed and one that
-- does not.
--
-- These limits are raised once, before any module is loaded, in the main
-- state and in every worker thread that mixes audio.  Nothing else changes:
-- the same code is compiled, just kept.  Memory cost is the machine-code
-- area, a few megabytes at the ceiling.  POKEPORT_JIT_OPT=0 leaves the
-- defaults; POKEPORT_JIT_OPT="k=v,k=v" replaces the set.
local M = {}

M.DEFAULT = {
  "maxtrace=4000",     -- root + side traces kept               (default 1000)
  "maxrecord=8000",    -- instructions recorded per trace        (default 4000)
  "maxside=400",       -- side traces per root                   (default 100)
  "maxsnap=2000",      -- snapshots per trace                    (default 500)
  "sizemcode=64",      -- KB per machine-code area               (default 32)
  "maxmcode=8192",     -- KB of machine code in all              (default 512)
}

M.applied = nil

function M.apply(list)
  if M.applied ~= nil then return M.applied end
  if not (jit and jit.opt and jit.opt.start and jit.status and jit.status()) then
    M.applied = false
    return false
  end
  local env = os.getenv and os.getenv("POKEPORT_JIT_OPT") or nil
  if env == "0" then
    M.applied = false
    return false
  end
  local defaults = list == nil
  list = list or M.DEFAULT
  if env and env ~= "" and env ~= "1" then
    list = {}
    for item in env:gmatch("[^,%s]+") do list[#list + 1] = item end
  elseif defaults then
    -- conf.lua may already own one bounded Apple-silicon code allocation.
    -- Keep that area and its matching budget while applying the additional
    -- recorder limits; never restore small-area growth after early setup.
    local arena = package.loaded["src.core.JitArena"]
    local status = arena and arena.status
    if status and status.applied then
      local owned = {maxtrace=status.maxTraces, sizemcode=status.areaKiB, maxmcode=status.maxCodeKiB}
      local merged = {}
      for i, item in ipairs(list) do
        local key = item:match("^(%w+)=")
        merged[i] = owned[key] and (key .. "=" .. owned[key]) or item
      end
      list = merged
    end
  end
  local ok = pcall(jit.opt.start, unpack(list))
  M.applied = ok and list or false
  return M.applied
end

return M
