-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Gen1Recomp pokegold LZ3 decoder, GPLv3.
-- Vendored from bryanthaboi/gen1recomp 1925fa9 src/import/Rom.lua.
-- See LICENSE.MD and VENDOR.md.
local R={}
local LZ_END = 0xFF
local LZ_LITERAL   = 0
local LZ_ITERATE   = 1
local LZ_ALTERNATE = 2
local LZ_ZERO      = 3
local LZ_FLIP      = 5
local LZ_REVERSE   = 6
local LZ_LONG      = 7

local function flipBits(value)
  local flipped = 0
  for bitIndex = 0, 7 do
    flipped = flipped + math.floor(value / 2 ^ bitIndex) % 2 * 2 ^ (7 - bitIndex)
  end
  return flipped
end

function R.decompressLz3(data)
  local bytes = data
  if type(data) == "string" then
    bytes = {}
    for index = 1, #data do bytes[index] = data:byte(index) end
  end

  local pos = 1
  local function nextByte()
    local value = bytes[pos]
    if not value then error("lz3 stream ended unexpectedly") end
    pos = pos + 1
    return value
  end

  local out = {}
  while true do
    local first = bytes[pos]
    if not first then error("lz3 stream ended without a terminator") end
    pos = pos + 1
    if first == LZ_END then break end

    local command, length
    if math.floor(first / 0x20) == LZ_LONG then
      -- 111xxxyy yyyyyyyy: xxx is the real command, yy.. is a 10-bit length
      command = math.floor(first / 4) % 8
      local high = first % 4
      length = high * 0x100 + nextByte() + 1
    else
      command = math.floor(first / 0x20)
      length = first % 0x20 + 1
    end

    if command == LZ_LITERAL then
      for _ = 1, length do out[#out + 1] = nextByte() end
    elseif command == LZ_ITERATE then
      local value = nextByte()
      for _ = 1, length do out[#out + 1] = value end
    elseif command == LZ_ALTERNATE then
      local a, b = nextByte(), nextByte()
      for index = 1, length do
        out[#out + 1] = (index % 2 == 1) and a or b
      end
    elseif command == LZ_ZERO then
      for _ = 1, length do out[#out + 1] = 0 end
    else
      -- Lookback commands (LZ_REPEAT/LZ_FLIP/LZ_REVERSE, and the unused id
      -- 7 which the hardware routine falls through to LZ_REPEAT for).
      -- A high-bit offset byte is a 7-bit negative lookback from the
      -- current output position; otherwise it is a 15-bit absolute offset
      -- from the start of the output buffer (two bytes, big-endian).
      local offsetByte = nextByte()
      local from
      if offsetByte >= 0x80 then
        from = #out - (offsetByte % 0x80)
      else
        from = offsetByte * 0x100 + nextByte() + 1
      end
      if command == LZ_FLIP then
        for index = 0, length - 1 do
          out[#out + 1] = flipBits(out[from + index])
        end
      elseif command == LZ_REVERSE then
        for index = 0, length - 1 do
          out[#out + 1] = out[from - index]
        end
      else
        for index = 0, length - 1 do
          out[#out + 1] = out[from + index]
        end
      end
    end
  end
  return out
end

return R
