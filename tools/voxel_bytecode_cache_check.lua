-- Run:  luajit tools/voxel_bytecode_cache_check.lua
--
-- C1 (mod half) -- DRAMATIC_SHAPE's big tables from bytecode.
--
-- `cachedChunk` in the mod's main.lua is a local; this check reproduces its
-- contract on the same primitives (string.dump, load, an MD5 of the source)
-- against a table filesystem, and pins the wiring in main.lua: the digest
-- header, the save-directory path, the fall-through to `load(source)`.
package.path = './?.lua;./?/init.lua;' .. package.path
local PASS, FAIL = 0, 0
local function check(cond, label)
  if cond then PASS = PASS + 1 else FAIL = FAIL + 1; print('FAIL: ' .. label) end
end

local src = assert(io.open('mods/DRAMATIC_SHAPE/main.lua')):read('*a')
check(src:find('local BYTECODE_DIR = "dramatic_shape_voxel_cache/bytecode"', 1, true) ~= nil, 'dumps live beside the voxel mesh cache')
check(src:find('local BYTECODE_TAG = "VXB1 "', 1, true) ~= nil, 'a tagged header names the format')
check(src:find('data.encode("string", "hex", data.hash("md5", source))', 1, true) ~= nil, 'the key is an MD5 of the source')
check(src:find('if V.bytecodeCache == false then return nil end', 1, true) ~= nil, 'V.bytecodeCache = false turns it off')
check(src:find('local chunk, err = cachedChunk(rel, source, name)\n  if not chunk then chunk, err = load(source, name) end', 1, true) ~= nil,
      'chunkFor falls through to load(source) when the cache answers nothing')
check(src:find('if fs.createDirectory(BYTECODE_DIR) then fs.write(path, header .. dump) end', 1, true) ~= nil, 'a fresh dump is written under the header')
check(src:find("local chunk = load(bytes:sub(#header + 1), name)\n    if chunk then return chunk end", 1, true) ~= nil,
      'a dump that will not load falls through rather than raising')

-- the contract, on the primitives
do
  local source = 'return { answer = 42, list = { 1, 2, 3 }, name = "voxel" }'
  local chunk = assert(load(source, '@probe'))
  local dump = string.dump(chunk, true)
  check(dump:sub(1, 1) == '\27', 'string.dump yields a binary chunk')
  local back = assert(load(dump, '@probe'))()
  check(back.answer == 42 and back.list[3] == 3 and back.name == 'voxel', 'the dump evaluates to the same table')
  local okBad = load('\27LJ\2garbage') == nil
  check(okBad, 'a corrupt dump makes load answer nil, not raise')
  -- the header check is exact: a changed source has a different digest
  local header = 'VXB1 ' .. ('a'):rep(32) .. '\n'
  local file = header .. dump
  check(file:sub(1, #header) == header, 'the header prefix test matches its own header')
  local other = 'VXB1 ' .. ('b'):rep(32) .. '\n'
  check(file:sub(1, #other) ~= other, 'and rejects another digest of the same length')
end

print(('%d checks, %d failed'):format(PASS + FAIL, FAIL))
if FAIL > 0 then os.exit(1) end
