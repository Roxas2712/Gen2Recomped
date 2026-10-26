-- WHAT THE LAUNCHER LOOKS LIKE.
--
-- The palette in RomImporter is one table of RGB triples that the whole
-- launcher draws from, which makes it exactly the right size of thing to let
-- a player repaint: a preset swaps the ground it sits on, an accent swaps the
-- colour that leads the eye, and nothing else in the drawing code has to know
-- either happened.
--
-- TWO AXES, NOT A COLOUR PICKER.  A picker for forty-odd palette keys is a way
-- to produce an unreadable launcher and no way to get back; every combination
-- offered here was picked to keep white text legible on the ground behind it
-- and the accent visible against both.  DEFAULT on either axis restores what
-- the launcher shipped with.
--
-- CARTRIDGE COLOURS ARE NOT THEMED.  The chip gradients say which game a tab
-- is -- Crystal's cyan, Prism's mint, Emerald's green -- and repainting them
-- to match a theme would take away the one thing in that row that identifies
-- a cartridge at a glance.  A preset moves the CHROME: the background, the
-- card interiors, the text and the dividers.
--
-- THE BASELINE IS CAPTURED ON FIRST APPLY, not re-derived.  `apply` writes
-- into the live table, so without a pristine copy to restore from, switching
-- preset twice would compose two presets and DEFAULT would restore the last
-- theme rather than the original.

local LauncherTheme = {}

-- id -> the palette keys it replaces.  Every preset names the same keys so
-- that switching between two of them cannot leave one key behind from the
-- other; DEFAULT is the absence of a preset rather than an entry here.
-- Edition presets keep the same quiet charcoal surfaces. Color identifies
-- actions and the brand, rather than tinting every text and panel differently.
local function edition(label, accent, hover)
  return {label=label, note="Charcoal surfaces, neutral text and one edition accent. The logo follows your accent.",
    accent={link=accent,hover=hover}, colors={
      bgTop={25,28,34},bgBot={11,13,18},slotBg={20,24,31},
      cardBlue={25,30,39},cardRed={25,30,39},cardGold={25,30,39},
      cardBorder={85,96,112},ink={241,243,247},heading={248,249,252},
      detail={208,215,224},warning={163,175,191},labelGray={163,175,191},modDot={174,185,200},
    }}
end
LauncherTheme.PRESETS = {
  heartgold=edition("HeartGold",{234,189,94},{255,225,163}),
  pureyellow=edition("PureYellow",{239,213,105},{255,238,172}),
  rubyred=edition("RubyRed",{241,125,134},{255,189,194}),
  sapphireblue=edition("SapphireBlue",{126,172,239},{186,212,255}),
  emeraldgreen=edition("EmeraldGreen",{106,206,164},{174,237,209}),
  soulsilver=edition("SoulSilver",{188,204,228},{229,237,250}),
  crystalcyan=edition("CrystalClear",{117,210,224},{184,238,247}),
  platinum=edition("PlatinumGlow",{181,169,216},{223,215,245}),
  obsidianblack=edition("ObsidianBlack",{159,177,207},{208,222,245}),
  pearlwhite=edition("PearlWhite",{230,222,210},{255,247,235}),
}
LauncherTheme.PRESET_ORDER = {"heartgold","pureyellow","rubyred","sapphireblue","emeraldgreen","soulsilver","crystalcyan","platinum","obsidianblack","pearlwhite"}
-- Keep saved choices readable across upgrades without adding duplicate presets.
LauncherTheme.ALIASES={slate="soulsilver",carbon="obsidianblack",heather="platinum",moss="emeraldgreen",ember="rubyred",abyss="sapphireblue",dusk="platinum"}
for old,id in pairs(LauncherTheme.ALIASES)do LauncherTheme.PRESETS[old]=LauncherTheme.PRESETS[id] end
function LauncherTheme.resolve(id)return LauncherTheme.ALIASES[id] or id end

-- EVERY GROUND HERE IS DARK, and that is a decision rather than an omission.
-- The launcher's cards are translucent fills over the ground, its button
-- sheens are white at low alpha and its toggle knob is a white circle; a light
-- ground turns all three invisible.  A light theme is not one more entry in
-- this table, it is a second set of rules for those three things, so it is not
-- offered rather than offered broken.

