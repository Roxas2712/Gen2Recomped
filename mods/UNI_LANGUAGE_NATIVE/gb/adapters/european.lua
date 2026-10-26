local Adapter={}
function Adapter.apply(mod,edition)
 local game=mod.game
 local data=game.data
 local function route(record,key,path)
  if type(record)=='table' and mod:info('assets/'..path) then record[key]=mod.path..'/assets/'..path end
 end
 for _,font in ipairs({data.font,game.fontData}) do
  route(font,'image','fonts/font.png')
  route(font,'imageBattleExtra','fonts/font_battle_extra.png')
 end
 local body=mod:read('lang/layouts.lua')
 local layouts=body and assert(loadstring(body))() or {}
 local function localPaths(value)
  if type(value)=='string' then
   local rel=value:match('^assets/generated/(.+)$')
   if rel and mod:info('assets/'..rel) then return mod.path..'/assets/'..rel end
   return value
  elseif type(value)=='table' then
   local out={};for k,v in pairs(value) do out[k]=localPaths(v) end;return out
  end
  return value
 end
 local function merge(target,patch)
  for k,v in pairs(patch or {}) do
   if type(v)=='table' and type(target[k])=='table' then merge(target[k],v) else target[k]=v end
  end
 end
 data.gen2MenuGfx=data.gen2MenuGfx or {}
 merge(data.gen2MenuGfx,localPaths(layouts.menu))
 if layouts.pokegear then data.gen2MenuGfx.pokegear=data.gen2MenuGfx.pokegear or {};merge(data.gen2MenuGfx.pokegear,localPaths(layouts.pokegear))end
 if layouts.diploma then
  if layouts.diploma.nativeAsian then data.gen2Diploma=data.gen2Diploma or {};merge(data.gen2Diploma,localPaths(layouts.diploma))
  else data.gen2Diploma=localPaths(layouts.diploma)end
 end
 if layouts.credits then data.gen2Credits=localPaths(layouts.credits)end
 if game.titleData and layouts.title then merge(game.titleData,localPaths(layouts.title)) end
 local world=mod:read('lang/world_layout.lua')
 if world then for id,blocks in pairs(assert(loadstring(world))()) do
  local tileset=data.gen2Tilesets and data.gen2Tilesets[id]
  if tileset then for index,tiles in pairs(blocks) do tileset.blocks[index]=tiles end end
 end end
 local gfx=data.gen2MenuGfx
 route(gfx.battleHud,'battleExtra','fonts/font_battle_extra.png')
 route(gfx.battleHud,'hpBar','battle/hud/hp_bar.png')
 route(gfx.battleHud,'enemyBorder','battle/hud/enemy_border.png')
 route(gfx.battleHud,'playerBorder','battle/hud/player_border.png')
 route(gfx.pack,'menu','pack/menu.png')
 route(gfx.pack,'pack','pack/pack.png')
 route(gfx.stats,'sheet','menu/stats_tiles.png')
 route(gfx,'border','naming/border.png')
 route(gfx,'cursor','naming/cursor.png')
 route(gfx,'middleLine','naming/middleline.png')
 route(gfx,'underLine','naming/underline.png')
 route(gfx.pokedex,'tiles','pokedex/dex.png')
 route(gfx.pokegear,'tiles','pokegear/gear.png')
 route(gfx.trainerCard,'card','trainer_card/card.png')
 route(gfx.trainerCard,'cardFemale','trainer_card/card_f.png')
 route(gfx.trainerCard,'status','trainer_card/status.png')
 route(gfx.trainerCard,'leaders','trainer_card/leaders.png')
 route(data.gen2Credits,'theEnd','credits/theend.png')
 local title=game.titleData
 route(title,'screen',edition=='crystal' and 'title/crystal_screen.png' or 'title/title_screen.png')
 route(title,'screenGray',edition=='crystal' and 'title/crystal_screen_gray.png' or 'title/title_screen_gray.png')
 route(title,'image',edition=='crystal' and 'title/crystal_logo.png' or 'title/pokemon_logo.png')
 route(title,'wordmark','title/crystal_wordmark.png')
 return true
end
return Adapter
