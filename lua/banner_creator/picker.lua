local config = require("banner_creator.config")
local discovery = require("banner_creator.discovery")
local pipeline = require("banner_creator.pipeline")

local M = {}

local MODES = {
  "default",
  "smush",
  "force_smush",
  "kern",
  "full_width",
  "overlap",
}

local ALIGNMENTS = {
  "hlvt",
  "hcvt",
  "hrvt",
  "jlvt",
  "jcvt",
  "jrvt",
}

local function bool_label(value)
  return value and "on" or "off"
end

local function value_label(value)
  if value == nil or value == "" then
    return "-"
  end
  return tostring(value)
end

local function select_value(title, values, current, cb)
  vim.ui.select(values, {
    prompt = title,
    format_item = function(item)
      return item == current and (tostring(item) .. " *") or tostring(item)
    end,
  }, function(choice)
    if choice ~= nil then
      cb(choice)
    end
  end)
end

local function input_value(title, current, cb)
  vim.ui.input({ prompt = title .. ": ", default = current and tostring(current) or "" }, function(value)
    if value ~= nil then
      cb(value ~= "" and value or nil)
    end
  end)
end

local function rows(state)
  local opts = state.opts
  local box = opts.boxes
  local lolcat = opts.lolcat
  return {
    { key = "renderer", text = "Renderer: " .. opts.renderer },
    { key = "font", text = "Font: " .. value_label(opts.font) },
    { key = "toilet_filter", text = "Toilet filter: " .. value_label(opts.toilet_filter) },
    { key = "width", text = "Width: " .. (opts.termwidth and "terminal" or value_label(opts.width)) },
    { key = "mode", text = "Render mode: " .. opts.mode },
    { key = "boxes_enabled", text = "Boxes: " .. bool_label(box.enabled) },
    { key = "boxes_design", text = "Box design: " .. value_label(box.design) },
    { key = "boxes_align", text = "Box align: " .. value_label(box.align) },
    { key = "boxes_padding", text = "Box padding: " .. value_label(box.padding) },
    { key = "boxes_size", text = "Box size: " .. value_label(box.size) },
    { key = "boxes_color", text = "Box color: " .. value_label(box.color) },
    { key = "lolcat_enabled", text = "Lolcat: " .. bool_label(lolcat.enabled) },
    { key = "lolcat_ansi", text = "Insert ANSI: " .. bool_label(lolcat.ansi) },
    { key = "lolcat_spread", text = "Lolcat spread: " .. value_label(lolcat.spread) },
    { key = "lolcat_freq", text = "Lolcat frequency: " .. value_label(lolcat.freq) },
    { key = "lolcat_seed", text = "Lolcat seed: " .. value_label(lolcat.seed) },
    { key = "lolcat_animate", text = "Lolcat animate: " .. bool_label(lolcat.animate) },
    { key = "lolcat_duration", text = "Lolcat duration: " .. value_label(lolcat.duration) },
    { key = "lolcat_speed", text = "Lolcat speed: " .. value_label(lolcat.speed) },
    { key = "lolcat_invert", text = "Lolcat invert: " .. bool_label(lolcat.invert) },
    { key = "lolcat_truecolor", text = "Lolcat truecolor: " .. bool_label(lolcat.truecolor) },
    { key = "lolcat_force", text = "Lolcat force: " .. bool_label(lolcat.force) },
  }
end

local function refresh_items(picker, state)
  picker:find({ refresh = true })
  picker:show_preview()
end

