-- Adapted from Gen1Recomp 2aec7650cb01845a4e98f1dbcf8a5c652990d984 src/link/Protocol.lua.
-- Copyright (C) 2026 BOIS CLUB GAMES, LLC; GPLv3 plus Section 7, see ../../LICENSE.MD.
local Fingerprint=require("src.link.Fingerprint")
local Protocol={}
function Protocol.wireMon3(packed)
  local Wire = require("src.link.Wire")
  local msg = Wire.sanitize({ type = "game3_trade_mon", mon = packed })
  return msg and msg.mon or nil
end

local function canonicalString(s)
  return '"' .. s:gsub('[%c"\\]', function(c)
    if c == '"' then return '\\"' end
    if c == "\\" then return "\\\\" end
    if c == "\n" then return "\\n" end
    if c == "\r" then return "\\r" end
    if c == "\t" then return "\\t" end
    return string.format("\\u%04x", c:byte())
  end) .. '"'
end

local function canonicalValue(v, out)
  local t = type(v)
  if t == "boolean" then
    out[#out + 1] = v and "true" or "false"
  elseif t == "number" then
    if v ~= v or v == math.huge or v == -math.huge then
      out[#out + 1] = "null"
    else
      out[#out + 1] = string.format("%.0f", math.floor(v))
    end
  elseif t == "string" then
    out[#out + 1] = canonicalString(v)
  elseif t == "table" then
    local n = #v
    if n > 0 or next(v) == nil then
      out[#out + 1] = "["
      for i = 1, n do
        if i > 1 then out[#out + 1] = "," end
        canonicalValue(v[i], out)
      end
      out[#out + 1] = "]"
    else
      local keys = {}
      for k in pairs(v) do keys[#keys + 1] = tostring(k) end
      table.sort(keys)
      out[#out + 1] = "{"
      for i, k in ipairs(keys) do
        if i > 1 then out[#out + 1] = "," end
        out[#out + 1] = canonicalString(k)
        out[#out + 1] = ":"
        local value = v[k]
        if value == nil then value = v[tonumber(k)] end
        canonicalValue(value, out)
      end
      out[#out + 1] = "}"
    end
  else
    out[#out + 1] = "null"
  end
end

function Protocol.canonical(v)
  local out = {}
  canonicalValue(v, out)
  return table.concat(out)
end

function Protocol.tradeDigest(packedSeat0, packedSeat1)
  local text = Protocol.canonical(packedSeat0) .. "|" .. Protocol.canonical(packedSeat1)
  return ("%08x%08x"):format(Fingerprint.fnv1a32(text, 0x811C9DC5),
                             Fingerprint.fnv1a32(text, 0x050C5D1F))
end


return Protocol
