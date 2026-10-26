-- PLATINUM'S STORY, AS BEATS (tools/gen4_playthrough/runner.lua).
--
-- Each beat names what the cartridge's own scripts must have done when it is
-- over -- the vars and flags pokeplatinum's scripts set -- so a beat fails
-- exactly where the port stops agreeing with the game. Run:
--
--   INSTALL=G:/Gen2Recomped/platinum VERSION=platinum MAP=T01R0202 X=4 Y=6 \
--     FACING=up PLAYTHROUGH=platinum TICKS=200000 love tools/gen4_hgss_overworld_harness

local B = {}

-- the bedroom's frame script: the TV's "Let's ask Prof. Rowan" notice
B[#B + 1] = { name = "bedroom",
  steps = { { "mash", 60 } },
  expect = function(r) return r:var(0x40F9) == 1 end, why = "0x40F9 = 1 (bedroom scene)" }

-- downstairs: Mom's scene (T01R0201 frame row 0x40A4 == 0 -> S0065)
B[#B + 1] = { name = "mom downstairs",
  steps = { { "warpto", "T01R0201" } },
  expect = function(r) return r:var(0x40A4) >= 1 end, why = "0x40A4 >= 1 (Mom's scene)" }

-- Barry's room (T01R0102 frame row 0x40A3 == 0 -> S000F): he rushes off to
-- the lake; flag 234, 0x40A3 = 1, 0x4070 = 2
B[#B + 1] = { name = "barry's room",
  steps = { { "warpto", "T01" }, { "warpto", "T01R0101" }, { "warpto", "T01R0102" } },
  expect = function(r) return r:var(0x40A3) == 1 and r:flag(234) end, why = "0x40A3 = 1, flag 234" }

-- Route 201: Barry stops the player (coord 1, 0x4086 == 0), then the lake
-- scene with Rowan and Dawn (S03DF: 0x4086 = 1)
B[#B + 1] = { name = "route 201 to the lake",
  steps = { { "warpto", "T01R0101" }, { "warpto", "T01" },
            { "teleport", "R201", 15, 28, "up" }, { "activecoord" },
            { "until", function(r) return r:var(0x4086) >= 1 end, 20000 } },
  expect = function(r) return r:var(0x4086) >= 1 end, why = "0x4086 >= 1 (the lake scene)" }

-- the briefcase (Route 201 person 12, S042F): the starter, the battle with Barry,
-- home to Mom (S0619: 0x4086 = 2, 0x40A4 = 3, warp), the Running Shoes
-- (T01R0201 frame row 0x40A4 == 3 -> S017D: 0x40A4 = 4)
B[#B + 1] = { name = "starter and running shoes",
  steps = { { "talkto", "briefcase" },
            { "until", function(r) return r:var(0x40A4) >= 4 end, 30000 } },
  expect = function(r) return #r:party() >= 1 and r:var(0x4086) >= 2 and r:var(0x40A4) >= 4 end,
  why = "a starter, 0x4086 >= 2, 0x40A4 >= 4 (shoes)" }

-- ---------------------------------------------------------------------------
-- THE REST OF THE STORY. Vars and flags are pokeplatinum's
-- (generated/vars_flags.txt, numbered as the enum counts them); scripts are
-- res/field/scripts/scripts_<map>.s and their init tables scripts_init_<map>.s.
-- Outdoor cells are local to the map (pret's global x/z minus the map's
-- chunk origin in matrix 0). Between story points the player is teleported;
-- the scenes themselves (coord triggers, frame scripts, talks) are real.

local function flag(id) return function(r) return r:flag(id) end end
local function varGe(id, v) return function(r) return r:var(id) >= v end end
local function badges(r)
  local n = 0
  for _, v in pairs((r.game.save or {}).badges or {}) do if v then n = n + 1 end end
  return n
end

-- A CHEAT, said as one (heartgold.lua's): the lead is rebuilt at level 75,
-- healed, with `move` first, so the runner's A-mashing (the first move, every
-- turn) wins the story battles. The story is under test here, not the battles.
local function trainUpWith(move, level, species)
  return function(r)
    local party = r:party()
    local lead = party[1]
    if not lead then return end
    local Pokemon = require("src.pokemon.Pokemon")
    local mon = Pokemon.new(r.game.data, species or lead.species, level or 75)
    mon.nickname, mon.otName, mon.otId = lead.nickname, lead.otName, lead.otId
    mon.moves = mon.moves or {}
    table.insert(mon.moves, 1, { id = move or 94, pp = 64 })
    while #mon.moves > 4 do table.remove(mon.moves) end
    party[1] = mon
  end
end
-- Surf by default: it hits both foes of a double battle (Floaroma Meadow's
-- grunts), and nothing early is immune to it (Stunky is to Psychic)
local trainUp = trainUpWith(57)
-- ...and from Canalave on the starter at 75 is not enough (Barry's five beat
-- a lone Turtwig at 75 with Surf): a Mewtwo at 100 leads instead
local function strong(move) return trainUpWith(move or 57, 100, 150) end
-- Psychic 94, Surf 57, Flamethrower 53, Crunch 242, Thunderbolt 85,
-- Earthquake 89, Ice Beam 58, Shadow Ball 247

-- ...and SIX DEEP, for the double battles (Spear Pillar's grunts need two
-- able Pokémon) and the League: six Mewtwo at 100 leading with `move`
local function fullTeam(move)
  return function(r)
    local party = r:party()
    local lead = party[1]
    local Pokemon = require("src.pokemon.Pokemon")
    for i = 1, 6 do
      local mon = Pokemon.new(r.game.data, 150, 100)
      if lead then mon.otName, mon.otId = lead.otName, lead.otId end
      mon.moves = mon.moves or {}
      table.insert(mon.moves, 1, { id = move, pp = 64 })
      while #mon.moves > 4 do table.remove(mon.moves) end
      party[i] = mon
    end
  end
end

-- SANDGEM (scripts_sandgem_town.s): the counterpart's coord trigger at the
-- west edge (x 4, y 10..15 while VAR_SANDGEM_TOWN_STATE 0x4071 == 0) leads
-- the player into the lab (0x4071 = 1, Warp); the lab's frame table
-- (0x40A6 == 0) is Rowan's Pokédex scene: FLAG_HAS_POKEDEX 0x90,
-- VAR_SANDGEM_TOWN_LAB_STATE 0x40A6 = 1
B[#B + 1] = { name = "sandgem: rowan's pokedex",
  steps = { { "teleport", "T02", 7, 13, "left" }, { "activecoord" },
            { "until", function(r) return r:flag(0x90) and r:var(0x40A6) >= 1 end, 40000 } },
  expect = function(r) return r:flag(0x90) and r:var(0x40A6) >= 1 and r:var(0x4071) >= 1 end,
  why = "flag 0x90 (Pokédex), 0x40A6 >= 1, 0x4071 >= 1", expectBudget = 8000 }