-- The accent is the colour used for links, the active-tab underline and the
-- focus ring -- the launcher's one loud colour.  `link` and `linkHover` are
-- the pair; hover is the same hue lifted toward white.
LauncherTheme.ACCENTS = {
  sky    = { label = "SKY",    link = { 127, 208, 255 }, hover = { 191, 234, 255 } },
  mint   = { label = "MINT",   link = { 106, 240, 178 }, hover = { 178, 250, 214 } },
  amber  = { label = "AMBER",  link = { 255, 198, 92 },  hover = { 255, 226, 166 } },
  rose   = { label = "ROSE",   link = { 255, 140, 162 }, hover = { 255, 196, 208 } },
  violet = { label = "VIOLET", link = { 186, 156, 255 }, hover = { 216, 198, 255 } },
  ice    = { label = "ICE",    link = { 214, 228, 248 }, hover = { 240, 246, 255 } },
  coral  = { label = "CORAL",  link = { 255, 146, 108 }, hover = { 255, 198, 176 } },
  lime   = { label = "LIME",   link = { 186, 240, 110 }, hover = { 218, 250, 176 } },
  cyan   = { label = "CYAN",   link = { 104, 230, 240 }, hover = { 176, 244, 250 } },
  gold   = { label = "GOLD",   link = { 255, 214, 122 }, hover = { 255, 234, 186 } },
  orchid = { label = "ORCHID", link = { 236, 150, 232 }, hover = { 246, 200, 244 } },
}

LauncherTheme.ACCENT_ORDER = {
  "sky", "mint", "amber", "rose", "violet", "ice",
  "coral", "lime", "cyan", "gold", "orchid",
}

-- HOW MUCH OF THE ACCENT REACHES THE BACKGROUND.  The launcher's ground is a
-- radial gradient with a bright point at the top centre, and mixing a little
-- of the accent into that point is what makes the accent read as the theme's
-- colour rather than as a setting that only repaints the links.  Low, because
-- the accents are far brighter than the ground and anything above about a
-- quarter stops being a tint and starts being a wash.
LauncherTheme.GLOW_MIX = 0.035

-- Rounded to whole channel values: the result is a colour, and the launcher
-- keys its cached background mesh on those numbers with %d -- which is a
-- truncation under LuaJIT and an outright error under a stricter Lua.
local function mix(a, b, t)
  local function ch(i)
    return math.floor(a[i] + (b[i] - a[i]) * t + 0.5)
  end
  return { ch(1), ch(2), ch(3) }
end

-- ---------------------------------------------------------------------------
-- TEXT
--
-- The third axis, and the one with the least room to play: everything here is
-- read, so a choice that looks striking in a screenshot and costs contrast is
-- a choice that makes the launcher worse.  Each family sets the same five keys
-- in the same relationship -- a bright ink for headings and names, a slightly
-- dimmer body, a dimmer still secondary, and two quiet greys for the
-- letterspaced labels and the mod dots -- so no family can invert the
-- hierarchy the layout is built on.
--
-- `ink` is the brightest of the five and is what most of the launcher prints
-- with.  It is deliberately a SEPARATE key from `white`: white is also the
-- glass sheen on a button, the 18% border highlight and the toggle knob, and
-- a text colour that repainted those would turn every button into a smudge.
LauncherTheme.TEXTS = {
  warm = {
    label = "WARM",
    note = "Paper-white, a little yellow in it.",
    colors = {
      ink       = { 255, 250, 240 },
      heading   = { 255, 248, 236 },
      detail    = { 236, 226, 210 },
      warning   = { 212, 200, 182 },
      labelGray = { 200, 188, 170 },
      modDot    = { 214, 202, 184 },
    },
  },
  cool = {
    label = "COOL",
    note = "Blue-white, the launcher's own cast pushed further.",
    colors = {
      ink       = { 242, 248, 255 },
      heading   = { 236, 244, 255 },
      detail    = { 212, 226, 244 },
      warning   = { 182, 200, 228 },
      labelGray = { 170, 190, 220 },
      modDot    = { 186, 204, 232 },
    },
  },
  paper = {
    label = "PAPER",
    note = "Plain white, no cast either way.",
    colors = {
      ink       = { 255, 255, 255 },
      heading   = { 250, 250, 250 },
      detail    = { 228, 228, 228 },
      warning   = { 202, 202, 202 },
      labelGray = { 190, 190, 190 },
      modDot    = { 206, 206, 206 },
    },
  },
  contrast = {
    label = "CONTRAST",
    note = "Everything brighter, including the small print.",
    colors = {
      ink       = { 255, 255, 255 },
      heading   = { 255, 255, 255 },
      detail    = { 245, 245, 245 },
      warning   = { 226, 226, 226 },
      labelGray = { 214, 214, 214 },
      modDot    = { 232, 232, 232 },
    },
  },
  phosphor = {
    label = "PHOSPHOR",
    note = "Monochrome green, like a CRT terminal.",
    colors = {
      ink       = { 186, 255, 198 },
      heading   = { 178, 252, 192 },
      detail    = { 162, 232, 178 },
      warning   = { 150, 214, 164 },
      labelGray = { 142, 204, 156 },
      modDot    = { 156, 222, 172 },
    },
  },
  amberText = {
    label = "AMBER",
    note = "Monochrome amber, the other terminal.",
    colors = {
      ink       = { 255, 226, 166 },
      heading   = { 252, 218, 156 },
      detail    = { 238, 202, 148 },
      warning   = { 226, 190, 140 },
      labelGray = { 216, 180, 132 },
      modDot    = { 230, 194, 146 },
    },
  },
}

