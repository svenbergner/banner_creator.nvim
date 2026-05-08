if vim.g.loaded_banner_creator_nvim then
  return
end
vim.g.loaded_banner_creator_nvim = true

vim.api.nvim_create_user_command("BannerCreator", function(args)
  require("banner_creator").open({
    text = args.args ~= "" and args.args or nil,
  })
end, {
  nargs = "*",
  desc = "Create a text banner with figlet/toilet, boxes, and lolcat",
})
