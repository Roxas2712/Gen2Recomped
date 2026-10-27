-- QA-only same-input comparison of exact pinned RS bottom-panel draw routines.
-- The reference game's battle simulation/upper-field composition is not tested.
local M={}
function M.new(battle)
  local root=assert(os.getenv('RS_BATTLE_REFERENCE_ROOT'),'Use guarded RS battle reference launcher')
  local function source(name,hash)
    local f=assert(io.open(root..'/'..name,'rb'));local s=f:read('*a');f:close()
    assert(love.data.encode('string','hex',love.data.hash('sha256',s))==hash,'Pinned reference changed: '..name)
    return s
  end
  local ui=source('src/core/game3/battle/ui.lua','49ce05eed37357728094db0e1c030917a18adaa051ae61b54a1892ecbcaae996')
  local chrome=source('src/ui/game3/battle_chrome.lua','97498b1af09b9de48b062d567836b20197fcbfe138f1bddab3df75a7bdbdb581')
  local function excerpt(s,first,last)
    local start=assert(s:find(first,1,true));local finish=assert(s:find(last,start+#first,true));return s:sub(start,finish-1)
  end
  local panel=battle.rsBattlePanel;local UI={};local st={wild=true};local menu=battle.data.constants.gen3BattleMenu
  local pp={};local maxPP={};local mon={moves={},pp=pp,maxPp=maxPP}
  st.player={mon=mon};local B={_manifest={textboxPal=panel.spec.palette,layout='rse',assetLayout='rs'}}
  local env=setmetatable({Ui=UI,BattleChrome=B,
    battle_font=function()return panel.font end,is_double=function()return false end,
    menu_labels=function()return {menu.rows[1][1],menu.rows[1][2],menu.rows[2][1],menu.rows[2][2]}end,
    action_prompt=function()
      local who=(battle.menuBattler and battle:menuBattler())or battle.player
      return menu.prompt[1]..'\n'..menu.prompt[2]:gsub('{MON}',who and who.name or'')
    end,
    Moves={displayName=function(id)return battle.data.moves[id].name end,get=function(id)return battle.data.moves[id]end},
    Types={name=require('src.battle.TypeChart').displayName},
    RomText={plain=function(key)return key=='gText_MoveInterfacePP'and panel.spec.pp or panel.spec.switch end},
    require=function(name)
      if name=='src.ui.game3.chrome'then return panel.chrome end
      return panel.context.load(name)
    end,
  },{__index=_G})
  UI.moveTypeOf=function(_,_,def)return def.type end
  local code=excerpt(ui,'local function c5to8(x)','-- pokeemerald/src/battle_bg.c:748')
    ..excerpt(ui,'local RS_MENU_COLORS =','-- pokeemerald/src/battle_controller_player.c:1530')
    ..excerpt(ui,'local function draw_move_menu_rs(st)','-- pokeemerald/src/battle_controller_player.c:1456')
    ..'\nreturn {action=draw_action_menu_rs,moves=draw_move_menu_rs}'
  local f=assert(loadstring(code,'@pinned-gen1-rs-battle-panel'));setfenv(f,env);local draw=f()
  local frameCode=excerpt(chrome,'BattleChrome.RSE_MENU_FRAMES =','function BattleChrome.drawEnemyBox')
  local frameChunk=assert(loadstring(frameCode,'@pinned-gen1-rs-battle-frames'));setfenv(frameChunk,env);frameChunk()
  B.layout=function()return'rs'end;B.isHoenn=function()return true end
  local colors=excerpt(chrome,'local function c5to8(x)','-- pokeemerald/graphics/battle_interface/textbox_map.bin')
  local colorChunk=assert(loadstring(colors,'@pinned-gen1-rs-battle-palette'));setfenv(colorChunk,env);colorChunk()
  return function()
    local mode=battle.phase=='menu'and'action'or'moves'
    love.graphics.setColor(1,1,1,1);love.graphics.draw(panel.images[mode],0,112)
    B.drawMenuFrames(mode=='action'and'menu'or'moves')
    UI._menuIndex=battle.menuIndex;UI._moveIndex=battle.moveIndex;UI._swap=nil
    if battle.moveSwapIndex then UI._swap={cursor=battle.moveSwapIndex-1}end
    local chooser=(battle.menuBattler and battle:menuBattler())or battle.player
    for i=1,4 do
      local m=chooser.curMoves[i];mon.moves[i]=m and m.id or 0;pp[i]=m and m.pp or 0
      local def=m and battle.data.moves[m.id];maxPP[i]=def and def.pp+(m.ppUps or 0)*math.floor(def.pp/5)or 0
    end
    draw[mode](st);return true
  end
end
return M
