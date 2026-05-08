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

function M.font_dir(renderer)
  local key = "font_dir:" .. renderer
  if cache[key] ~= nil then
    return cache[key]
  end

  if not M.executable(renderer) then
    cache[key] = nil
    return nil
  end

  local ok, stdout = system_sync({ renderer, "-I2" })
  cache[key] = ok and trim(stdout) or nil
  return cache[key]
end

function M.fonts(renderer)
  local key = "fonts:" .. renderer
  if cache[key] then
    return cache[key]
  end

  local dir = M.font_dir(renderer)
  local fonts = {}
  if dir and vim.uv.fs_stat(dir) then
    for name, kind in vim.fs.dir(dir) do
      if kind == "file" and (name:match("%.flf$") or name:match("%.tlf$")) then
        fonts[#fonts + 1] = name:gsub("%.flf$", ""):gsub("%.tlf$", "")
      end
    end
  end
  table.sort(fonts)
  cache[key] = fonts
  return fonts
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

function M.toilet_filters()
  if cache.toilet_filters then
    return cache.toilet_filters
  end

  local filters = {}
  if M.executable("toilet") then
    local ok, stdout = system_sync({ "toilet", "-F", "list" })
    if ok then
      for line in stdout:gmatch("[^\r\n]+") do
        local filter = line:match('^"([^"]+)"')
        if filter then
          filters[#filters + 1] = filter
        end
      end
    end
  end
  table.sort(filters)
  cache.toilet_filters = filters
  return filters
end

function M.clear_cache()
  cache = {}
end

return M
