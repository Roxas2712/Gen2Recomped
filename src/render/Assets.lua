-- Central image cache plus the mod-visible asset search path.  Every
-- renderer that used to call love.graphics.newImage(path) straight goes
-- through Assets.image, so an enabled mod shadows a generated asset with
-- its own file without editing a single record, and one flush() drops
-- every downstream cache for dev-mode hot reload.
--
-- No loader installed means resolve() is the identity, which is what
-- keeps a mod-free boot (and every headless test) loading exactly the
-- paths it always did.

local Assets = {}
local Performance = require('src.core.Performance')
local Prefetch = require('src.render.GbAssetPrefetch')

-- resolved path -> love Image
local cache = {}
local recoveries = {}
-- downstream caches that must empty when the search path changes
local invalidators = {}
local releasers = {}
local dataCache = {}
local nativeMutable,nativeShared
local nativeDecode=love and love.image and love.image.newImageData
local nativeUpload=love and love.graphics and love.graphics.newImage

-- The loader bridge: overrideOrder() yields mods highest-priority-first
-- and derivedPath(rel) yields an existing save/mod-derived/<id>/<rel>.
-- nil until the loader installs one.
Assets.loader = nil

local GENERATED = "assets/generated/"
local function canRecover(path)
  return type(path)=='string' and path:sub(1,#GENERATED)==GENERATED
end

-- Session-owned language files. The provider owns its tables; switching or
-- retiring a loader drops their visibility without patching LOVE's constructors.
local languageLayers={}
function Assets.languageLayer(owner,layer,active)
  for i=#languageLayers,1,-1 do
    if languageLayers[i].owner==owner or not languageLayers[i].active() then table.remove(languageLayers,i) end
  end
  languageLayers[#languageLayers+1]={owner=owner,layer=layer,active=active}
end
local function languageFile(path)
  if type(path)~='string' then return end
  for i=#languageLayers,1,-1 do
    local row=languageLayers[i]
    if row.active() then
      local layer=row.layer
      local resolved=layer.paths and layer.paths[path] or path
      local bytes=layer.files and layer.files[resolved]
      if bytes then return bytes,resolved end
    end
  end
end
local function imageSource(path)
  local bytes=languageFile(path)
  return bytes and love.data.newByteData(bytes) or path
end

-- The PNG header is cheap to read; decoding and recolouring stay in the pool.
-- Non-PNG and @2x sources retain newImage(path)'s native interpretation.
function Assets.prefetchPayload(path)
  if not Assets.canPrefetchPixels()then return end
  if type(path)~='string'or not path:lower():match('%.png$')or path:match('@%d+x')then return end
  local resolved=Assets.resolve(path)
  local raw=languageFile(resolved)
  local physical=require('src.import.CacheFs').workerReadPath(resolved)
  local fs=love and love.filesystem
  if not(fs and fs.read and fs.getInfo)then return end
  local info=not raw and fs.getInfo(physical,'file')
  if raw and #raw>Prefetch.MAX_IMAGE_BYTES then return end
  if not raw and(not info or type(info.size)~='number'or info.size>Prefetch.MAX_IMAGE_BYTES)then return end
  local head=raw or fs.read(physical,24)
  local w,h=require('src.render.GbAssetWorker').dimensions(head)
  if not w then return end
  local signature=physical..'|'..tostring(raw or '')
  return {kind='decode',path=physical,bytes=raw,width=w,height=h},signature,w*h*4,resolved
end
function Assets.prefetchImage(path,front)
  if Performance.gbAssetPrefetch==false or type(path)~='string'then return false end
  local key='image:'..Assets.resolve(path)
  return Prefetch.request(key,function()
    local resolved=Assets.resolve(path)
    if cache[resolved]and dataCache[resolved]then return end
    return Assets.prefetchPayload(path)
  end,front)
end
local function decoded(path)
  if Performance.gbAssetPrefetch==false then return end
  -- Avoid filesystem reads on a cache miss in the speculative store.
  if not Prefetch.has('image:'..path)then return end
  local payload,signature=Assets.prefetchPayload(path)
  return payload and Prefetch.get('image:'..path,signature)
end

local function exists(path)
  if languageFile(path) then return true end
  local fs = love and love.filesystem
  if not (fs and fs.getInfo) then return false end
  return fs.getInfo(path) ~= nil
end
Assets.exists = exists

-- M10: the answer to a resolve is remembered.  With a loader installed
-- every lookup walked the mod list and asked PhysFS for each candidate --
-- N mods is N getInfo calls per asset, and a map load asks for hundreds
-- of assets, every one of them again on the next map.  Nothing that
-- decides the answer changes between installs: overrides are files in the
-- mod folders, derived art is written by AssetTransform BEFORE the loader
-- is installed (Loader:load), and dev hot reload goes through flush().
-- So the memo is dropped exactly where the central image cache is, in
-- invalidate(), and never anywhere else.  Performance.assetResolveCache
-- = false walks the list every time, as before.
local resolved = {}

-- an override dir shadows the generated cache; a transform's derived
-- output is the fallback under it, so hand-authored art beats generated
local function resolveWalk(loader, path)
  local rel = path:sub(#GENERATED + 1)
  for _, mod in ipairs(loader:overrideOrder()) do
    local candidate = mod.path .. "/overrides/" .. rel
    if exists(candidate) then return candidate end
  end
  return loader:derivedPath(rel) or path
end

local function memoOn()
  return Performance.assetResolveCache ~= false
end

function Assets.resolve(path)
  local _,localized=languageFile(path)
  if localized then return localized end
  local loader = Assets.loader
  if not loader or type(path) ~= "string" then return path end
  if path:sub(1, #GENERATED) ~= GENERATED then return path end
  if not memoOn() then
    if next(resolved) then resolved = {} end
    return resolveWalk(loader, path)
  end
  local hit = resolved[path]
  if hit ~= nil then
    if not (loader.stale and loader:stale()) then return hit end
    resolved = {}
  end
  local answer = resolveWalk(loader, path)
  resolved[path] = answer
  return answer
end

-- how many answers are remembered (for the check tool and the dev overlay)
function Assets.resolveMemoSize()
  local n = 0
  for _ in pairs(resolved) do n = n + 1 end
  return n
end

-- Last-resort art for a path that is not on disk.  Generated by the importer
-- alongside every other sheet; if even this is missing we fall back to a
-- blank 16x16 image built in memory so a bad path can never be fatal.
local MISSING_IMAGE = "assets/generated/sprites/placeholder_sprite.png"
local blankImage = nil

local function blank()
  if not blankImage then
    local data = love.image.newImageData(16, 16)
    blankImage = love.graphics.newImage(data)
  end
  return blankImage
end

-- Native generated sheets recover without aborting a map load. Optional
-- images retain the Gen1 failure contract so pcall can select a real fallback.
local function loadImage(resolved, recover)
  local ok, image = pcall(function()
    local bytes=languageFile(resolved)
    if bytes then return love.graphics.newImage(love.image.newImageData(love.data.newByteData(bytes))) end
    return love.graphics.newImage(decoded(resolved)or resolved)
  end)
  if ok then return image, false end
  if not recover then error(image,3) end
  local Logger = require("src.core.Logger")
  Logger.warn("assets: missing image '%s' (using placeholder)", tostring(resolved))
  local fellBack, placeholder = pcall(love.graphics.newImage, Assets.resolve(MISSING_IMAGE))
  if fellBack then return placeholder, true end
  return blank(), true
end

function Assets.image(path)
  local resolved = Assets.resolve(path)
  local image = cache[resolved]
  local recover=canRecover(path)
  if not image or (not recover and recoveries[resolved]) then
    local recovered
    image,recovered=loadImage(resolved,recover)
    cache[resolved] = image
    recoveries[resolved]=recovered or nil
  end
  return image
end

-- pixel-level reads (tile-shift variants, the spinner strip blit) resolve
-- the same way but stay uncached: the caller keeps the derived product.
-- Native generated sheets keep their missing-sheet fallback. Other pixel
-- inputs retain the Gen1 API's decode failure: callers use pcall to choose an
-- optional atlas/native renderer. Returning unrelated placeholder pixels can
-- make that caller publish invalid dimensions, masks and frame bounds.
function Assets.imageData(path)
  local resolved = Assets.resolve(path)
  local data=decoded(resolved)
  if data then return data:clone()end
  local ok, data = pcall(love.image.newImageData, imageSource(resolved))
  if ok then return data end
  if not canRecover(path) then
    error(data,2)
  end
  local Logger = require("src.core.Logger")
  Logger.warn("assets: missing image data '%s' (using placeholder)", tostring(resolved))
  local fellBack, placeholder = pcall(love.image.newImageData, Assets.resolve(MISSING_IMAGE))
  if fellBack then return placeholder end
  return love.image.newImageData(16, 16)
end

-- G8: THE SAME PIXELS, READ-ONLY, DECODED ONCE.
--
-- `Assets.imageData` decodes the PNG on every call because its callers may
-- write into the result (mapPixel for an OBP variant, the party menu's
-- tints).  The bakes that only READ -- the water-shift variants ask for the
-- whole tileset atlas once per animated tile, the RED++ atlas, the toggle
-- strips, the multi-tile frames -- paid that decode each time.  This answers
-- the decoded data from a cache instead.  The contract is in the name: a
-- caller must not paste into, mapPixel over or otherwise change what it
-- gets back; it may copy from it.  Cleared with the image cache.
local dataOrigins = {}
function Assets.imageDataShared(path)
  if Performance.assetSharedDecode == false then
    if next(dataCache) then dataCache,dataOrigins = {},{} end
    return Assets.imageData(path)
  end
  local resolved = Assets.resolve(path)
  local data = dataCache[resolved]
  -- A native recovery entry cannot masquerade as an optional decode.
  -- A successful generated entry may be decoded once more on this uncommon
  -- alias boundary; the public mutable reader remains the actual owner.
  if data and (canRecover(path) or not dataOrigins[resolved]) then return data end
  data = Assets.imageData(path)
  dataCache[resolved] = data
  dataOrigins[resolved] = canRecover(path)
  return data
end
nativeMutable,nativeShared=Assets.imageData,Assets.imageDataShared
function Assets.canPrefetchPixels()
  local Cache=package.loaded['src.import.CacheFs']
  local function original(fn)return Cache and Cache.nativeImageConstructor(fn)or fn end
  return Assets.imageData==nativeMutable and Assets.imageDataShared==nativeShared
    and love and love.image and original(love.image.newImageData)==original(nativeDecode)
    and love.graphics and original(love.graphics.newImage)==original(nativeUpload)
end

-- Gen1Recomp's hook contract distinguishes a soft cache refresh from retiring
-- a session. Keep function registrations compatible with existing renderers.
function Assets.register(hooks)
  if type(hooks) == "function" then
    invalidators[#invalidators + 1] = hooks
    return
  end
  if type(hooks) ~= "table" then return end
  if type(hooks.invalidate) == "function" then
    invalidators[#invalidators + 1] = hooks.invalidate
  end
  if type(hooks.release) == "function" then
    releasers[#releasers + 1] = hooks.release
  end
end

-- hot reload's single entry point (20-developer-tooling): drop the central
-- cache and fan out to every registered downstream one.  A cache whose
-- invalidator throws must not strand the ones behind it in the list.
function Assets.invalidate()
  Prefetch.clear()
  -- the count is returned, not logged, because this is also the mod loader's
  -- own flush and that one has nothing to say; the caller who cares -- a
  -- version switch -- is the one that reports it
  local dropped = 0
  for _ in pairs(cache) do dropped = dropped + 1 end
  cache = {}
  recoveries = {}
  dataCache = {}
  dataOrigins = {}
  resolved = {}
  for _, fn in ipairs(invalidators) do pcall(fn) end
  return dropped
end

Assets.flush = Assets.invalidate

-- Session retirement, following Gen1Recomp's releaseSession API. A refresh
-- leaves live renderers' images usable; only a retired session releases owned
-- resources. Native missing-sheet aliases may share the same blank image.
function Assets.releaseSession()
  Prefetch.clear()
  local released = {}
  local function release(resource)
    if resource and not released[resource] then
      released[resource] = true
      pcall(function() if resource.release then resource:release() end end)
    end
  end
  for _, resource in pairs(cache) do release(resource) end
  for _, resource in pairs(dataCache) do release(resource) end
  release(blankImage)
  cache, recoveries, dataCache, dataOrigins, resolved = {}, {}, {}, {}, {}
  blankImage = nil
  for _, fn in ipairs(releasers) do pcall(fn) end
end

-- Loader:load hands over the live mod set once the merge is done.  Load
-- order is priority ascending, so the search walks it backwards: the mod
-- that wins the record merge wins the asset lookup too.
function Assets.installLoader(loader)
  if not loader then
    Assets.loader = nil
    Assets.invalidate()
    return
  end
  local bridge = {}
  -- M10: the order is a property of this install, built once; a mod set
  -- that changes comes back through installLoader and gets a new bridge
  -- (every rollback today happens inside Loader:load, before this bridge
  -- exists; the count guard is for a future one that does not)
  local order, orderCount
  function bridge:overrideOrder()
    local loaded = loader.loaded or {}
    local enabled = memoOn()
    if enabled and order and orderCount == #loaded then return order end
    if order then resolved = {} end
    local built = {}
    for i = #loaded, 1, -1 do
      built[#built + 1] = { id = loaded[i].manifest.id, path = loaded[i].path }
    end
    if enabled then order, orderCount = built, #loaded
    else order, orderCount = nil, nil end
    return built
  end
  function bridge:stale()
    return order ~= nil and orderCount ~= #(loader.loaded or {})
  end
  function bridge:derivedPath(rel)
    for _, mod in ipairs(self:overrideOrder()) do
      local candidate = "save/mod-derived/" .. mod.id .. "/" .. rel
      if exists(candidate) then return candidate end
    end
    return nil
  end
  Assets.loader = bridge
  Assets.invalidate()
end

return Assets
