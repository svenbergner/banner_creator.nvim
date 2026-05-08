local config = require("banner_creator.config")
local discovery = require("banner_creator.discovery")
local pipeline = require("banner_creator.pipeline")
local picker = require("banner_creator.picker")

local M = {}

function M.setup(opts)
  config.setup(opts)
end

function M.render(text, opts, cb)
  local err = discovery.figlet_error()
  if err then
    cb(nil, err)
    return
  end
  pipeline.render(text, config.get(opts), cb)
end

function M.open(opts)
  opts = opts or {}
  local err = discovery.figlet_error()
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end

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
