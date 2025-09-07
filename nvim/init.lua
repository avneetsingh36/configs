-- ~/.config/nvim/init.lua
-- Minimal, classic‑Vim feel: no mouse, no fancy scrolling, Gruvbox theme via lazy.nvim

-- ===== Basics =====
vim.g.mapleader = " "
vim.g.maplocalleader = " "

-- Classic Vim vibe: disable mouse (no clicking/trackpad scrolling in Neovim)
vim.o.mouse = ""

-- Sensible, minimal UI
vim.o.number = true            -- show line numbers
vim.o.relativenumber = false
vim.o.wrap = false             -- no soft wrapping
vim.o.termguicolors = true     -- 24-bit colors

-- Indentation: 4 spaces (no hard tabs)
vim.o.tabstop = 2
vim.o.shiftwidth = 2
vim.o.softtabstop = 2
vim.o.expandtab = true
vim.o.guicursor = ""           -- solid block cursor (like old-school Vim)
vim.o.showmode = false         -- avoid '-- INSERT --' (statusline usually shows it)

-- Files
vim.o.swapfile = false
vim.o.backup = false
vim.o.writebackup = false
vim.o.undofile = true          -- persistent undo

-- ===== lazy.nvim bootstrap =====
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- ===== Plugins =====
require("lazy").setup({
  {
    "ellisonleao/gruvbox.nvim",
    priority = 1000, -- ensure it loads first
    opts = {
      -- contrast left at default ("hard" | "soft" | "")
      italic = { strings = false, comments = false, folds = false },
      transparent_mode = false,
    },
    config = function(_, opts)
      require("gruvbox").setup(opts)
      vim.o.background = "dark"       -- set to "light" if you prefer
      vim.cmd.colorscheme("gruvbox")
    end,
  },
}, {
  ui = { border = "rounded" },
})

-- ===== Minimal keymaps =====
local map = vim.keymap.set
map("n", "<leader>w", "<cmd>w<CR>", { desc = "Save" })
map("n", "<leader>q", "<cmd>q<CR>", { desc = "Quit" })

-- ===== Optional: load your runner if present =====
-- If you kept lua/runner.lua from earlier, this will attach its mappings (<leader>r / <leader>R)
pcall(function()
  local runner = require("runner")
  if runner and runner.setup then runner.setup() end
end)

