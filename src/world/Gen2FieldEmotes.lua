-- Authored Gen2 bubbles use the native field owner. Contributions by Roxas2712.
local E = {}
E.ORDER = { 'shock', 'question', 'happy', 'sad', 'heart', 'bolt', 'sleep', 'fish' }
function E.kind(data, index)
  local authored = data and data.field and data.field.emotes
  return ((authored and authored.order) or E.ORDER)[(tonumber(index) or 0)+1] or 'shock'
end
function E.path(data, kind)
  local field = data and data.field and data.field.emotes
  local legacy = data and data.gen2MenuGfx and data.gen2MenuGfx.emotes
  return field and field[kind] or legacy and legacy[kind]
end
function E.draw(data, cache, kind, x, y)
  local path = E.path(data, kind)
  if type(path) ~= 'string' then return false end
  cache.gen2EmoteImages = cache.gen2EmoteImages or {}
  local image = cache.gen2EmoteImages[path]
  if image == nil then
    local ok, result = pcall(require('src.render.Assets').image, path)
    image = ok and result or false
    cache.gen2EmoteImages[path] = image
  end
  if not image then return false end
  love.graphics.setColor(1, 1, 1, 1)
  love.graphics.draw(image, x, y)
  return true
end
return E
