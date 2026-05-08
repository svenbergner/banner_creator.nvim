# banner_creator.nvim

A Neovim plugin to generate banner-style text with `figlet`/`toilet`, `boxes`, and `lolcat`.

## Requirements

- Neovim with `vim.system`
- [`folke/snacks.nvim`](https://github.com/folke/snacks.nvim) with picker support
- Optional command line tools: `figlet`, `toilet`, `boxes`, `lolcat`

## Usage

```vim
:BannerCreator
:BannerCreator Hello World
```

`BannerCreator` prompts for text when no argument is passed. It then opens a Snacks picker where `<Space>` edits or toggles the selected option and `<CR>` inserts the current rendered banner. Font and box-design selection open their own Snacks picker with a live preview for the highlighted choice.

## Setup

```lua
require("banner_creator").setup({
  renderer = "figlet",
  width = 80,
  boxes = {
    enabled = false,
    design = "simple",
  },
  lolcat = {
    enabled = false,
    ansi = false,
  },
})
```

## API

```lua
require("banner_creator").open({ text = "Hello" })
require("banner_creator").render("Hello", {}, function(output, err)
  if err then
    vim.notify(err, vim.log.levels.ERROR)
    return
  end
  print(output)
end)
```

Run `:checkhealth banner_creator` to inspect external dependencies.
