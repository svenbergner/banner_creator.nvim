package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local pipeline = require("banner_creator.pipeline")
local config = require("banner_creator.config")

config.persist_path = "/private/tmp/banner_creator_nvim_options_test.json"
os.remove(config.persist_path)

local commands = pipeline.commands({
  font = "standard",
  width = 90,
  mode = "kern",
  boxes = {
    enabled = true,
    design = "simple",
    align = "hlvt",
    padding = "1",
  },
})

assert(commands[1][1] == "figlet")
assert(vim.tbl_contains(commands[1], "standard"))
assert(vim.tbl_contains(commands[1], "-k"))
assert(commands[2][1] == "boxes")
assert(vim.tbl_contains(commands[2], "h1v1"))
assert(commands[3] == nil)

local executable = vim.fn.executable
vim.fn.executable = function(name)
  if name == "figlet" then
    return 0
  end
  return executable(name)
end

local checked_missing_figlet = false
require("banner_creator").render("Hi", {}, function(output, err)
  assert(output == nil)
  assert(err and err:match("figlet"))
  checked_missing_figlet = true
end)
assert(checked_missing_figlet)
vim.fn.executable = executable

config.setup()
config.persist({
  font = "standard",
  width = 120,
  termwidth = false,
  mode = "kern",
  boxes = {
    enabled = true,
    design = "simple",
    align = "hlvt",
    padding = "1",
  },
})
local persisted = config.get()
assert(persisted.font == "standard")
assert(persisted.width == 120)
assert(persisted.boxes.enabled == true)
assert(persisted.boxes.padding == "1")

config.persist({
  font = "standard",
  width = 80,
  termwidth = false,
  mode = "default",
  boxes = {
    enabled = false,
    design = "simple",
    align = "hlvt",
    padding = nil,
  },
})
persisted = config.get()
assert(persisted.width == 80)
assert(persisted.boxes.enabled == false)
assert(persisted.boxes.padding == nil)

config.persist({
  font = "standard",
  width = 132,
  termwidth = false,
  mode = "full_width",
  boxes = {
    enabled = true,
    design = "stone",
    align = "hcvt",
    padding = "2",
    size = "40x",
  },
})
config.setup()
persisted = config.get()
assert(persisted.width == 132)
assert(persisted.mode == "full_width")
assert(persisted.boxes.enabled == true)
assert(persisted.boxes.design == "stone")
assert(persisted.boxes.align == "hcvt")
assert(persisted.boxes.padding == "2")
assert(persisted.boxes.size == "40x")

config.options = vim.deepcopy(config.defaults)
config._loaded = false
persisted = config.get()
assert(persisted.width == 132)
assert(persisted.mode == "full_width")
assert(persisted.boxes.enabled == true)
assert(persisted.boxes.padding == "2")
os.remove(config.persist_path)

print("pipeline_spec ok")
