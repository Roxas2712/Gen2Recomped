-- CPU image decoder fixture: pixels are losslessly decoded from pinned PNGs.
-- Mesh uploads are validated CPU buffers. No shader/window/device is accepted as valid.
return function(root)
  local Json = require("src.link.Json")
  local f = assert(io.open(root .. "/index.json", "rb"))
  local index = assert(Json.decode(f:read("*a")))
  f:close()
  local ImageData = {}
  ImageData.__index = ImageData
  function ImageData:getDimensions()
    return self.w, self.h
  end
  function ImageData:getWidth()
    return self.w
  end
  function ImageData:getHeight()
    return self.h
  end
  function ImageData:getPixel(x, y)
    assert(
      x >= 0 and y >= 0 and x < self.w and y < self.h and x == math.floor(x) and y == math.floor(y),
      "pixel outside image"
    )
    local k = y * self.w + x
    if self.changed[k] then
      return unpack(self.changed[k])
    end
    if self.raw then
      local r, g, b, a = self.raw:byte(k * 4 + 1, k * 4 + 4)
      return r / 255, g / 255, b / 255, a / 255
    end
    return 0, 0, 0, 0
  end
  function ImageData:setPixel(x, y, r, g, b, a)
    self.changed[y * self.w + x] = { r, g, b, a or 1 }
  end
  function ImageData:mapPixel(fn, x, y, w, h)
    x, y = x or 0, y or 0
    w, h = w or self.w, h or self.h
    for py = y, y + h - 1 do
      for px = x, x + w - 1 do
        self:setPixel(px, py, fn(px, py, self:getPixel(px, py)))
      end
    end
  end
  function ImageData:paste(source, dx, dy, sx, sy, w, h)
    sx, sy = sx or 0, sy or 0
    w, h = w or source.w, h or source.h
    if source == self then
      source = source:clone()
    end
    for y = 0, h - 1 do
      for x = 0, w - 1 do
        self:setPixel(dx + x, dy + y, source:getPixel(sx + x, sy + y))
      end
    end
  end
  function ImageData:getString()
    local bytes = {}
    for y = 0, self.h - 1 do
      for x = 0, self.w - 1 do
        local r, g, b, a = self:getPixel(x, y)
        bytes[#bytes + 1] = string.char(
          math.floor(r * 255 + 0.5),
          math.floor(g * 255 + 0.5),
          math.floor(b * 255 + 0.5),
          math.floor(a * 255 + 0.5)
        )
      end
    end
    return table.concat(bytes)
  end
  function ImageData:release()
    self.released = true
  end
  function ImageData:clone()
    local c = setmetatable({ w = self.w, h = self.h, raw = self.raw, changed = {} }, ImageData)
    for k, v in pairs(self.changed) do
      c.changed[k] = { unpack(v) }
    end
    return c
  end
  local stats = { allocations = 0, vertices = 0, indices = 0 }
  local Mesh = {}
  Mesh.__index = Mesh
  function Mesh:release()
    self.released = true
  end
  function Mesh:getVertexCount()
    return self.count
  end
  function Mesh:setTexture(value)
    self.texture = value
  end
  function Mesh:getTexture()
    return self.texture
  end
  function Mesh:setDrawRange(first, count)
    self.first, self.drawCount = first, count
  end
  function Mesh:setVertexMap(indices)
    for _, i in ipairs(indices) do
      assert(type(i) == "number" and i % 1 == 0 and i >= 1 and i <= self.count, "invalid CPU mesh index")
    end
    self.indices = indices
    stats.indices = stats.indices + #indices
  end
  function Mesh:getVertexMap()
    return self.indices
  end
  function Mesh:setVertices(vertices, first)
    assert(type(vertices) == "table", "CPU fixture accepts explicit vertex tables only")
    first = first or 1
    for i, v in ipairs(vertices) do
      assert(type(v) == "table", "invalid CPU vertex")
      for _, n in ipairs(v) do
        assert(type(n) == "number" and n == n and math.abs(n) < math.huge, "nonfinite CPU vertex")
      end
      self.vertices[first + i - 1] = v
    end
  end
  love.graphics.newMesh = function(format, vertices, mode, usage)
    local n = type(vertices) == "number" and vertices or #vertices
    assert(n >= 0 and n % 1 == 0, "invalid CPU vertex count")
    local mesh = setmetatable({ count = n, vertices = {}, format = format }, Mesh)
    if type(vertices) == "table" then
      mesh:setVertices(vertices)
    end
    stats.allocations = stats.allocations + 1
    stats.vertices = stats.vertices + n
    return mesh
  end
  local oldImage = love.graphics.newImage
  love.filesystem.newFileData = function(bytes, name)
    return {
      bytes = bytes,
      filename = name,
      getString = function(self)
        return self.bytes
      end,
      getFilename = function(self)
        return self.filename
      end,
      release = function(self)
        self.released = true
      end,
    }
  end
  love.image = love.image or {}
  love.image.newImageData = function(path, h)
    if type(path) == "number" then
      return setmetatable({ w = path, h = h, changed = {} }, ImageData)
    end
    if type(path) == "table" and path.getFilename then
      path = path:getFilename()
    end
    local spec = assert(index[path], "pixel fixture unavailable: " .. tostring(path))
    local file = assert(io.open(root .. "/" .. spec.file, "rb"))
    local raw = file:read("*a")
    file:close()
    assert(#raw == spec.width * spec.height * 4, "invalid RGBA fixture")
    return setmetatable({ w = spec.width, h = spec.height, raw = raw, changed = {}, path = path }, ImageData)
  end
  love.graphics.newImage = function(value, ...)
    if type(value) == "table" and value.getDimensions then
      local w, h = value:getDimensions()
      local image = love.graphics.newCanvas(w, h)
      image.path = value.path
      return image
    end
    local image = oldImage(value, ...)
    if type(image) == "table" then
      image.setFilter = image.setFilter or function() end
      image.setMipmapFilter = image.setMipmapFilter or function() end
      image.release = image.release or function(self)
        self.released = true
      end
    end
    return image
  end
  return stats
end
