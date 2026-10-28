-- Extraction baseline only. Interactive shop acceptance is a separate driver.
return function(game)
  local out=assert(os.getenv('EDITION_QA_OUT'));local edition=require('src.core.GameVersion').get()
  assert(require('src.import.RomImporter').readyReport(edition).ok)
  assert(#require('src.import.Gen3RsShopAssets').missing(edition)==0)
  local spec=assert(game.data.constants.gen3RsShop);assert(spec.version==edition and #spec.resources==8)
  local f=assert(love.filesystem.load('data/generated/gba/items/shop/manifest.lua'));setfenv(f,{});local man=f()
  assert(man.game==edition and man.assetLayout=='rs'and man.shopVersion==2)
  local bg=assert(love.filesystem.read('data/generated/gba/items/shop/bg.rgba'));assert(#bg==240*160*4)
  assert(#assert(love.filesystem.read('data/generated/gba/items/shop/money_label.rgba'))==32*16*4)
  assert(man.geometry.iconPane==false and man.geometry.ownedQuantityLabel==false)
  local report={status='pass',edition=edition,shopAssetsExtracted=true,interactiveShopAccepted=false,
    resources=spec.resources,manifest=man,fullGameAcceptance=false}
  local target=assert(io.open(out..'/result.json','w'));target:write(require('src.link.Json').encode(report));target:close()
  love.event.quit(0)
end
