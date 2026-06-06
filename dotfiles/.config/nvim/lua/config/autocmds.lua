-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

vim.api.nvim_create_autocmd("ColorScheme", {
  pattern = "nord",
  callback = function()
    local transparent = { bg = "NONE" }
    vim.api.nvim_set_hl(0, "NormalFloat", transparent)
    vim.api.nvim_set_hl(0, "FloatBorder", transparent)
    vim.api.nvim_set_hl(0, "FloatTitle", transparent)
    vim.api.nvim_set_hl(0, "NeoTreeNormal", transparent)
    vim.api.nvim_set_hl(0, "NeoTreeNormalNC", transparent)
    vim.api.nvim_set_hl(0, "TelescopeNormal", transparent)
    vim.api.nvim_set_hl(0, "TelescopeBorder", transparent)

    -- neo-tree resets filtered-item highlights on ColorScheme; schedule so we win.
    vim.schedule(function()
      local dotfile = { fg = "#8FBCBB", bg = "NONE" } -- nord7 — readable on transparent bg
      vim.api.nvim_set_hl(0, "NeoTreeDotfile", dotfile)
      vim.api.nvim_set_hl(0, "NeoTreeGitIgnored", dotfile)
      vim.api.nvim_set_hl(0, "NeoTreeHiddenByName", dotfile)
      vim.api.nvim_set_hl(0, "NeoTreeIgnored", dotfile)
      vim.api.nvim_set_hl(0, "NeoTreeWindowsHidden", dotfile)
    end)
  end,
})
