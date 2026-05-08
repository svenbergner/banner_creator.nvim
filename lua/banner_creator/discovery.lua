local M = {}

local cache = {}

local function trim(value)
  return (value or ""):gsub("^%s+", ""):gsub("%s+$", "")
end

local function system_sync(cmd)
  local result = vim.system(cmd, { text = true }):wait()
  return result.code == 0, result.stdout or "", result.stderr or ""
end

function M.executable(name)
  return vim.fn.executable(name) == 1
end

function M.figlet_error()
  if M.executable("figlet") then
    return nil
  end
  return "banner_creator.nvim requires figlet, but the `figlet` executable was not found in $PATH"
end

function M.font_dir()
  local key = "font_dir"
  if cache[key] ~= nil then
    return cache[key]
  end

  if not M.executable("figlet") then
    cache[key] = nil
    return nil
  end

  local ok, stdout = system_sync({ "figlet", "-I2" })
  cache[key] = ok and trim(stdout) or nil
  return cache[key]
end

function M.fonts()
  if cache.fonts then
    return cache.fonts
  end

  local dir = M.font_dir()
  local fonts = {}
  if dir and vim.uv.fs_stat(dir) then
    for name, kind in vim.fs.dir(dir) do
      if kind == "file" and (name:match("%.flf$") or name:match("%.tlf$")) then
        fonts[#fonts + 1] = name:gsub("%.flf$", ""):gsub("%.tlf$", "")
      end
    end
  end
  table.sort(fonts)
  cache.fonts = fonts
  return cache.fonts
end

function M.box_designs()
  if cache.box_designs then
    return cache.box_designs
  end

  local designs = {}
  if M.executable("boxes") then
    local ok, stdout = system_sync({ "boxes", "-l" })
    if ok then
      for line in stdout:gmatch("[^\r\n]+") do
        local name = line:match("^([%w][%w_%-]*)%s+alias")
          or line:match("^([%w][%w_%-]*)%s*$")
        if name and not name:match("^%d+$") then
          designs[#designs + 1] = name
        end
      end
    end
  end
  table.sort(designs)
  cache.box_designs = designs
  return designs
end

function M.clear_cache()
  cache = {}
end

return M
