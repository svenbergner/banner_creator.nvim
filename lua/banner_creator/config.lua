local M = {}

M.defaults = {
  font = nil,
  width = 80,
  termwidth = false,
  mode = "default",
  boxes = {
    enabled = false,
    design = "simple",
    align = "hlvt",
    padding = nil,
    size = nil,
  },
  picker = {
    layout = nil,
  },
}

M.options = vim.deepcopy(M.defaults)
M.persist_path = vim.fn.stdpath("state") .. "/banner_creator.nvim/options.json"
M._loaded = false

local function persisted_options(opts)
  opts = opts or {}
  return {
    font = opts.font,
    width = opts.width,
    termwidth = opts.termwidth,
    mode = opts.mode,
    boxes = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults.boxes), opts.boxes or {}),
  }
end

local function read_persisted()
  local path = M.persist_path
  if not path or vim.fn.filereadable(path) ~= 1 then
    return {}
  end

  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return {}
  end

  local decoded_ok, decoded = pcall(vim.json.decode, table.concat(lines, "\n"))
  if not decoded_ok or type(decoded) ~= "table" then
    return {}
  end

  return persisted_options(decoded)
end

local function write_persisted(opts)
  local path = M.persist_path
  if not path or path == "" then
    return
  end

  local dir = vim.fn.fnamemodify(path, ":h")
  if vim.fn.isdirectory(dir) == 0 then
    vim.fn.mkdir(dir, "p")
  end

  local ok, encoded = pcall(vim.json.encode, persisted_options(opts))
  if ok then
    pcall(vim.fn.writefile, { encoded }, path)
  end
end

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {}, read_persisted())
  M._loaded = true
end

function M.get(opts)
  if not M._loaded then
    M.setup()
  end
  return vim.tbl_deep_extend("force", vim.deepcopy(M.options), opts or {})
end

function M.persist(opts)
  if not M._loaded then
    M.setup()
  end
  local persisted = persisted_options(opts)
  M.options.font = persisted.font
  M.options.width = persisted.width
  M.options.termwidth = persisted.termwidth
  M.options.mode = persisted.mode
  M.options.boxes = persisted.boxes
  write_persisted(M.options)
end

return M
