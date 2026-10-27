-- Reusable Pokédex unit conversion for current and future editions.
--
-- International ROMs normally store the canonical values as decimetres and
-- hectograms.  Always prefer those values: English feet/pounds are rounded
-- display data and cannot always be converted back without losing a tenth.

local Units = {}

local function positive(value, label)
  value = tonumber(value)
  assert(value and value > 0, label .. " must be a positive number")
  return value
end

local function roundTenth(value)
  return math.floor(value * 10 + 0.5) / 10
end

function Units.fromRomMetric(heightDm, weightHg)
  return {
    heightM = positive(heightDm, "heightDm") / 10,
    weightKg = positive(weightHg, "weightHg") / 10,
  }
end

-- Fallback for engines which expose only localized English display values.
-- This is deliberately explicit so importers do not mistake feet/pounds for
-- the lossless source when canonical ROM fields are available.
function Units.fromImperial(heightFt, heightIn, weightLb)
  heightFt = tonumber(heightFt)
  heightIn = tonumber(heightIn or 0)
  weightLb = positive(weightLb, "weightLb")
  assert(heightFt and heightFt >= 0, "heightFt must be non-negative")
  assert(heightIn and heightIn >= 0 and heightIn < 12,
    "heightIn must be between 0 and 11")
  return {
    heightM = roundTenth((heightFt * 12 + heightIn) * 0.0254),
    weightKg = roundTenth(weightLb * 0.45359237),
  }
end

function Units.normalize(record)
  assert(type(record) == "table", "Pokédex metric record must be a table")
  if record.heightDm ~= nil or record.weightHg ~= nil then
    return Units.fromRomMetric(record.heightDm, record.weightHg)
  end
  if record.heightM ~= nil or record.weightKg ~= nil then
    return {
      heightM = positive(record.heightM, "heightM"),
      weightKg = positive(record.weightKg, "weightKg"),
    }
  end
  return Units.fromImperial(record.heightFt, record.heightIn, record.weightLb)
end

function Units.normalizeCatalog(catalog)
  assert(type(catalog) == "table", "Pokédex metric catalog must be a table")
  local result = {}
  for species, record in pairs(catalog) do
    result[species] = Units.normalize(record)
  end
  return result
end

return Units
