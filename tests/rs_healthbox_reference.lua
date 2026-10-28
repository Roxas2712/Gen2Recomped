-- Full-render comparison against the exact pinned Gen1Recomp RS compositor.
local M={}
function M.new(game,battle)
  local Assets=require('src.render.Assets')
  local spec=assert(game.data.constants.gen3RsHealthbox)
  local hud=assert(game.data.constants.gen3BattleHud)
  local g=love.graphics;local quads={}
  local function element(n,x,y,hb)
    if not quads[n]then quads[n]=g.newQuad(n%40*8,math.floor(n/40)*8,8,8,320,24)end
    g.setColor(1,1,1,1);g.draw(Assets.image(hb and spec.elementsExp or spec.elements),quads[n],x,y)
  end
  local function pixels(hp,max,width)
    if max<=0 or hp<=0 then return 0 end
    return math.max(1,math.floor(math.min(hp,max)*width/max))
  end
  local Chrome={}
  function Chrome.manifest()return{healthboxPal=spec.palette}end
  function Chrome.drawPlayerBox(x,y)g.setColor(1,1,1,1);g.draw(Assets.image(hud.images.player),x,y)end
  function Chrome.drawEnemyBox(x,y)g.setColor(1,1,1,1);g.draw(Assets.image(hud.images.opponent),x,y)end
  Chrome.drawElementTile=element
  function Chrome.drawHpBar(x,y,hp,max,status)
    local fill=pixels(hp,max,48)
    local base=fill>24 and 3 or fill>9 and 47 or 56
    if status then element(65,x+8,y)else element(1,x,y);element(2,x+8,y)end
    for i=0,5 do element(base+math.max(0,math.min(8,fill-i*8)),x+16+i*8,y)end
  end
  function Chrome.drawExpBar(x,y,ratio)
    local fill=math.floor(math.max(0,math.min(1,ratio))*64)
    for i=0,7 do element(12+math.max(0,math.min(8,fill-i*8)),x+i*8,y,true)end
  end
  local names={'PSN','PAR','SLP','FRZ','BRN'}
  function Chrome.drawRsStatusIcon(id,status,x,y)
    local path=spec.status[id+1][names[status]]
    if path then g.setColor(1,1,1,1);g.draw(Assets.image(path),x,y)end
  end
  local function host(side)
    if type(side)=='number'then return battle:battlerAt(side)end
    return side=='player'and battle.player or battle.enemy
  end
  local Anim={stage=function()return{}end}
  function Anim.present(side)
    local b=host(side);return{displayStatus=b.shownStatus or false,displayLevel=b.mon.level}
  end
  function Anim.displayHpRatio(side)
    local b=host(side);return b.shownHP/b.mon.stats.hp,b.shownHP,b.mon.stats.hp
  end
  function Anim.displayExpRatio()return battle:expFraction()end
  local compact=battle:isDouble()
  local centres={[0]={x=159,y=77},[1]={x=44,y=19},[2]={x=171,y=102},[3]={x=32,y=44}}
  local st={trainer=true,double=compact}
  function Chrome.drawDoublesBox(player,x,y)
    g.setColor(1,1,1,1);g.draw(Assets.image(player and hud.images.playerDoubles or hud.images.opponentDoubles),x,y)
  end
  local bindings={__package={loaded={['src.core.game3.battle']={_st=st}}},
    ['src.ui.game3.battle_chrome']=Chrome,
    ['src.ui.game3.frlg_font']=battle.rsBattlePanel.font,
    ['src.core.game3.battle.state']={displayName=function(b)return b.name end},
    ['src.core.game3.rom_text']={has=function()return false end},
    ['src.mods.Runtime']={wantsHook=function()return false end},
    ['src.core.game3.battle.mod_registries']={},
    ['src.ui.LevelDisplay']=require('src.ui.LevelDisplay'),
    ['src.core.game3.profile']={forSession=function()return{ui={healthbox={layout='rs',doublesCenters=centres}}}end},
    ['src.core.game3.battle.anim']=Anim,
    ['src.ui.game3.summary_chrome']={},
    ['src.core.game3.summary_data']={statusAilment=function(mon)
      for i,key in ipairs(names)do if mon.status==key then return i end end;return 0 end},
  }
  local loadReference=require('compat.gen1-rs.Loader').new(require('src.core.GameVersion').get(),bindings)
  local reference=loadReference('src.core.game3.battle.healthbox')
  local function view(b)
    local gender=require('src.pokemon.DayCare').gender(game.data,b.mon)
    return{name=b.name,mon={species=game.data.pokemon[b.mon.species].index,
      name=game.data.pokemon[b.mon.species].name,nickname=b.mon.nickname,level=b.mon.level,
      gender=gender=='male'and'M'or gender=='female'and'F'or'U',hp=b.mon.hp,maxHp=b.mon.stats.hp,status=b.shownStatus}}
  end
  local function read(path)
    local f=assert(io.open(path,'rb'));local raw=f:read('*a');f:close()
    return love.image.newImageData(love.filesystem.newFileData(raw,'capture.png'))
  end
  function M.compare(out,name,shot)
    local actual=name..'-host';shot(actual)
    local H=require('src.core.game3.battle.healthbox');local previous=H._nativeDraw
    H._nativeDraw=function(_,b,_,_,player)
      return reference.draw(compact and b.position or(player and'player'or'enemy'),view(b),{st=st})
    end
    local ok,why=pcall(shot,name..'-reference');H._nativeDraw=previous
    if not ok then error(why,0)end
    local a,b=read(out..'/'..actual..'.png'),read(out..'/'..name..'-reference.png')
    local p=assert(game.renderer.uiPresentation)
    local ww,wh=g.getDimensions();local dx,dy=a:getWidth()/ww,a:getHeight()/wh
    local count,diffs,examples=0,0,{}
    local rectangles={{path=hud.images.opponent,x=12,y=14},{path=hud.images.player,x=126,y=72}}
    if compact then
      rectangles={}
      for id=0,3 do rectangles[#rectangles+1]={path=id%2==0 and hud.images.playerDoubles or hud.images.opponentDoubles,
        x=centres[id].x-32,y=centres[id].y-16}end
    end
    for _,r in ipairs(rectangles)do
      local image=Assets.image(r.path);local data=image:newImageData()
      for y=0,image:getHeight()-1 do for x=0,image:getWidth()-1 do
        local _,_,_,alpha=data:getPixel(x,y)
        if alpha>0 then
          local sx=math.floor((p.x+(r.x+x+.5)*p.scaleX)*dx)
          local sy=math.floor((p.y+(r.y+y+.5)*p.scaleY)*dy)
          local ar,ag,ab,aa=a:getPixel(sx,sy);local br,bg,bb,ba=b:getPixel(sx,sy)
          count=count+1
          if math.abs(ar-br)>1/255 or math.abs(ag-bg)>1/255 or math.abs(ab-bb)>1/255 or math.abs(aa-ba)>1/255 then
            diffs=diffs+1;if #examples<5 then examples[#examples+1]={x=r.x+x,y=r.y+y}end
          end
        end
      end end
      data:release()
    end
    a:release();b:release()
    return {pixels=count,differences=diffs,examples=examples,
      viewport={x=p.x,y=p.y,scaleX=p.scaleX,scaleY=p.scaleY,dpiX=dx,dpiY=dy}}
  end
  return M
end
return M
