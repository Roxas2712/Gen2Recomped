-- Adapted from Uni-Language Ascendant by Roxas2712 (2026), GPL-3.0.
-- Host integration; language profiles and cartridge inputs stay in the mod.
-- Same logical GB/GBC sheets, with the host's spelling and directory layout.
-- A route is accepted only after the caller verifies identical dimensions.
local R={}
function R.candidates(source)
 local rest=source:match('^assets/(.+)%.png$');if not rest then return{}end
 local out={'assets/generated/'..rest..'.png'}
 if rest:match('^tilesets/')then out[#out+1]='assets/generated/'..rest:gsub('_','')..'.png'end
 local exact={
  ['tilesets/overworld']='tilesets/0',
  ['fonts/font_battle_extra']='fonts/font_battle_extra',
  ['battle/font_battle_extra']='fonts/font_battle_extra',
  ['pokegear/gear']='ui/pokegear_gear',['pokegear/sprites']='ui/pokegear_sprites',
  ['pokegear/nest_icon']='ui/town_map_cursor',
  ['title/title_screen']='title/gen2_title',['title/copyright_splash']='intro/gen2_copyright',
  ['title/hooh_1']='title/gen2_mascot_1',['title/hooh_2']='title/gen2_mascot_2',
  ['title/hooh_3']='title/gen2_mascot_3',['title/hooh_4']='title/gen2_mascot_4',
  ['title/hooh_5']='title/gen2_mascot_5',
 }
 if exact[rest]then out[#out+1]='assets/generated/'..exact[rest]..'.png'end
 return out
end
return R
