-- Copyright (c) 2026 Roxas2712. See LICENSE-ROXAS2712.md.
-- Shared native GSC RTC reads. The public Clock spelling follows the
-- reference contract; no private mod implementation or clock is embedded.
local Clock = { MINUTES_PER_DAY = 1440, DAYS = 7, DEFAULT_HOUR = 10, DEFAULT_MINUTE = 0 }
local Strings = require("src.core.Strings")
Clock.DAY_NAMES = { "SUNDAY", "MONDAY", "TUESDAY", "WEDNESDAY", "THURSDAY", "FRIDAY", "SATURDAY" }
local observed = setmetatable({}, { __mode = "k" })
local function integer(value)
  local n = tonumber(value)
  if n and n == n and n ~= math.huge and n ~= -math.huge then return math.floor(n) end
end
local function rtc(save)
  return type(save) == "table" and type(save.rtc) == "table" and save.rtc or nil
end
function Clock.hostMinutes()
  return ((integer(os.date("%H")) or 0) * 60 + (integer(os.date("%M")) or 0)) % 1440
end
function Clock.hostWeekday(now)
  return (integer(os.date("%w", now)) or 0) % 7
end
function Clock.minutes(save)
  local state = rtc(save)
  return (Clock.hostMinutes() + (state and integer(state.startMinute) or 0)) % 1440
end
function Clock.hour(save) return math.floor(Clock.minutes(save) / 60) end
function Clock.minute(save) return Clock.minutes(save) % 60 end
function Clock.isSet(save)
  local state = rtc(save)
  return state ~= nil and integer(state.startMinute) ~= nil
end
function Clock.setTime(save, hour, minute)
  if type(save) ~= "table" then return false end
  hour, minute = integer(hour or 0), integer(minute or 0)
  if not hour or not minute then return false end
  save.rtc = rtc(save) or {}
  save.rtc.startMinute = ((hour % 24) * 60 + minute % 60 - Clock.hostMinutes()) % 1440
  return true
end
local function note(save, day, reason)
  if type(save) ~= "table" then return day end
  local Runtime = require("src.mods.Runtime")
  if not require("src.core.GameVersion").isGen2() or not Runtime.wants("clock.day_changed") then
    observed[save] = nil
    return day
  end
  local previous = observed[save]
  observed[save] = day -- Commit before dispatch: reentrant reads cannot emit twice.
  if previous ~= nil and previous ~= day then
    Runtime.emit("clock.day_changed", { day = day, previous = previous, reason = reason })
  end
  return day
end
function Clock.weekday(save, now)
  local state = rtc(save)
  local offset = state and integer(state.startDay)
  if offset == nil then offset = type(save) == "table" and integer(save.g2DayOffset) or 0 end
  return note(save, (Clock.hostWeekday(now) + (offset or 0)) % 7, "rollover")
end
function Clock.setWeekday(save, day)
  day = integer(day)
  if type(save) ~= "table" or not day then return false end
  save.rtc = rtc(save) or {}
  day = day % 7
  save.rtc.startDay = (day - Clock.hostWeekday()) % 7
  save.rtc.dayOfWeek = day
  -- Keep the existing native field in sync for older native consumers/saves.
  save.g2DayOffset = save.rtc.startDay
  note(save, day, "set")
  return true
end
function Clock.weekdayName(day)
  local name = Clock.DAY_NAMES[day]
  return name and Strings(name)
end
function Clock.daytimeLabel(hour)
  hour = integer(hour) or Clock.hour()
  hour = hour % 24
  return Strings(hour < 4 and "NITE" or hour < 10 and "MORN" or hour < 18 and "DAY" or "NITE")
end
function Clock.resetObservations() observed = setmetatable({}, { __mode = "k" }) end
return Clock
