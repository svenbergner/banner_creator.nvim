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

local function preview_valid(ctx)
  return ctx
    and ctx.preview
    and type(ctx.buf) == "number"
    and vim.api.nvim_buf_is_valid(ctx.buf)
end

local function set_preview_lines(ctx, lines)
  if preview_valid(ctx) then
    pcall(ctx.preview.set_lines, ctx.preview, lines)
  end
end

local function preview_display_line_count(ctx, lines)
  if not (ctx and type(ctx.win) == "number" and vim.api.nvim_win_is_valid(ctx.win)) then
    return #lines
  end

  local width = math.max(1, vim.api.nvim_win_get_width(ctx.win))
  local count = 0
  for _, line in ipairs(lines) do
    local display_width = vim.fn.strdisplaywidth(line)
    count = count + math.max(1, math.ceil(display_width / width))
  end
  return count
end

local function projected_preview_width()
  local available_width = math.max(1, vim.o.columns - 4)
  local picker_width = math.floor(available_width * 0.8)
  local preview_width = math.floor(picker_width * 0.55)
  return math.max(1, preview_width - 2)
end

local function picker_preview_width(picker)
  local win = picker
    and picker.preview
    and picker.preview.win
    and picker.preview.win.win
  if type(win) == "number" and vim.api.nvim_win_is_valid(win) then
    return math.max(1, vim.api.nvim_win_get_width(win))
  end
  return projected_preview_width()
end

local function display_line_count_for_width(lines, width)
  local count = 0
  width = math.max(1, width)
  for _, line in ipairs(lines) do
    local display_width = vim.fn.strdisplaywidth(line)
    count = count + math.max(1, math.ceil(display_width / width))
  end
  return count
end

local function select_value(title, values, current, cb)
  if #values == 0 then
    vim.notify("No values available for " .. title, vim.log.levels.WARN)
    return
  end

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

local function select_preview_value(title, values, current, state, apply_preview, cb, opts)
  opts = opts or {}
  if #values == 0 then
    vim.notify("No values available for " .. title, vim.log.levels.WARN)
    return
  end

  local ok, snacks = pcall(require, "snacks")
  local Snacks = ok and snacks or _G.Snacks
  if not Snacks or not Snacks.picker then
    select_value(title, values, current, cb)
    return
  end

  local preview_token = 0
  local items = {}
  for _, value in ipairs(values) do
    items[#items + 1] = {
      value = value,
      text = value == current and (tostring(value) .. " *") or tostring(value),
    }
  end

  Snacks.picker.pick({
    title = title,
    prompt = title .. " ",
    auto_close = false,
    items = items,
    layout = {
      reverse = false,
      layout = {
        box = "horizontal",
        width = 0.8,
        min_width = 80,
        height = 0.7,
        {
          box = "vertical",
          width = opts.list_width or 0.3,
          { win = "list", title = " " .. title .. " ", title_pos = "center", border = true },
          { win = "input", height = 1, border = true, title = "{title}", title_pos = "center" },
        },
        {
          win = "preview",
          title = "{preview:Preview}",
          title_pos = "center",
          border = true,
        },
      },
    },
    format = "text",
    preview = function(ctx)
      preview_token = preview_token + 1
      local token = preview_token
      local preview_opts = vim.deepcopy(state.opts)
      apply_preview(preview_opts, ctx.item.value)

      ctx.preview:reset()
      ctx.preview:minimal()
      ctx.preview:set_title("Preview: " .. tostring(ctx.item.value))
      ctx.preview:set_lines({ "Rendering..." })

      pipeline.render(state.text, preview_opts, function(output, err)
        if token ~= preview_token or not preview_valid(ctx) then
          return
        end
        if err then
          set_preview_lines(ctx, vim.split(err, "\n", { plain = true }))
        else
          set_preview_lines(ctx, vim.split(output or "", "\n", { plain = true }))
        end
      end)
    end,
    confirm = function(selection_picker, selected)
      selection_picker:close()
      if selected and selected.value ~= nil then
        cb(selected.value)
      end
    end,
  })
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
  return {
    { key = "font", text = "Font: " .. value_label(opts.font) },
    { key = "width", text = "Width: " .. (opts.termwidth and "terminal" or value_label(opts.width)) },
    { key = "mode", text = "Render mode: " .. opts.mode },
    { key = "boxes_enabled", text = "Boxes: " .. bool_label(box.enabled) },
    { key = "boxes_design", text = "Box design: " .. value_label(box.design) },
    { key = "boxes_align", text = "Box align: " .. value_label(box.align) },
    { key = "boxes_padding", text = "Box padding: " .. value_label(box.padding) },
    { key = "boxes_size", text = "Box size: " .. value_label(box.size) },
  }
end

local function option_picker_height(state)
  local option_count = #rows(state)
  local preview_count = state.preview_line_count or 0
  local content_height = math.max(option_count + 5, preview_count + 2)
  return math.max(11, math.min(vim.o.lines - 4, content_height))
end

local function option_picker_layout(state)
  local height = option_picker_height(state)

  return {
    reverse = false,
    layout = {
      box = "horizontal",
      width = 0.8,
      min_width = 100,
      height = height,
      border = "none",
      {
        box = "vertical",
        width = 0.45,
        { win = "list", title = " Options ", title_pos = "center", border = true },
        {
          win = "input",
          height = 1,
          border = true,
          title = " Space: change option | Return: insert result ",
          title_pos = "center",
        },
      },
      {
        win = "preview",
        title = "{preview:Preview}",
        title_pos = "center",
        border = true,
        width = 0.55,
      },
    },
  }
end

