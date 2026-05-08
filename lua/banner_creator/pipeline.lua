local M = {}

local discovery = require("banner_creator.discovery")

local function add(args, ...)
  for _, value in ipairs({ ... }) do
    if value ~= nil and value ~= "" then
      args[#args + 1] = tostring(value)
    end
  end
end

local function add_option(args, flag, value)
  if value ~= nil and value ~= "" then
    add(args, flag, value)
  end
end

local function normalize_padding(value)
  if value == nil or value == "" then
    return nil
  end
  value = tostring(value)
  if value:match("^%d+$") then
    return "h" .. value .. "v" .. value
  end
  return value
end

local function figlet_args(opts)
  local args = { "figlet" }
  if opts.font then
    add(args, "-f", opts.font)
  end

  if opts.termwidth then
    add(args, "-t")
  elseif opts.width then
    add(args, "-w", opts.width)
  end

  local mode = opts.mode
  if mode == "smush" then
    add(args, "-s")
  elseif mode == "force_smush" then
    add(args, "-S")
  elseif mode == "kern" then
    add(args, "-k")
  elseif mode == "full_width" then
    add(args, "-W")
  elseif mode == "overlap" then
    add(args, "-o")
  end

  return args
end

local function boxes_args(opts)
  local box = opts.boxes or {}
  if not box.enabled then
    return nil
  end

  local args = { "boxes" }
  add_option(args, "-d", box.design)
  add_option(args, "-a", box.align)
  add_option(args, "-p", normalize_padding(box.padding))
  add_option(args, "-s", box.size)
  return args
end

function M.commands(opts)
  local commands = { figlet_args(opts) }
  local box = boxes_args(opts)
  if box then
    commands[#commands + 1] = box
  end
  return commands
end

local function run_one(cmd, input, cb)
  vim.system(cmd, { text = true, stdin = input }, function(result)
    vim.schedule(function()
      if result.code ~= 0 then
        cb(nil, table.concat({
          "Command failed: " .. table.concat(cmd, " "),
          result.stderr or "",
        }, "\n"))
        return
      end
      cb(result.stdout or "", nil)
    end)
  end)
end

function M.render(text, opts, cb)
  local figlet_err = discovery.figlet_error()
  if figlet_err then
    cb(nil, figlet_err)
    return
  end

  local commands = M.commands(opts)
  local index = 1

  local function next_step(input)
    local cmd = commands[index]
    if not cmd then
      cb(input, nil)
      return
    end

    index = index + 1
    run_one(cmd, input, function(output, err)
      if err then
        cb(nil, err)
        return
      end
      next_step(output)
    end)
  end

  next_step(text or "")
end

return M
