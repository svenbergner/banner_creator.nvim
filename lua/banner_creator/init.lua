local config = require("banner_creator.config")
local pipeline = require("banner_creator.pipeline")
local picker = require("banner_creator.picker")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.render(text, opts, cb)
  pipeline.render(text, config.get(opts), cb)
end

function M.open(opts)
  opts = opts or {}
  if opts.text and opts.text ~= "" then
    picker.open(opts)
    return
  end

  vim.ui.input({ prompt = "Banner text: " }, function(text)
    if text and text ~= "" then
      opts.text = text
      picker.open(opts)
    end
  end)
end

return M
