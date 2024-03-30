local util = require("image.utils.logger")

local cached_size = {
  screen_x = 0,
  screen_y = 0,
  screen_cols = 0,
  screen_rows = 0,
  cell_width = 0,
  cell_height = 0,
}

-- https://github.com/edluffy/hologram.nvim/blob/main/lua/hologram/state.lua#L15
local update_size = function()
  local ffi = require("ffi")
  ffi.cdef([[
    typedef struct {
      unsigned short row;
      unsigned short col;
      unsigned short xpixel;
      unsigned short ypixel;
    } winsize;
    int ioctl(int, int, ...);
  ]])

  local TIOCGWINSZ = nil
  if vim.fn.has("linux") == 1 then
    TIOCGWINSZ = 0x5413
  elseif vim.fn.has("mac") == 1 then
    TIOCGWINSZ = 0x40087468
  elseif vim.fn.has("bsd") == 1 then
    TIOCGWINSZ = 0x40087468
  end

  ---@type { row: number, col: number, xpixel: number, ypixel: number }
  local sz = ffi.new("winsize")
  assert(ffi.C.ioctl(1, TIOCGWINSZ, sz) == 0, "Failed to get terminal size")

  cached_size = {
    screen_x = sz.xpixel,
    screen_y = sz.ypixel,
    screen_cols = sz.col,
    screen_rows = sz.row,
    cell_width = sz.xpixel / sz.col,
    cell_height = sz.ypixel / sz.row,
  }
end

local update_size_remote = function()
  os.execute("stty -g > ~/.tty_config")
  os.execute("stty raw")
  local input = io.open("/dev/stdin", "r")
  local output = io.open("/dev/stdout", "w")
  if input == nil or output == nil then
    util.log("Failed to open /dev/stdin or /dev/stdout")
    return
  end

  output:write("\27[14t")
  output:flush()
  local response = ""
  while true do
    local chunk = input:read(1)
    if chunk == nil then
      break
    end

    response = response .. chunk

    if chunk == "t" then
      break
    end
  end

  local _, _, height, width = string.find(response, "\27%[4;(%d+);(%d+)t")

  output:write("\27[18t")
  output:flush()
  local col_row = ""

  while true do
    local chunk = input:read(1)
    if chunk == nil then
      break
    end

    col_row = col_row .. chunk

    if chunk == "t" then
      break
    end
  end
  output:close()
  input:close()
  os.execute("stty \"$(cat ~/.tty_config)\"")
  local _, _, row, col = string.find(col_row, "\27%[8;(%d+);(%d+)t")
  util.log(row, col)

  cached_size = {
    screen_x = tonumber(width),
    screen_y = tonumber(height),
    screen_cols = tonumber(col),
    screen_rows = tonumber(row),
    cell_width = tonumber(width) / tonumber(col),
    cell_height = tonumber(height) / tonumber(row),
  }
end


update_size_remote()
vim.api.nvim_create_autocmd("VimResized", {
  callback = update_size_remote,
})

local get_tty = function()
  local handle = io.popen("tty 2>/dev/null")
  if not handle then return nil end
  local result = handle:read("*a")
  handle:close()
  result = vim.fn.trim(result)
  if result == "" then return nil end
  return result
end

return {
  get_size = function()
    return cached_size
  end,
  get_tty = get_tty,
}