local function edit_option(picker, item, state)
  local opts = state.opts
  local box = opts.boxes
  local lolcat = opts.lolcat
  local key = item and item.key
  if not key then
    return
  end

  local function changed()
    refresh_items(picker, state)
  end

  if key == "renderer" then
    select_value("Renderer", { "figlet", "toilet" }, opts.renderer, function(choice)
      opts.renderer = choice
      opts.font = nil
      changed()
    end)
  elseif key == "font" then
    local fonts = discovery.fonts(opts.renderer)
    select_value("Font", fonts, opts.font, function(choice)
      opts.font = choice
      changed()
    end)
  elseif key == "toilet_filter" then
    local filters = { "-" }
    vim.list_extend(filters, discovery.toilet_filters())
    select_value("Toilet filter", filters, opts.toilet_filter or "-", function(choice)
      opts.toilet_filter = choice ~= "-" and choice or nil
      changed()
    end)
  elseif key == "width" then
    input_value("Width or 'term'", opts.termwidth and "term" or opts.width, function(value)
      opts.termwidth = value == "term"
      opts.width = opts.termwidth and opts.width or tonumber(value)
      changed()
    end)
  elseif key == "mode" then
    select_value("Render mode", MODES, opts.mode, function(choice)
      opts.mode = choice
      changed()
    end)
  elseif key == "boxes_enabled" then
    box.enabled = not box.enabled
    changed()
  elseif key == "boxes_design" then
    select_value("Box design", discovery.box_designs(), box.design, function(choice)
      box.design = choice
      changed()
    end)
  elseif key == "boxes_align" then
    select_value("Box align", ALIGNMENTS, box.align, function(choice)
      box.align = choice
      changed()
    end)
  elseif key == "boxes_padding" then
    input_value("Box padding", box.padding, function(value)
      box.padding = value
      changed()
    end)
  elseif key == "boxes_size" then
    input_value("Box size", box.size, function(value)
      box.size = value
      changed()
    end)
  elseif key == "boxes_color" then
    select_value("Box color", { "-", "true", "false" }, box.color == nil and "-" or tostring(box.color), function(choice)
      box.color = choice == "-" and nil or choice == "true"
      changed()
    end)
  elseif key == "lolcat_enabled" then
    lolcat.enabled = not lolcat.enabled
    changed()
  elseif key == "lolcat_ansi" then
    lolcat.ansi = not lolcat.ansi
    changed()
  elseif key:match("^lolcat_") then
    local name = key:gsub("^lolcat_", "")
    if type(lolcat[name]) == "boolean" then
      lolcat[name] = not lolcat[name]
      changed()
    else
      input_value("Lolcat " .. name, lolcat[name], function(value)
        lolcat[name] = value
        changed()
      end)
    end
  end
end

local function insert_text(text)
  local lines = vim.split((text or ""):gsub("\n$", ""), "\n", { plain = true })
  vim.api.nvim_put(lines, "l", true, true)
end

function M.open(opts)
  opts = opts or {}
  local state = {
    text = opts.text or "",
    opts = config.get(opts.options),
    preview_token = 0,
    last_output = nil,
    last_error = nil,
  }

  local ok, snacks = pcall(require, "snacks")
  local Snacks = ok and snacks or _G.Snacks
  if not Snacks or not Snacks.picker then
    vim.notify("banner_creator.nvim requires folke/snacks.nvim picker", vim.log.levels.ERROR)
    return
  end

  Snacks.picker.pick({
    title = "Banner Creator",
    prompt = "Option ",
    finder = function()
      return rows(state)
    end,
    layout = state.opts.picker and state.opts.picker.layout or nil,
    format = "text",
    preview = function(ctx)
      state.preview_token = state.preview_token + 1
      local token = state.preview_token
      ctx.preview:reset()
      ctx.preview:minimal()
      ctx.preview:set_title("Preview")
      ctx.preview:set_lines({ "Rendering..." })
      pipeline.render(state.text, state.opts, function(output, err)
        if token ~= state.preview_token or not vim.api.nvim_buf_is_valid(ctx.buf) then
          return
        end
        state.last_output = output
        state.last_error = err
        if err then
          ctx.preview:set_lines(vim.split(err, "\n", { plain = true }))
        else
          ctx.preview:set_lines(vim.split(output or "", "\n", { plain = true }))
        end
      end)
    end,
    actions = {
      edit_option = function(picker, item)
        edit_option(picker, item or picker:current(), state)
      end,
    },
    confirm = function(picker)
      pipeline.render(state.text, state.opts, function(output, err)
        if err then
          vim.notify(err, vim.log.levels.ERROR)
          return
        end
        picker:close()
        insert_text(output)
      end)
    end,
    win = {
      input = {
        keys = {
          ["<Space>"] = { "edit_option", mode = { "n", "i" } },
        },
      },
      list = {
        keys = {
          ["<Space>"] = "edit_option",
        },
      },
    },
  })
end

return M
