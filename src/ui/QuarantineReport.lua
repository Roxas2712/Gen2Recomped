-- Load-report screen (15-save-data D7.4): what the validation pass moved,
-- removed or remapped, shown once before the overworld.  Game:restoreSave
-- pushes it (Screens id "QuarantineReport") only when the report is
-- non-empty, so a vanilla load never constructs it.  Nothing here mutates
-- the save -- save.orphaned persists and the report stays re-derivable.

local Font = require("src.render.Font")
local SaveData = require("src.core.SaveData")
local Strings = require("src.core.Strings")

local QuarantineReport = {}
QuarantineReport.__index = QuarantineReport
QuarantineReport.isOpaque = true

local function clip(text)
  return tostring(text)
end

local function section(lines, header, rows)
  if #rows == 0 then return end
  if #lines > 0 then lines[#lines + 1] = "" end
  lines[#lines + 1] = header
  for _, row in ipairs(rows) do lines[#lines + 1] = clip(" " .. row) end
end

-- report shape: { lostMons = {{species, from}}, lostItems = {{id, count,
-- from}}, remappedMaps = {{id, to, field}}, restoredMons, restoredItems,
-- recovered, modsDiff }
local function buildLines(report, meta)
  local lines = {}
  if #(report.lostMail or {})>0 then
    lines[#lines+1]=Strings("MAIL repairs: %d",#report.lostMail)
    for _,entry in ipairs(report.lostMail)do
      lines[#lines+1]=clip(" "..tostring(entry.why or "Invalid letter"))
    end
  end
  if #(report.restoredMail or {})>0 then
    lines[#lines+1]=Strings("MAIL restored: %d",#report.restoredMail)
  end
  if report.recovered then
    lines[#lines + 1] = "Save recovered from"
    lines[#lines + 1] = clip(" the ." .. tostring(report.recovered) .. " backup copy")
  end
  local rows = {}
  for _, mon in ipairs(report.lostMons or {}) do
    rows[#rows + 1] = Strings("%s (%s)", mon.species or "?", mon.from or "?")
  end
  section(lines, "Moved to LOST box:", rows)
  rows = {}
  for _, item in ipairs(report.lostItems or {}) do
    rows[#rows + 1] = Strings("%s x%d", item.id or "?", item.count or 1)
  end
  section(lines, "Items removed:", rows)
  rows = {}
  for _, map in ipairs(report.remappedMaps or {}) do
    if map.to then
      rows[#rows + 1] = ("%s>%s"):format(map.id or "?", map.to)
    else
      rows[#rows + 1] = Strings("%s (%s)", map.id or "?", map.field or "?")
    end
  end
  section(lines, "Location reset:", rows)
  rows = {}
  for _, mon in ipairs(report.restoredMons or {}) do
    rows[#rows + 1] = Strings("%s to box %d", mon.species or "?", mon.box or 0)
  end
  for _, item in ipairs(report.restoredItems or {}) do
    rows[#rows + 1] = Strings("%s x%d", item.id or "?", item.count or 1)
  end
  section(lines, "Restored:", rows)
  local notice = SaveData.modsDiffNotice(report.modsDiff, meta)
  if notice then
    if #lines > 0 then lines[#lines + 1] = "" end
    lines[#lines + 1] = notice
  end
  return lines
end

function QuarantineReport.new(game, report)
  local self = setmetatable({
    game = game,
    report = report or {},
    offset = 0,
  }, QuarantineReport)
  self.lines = buildLines(self.report,
    game and game.save and game.save.meta)
  self:layout()
  return self
end

function QuarantineReport:uiSize()
  if require("src.core.GameVersion").isGen3() then return 240, 160 end
  return 160, 144
end

-- This host report shares the current cartridge font. GBA glyphs are taller
-- and proportional; neither eight-pixel rows nor byte-count clipping fits.
function QuarantineReport:layout()
  local w, h = self:uiSize()
  local glyph = Font.glyphHeight()
  local step = math.max(8, glyph + (glyph > 8 and 2 or 0))
  local first = 8 + glyph + 4
  local footer = h - 6 - glyph
  local visible = math.max(1, math.floor((footer - 4 - first - glyph) / step) + 1)
  local width = w - 24
  local wrapped = {}
  for _, text in ipairs(self.lines) do
    if text == "" then wrapped[#wrapped + 1] = "" end
    while text ~= "" do
      local spans = Font.split(text)
      local count = math.max(1, Font.spansFitting(spans, width))
      local last = spans[math.min(count, #spans)].to
      if count < #spans then
        local wordEnd = text:sub(1, last):match("^.*()%s")
        if wordEnd and wordEnd > 1 then last = wordEnd - 1 end
      end
      wrapped[#wrapped + 1] = text:sub(1, last)
      text = text:sub(last + 1):gsub("^%s+", "")
    end
  end
  self.lines = wrapped
  self.metrics = {width=w, height=h, glyph=glyph, step=step,
    first=first, footer=footer, visible=visible, textWidth=width}
end

function QuarantineReport:maxOffset()
  return math.max(0, #self.lines - self.metrics.visible)
end

function QuarantineReport:update()
  local input = self.game and self.game.input
  if not input then return end
  if input:wasPressed("up") then
    self.offset = math.max(0, self.offset - 1)
  elseif input:wasPressed("down") then
    self.offset = math.min(self:maxOffset(), self.offset + 1)
  elseif input:wasPressed("a") or input:wasPressed("start")
      or input:wasPressed("b") then
    -- CONTINUE: the overworld is already beneath this screen
    self.game.stack:pop()
  end
end

function QuarantineReport:draw()
  local m = self.metrics
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.rectangle("fill", 0, 0, m.width, m.height)
  Font.drawBox(0, 0, m.width / 8, m.height / 8)
  love.graphics.setColor(0, 0, 0, 1)
  Font.draw(Strings("LOAD REPORT"), 8, 8)
  for row = 1, m.visible do
    local line = self.lines[self.offset + row]
    if line then Font.draw(line, 8, m.first + (row - 1) * m.step) end
  end
  if self.offset < self:maxOffset() then
    Font.drawCode(require("src.ui.Theme").moreArrow, m.width - 16, m.footer)
  end
  Font.draw(Strings("A:CONTINUE"), 8, m.footer)
  love.graphics.setColor(1, 1, 1, 1)
end

return QuarantineReport
