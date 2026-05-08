local discovery = require("banner_creator.discovery")

local M = {}

local function start(name)
  if vim.health and vim.health.start then
    vim.health.start(name)
  else
    vim.health.report_start(name)
  end
end

local function ok(msg)
  if vim.health and vim.health.ok then
    vim.health.ok(msg)
  else
    vim.health.report_ok(msg)
  end
end

local function warn(msg)
  if vim.health and vim.health.warn then
    vim.health.warn(msg)
  else
    vim.health.report_warn(msg)
  end
end

function M.check()
  start("banner_creator.nvim")

  local has_snacks = pcall(require, "snacks")
  if has_snacks or _G.Snacks then
    ok("snacks.nvim is available")
  else
    warn("snacks.nvim is required for the picker UI")
  end

  for _, exe in ipairs({ "figlet", "toilet", "boxes", "lolcat" }) do
    if discovery.executable(exe) then
      ok(exe .. " is executable")
    else
      warn(exe .. " is not executable")
    end
  end
end

return M