-- out of the lab: Sandgem's frame table (0x4071 == 1, OnFrame_ExitLab) is
-- the counterpart's tour of the Pokémon Center and Mart: 0x4071 = 2
B[#B + 1] = { name = "sandgem: the tour",
  steps = { { "warpto", "T02" }, { "until", varGe(0x4071, 2), 30000 } },
  expect = varGe(0x4071, 2), why = "0x4071 >= 2 (the tour)" }

-- home (scripts_twinleaf_town_player_house_1f.s, Mom = person 0): with the
-- Pokédex she gives the Journal, Barry's mom comes in with the Parcel
-- (FLAG_RECEIVED_PARCEL 0x8F)
B[#B + 1] = { name = "the parcel",
  steps = { { "teleport", "T01R0201", 5, 6, "down" }, { "talk", 0 },
            { "until", flag(0x8F), 30000 } },
  expect = flag(0x8F), why = "flag 0x8F (Parcel)", expectBudget = 8000 }

-- Route 202 (coord 1, x 20 y 25..29 while VAR_ROUTE_202_STATE 0x4087 == 0,
-- FLAG_RECEIVED_PARCEL set): the catching tutorial, the Poké Balls (0x4087 = 1)
B[#B + 1] = { name = "route 202 catching tutorial",
  steps = { { "teleport", "R202", 21, 27, "left" }, { "activecoord" },
            { "until", varGe(0x4087, 1), 30000 } },
  expect = varGe(0x4087, 1), why = "0x4087 >= 1 (the tutorial)", expectBudget = 8000 }

-- JUBILIFE (scripts_jubilife_city.s). Coord 1 (45..48,60 while
-- VAR_JUBILIFE_CITY_STATE 0x4077 == 0): the counterpart meets the player and
-- Looker, 0x4077 = 1
B[#B + 1] = { name = "jubilife: looker",
  steps = { { "teleport", "C01", 46, 62, "up" }, { "activecoord" },
            { "until", varGe(0x4077, 1), 30000 } },
  expect = varGe(0x4077, 1), why = "0x4077 >= 1", expectBudget = 8000 }

-- the Trainers' School (C01R0701): Barry (person 1) takes the Parcel, gives
-- the Town Map: FLAG_TALKED_TO_TRAINERS_SCHOOL_RIVAL 0xF1,
-- VAR_POKETCH_CAMPAIGN_STATE 0x40E7 = 1 (the clowns appear)
B[#B + 1] = { name = "jubilife: the trainers' school",
  steps = { { "teleport", "C01", 40, 42, "up" }, { "warpto", "C01R0701" }, { "talk", 1 },
            { "until", flag(0xF1), 30000 } },
  expect = function(r) return r:flag(0xF1) and r:var(0x40E7) >= 1 end, why = "flag 0xF1, 0x40E7 >= 1",
  expectBudget = 8000 }

