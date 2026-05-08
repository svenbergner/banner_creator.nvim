local M = {}

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

local function renderer_args(opts)
  local args = { opts.renderer or "figlet" }
  if opts.font then
    add(args, "-f", opts.font)
  end
  if opts.renderer == "toilet" and opts.toilet_filter then
    add(args, "-F", opts.toilet_filter)
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
  add_option(args, "-p", box.padding)
  add_option(args, "-s", box.size)
  if box.color == true then
    add(args, "--color")
  elseif box.color == false then
    add(args, "--no-color")
  end
  return args
end

local function lolcat_args(opts)
  local lolcat = opts.lolcat or {}
  if not lolcat.enabled then
    return nil
  end

  local args = { "lolcat" }
  add_option(args, "--spread", lolcat.spread)
  add_option(args, "--freq", lolcat.freq)
  add_option(args, "--seed", lolcat.seed)
  if lolcat.animate then
    add(args, "--animate")
  end
  add_option(args, "--duration", lolcat.duration)
  add_option(args, "--speed", lolcat.speed)
  if lolcat.invert then
    add(args, "--invert")
  end
  if lolcat.truecolor then
    add(args, "--truecolor")
  end
  if lolcat.force then
    add(args, "--force")
  end
  return args
end

function M.commands(opts)
  local commands = { renderer_args(opts) }
  local box = boxes_args(opts)
  if box then
    commands[#commands + 1] = box
  end
  local lolcat = lolcat_args(opts)
  if lolcat then
    commands[#commands + 1] = lolcat
  end
  return commands
end

function M.strip_ansi(text)
  text = text or ""
  text = text:gsub("\27%[[0-9;:]*[A-Za-z]", "")
  text = text:gsub("\27%][^\7]*\7", "")
  return text
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
  local commands = M.commands(opts)
  local index = 1

  local function next_step(input)
    local cmd = commands[index]
    if not cmd then
      if opts.lolcat and opts.lolcat.enabled and not opts.lolcat.ansi then
        input = M.strip_ansi(input)
      end
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
