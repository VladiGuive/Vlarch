-- Nord colorscheme — palette in ~/.config/themes/*.json (vlarch-theme-generate / Walker $ themes)
return {
  {
    "shaunsingh/nord.nvim",
    lazy = false,
    priority = 1000,
    init = function()
      vim.g.nord_disable_background = true
    end,
  },
  {
    "LazyVim/LazyVim",
    opts = {
      colorscheme = "nord",
    },
  },
}
