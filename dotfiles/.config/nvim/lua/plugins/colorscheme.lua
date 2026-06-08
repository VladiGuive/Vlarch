-- Nord colorscheme — palette in dotfiles/theme/nord.json (generated dotfiles via vlarch-theme-generate)
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