-- the Pokétch campaign: coord 5 (44..48,40 while 0x40E7 == 1) is the
-- president's pitch (0x40E7 = 2); the three clowns' quizzes (persons 24, 25,
-- 27; every answer is YES) give the coupons (0xED, 0xEE, 0xEF); the president
-- (person 23) then gives the Pokétch: FLAG_RECEIVED_POKETCH 0xF3, 0x4077 = 2
-- A WANDERER is talked to as a player would: walk up, press A, and when it
-- has wandered off in the meantime (the A fell on nothing -- no script ran),
-- walk up again. Up to `tries` times, then the flag must be set.
local function talkUntil(steps, id, done, tries)
  for _ = 1, tries or 6 do
    steps[#steps + 1] = { "talk", id, retarget = true, avoidTriggers = true, unless = done }
    steps[#steps + 1] = { "until", function(r)
      return done(r) or (r.stepT > 90 and not r:busy())
    end, 20000 }
    steps[#steps + 1] = { "do", function() end }
  end
  steps[#steps + 1] = { "until", done, 20000 }
end
local poketch = { { "warpto", "C01" }, { "walkto", 44, 42 },
                  -- by number: `activecoord` takes the first armed trigger in
                  -- the list, which is Looker's strip (coord 3, 0x4077 == 1) --
                  -- his "have you not obtained a Pokétch?" pushes back forever
                  { "coord", 5 }, { "until", varGe(0x40E7, 2), 20000 } }
talkUntil(poketch, 24, flag(0xED))
talkUntil(poketch, 25, flag(0xEE))
talkUntil(poketch, 27, flag(0xEF))
talkUntil(poketch, 23, flag(0xF3))
B[#B + 1] = { name = "jubilife: the poketch",
  steps = poketch,
  expect = function(r) return r:flag(0xF3) and r:var(0x4077) >= 2 end, why = "flag 0xF3 (Pokétch), 0x4077 >= 2",
  expectBudget = 8000, budget = 120000 }

-- Route 203 (coord 1, x 4 y 21..24 while VAR_ROUTE_203_RIVAL_STATE 0x4088
-- == 0): Barry's battle, 0x4088 = 1
B[#B + 1] = { name = "route 203 rival",
  steps = { { "do", trainUp }, { "teleport", "R203", 2, 22, "right" }, { "activecoord" },
            { "until", varGe(0x4088, 1), 60000 } },
  expect = varGe(0x4088, 1), why = "0x4088 >= 1 (Barry beaten)", expectBudget = 8000 }

-- OREBURGH (scripts_oreburgh_city.s): coord 1 (10,12..15 while
-- VAR_OREBURGH_CITY_STATE 0x4079 == 0) is the youngster at the gate who
-- shows the way: 0x4079 = 1
B[#B + 1] = { name = "oreburgh: the youngster",
  steps = { { "teleport", "C03", 12, 13, "left" }, { "activecoord" },
            { "until", varGe(0x4079, 1), 30000 } },
  expect = varGe(0x4079, 1), why = "0x4079 >= 1", expectBudget = 8000 }

-- Oreburgh Mine B2F (D01R0102): Roark (person 0, between two Rock Smash
-- rocks) heads back to his gym: FLAG_ROARK_RETURNED_TO_OREBURGH_GYM 0x7A
B[#B + 1] = { name = "roark in the mine",
  steps = { { "teleport", "D01R0102", 15, 2, "down" }, { "talk", 0 },
            { "until", flag(0x7A), 30000 } },
  expect = flag(0x7A), why = "flag 0x7A (Roark back at his gym)", expectBudget = 8000 }

-- Oreburgh Gym (C03GYM0101): Roark (person 0), the Coal Badge, TM76
-- (FLAG_RECEIVED_ROARK_TM76 0x75); 0x4079 = 2, VAR_JUBILIFE_CITY_STATE = 3.
-- Rock types: Surf.
B[#B + 1] = { name = "roark",
  steps = { { "do", trainUpWith(57) }, { "teleport", "C03GYM0101", 5, 6, "up" }, { "talk", 0 },
            { "until", flag(0x75), 60000 } },
  expect = function(r) return r:flag(0x75) and r:var(0x4079) >= 2 end, why = "flag 0x75 (Coal Badge, TM76), 0x4079 >= 2",
  expectBudget = 12000 }

-- coord 2 (6,12..15 while 0x4079 == 2): Barry runs into the player on the
-- way out of town -- 0x4079 = 3
B[#B + 1] = { name = "oreburgh: barry",
  steps = { { "teleport", "C03", 8, 13, "left" }, { "activecoord" },
            { "until", varGe(0x4079, 3), 30000 } },
  expect = varGe(0x4079, 3), why = "0x4079 >= 3", expectBudget = 8000 }

-- Jubilife coord 2 (45..47,7 while 0x4077 == 3): Rowan and the counterpart
-- held up by two grunts -- the tag battle, 0x4077 = 4
B[#B + 1] = { name = "jubilife: the galactic grunts",
  steps = { { "do", trainUp }, { "teleport", "C01", 46, 10, "up" }, { "activecoord" },
            { "until", varGe(0x4077, 4), 60000 } },
  expect = varGe(0x4077, 4), why = "0x4077 >= 4 (the tag battle)", expectBudget = 8000 }

-- THE VALLEY WINDWORKS. Route 205 South's coord 1 (19,83..88 while
-- VAR_VALLEY_WINDWORKS_STATE 0x4089 == 0): the little girl whose papa is shut
-- in the Windworks, 0x4089 = 1 (and Floaroma's two grunts leave)
B[#B + 1] = { name = "route 205: the little girl",
  steps = { { "teleport", "R205A", 21, 84, "left" }, { "activecoord" },
            { "until", varGe(0x4089, 1), 30000 } },
  expect = varGe(0x4089, 1), why = "0x4089 >= 1", expectBudget = 8000 }

-- Floaroma Meadow (D13R0101) coord 1 (12..13,48 while
-- VAR_FLOAROMA_MEADOW_STATE 0x40E9 == 0): the two grunts' double battle,
-- the Works Key (FLAG_OBTAINED_FLOAROMA_MEADOW_WORKS_KEY 0x9F)
B[#B + 1] = { name = "floaroma meadow grunts",
  steps = { { "do", trainUp }, { "teleport", "D13R0101", 12, 52, "up" }, { "activecoord" },
            { "until", flag(0x9F), 60000 } },
  expect = function(r) return r:flag(0x9F) and r:var(0x40E9) >= 1 end, why = "flag 0x9F (Works Key), 0x40E9 >= 1",
  expectBudget = 8000 }

-- The Windworks' door (D02): the grunt (person 0) in front of it, beaten,
-- goes inside; the door (bg 2 at (19,14)) then takes the Works Key --
-- FLAG_UNLOCKED_VALLEY_WINDWORKS_DOOR 0x10F
B[#B + 1] = { name = "the windworks door",
  steps = { { "do", trainUp }, { "teleport", "D02", 19, 18, "up" }, { "talk", 0 },
            { "until", function(r) return r:personAt(0) == "absent" or r:personAt(0):find("hidden") end, 40000 },
            { "sign", 2 }, { "until", flag(0x10F), 8000 } },
  expect = flag(0x10F), why = "flag 0x10F (the door unlocked)", expectBudget = 8000 }

-- Inside (D02R0101): the frame table (VAR_VALLEY_WINDWORKS_TEAM_GALACTIC_STATE
-- 0x40CF == 0) sets 1, then coord 1 (19,6..7 while 0x40CF == 1) is Mars:
-- the battle, 0x40CF = 2, 0x4089 = 2
B[#B + 1] = { name = "mars at the windworks",
  steps = { { "do", trainUp }, { "warpto", "D02R0101" }, { "until", varGe(0x40CF, 1), 8000 },
            { "activecoord" }, { "until", varGe(0x4089, 2), 60000 } },
  expect = function(r) return r:var(0x4089) >= 2 and r:var(0x40CF) >= 2 end, why = "0x4089 >= 2, 0x40CF >= 2 (Mars beaten)",
  expectBudget = 12000 }

-- ETERNA (scripts_eterna_city.s). Coord 1 (15,11..14 while
-- VAR_ETERNA_CITY_STATE 0x407A == 0): Barry, 0x407A = 1; coords 4/7 (while
-- 0x407A == 1): Cynthia gives HM01 Cut, 0x407A = 2
B[#B + 1] = { name = "eterna: barry",
  steps = { { "teleport", "C04", 17, 13, "left" }, { "activecoord" },
            { "until", varGe(0x407A, 1), 30000 } },
  expect = varGe(0x407A, 1), why = "0x407A >= 1", expectBudget = 8000 }
B[#B + 1] = { name = "eterna: cynthia's cut",
  steps = { { "activecoord" }, { "until", varGe(0x407A, 2), 30000 } },
  expect = varGe(0x407A, 2), why = "0x407A >= 2 (HM01)", expectBudget = 8000 }

-- Eterna Gym (C04GYM0101): Gardenia (person 1), the Forest Badge, TM86
-- (FLAG_RECEIVED_GARDENIA_TM86 0x74). Grass types: Flamethrower.
B[#B + 1] = { name = "gardenia",
  steps = { { "do", trainUpWith(53) }, { "teleport", "C04GYM0101", 11, 6, "up" }, { "talk", 1 },
            { "until", flag(0x74), 60000 } },
  expect = flag(0x74), why = "flag 0x74 (Forest Badge, TM86)", expectBudget = 12000 }

-- The Galactic building's 4F (C04R0204): Jupiter (person 0) --
-- FLAG_TEAM_GALACTIC_LEFT_ETERNA_BUILDING 0x81, 0x407A = 3
B[#B + 1] = { name = "jupiter in the eterna building",
  steps = { { "do", trainUp }, { "teleport", "C04R0204", 12, 7, "up" }, { "talk", 0 },
            { "until", flag(0x81), 60000 } },
  expect = function(r) return r:flag(0x81) and r:var(0x407A) >= 3 end, why = "flag 0x81, 0x407A >= 3",
  expectBudget = 12000 }

-- the Cycle Shop (C04R0101): the owner (person 0, back from the building)
-- gives the Bicycle (FLAG_RECEIVED_BICYCLE 0x82)
B[#B + 1] = { name = "the bicycle",
  steps = { { "teleport", "C04R0101", 3, 8, "up" }, { "talk", 0 },
            { "until", flag(0x82), 20000 } },
  expect = flag(0x82), why = "flag 0x82 (Bicycle)", expectBudget = 8000 }

-- Route 207 (coord 1, x 52 y 8..10 while VAR_ROUTE_207_COUNTERPART_TRIGGER_STATE
-- 0x408C == 0): the counterpart's Vs. Seeker, 0x408C = 1
B[#B + 1] = { name = "route 207: the vs. seeker",
  steps = { { "teleport", "R207", 49, 9, "right" }, { "activecoord" },
            { "until", varGe(0x408C, 1), 30000 } },
  expect = varGe(0x408C, 1), why = "0x408C >= 1", expectBudget = 8000 }

-- Mt. Coronet 1F South (D05R0101) coord 1 (14,23 while
-- VAR_MT_CORONET_1F_SOUTH_STATE 0x4096 == 0): Cyrus's speech, 0x4096 = 1
B[#B + 1] = { name = "cyrus at mt. coronet",
  steps = { { "teleport", "D05R0101", 14, 25, "up" }, { "activecoord" },
            { "until", varGe(0x4096, 1), 30000 } },
  expect = varGe(0x4096, 1), why = "0x4096 >= 1", expectBudget = 8000 }

-- HEARTHOME (scripts_hearthome_city.s). Coord 1 (13,53..57 while
-- VAR_HEARTHOME_CITY_STATE 0x40F6 == 0): the Buneary and Keira, 0x40F6 = 1
B[#B + 1] = { name = "hearthome: keira",
  steps = { { "teleport", "C05", 11, 55, "right" }, { "activecoord" },
            { "until", varGe(0x40F6, 1), 30000 } },
  expect = varGe(0x40F6, 1), why = "0x40F6 >= 1", expectBudget = 8000 }

-- the Contest Hall (C05R1101): its frame table (VAR_CONTEST_HALL_LOBBY_STATE
-- 0x40F7 == 0) is the counterpart's mother; then Fantina (person 10) goes
-- back to her gym -- FLAG_HIDE_HEARTHOME_CITY_GYM_GUIDE 0x18D (the guide in
-- front of the gym door steps away)
B[#B + 1] = { name = "hearthome: fantina at the contest hall",
  steps = { { "teleport", "C05", 31, 21, "up" }, { "warpto", "C05R1101" },
            { "until", varGe(0x40F7, 1), 30000 }, { "talk", 10 },
            { "until", flag(0x18D), 20000 } },
  expect = function(r) return r:flag(0x18D) and r:var(0x40F7) >= 1 end, why = "flag 0x18D, 0x40F7 >= 1",
  expectBudget = 8000 }

-- Hearthome Gym's leader room (C05GYM0104): Fantina (person 0), the Relic
-- Badge, TM65 (FLAG_RECEIVED_FANTINA_TM65 0x7D);
-- VAR_ROUTE_209_GATE_TO_HEARTHOME_CITY_STATE 0x407B = 1. Ghost types: Crunch.
B[#B + 1] = { name = "fantina",
  steps = { { "do", trainUpWith(242) }, { "teleport", "C05GYM0104", 4, 12, "up" }, { "talk", 0 },
            { "until", flag(0x7D), 60000 } },
  expect = function(r) return r:flag(0x7D) and r:var(0x407B) >= 1 end, why = "flag 0x7D (Relic Badge, TM65), 0x407B >= 1",
  expectBudget = 12000 }

-- the Route 209 gate (C05R0601) coord 1 (5,5..9 while 0x407B == 1): Barry's
-- battle, 0x407B = 2
B[#B + 1] = { name = "route 209 gate: barry",
  steps = { { "do", trainUp }, { "teleport", "C05R0601", 2, 7, "right" }, { "activecoord" },
            { "until", varGe(0x407B, 2), 60000 } },
  expect = varGe(0x407B, 2), why = "0x407B >= 2 (Barry beaten)", expectBudget = 8000 }

-- Solaceon (T04) coord 1 (13..19,29 while VAR_SOLACEON_TOWN_STATE 0x4073 ==
-- 0): the counterpart, 0x4073 = 1
B[#B + 1] = { name = "solaceon: the counterpart",
  steps = { { "teleport", "T04", 16, 31, "up" }, { "activecoord" },
            { "until", varGe(0x4073, 1), 30000 } },
  expect = varGe(0x4073, 1), why = "0x4073 >= 1", expectBudget = 8000 }

-- VEILSTONE (scripts_veilstone_city.s). Coord 2 (9..12,40 while
-- VAR_VEILSTONE_CITY_CRASHER_WAKE_STATE 0x40F5 == 0): Wake and the
-- counterpart, 0x40F5 = 1
B[#B + 1] = { name = "veilstone: crasher wake",
  steps = { { "teleport", "C07", 10, 42, "up" }, { "coord", 2 },
            { "until", varGe(0x40F5, 1), 30000 } },
  expect = varGe(0x40F5, 1), why = "0x40F5 >= 1", expectBudget = 8000 }

-- Veilstone Gym (C07GYM0101): Maylene (person 0), the Cobble Badge, TM60
-- (FLAG_RECEIVED_MAYLENE_TM60 0x9D); VAR_VEILSTONE_CITY_COUNTERPART_NEEDS_HELP_STATE
-- 0x411A = 1. Fighting types: Psychic.
B[#B + 1] = { name = "maylene",
  steps = { { "do", trainUpWith(94) }, { "teleport", "C07GYM0101", 12, 6, "up" }, { "talk", 0 },
            { "until", flag(0x9D), 60000 } },
  expect = function(r) return r:flag(0x9D) and r:var(0x411A) >= 1 end, why = "flag 0x9D (Cobble Badge, TM60), 0x411A >= 1",
  expectBudget = 12000 }

-- back out in Veilstone, the frame table (0x411A == 1) has the counterpart
-- call for help at the warehouse (0x411A = 2; she stands at (24,20)). Talked
-- to from the west (the script handles the player facing east, north or
-- south only) she joins the tag battle against the warehouse's two grunts;
-- Looker follows and the player is warped inside: the warehouse's frame
-- table (VAR_VEILSTONE_CITY_GALACTIC_WAREHOUSE_STATE 0x411F == 1) sets 2
-- (and VAR_PASTORIA_CITY_STATE 0x407C = 1)
B[#B + 1] = { name = "veilstone: the galactic warehouse",
  steps = { { "do", trainUp }, { "warpto", "C07" }, { "until", varGe(0x411A, 2), 20000 },
            { "walkto", 23, 20 }, { "face", "right" }, { "press", "a" },
            { "until", varGe(0x411F, 2), 60000 } },
  expect = function(r) return r:var(0x411F) >= 2 and r:var(0x407C) >= 1 end, why = "0x411F >= 2, 0x407C >= 1",
  expectBudget = 12000 }

-- in the warehouse: HM02 Fly is the ball at (13,8) (person 1,
-- FLAG_OBTAINED_VEILSTONE_CITY_GALACTIC_WAREHOUSE_HM02 0x4E2)
B[#B + 1] = { name = "hm02 fly",
  steps = { { "talk", 1 }, { "until", flag(0x4E2), 8000 } },
  expect = flag(0x4E2), why = "flag 0x4E2 (HM02)" }

-- PASTORIA (scripts_pastoria_city.s). Coord 2 (13,28 while
-- VAR_PASTORIA_CITY_STATE 0x407C == 1), in front of the gym door: Barry's
-- battle, 0x407C = 2
B[#B + 1] = { name = "pastoria: barry",
  steps = { { "do", trainUp }, { "teleport", "C06", 13, 30, "up" }, { "activecoord" },
            { "until", varGe(0x407C, 2), 60000 } },
  expect = varGe(0x407C, 2), why = "0x407C >= 2 (Barry beaten)", expectBudget = 8000 }

-- Pastoria Gym (C06GYM0101): Crasher Wake (person 0), the Fen Badge, TM55
-- (FLAG_RECEIVED_WAKE_TM55 0x9C), 0x407C = 3. Water types: Thunderbolt.
B[#B + 1] = { name = "crasher wake",
  steps = { { "do", trainUpWith(412, 80) }, { "teleport", "C06GYM0101", 13, 6, "up" }, { "talk", 0 },
            { "until", flag(0x9C), 60000 } },
  expect = function(r) return r:flag(0x9C) and r:var(0x407C) >= 3 end, why = "flag 0x9C (Fen Badge, TM55), 0x407C >= 3",
  expectBudget = 12000 }

-- out of the gym: the frame table (0x407C == 3) is Barry and Wake (0x407C =
-- 4); coord 3 (34,10 while 0x407C == 4) is the Great Marsh "bomb" -- the
-- grunt runs east (FLAG_PASTORIA_CITY_GRUNT_M_MOVED_EAST 0x102, 0x407C = 5);
-- the grunt (person 21) then talked to leaves for Route 213
-- (FLAG_TALKED_TO_PASTORIA_CITY_GRUNT_M 0x103)
B[#B + 1] = { name = "pastoria: the grunt's bomb",
  steps = { { "warpto", "C06" }, { "until", varGe(0x407C, 4), 20000 },
            { "activecoord" }, { "until", flag(0x102), 30000 },
            { "talk", 21 }, { "until", flag(0x103), 20000 } },
  expect = function(r) return r:flag(0x103) and r:var(0x407C) >= 5 end, why = "flag 0x103, 0x407C >= 5",
  expectBudget = 8000 }

-- Route 213 (R213): the grunt (person 30, by the Pastoria gate first, then at
-- (43,33)) talked to twice -- FLAG_TALKED_TO_ROUTE_213_GRUNT_M 0x118, then
-- Looker's scene: FLAG_ROUTE_213_GRUNT_M_LEFT 0x104
B[#B + 1] = { name = "route 213: the grunt",
  steps = { { "teleport", "R213", 8, 12, "right" }, { "talk", 30 }, { "until", flag(0x118), 20000 },
            { "talk", 30, retarget = true }, { "until", flag(0x104), 30000 } },
  expect = flag(0x104), why = "flag 0x104 (the grunt left)", expectBudget = 8000 }

-- Valor Lakefront (L02): the grunt (person 5) runs north
-- (FLAG_TALKED_TO_VALOR_LAKEFRONT_GRUNT_M 0x106); talked to again he
-- battles, then Cynthia hands over the SecretPotion -- 0x407C = 6
B[#B + 1] = { name = "valor lakefront: the secretpotion",
  steps = { { "do", trainUp }, { "teleport", "L02", 47, 57, "up" }, { "talk", 5 },
            { "until", flag(0x106), 20000 }, { "talk", 5, retarget = true },
            { "until", varGe(0x407C, 6), 60000 } },
  expect = varGe(0x407C, 6), why = "0x407C >= 6 (SecretPotion)", expectBudget = 8000 }

-- Route 210 South (R210A): the Psyduck (persons 19, 26, 27, 28) take the
-- SecretPotion, Cynthia gives the Old Charm -- FLAG_USED_SECRETPOTION 0x107
B[#B + 1] = { name = "route 210: the psyduck",
  steps = { { "teleport", "R210A", 17, 46, "up" }, { "talkany", { 19, 26, 27, 28 } },
            { "until", flag(0x107), 30000 } },
  expect = flag(0x107), why = "flag 0x107 (the Psyduck cured)", expectBudget = 8000 }

-- CELESTIC (T05): the grunt (person 2) at the cave door, beaten; the elder
-- takes the Old Charm (FLAG_DELIVERED_OLD_CHARM 0xA6)
B[#B + 1] = { name = "celestic: the grunt",
  steps = { { "do", trainUp }, { "teleport", "T05", 15, 13, "up" }, { "talk", 2 },
            { "until", flag(0xA6), 60000 } },
  expect = flag(0xA6), why = "flag 0xA6 (Old Charm delivered)", expectBudget = 8000 }

-- the cave (T05R0501): the painting (bg 1 at (9,2)), the elder and Cyrus --
-- the battle, HM03 Surf; VAR_CELESTIC_TOWN_STATE 0x4074 = 1. Dark/Poison/
-- Flying: Thunderbolt.
B[#B + 1] = { name = "celestic: cyrus at the painting",
  steps = { { "do", trainUpWith(85) }, { "teleport", "T05R0501", 9, 5, "up" }, { "sign", 1 },
            { "until", varGe(0x4074, 1), 60000 } },
  expect = function(r) return r:var(0x4074) >= 1 and r:flag(0xA7) end, why = "0x4074 >= 1, flag 0xA7",
  expectBudget = 12000 }

-- out of the cave: Celestic's frame table (0x4074 == 1) is Cynthia's
-- send-off -- 0x4074 = 2 (Route 218's blockade leaves, 0x299)
B[#B + 1] = { name = "celestic: cynthia",
  steps = { { "warpto", "T05" }, { "until", varGe(0x4074, 2), 30000 } },
  expect = function(r) return r:var(0x4074) >= 2 and r:flag(0x299) end, why = "0x4074 >= 2, flag 0x299",
  expectBudget = 8000 }

-- CANALAVE. The gate (R218R0201) coord 1 (7,5..9 while
-- VAR_ROUTE_218_GATE_TO_CANALAVE_CITY_STATE 0x4105 == 0): the Pokédex
-- upgrade, 0x4105 = 1
B[#B + 1] = { name = "canalave gate: the scientist",
  steps = { { "teleport", "R218R0201", 9, 7, "left" }, { "activecoord" },
            { "until", varGe(0x4105, 1), 30000 } },
  expect = varGe(0x4105, 1), why = "0x4105 >= 1", expectBudget = 8000 }

-- Canalave coord 1 (15,19..22 while VAR_CANALAVE_CITY_STATE 0x4078 == 0) on
-- the bridge: Barry's battle, 0x4078 = 1
B[#B + 1] = { name = "canalave: barry on the bridge",
  steps = { { "do", strong() }, { "teleport", "C02", 18, 20, "left" }, { "activecoord" },
            { "until", varGe(0x4078, 1), 60000 } },
  expect = varGe(0x4078, 1), why = "0x4078 >= 1 (Barry beaten)", expectBudget = 8000 }

-- Canalave Gym (C02GYM0101): Byron (person 4), the Mine Badge, TM91
-- (FLAG_RECEIVED_BYRON_TM91 0x92), 0x4078 = 2. Steel types: Earthquake.
B[#B + 1] = { name = "byron",
  steps = { { "do", strong(89) }, { "teleport", "C02GYM0101", 16, 6, "up" }, { "talk", 4 },
            { "until", flag(0x92), 60000 } },
  expect = function(r) return r:flag(0x92) and r:var(0x4078) >= 2 end, why = "flag 0x92 (Mine Badge, TM91), 0x4078 >= 2",
  expectBudget = 12000 }

-- out of the gym: the frame table (0x4078 == 2) is Barry -- 0x4078 = 3,
-- VAR_CANALAVE_LIBRARY_STATE 0x40B2 = 1
B[#B + 1] = { name = "canalave: barry after byron",
  steps = { { "warpto", "C02" }, { "until", varGe(0x4078, 3), 30000 } },
  expect = function(r) return r:var(0x4078) >= 3 and r:var(0x40B2) >= 1 end, why = "0x4078 >= 3, 0x40B2 >= 1",
  expectBudget = 8000 }

-- Iron Island (D24): Riley (person 1) gives HM04 Strength and leaves
-- (FLAG_HIDE_IRON_ISLAND_RILEY 0x214) -- the library's Barry wants it
B[#B + 1] = { name = "iron island: riley",
  steps = { { "teleport", "D24", 21, 13, "up" }, { "talk", 1 },
            { "until", flag(0x214), 30000 } },
  expect = flag(0x214), why = "flag 0x214 (Riley gave HM04)", expectBudget = 8000 }

-- Barry at the library door (C02 person 18) lets the player by once HM04 is
-- in the bag and goes in (FLAG_HIDE_CANALAVE_CITY_RIVAL_LIBRARY 0x2CC); 3F's
-- frame table (0x40B2 == 1) is Rowan's story and the Lake Valor explosion:
-- FLAG_LAKE_VALOR_EXPLODED 0xA8, 0x40B2 = 2, 0x4078 = 4
B[#B + 1] = { name = "canalave library: the explosion",
  steps = { { "teleport", "C02", 5, 18, "up" }, { "talk", 18 }, { "until", flag(0x2CC), 20000 },
            { "teleport", "C02R0103", 11, 6, "down" },
            { "until", flag(0xA8), 40000 } },
  expect = function(r) return r:flag(0xA8) and r:var(0x40B2) >= 2 end, why = "flag 0xA8 (Lake Valor), 0x40B2 >= 2",
  expectBudget = 8000 }

-- back out: Canalave's frame table (0x4078 == 4) -- Rowan, the counterpart
-- and the sailor; 0x4078 = 5
B[#B + 1] = { name = "canalave: rowan's orders",
  steps = { { "teleport", "C02", 5, 16, "down" }, { "until", varGe(0x4078, 5), 30000 } },
  expect = varGe(0x4078, 5), why = "0x4078 >= 5", expectBudget = 8000 }

-- THE LAKES. Lake Valor, drained (D28R0101) -> Valor Cavern (D28R0103):
-- Saturn (person 1) -- FLAG_DEFEATED_COMMANDER_SATURN_VALOR_CAVERN 0x13E.
-- Golbat/Bronzor/Toxicroak: Psychic.
B[#B + 1] = { name = "saturn at lake valor",
  steps = { { "do", strong() }, { "teleport", "D28R0103", 14, 23, "up" }, { "talk", 1 },
            { "until", flag(0x13E), 60000 } },
  expect = flag(0x13E), why = "flag 0x13E (Saturn beaten)", expectBudget = 12000 }

-- Lake Verity (D27R0102): the frame table (VAR_LAKE_VERITY_PROF_ROWAN_STATE
-- 0x4097 == 0) is Rowan; Mars (person 7) -- FLAG_TEAM_GALACTIC_LEFT_LAKE_VERITY
-- 0xBA, VAR_LAKE_ACUITY_STATE 0x40D3 = 1
B[#B + 1] = { name = "mars at lake verity",
  steps = { { "do", strong() }, { "teleport", "D27R0102", 47, 54, "up" },
            { "until", varGe(0x4097, 1), 30000 }, { "talk", 7 },
            { "until", flag(0xBA), 60000 } },
  expect = function(r) return r:flag(0xBA) and r:var(0x40D3) >= 1 end, why = "flag 0xBA, 0x40D3 >= 1",
  expectBudget = 12000 }

-- Snowpoint Gym (C09GYM0101): Candice (person 0, past the snowballs), the
-- Icicle Badge, TM72 (FLAG_RECEIVED_CANDICE_TM72 0x9E). Ice: Flamethrower.
B[#B + 1] = { name = "candice",
  steps = { { "do", strong(53) }, { "teleport", "C09GYM0101", 11, 6, "up" }, { "talk", 0 },
            { "until", flag(0x9E), 60000 } },
  expect = flag(0x9E), why = "flag 0x9E (Icicle Badge, TM72)", expectBudget = 12000 }

-- Acuity Lakefront (L03) coord 1 (22..23,52 while VAR_ACUITY_LAKEFRONT_STATE
-- 0x4084 == 0): Barry on the way up, 0x4084 = 1; then up the Rock Climb wall
-- (teleported past) into Lake Acuity (D29R0102), whose frame table
-- (VAR_LAKE_ACUITY_STATE 0x40D3 == 1) is Jupiter taking Uxie: 0x40D3 = 2
B[#B + 1] = { name = "lake acuity: jupiter",
  steps = { { "teleport", "L03", 22, 54, "up" }, { "activecoord" }, { "until", varGe(0x4084, 1), 20000 },
            { "teleport", "L03", 20, 39, "up" }, { "warpto", "D29R0102" },
            { "until", varGe(0x40D3, 2), 40000 } },
  expect = varGe(0x40D3, 2), why = "0x40D3 >= 2 (Uxie taken)", expectBudget = 8000 }

-- THE GALACTIC HQ. Veilstone's grunt (person 23, shown once Uxie is taken)
-- drops the Storage Key and Looker asks the player in (YES):
-- FLAG_VEILSTONE_CITY_GRUNT_DROPPED_STORAGE_KEY 0x155,
-- VAR_VEILSTONE_CITY_GALACTIC_WAREHOUSE_STATE 0x411F = 3
B[#B + 1] = { name = "veilstone: the storage key",
  steps = { { "teleport", "C07", 47, 17, "right" }, { "talk", 23 },
            { "until", varGe(0x411F, 3), 40000 } },
  expect = function(r) return r:flag(0x155) and r:var(0x411F) >= 3 end, why = "flag 0x155, 0x411F >= 3",
  expectBudget = 8000 }

-- the warehouse (C07R0301) coord 1 (8..9,8 while 0x411F == 3): Looker opens
-- the HQ door -- FLAG_USED_STORAGE_KEY 0x10E, 0x411F = 4
B[#B + 1] = { name = "the galactic hq door",
  steps = { { "teleport", "C07R0301", 8, 10, "up" }, { "activecoord" },
            { "until", varGe(0x411F, 4), 30000 } },
  expect = function(r) return r:flag(0x10E) and r:var(0x411F) >= 4 end, why = "flag 0x10E, 0x411F >= 4",
  expectBudget = 8000 }

-- the Hall (D26R0109) coord 1 (20,12..13 while VAR_GALACTIC_HQ_HALL_STATE
-- 0x408E == 0): Cyrus's speech, 0x408E = 1. (The locked doors and the
-- Galactic Key are teleported past.)
B[#B + 1] = { name = "galactic hq: cyrus's speech",
  steps = { { "teleport", "D26R0109", 23, 12, "left" }, { "activecoord" },
            { "until", varGe(0x408E, 1), 30000 } },
  expect = varGe(0x408E, 1), why = "0x408E >= 1", expectBudget = 8000 }

-- 4F (D26R0104) coord 1 (8..9,11 while VAR_GALACTIC_HQ_4F_STATE 0x40D6 ==
-- 0): Cyrus's battle and the Master Ball, 0x40D6 = 1. Dark/Poison/Flying:
-- Thunderbolt.
B[#B + 1] = { name = "galactic hq: cyrus",
  steps = { { "do", strong(85) }, { "teleport", "D26R0104", 8, 13, "up" }, { "activecoord" },
            { "until", varGe(0x40D6, 1), 60000 } },
  expect = varGe(0x40D6, 1), why = "0x40D6 >= 1 (Cyrus beaten)", expectBudget = 12000 }

-- the Control Room (D26R0107): Saturn (person 0) --
-- FLAG_DEFEATED_GALACTIC_HQ_CONTROL_ROOM_SATURN 0xAD; then the button (bg 4
-- at (8,5), YES) frees the lake trio: FLAG_FREED_GALACTIC_HQ_POKEMON 0x97D,
-- VAR_MT_CORONET_2F_STATE 0x40A9 = 1
B[#B + 1] = { name = "galactic hq: saturn and the lake trio",
  steps = { { "do", strong(85) }, { "teleport", "D26R0107", 8, 12, "up" }, { "talk", 0 },
            { "until", flag(0xAD), 60000 }, { "sign", 4 },
            { "until", flag(0x97D), 30000 } },
  expect = function(r) return r:flag(0x97D) and r:var(0x40A9) >= 1 end, why = "flag 0x97D (the trio freed), 0x40A9 >= 1",
  expectBudget = 12000 }

-- SPEAR PILLAR (D05R0114; the climb up Mt. Coronet is teleported past).
-- Coord 1 (31,48 while VAR_SPEAR_PILLAR_STATE 0x4098 == 0): two grunts, a
-- double battle (two able Pokémon needed), 0x4098 = 1
B[#B + 1] = { name = "spear pillar: the grunts",
  steps = { { "do", fullTeam(57) }, { "teleport", "D05R0114", 31, 51, "up" }, { "activecoord" },
            { "until", varGe(0x4098, 1), 60000 } },
  expect = varGe(0x4098, 1), why = "0x4098 >= 1", expectBudget = 12000 }

-- coord 2 (30..32,32 while 0x4098 == 1): Mars and Jupiter, a tag battle with
-- Barry; Cyrus summons Dialga and Palkia, Giratina tears the pillar:
-- 0x4098 = 3, FLAG_SPEAR_PILLAR_IS_DISTORTED 0x132,
-- VAR_SPEAR_PILLAR_DISTORTED_STATE 0x40C3 = 1, warp to D05R0115
B[#B + 1] = { name = "spear pillar: mars and jupiter",
  steps = { { "do", fullTeam(57) }, { "activecoord" },
            { "until", function(r) return r:var(0x4098) >= 3 and r:flag(0x132) end, 80000 } },
  expect = function(r) return r:var(0x4098) >= 3 and r:var(0x40C3) >= 1 end, why = "0x4098 >= 3, 0x40C3 >= 1",
  expectBudget = 12000, budget = 100000 }

-- the distorted pillar (D05R0115): the frame table (0x40C3 == 1) is Cynthia
-- (0x40C3 = 2); YES and she leads the way into the Distortion World
-- (D34R0101), whose frame table (VAR_DISTORTION_WORLD_PROGRESS 0x4055 == 0)
-- sets 1
B[#B + 1] = { name = "into the distortion world",
  steps = { { "until", function(r) return r:map() == "D34R0101" end, 40000 },
            { "until", varGe(0x4055, 1), 30000 } },
  expect = function(r) return r:map() == "D34R0101" and r:var(0x4055) >= 1 end, why = "in D34R0101, 0x4055 >= 1",
  expectBudget = 8000 }

-- THE DISTORTION WORLD (ov9_02249960.c; src/world/Gen4DistPlatforms.lua) IS
-- NOT WALKED. Its floors move the player on the 3D surface walker
-- (Gen4DistSurface), which the runner's breadth-first planner
-- (Collision.canMove over cells) cannot plan across -- "no path" from 1F's
-- arrival (33,30) to the slab's tile event at (40,289,52), cell (19,42) here.
-- A CHEAT, said as one: the run is put where the cartridge leaves it after
-- Giratina's portal -- VAR_DISTORTION_WORLD_PROGRESS 0x4055 = 14,
-- VAR_EXITED_DISTORTION_WORLD_STATE 0x40AA = 1, at Sendoff Spring (D17R0101)
-- -- and Sendoff Spring's frame table (0x40AA == 1) is the real Cynthia
-- scene: 0x40AA = 2, VAR_SANDGEM_TOWN_LAB_STATE 0x40A6 = 2,
-- FLAG_SPEAR_PILLAR_IS_DISTORTED 0x132 cleared.
local function setVar(r, id, v) require("src.script.Gen4Commands").setVar(r.game.save, id, v) end
B[#B + 1] = { name = "sendoff spring: out of the distortion world",
  steps = { { "do", function(r) setVar(r, 0x4055, 14); setVar(r, 0x40AA, 1) end },
            { "teleport", "D17R0101", 32, 18, "down" },
            { "until", varGe(0x40AA, 2), 30000 } },
  expect = function(r) return r:var(0x40AA) >= 2 and r:var(0x40A6) >= 2 and not r:flag(0x132) end,
  why = "0x40AA >= 2, 0x40A6 >= 2, flag 0x132 clear", expectBudget = 8000 }

-- Rowan's lab (T02R0101): the frame table (0x40A6 == 2,
-- OnFrame_ReturnedFromDistortionWorld): 0x40A6 = 3,
-- VAR_VALOR_LAKEFRONT_BLOCK_SUNYSHORE_STATE 0x4112 = 1 (the way to Sunyshore)
B[#B + 1] = { name = "sandgem lab: after the distortion world",
  steps = { { "teleport", "T02", 8, 12, "up" }, { "warpto", "T02R0101" },
            { "until", varGe(0x40A6, 3), 30000 } },
  expect = function(r) return r:var(0x40A6) >= 3 and r:var(0x4112) >= 1 end, why = "0x40A6 >= 3, 0x4112 >= 1",
  expectBudget = 8000 }

-- SUNYSHORE (scripts_sunyshore_city.s). In through the Route 222 gate
-- (R222R0301): the frame table (VAR_SUNYSHORE_CITY_STATE 0x407E == 0) is
-- Flint, who only goes on with the player at the gate's cells (0,54)/(0,55):
-- 0x407E = 1, Flint at the gym door
B[#B + 1] = { name = "sunyshore: flint",
  steps = { { "teleport", "R222R0301", 3, 7, "right" }, { "warpto", "C08" },
            { "until", varGe(0x407E, 1), 30000 } },
  expect = varGe(0x407E, 1), why = "0x407E >= 1", expectBudget = 8000 }

-- the Vista Lighthouse (C08R0801): Volkner (person 2) goes back to his gym
-- (FLAG_VOLKNER_RETURNED_TO_GYM 0x162); Flint (person 18) then steps away
-- from the door (FLAG_HIDE_SUNYSHORE_CITY_FLINT 0x239)
B[#B + 1] = { name = "sunyshore: volkner at the lighthouse",
  steps = { { "teleport", "C08R0801", 6, 5, "up" }, { "face", "up" }, { "press", "a" }, { "until", flag(0x162), 30000 },
            { "teleport", "C08", 13, 15, "up" }, { "talk", 18 }, { "until", flag(0x239), 30000 } },
  expect = function(r) return r:flag(0x162) and r:flag(0x239) end, why = "flags 0x162, 0x239", expectBudget = 8000 }

-- Sunyshore Gym's last room (C08GYM0103; the gear puzzles teleported past):
-- Volkner (person 0), the Beacon Badge, TM57 (FLAG_RECEIVED_VOLKNER_TM57
-- 0xB6), 0x407E = 2. Electric types: Earthquake.
B[#B + 1] = { name = "volkner",
  steps = { { "do", strong(89) }, { "teleport", "C08GYM0103", 11, 6, "up" }, { "talk", 0 },
            { "until", flag(0xB6), 60000 } },
  expect = function(r) return r:flag(0xB6) and r:var(0x407E) >= 2 end, why = "flag 0xB6 (Beacon Badge, TM57), 0x407E >= 2",
  expectBudget = 12000 }

-- coord 1 (21..25,7 while 0x407E == 2): Barry and Jasmine, HM07 Waterfall
-- (FLAG_RECEIVED_SUNYSHORE_CITY_HM07 0x9A), 0x407E = 3
B[#B + 1] = { name = "sunyshore: jasmine's waterfall",
  steps = { { "teleport", "C08", 23, 9, "up" }, { "activecoord" },
            { "until", flag(0x9A), 30000 } },
  expect = function(r) return r:flag(0x9A) and r:var(0x407E) >= 3 end, why = "flag 0x9A (HM07), 0x407E >= 3",
  expectBudget = 8000 }

-- THE POKEMON LEAGUE (Route 223 and Victory Road teleported past). The north
-- Pokémon Center (C10R0101) coord 1 (10..12,4 while VAR_RIVAL_BEAT_SUNYSHORE_GYM
-- 0x40EF == 0): Barry's last battle, 0x40EF = 1; the guard (person 0) at the
-- door then steps aside: FLAG_POKEMON_LEAGUE_DOOR_GUARD_MOVED_AWAY 0xAF
B[#B + 1] = { name = "the league: barry",
  steps = { { "do", fullTeam(57) }, { "teleport", "C10R0101", 11, 7, "up" }, { "activecoord" },
            { "until", varGe(0x40EF, 1), 60000 },
            { "talk", 0 }, { "until", flag(0xAF), 20000 } },
  expect = function(r) return r:var(0x40EF) >= 1 and r:flag(0xAF) end, why = "0x40EF >= 1, flag 0xAF",
  expectBudget = 12000 }

-- the Elite Four (C10R0103/0105/0107/0109): each room's member is person 0
-- at (8,5); FLAG_DEFEATED_AARON 0xB0, BERTHA 0xB1, FLINT 0xB2, LUCIAN 0xB3.
-- Six Mewtwo at 100, leading with Flamethrower for Aaron's bugs, Surf for
-- Bertha's ground and Flint's fire, Shadow Ball for Lucian's psychics.
local E4 = { { "aaron", "C10R0103", 0xB0, 53 }, { "bertha", "C10R0105", 0xB1, 57 },
             { "flint", "C10R0107", 0xB2, 57 }, { "lucian", "C10R0109", 0xB3, 247 } }
for _, e in ipairs(E4) do
  local f = e[3]
  B[#B + 1] = { name = "elite four " .. e[1],
    steps = { { "do", fullTeam(e[4]) }, { "teleport", e[2], 8, 9, "up" }, { "talk", 0 },
              { "until", flag(f), 60000 } },
    expect = flag(f), why = ("flag 0x%X"):format(f), expectBudget = 12000 }
end

-- the Champion's room (C10R0111): its frame table (VAR_MAP_LOCAL_0x03 == 0)
-- is Cynthia's battle -- FLAG_DEFEATED_CYNTHIA 0xB4 -- then the hallway and
-- the Hall of Fame (C10R0113): ClearGame sets FLAG_GAME_COMPLETED 0x964 and
-- the credits roll. Ice Beam for her Garchomp.
B[#B + 1] = { name = "champion cynthia",
  steps = { { "do", fullTeam(58) }, { "teleport", "C10R0111", 8, 16, "up" },
            { "until", flag(0xB4), 80000 },
            { "until", flag(0x964), 120000 } },
  expect = function(r) return r:flag(0xB4) and r:flag(0x964) end, why = "flags 0xB4 (Cynthia), 0x964 (game completed)",
  expectBudget = 12000, budget = 220000, passBusy = true }

return B