local function update_picker_height(picker, state, preview_line_count)
  if not picker then
    return
  end
  if state.opts.picker and state.opts.picker.layout then
    return
  end

  state.preview_line_count = preview_line_count
  local height = option_picker_height(state)
  if state.layout_height == height then
    return
  end

  state.layout_height = height
  if picker.list and picker.list.set_target then
    picker.list:set_target(nil, nil, { force = true })
  end
  if pcall(picker.set_layout, picker, option_picker_layout(state)) then
    vim.schedule(function()
      if picker.closed then
        return
      end
      if picker.list and picker.list.set_target then
        picker.list.target = nil
      end
      pcall(picker._show_preview, picker)
    end)
  end
end

local function resize_picker_for_preview(picker, state)
  if not state.last_preview_lines then
    return
  end

  vim.defer_fn(function()
    if picker.closed then
      return
    end
    local display_lines = display_line_count_for_width(state.last_preview_lines, projected_preview_width()) + 1
    update_picker_height(picker, state, display_lines)
    vim.schedule(function()
      if picker.closed then
        return
      end
      if picker.list then
        picker.list.target = nil
      end
      pcall(picker._show_preview, picker)
    end)
  end, 50)
end

local function refresh_items(picker, state)
  if picker.list and picker.list.set_target then
    picker.list:set_target(nil, nil, { force = true })
  end
  picker:find({ refresh = true })
  vim.schedule(function()
    if picker.closed then
      return
    end
    if picker.list and picker.list.set_target then
      picker.list.target = nil
    end
    pcall(picker._show_preview, picker)
  end)
end

local function edit_option(picker, item, state)
  local opts = state.opts
  local box = opts.boxes
  local key = item and item.key
  if not key then
    return
  end

  local function changed()
    config.persist(state.opts)
    refresh_items(picker, state)
    pcall(function()
      picker:focus("list", { show = true })
    end)
  end

  if key == "font" then
    local fonts = discovery.fonts()
    select_preview_value("Font", fonts, opts.font, state, function(preview_opts, choice)
      preview_opts.font = choice
    end, function(choice)
      opts.font = choice
      changed()
    end)
  elseif key == "width" then
    input_value("Width or 'term'", opts.termwidth and "term" or opts.width, function(value)
      opts.termwidth = value == "term"
      opts.width = opts.termwidth and opts.width or tonumber(value)
      changed()
    end)
  elseif key == "mode" then
    select_preview_value("Render mode", MODES, opts.mode, state, function(preview_opts, choice)
      preview_opts.mode = choice
    end, function(choice)
      opts.mode = choice
      changed()
    end)
  elseif key == "boxes_enabled" then
    box.enabled = not box.enabled
    changed()
  elseif key == "boxes_design" then
    select_preview_value("Box design", discovery.box_designs(), box.design, state, function(preview_opts, choice)
      preview_opts.boxes.enabled = true
      preview_opts.boxes.design = choice
    end, function(choice)
      box.enabled = true
      box.design = choice
      changed()
    end)
  elseif key == "boxes_align" then
    select_preview_value("Box align", ALIGNMENTS, box.align, state, function(preview_opts, choice)
      preview_opts.boxes.enabled = true
      preview_opts.boxes.align = choice
    end, function(choice)
      box.enabled = true
      box.align = choice
      changed()
    end, { list_width = 14 })
  elseif key == "boxes_padding" then
    input_value("Box padding (number = all sides, e.g. 1; boxes format: h1v1)", box.padding, function(value)
      box.padding = value
      changed()
    end)
  elseif key == "boxes_size" then
    input_value("Box size", box.size, function(value)
      box.size = value
      changed()
    end)
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
    preview_line_count = 0,
    last_preview_lines = nil,
    last_output = nil,
    last_error = nil,
  }
  state.layout_height = option_picker_height(state)

  local ok, snacks = pcall(require, "snacks")
  local Snacks = ok and snacks or _G.Snacks
  if not Snacks or not Snacks.picker then
    vim.notify("banner_creator.nvim requires folke/snacks.nvim picker", vim.log.levels.ERROR)
    return
  end

  Snacks.picker.pick({
    title = "Banner Creator",
    prompt = "Option ",
    auto_close = false,
    finder = function()
      return rows(state)
    end,
    layout = state.opts.picker and state.opts.picker.layout or option_picker_layout(state),
    format = "text",
    preview = function(ctx)
      state.preview_token = state.preview_token + 1
      local token = state.preview_token
      ctx.preview:reset()
      ctx.preview:minimal()
      ctx.preview:set_title("Preview")
      ctx.preview:set_lines({ "Rendering..." })
      pipeline.render(state.text, state.opts, function(output, err)
        if token ~= state.preview_token or not preview_valid(ctx) then
          return
        end
        state.last_output = output
        state.last_error = err
        local lines
        if err then
          lines = vim.split(err, "\n", { plain = true })
        else
          lines = vim.split(output or "", "\n", { plain = true })
        end
        state.last_preview_lines = lines
        update_picker_height(ctx.picker, state, preview_display_line_count(ctx, lines))
        set_preview_lines(ctx, lines)
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
    on_show = function(picker)
      state.resize_augroup = vim.api.nvim_create_augroup(
        "banner_creator_picker_resize_" .. tostring(picker.id),
        { clear = true }
      )
      vim.api.nvim_create_autocmd("VimResized", {
        group = state.resize_augroup,
        callback = function()
          vim.defer_fn(function()
            if not picker.closed then
              resize_picker_for_preview(picker, state)
            end
          end, 20)
        end,
      })
    end,
    on_close = function()
      if state.resize_augroup then
        pcall(vim.api.nvim_del_augroup_by_id, state.resize_augroup)
        state.resize_augroup = nil
      end
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