LauncherTheme.TEXT_ORDER = {
  "warm", "cool", "paper", "contrast", "phosphor", "amberText",
}

-- The keys any preset is allowed to touch, so a malformed entry cannot repaint
-- cartridge chips. Primary actions follow the chosen accent. Built from the union of the presets
-- above rather than written out twice.
local THEMED_KEYS = {}
for _, preset in pairs(LauncherTheme.PRESETS) do
  for key in pairs(preset.colors or {}) do THEMED_KEYS[key] = true end
end
for _, family in pairs(LauncherTheme.TEXTS) do
  for key in pairs(family.colors or {}) do THEMED_KEYS[key] = true end
end
THEMED_KEYS.playTop=true
THEMED_KEYS.playBot=true
THEMED_KEYS.playInk=true
THEMED_KEYS.link = true
THEMED_KEYS.linkHover = true
-- The bright point of the background gradient.  Derived rather than declared:
-- apply() always writes it from the preset's own bgTop and the accent, so it
-- needs no baseline of its own and cannot drift out of step with either.
THEMED_KEYS.bgGlow = true

local baseline = nil
local logoAccent, logoShader

local function copyTriple(rgb)
  return { rgb[1], rgb[2], rgb[3] }
end

-- Snapshot the shipped values for every key a theme may touch.  Taken once,
-- from the first palette handed in, and never refreshed: a second capture
-- after a theme had been applied would record the theme as the baseline.
function LauncherTheme.capture(pal)
  if baseline or type(pal) ~= "table" then return baseline end
  baseline = {}
  for key in pairs(THEMED_KEYS) do
    if type(pal[key]) == "table" then baseline[key] = copyTriple(pal[key]) end
  end
  return baseline
end

-- Testing seam, and the honest way to re-capture: forget the snapshot.
function LauncherTheme.forget()
  baseline = nil
end

function LauncherTheme.presetLabel(id)
  local preset = id and LauncherTheme.PRESETS[id]
  if preset then return preset.label end
  return "DEFAULT"
end

function LauncherTheme.accentLabel(id)
  local accent = id and LauncherTheme.ACCENTS[id]
  if accent then return accent.label end
  return "DEFAULT"
end

function LauncherTheme.presetNote(id)
  local preset = id and LauncherTheme.PRESETS[id]
  return preset and preset.note or nil
end

function LauncherTheme.textLabel(id)
  local family = id and LauncherTheme.TEXTS[id]
  if family then return family.label end
  return "DEFAULT"
end

function LauncherTheme.textNote(id)
  local family = id and LauncherTheme.TEXTS[id]
  return family and family.note or nil
end

