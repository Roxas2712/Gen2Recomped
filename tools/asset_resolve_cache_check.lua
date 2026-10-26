-- Check for the Assets.resolve memo (src/render/Assets.lua, M10).
--   luajit tools/asset_resolve_cache_check.lua
-- A stub filesystem counts getInfo calls.  With a loader of three mods, a
-- generated path is walked once and then answered from the memo; an
-- override, a derived file and a plain vanilla answer all memoise; a
-- non-generated path is never memoised; invalidate()/flush() and a new
-- installLoader drop the memo; a mod leaving the loaded list rebuilds the
-- order and drops the memo; the switch off walks every time.

package.path = "./?.lua;./?/init.lua;" .. package.path

local files, infoCalls = {}, 0
love = {
  filesystem = {
    getInfo = function(path) infoCalls = infoCalls + 1; return files[path] and {} or nil end,
  },
  image = { newImageData = function() return {} end },
  graphics = { newImage = function(p) return { path = p } end },
}
local Assets = require("src.render.Assets")
local Performance = require("src.core.Performance")
local n = 0
local function eq(a, b, what)
  n = n + 1
  if a ~= b then error(("%s: got %s, want %s"):format(what, tostring(a), tostring(b)), 2) end
end

local loader = { loaded = {
  { manifest = { id = "low" }, path = "mods/low" },
  { manifest = { id = "mid" }, path = "mods/mid" },
  { manifest = { id = "top" }, path = "mods/top" },
} }
files["mods/top/overrides/sprites/a.png"] = true
files["save/mod-derived/low/sprites/b.png"] = true

Assets.installLoader(loader)
local A, B, C = "assets/generated/sprites/a.png", "assets/generated/sprites/b.png", "assets/generated/sprites/c.png"

eq(Assets.resolve(A), "mods/top/overrides/sprites/a.png", "override wins (highest priority first)")
local walked = infoCalls
eq(walked > 0, true, "first lookup walks the filesystem")
Assets.resolve(A); Assets.resolve(A)
eq(infoCalls, walked, "repeat lookups make no filesystem calls")

infoCalls = 0
eq(Assets.resolve(B), "save/mod-derived/low/sprites/b.png", "derived art is the fallback")
Assets.resolve(B)
eq(infoCalls, 3 + 3, "derived: three override checks, then the derived walk -- once")

infoCalls = 0
eq(Assets.resolve(C), C, "no override, no derived: the generated path itself")
Assets.resolve(C)
eq(infoCalls, 6, "a vanilla answer is memoised too")
eq(Assets.resolveMemoSize(), 3, "three answers remembered")

infoCalls = 0
eq(Assets.resolve("mods/top/main.lua"), "mods/top/main.lua", "non-generated path is itself")
eq(infoCalls, 0, "...and never touches the filesystem")

-- the image cache goes through the same memo
infoCalls = 0
Assets.image(A); Assets.image(A)
eq(infoCalls, 0, "Assets.image on a memoised path makes no filesystem calls")

-- invalidate drops it
Assets.invalidate()
eq(Assets.resolveMemoSize(), 0, "invalidate drops the memo")
infoCalls = 0
Assets.resolve(A)
eq(infoCalls > 0, true, "after invalidate the walk happens again")

-- a mod set that changes under the bridge rebuilds the order
files["mods/top/overrides/sprites/a.png"] = nil
table.remove(loader.loaded, 3)
eq(Assets.resolve(A), A, "a mod gone from the list no longer answers")
eq(Assets.resolveMemoSize(), 1, "memo rebuilt after the order changed")

-- reinstall drops everything
Assets.installLoader(nil)
eq(Assets.resolve(A), A, "no loader: identity")
eq(Assets.resolveMemoSize(), 0, "installLoader(nil) dropped the memo")

-- switch off: walks every time
Performance.assetResolveCache = false
Assets.installLoader(loader)
infoCalls = 0
Assets.resolve(C); Assets.resolve(C)
eq(infoCalls, 8, "switch off: every lookup walks (two mods: 2 overrides + 2 derived, twice)")
eq(Assets.resolveMemoSize(), 0, "switch off: nothing remembered")
Performance.assetResolveCache = true

-- Turning the switch off must bypass entries warmed before that change.
eq(Assets.resolve(C), C, 'warm a generated answer')
eq(Assets.resolveMemoSize(), 1, 'warm answer is remembered')
Performance.assetResolveCache = false
files['mods/low/overrides/sprites/c.png'] = true
eq(Assets.resolve(C), 'mods/low/overrides/sprites/c.png', 'warm memo is bypassed immediately when disabled')
eq(Assets.resolveMemoSize(), 0, 'disabling drops old answers')
files['mods/low/overrides/sprites/c.png'] = nil
eq(Assets.resolve(C), C, 'disabled lookup sees file changes without a flush')
Performance.assetResolveCache = true
eq(Assets.resolve(C), C, 're-enabled lookup does not revive old answers')

print(("asset_resolve_cache_check: %d checks ok"):format(n))
