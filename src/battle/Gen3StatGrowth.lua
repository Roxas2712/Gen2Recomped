-- Native two-page stat window. Exact compositor: retained Gen1Recomp source.
local M={}
local function stats(v)
  return{maxHp=v.hp,atk=v.attack,def=v.defense,spa=v.spatk,spd=v.spdef,spe=v.speed}
end
function M.new(game,mon,change)
  local version=require('src.core.GameVersion').get()
  local spec=game.data.constants and game.data.constants.gen3StatGrowth
  if not require('src.import.Gen3StatGrowthAssets').valid(spec,version)then return end
  local self={game=game,spec=spec}
  local font=require('src.ui.game3.frlg_font')
  local window=require('src.ui.game3.window')
  local ui={}
  if spec.layout=='rs'then
    for _,screen in ipairs(game.stack.states or{})do
      if screen.rsBattlePanel then self.context=screen.rsBattlePanel.context;break end
    end
    if not self.context then self.context=require('src.ui.Gen3RsSceneContext').new(game);self.ownsContext=true end
    font=self.context.load('src.ui.game3.frlg_font')
    local chrome=self.context.load('src.ui.game3.chrome')
    window={template=window.template,stdFrame=function(t)chrome.stdFrame(t.left,t.top,t.width,t.height)end}
    ui.levelUpBox={layout='rs',x=12,y=1,w=17,h=6,names='native_stats',stats={'maxHp','spa','atk','spd','def','spe'}}
  elseif spec.layout=='emerald'then
    ui.levelUpBox={x=19,y=8,w=10,h=11,pitch=15}
    ui.party={text={levelUpStats={'stat1','stat2','stat3','stat4','stat5','stat6'}}}
  end
  local function text(key)
    local index=tonumber(tostring(key):match('^stat(%d)$'))
    return index and spec.labels[index]or key=='BattleText_Dash'and'-'or key=='BattleText_Plus'and'+'or''
  end
  local bindings={['src.ui.game3.window']=window,['src.ui.game3.frlg_font']=font,
    ['src.core.game3.rom_text']={plain=text,at=function(_,i)return spec.labels[i+1]end},
    ['src.core.game3.profile']={forSession=function()return{ui=ui}end},
    ['src.core.game3.audio']={playSe=function()require('src.core.Sound').play(game.data,'Press_AB')end},
    ['src.core.game3.se_ids']={SE_SELECT=5}}
  self.scene=require('compat.gen1-rs.Loader').new('emerald',bindings)('src.ui.game3.stat_growth')
  self.scene.open({},stats(change and change.old or mon.stats),stats(change and change.new or mon.stats),nil,{pos=spec.box})
  return self
end
function M.advance(self)
  self.scene.handleInput(self.game.input)
  if self.scene.isOpen()then return false end
  if self.ownsContext and self.context.canvas then self.context.canvas:release();self.context.canvas=nil end
  return true
end
function M.draw(self)
  local ok,why=require('src.render.GraphicsScope').call(self.scene.draw)
  if not ok then error(why,0)end
end
return M