-- apply(pal, themeId, accentId, textId)
--
-- Restores the baseline first, then lays the ground over it, then the text
-- family, then the accent, then the derived background glow.  In that order so
-- that a ground which sets its own reading colours is still overruled by an
-- explicit TEXT choice, an explicit ACCENT still beats both, and clearing any
-- one of the three back to DEFAULT cannot leave another's colours behind.
function LauncherTheme.apply(pal, themeId, accentId, textId)
  if type(pal) ~= "table" then return pal end
  LauncherTheme.capture(pal)
  if not baseline then return pal end
  for key, rgb in pairs(baseline) do pal[key] = copyTriple(rgb) end
  local preset = themeId and LauncherTheme.PRESETS[themeId]
  if preset then
    for key, rgb in pairs(preset.colors or {}) do
      if THEMED_KEYS[key] and type(rgb) == "table" then
        pal[key] = copyTriple(rgb)
      end
    end
  end
  -- TEXT AFTER GROUND, because a ground carries its own reading colours (it
  -- has to: a green ground wants a green-leaning body or the page looks like
  -- two designs) and an explicit TEXT choice is the player overruling that.
  local text = textId and LauncherTheme.TEXTS[textId]
  if text then
    for key, rgb in pairs(text.colors or {}) do
      if THEMED_KEYS[key] and type(rgb) == "table" then
        pal[key] = copyTriple(rgb)
      end
    end
  end
  local accent = (accentId and LauncherTheme.ACCENTS[accentId]) or (preset and preset.accent)
  logoAccent=accent and {accent.link[1]/255,accent.link[2]/255,accent.link[3]/255} or nil
  if accent then
    pal.playTop=copyTriple(accent.link);pal.playBot=mix(accent.link,{0,0,0},0.16);pal.playInk={12,18,26}
    pal.link = copyTriple(accent.link)
    pal.linkHover = copyTriple(accent.hover)
  end
  -- ...and the ground's bright point, last, because it is a function of both
  -- axes: the preset decides what colour the top of the screen is, the accent
  -- tints it.  Written unconditionally so that clearing the accent puts the
  -- preset's own bgTop back rather than leaving the last tint on it.
  local top = pal.bgTop
  if type(top) == "table" then
    if accent then
      pal.bgGlow = mix(top, accent.link, LauncherTheme.GLOW_MIX)
    else
      pal.bgGlow = copyTriple(top)
    end
  end
  return pal
end

-- The pair the launcher stores, normalised: an id no longer in the table (a
-- theme removed in a later build, a hand-edited options file) reads back as
-- DEFAULT rather than painting nothing and leaving the launcher half themed.
function LauncherTheme.fromOptions(opts)
  local theme, accent, text = nil, nil, nil
  if type(opts) == "table" then
    local t = opts.launcherTheme
    if type(t) == "string" and LauncherTheme.PRESETS[t] then theme = LauncherTheme.resolve(t) end
    local a = opts.launcherAccent
    if type(a) == "string" and LauncherTheme.ACCENTS[a] then accent = a end
    if LauncherTheme.ALIASES[t] then accent=nil end
    local x = opts.launcherText
    if type(x) == "string" and LauncherTheme.TEXTS[x] then text = x end
  end
  return theme, accent, text
end

-- The stepper's value lists, DEFAULT first so that a player who has never
-- touched either row sees where they started.
function LauncherTheme.presetValues()
  local out = { false }
  for _, id in ipairs(LauncherTheme.PRESET_ORDER) do out[#out + 1] = id end
  return out
end

function LauncherTheme.accentValues()
  local out = { false }
  for _, id in ipairs(LauncherTheme.ACCENT_ORDER) do out[#out + 1] = id end
  return out
end

function LauncherTheme.textValues()
  local out = { false }
  for _, id in ipairs(LauncherTheme.TEXT_ORDER) do out[#out + 1] = id end
  return out
end

-- Recolor the existing brand art at draw time; keep alpha, dark outlines and
-- bright highlights. Never overwrite source images or tint imported cartridges.
function LauncherTheme.drawLogo(image,...)
  local g=love.graphics
  if not logoAccent or not g.newShader or not g.setShader then return g.draw(image,...) end
  if logoShader==nil then
    local ok,value=pcall(g.newShader,[[
      extern vec3 editionAccent;
      vec4 effect(vec4 color, Image tex, vec2 uv, vec2 screen) {
        vec4 pixel=Texel(tex,uv);
        float light=dot(pixel.rgb,vec3(0.2126,0.7152,0.0722));
        vec3 body=editionAccent*mix(0.13,1.0,smoothstep(0.03,0.68,light));
        body=mix(body,vec3(1.0),smoothstep(0.64,1.0,light)*0.8);
        return vec4(body,pixel.a)*color;
      }
    ]]);logoShader=ok and value or false
  end
  if not logoShader then return g.draw(image,...)end
  local previous=g.getShader and g.getShader()
  logoShader:send('editionAccent',logoAccent);g.setShader(logoShader)
  g.draw(image,...);g.setShader(previous)
end

return LauncherTheme
