local M = {}

M.defaults = {
  renderer = "figlet",
  font = nil,
  toilet_filter = nil,
  width = 80,
  termwidth = false,
  mode = "default",
  boxes = {
    enabled = false,
    design = "simple",
    align = "hlvt",
    padding = nil,
    size = nil,
    color = nil,
  },
  lolcat = {
    enabled = false,
    ansi = false,
    spread = nil,
    freq = nil,
    seed = nil,
    animate = false,
    duration = nil,
    speed = nil,
    invert = false,
    truecolor = false,
    force = false,
  },
  picker = {
    layout = nil,
  },
}

M.options = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.options = vim.tbl_deep_extend("force", vim.deepcopy(M.defaults), opts or {})
end

function M.get(opts)
  return vim.tbl_deep_extend("force", vim.deepcopy(M.options), opts or {})
end

return M
