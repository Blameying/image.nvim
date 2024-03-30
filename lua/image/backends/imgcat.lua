local utils = require("image/utils")

---@type Backend
---@diagnostic disable-next-line: missing-fields
local backend = {
  ---@diagnostic disable-next-line: assign-type-mismatch
  state = nil,
  features = {
    crop = false,
  },
}

backend.setup = function(state)
  backend.state = state
end

backend.render = function(image, x, y, width, height)
  local command = string.format('imgcat -s -r -W %u%% -H %u%% -f %s', width, height, image.path)
  os.execute(command)
  image.is_rendered = true
  backend.state.images[image.id] = image
end

backend.clear = function(image_id, shallow)
  -- iTerm2's imgcat doesn't support clearing individual images
  -- We'll clear all images by moving the cursor to the next line
  os.execute('printf "\\n"')

  if image_id then
    local image = backend.state.images[image_id]
    if not image then return end
    image.is_rendered = false
    if not shallow then backend.state.images[image_id] = nil end
  else
    for id, image in pairs(backend.state.images) do
      image.is_rendered = false
      if not shallow then backend.state.images[id] = nil end
    end
  end
end

return backend
