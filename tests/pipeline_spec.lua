package.path = "./lua/?.lua;./lua/?/init.lua;" .. package.path

local pipeline = require("banner_creator.pipeline")

local commands = pipeline.commands({
  renderer = "figlet",
  font = "standard",
  width = 90,
  mode = "kern",
  boxes = {
    enabled = true,
    design = "simple",
    align = "hlvt",
  },
  lolcat = {
    enabled = true,
    spread = 3,
    ansi = false,
  },
})

assert(commands[1][1] == "figlet")
assert(vim.tbl_contains(commands[1], "standard"))
assert(vim.tbl_contains(commands[1], "-k"))
assert(commands[2][1] == "boxes")
assert(commands[3][1] == "lolcat")

assert(pipeline.strip_ansi("\27[31mred\27[0m") == "red")

local toilet = pipeline.commands({
  renderer = "toilet",
  toilet_filter = "crop",
  boxes = { enabled = false },
  lolcat = { enabled = false },
})
assert(vim.tbl_contains(toilet[1], "-F"))
assert(vim.tbl_contains(toilet[1], "crop"))

print("pipeline_spec ok")
