-- --------------------------------------------
-- Basic Options
-- --------------------------------------------

vim.g.mapleader = " "            -- ← optional but popular (Space as leader)
require("runner").setup()        -- ← wire up the run keymaps/commands

vim.opt.number = true
vim.opt.relativenumber = true
vim.opt.tabstop = 2
vim.opt.shiftwidth = 2
vim.opt.expandtab = true
vim.opt.autoindent = true
vim.opt.cindent = true
vim.opt.smartindent = true
vim.opt.smarttab = true   -- ✨ added
vim.opt.breakindent = true -- ✨ added
vim.opt.termguicolors = true
vim.opt.clipboard = "unnamedplus"
vim.opt.cursorline = true
vim.opt.incsearch = false
vim.opt.hlsearch = false
vim.opt.virtualedit = "onemore"
vim.opt.backspace = { "indent", "eol", "start" }

-- ✨ NEW: Proper enter behavior
vim.opt.indentkeys:append("0{,0},0),0],0>,0)")
vim.opt.formatoptions:append("o")

-- --------------------------------------------
-- Plugin Manager: lazy.nvim bootstrap
-- --------------------------------------------
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not vim.loop.fs_stat(lazypath) then
  vim.fn.system({
    "git", "clone", "--filter=blob:none",
    "https://github.com/folke/lazy.nvim.git",
    "--branch=stable", lazypath,
  })
end
vim.opt.rtp:prepend(lazypath)

-- --------------------------------------------
-- Install Plugins
-- --------------------------------------------
require("lazy").setup({
  { "folke/tokyonight.nvim", lazy = false, priority = 1000 },
  {
    "nvim-treesitter/nvim-treesitter",
    build = ":TSUpdate",
    opts = {
      ensure_installed = { "cpp", "c", "lua" },  -- add "python" if you want TS highlighting
      highlight = { enable = true },
      indent = { enable = true },
    },
  },
  { "neovim/nvim-lspconfig" },
  {
    "hrsh7th/nvim-cmp",
    dependencies = {
      "hrsh7th/cmp-nvim-lsp",
      "L3MON4D3/LuaSnip",
    },
  },
  { "windwp/nvim-autopairs", event = "InsertEnter", config = true },
  { "nvim-lualine/lualine.nvim" },
  { "karb94/neoscroll.nvim", config = true },
})

-- --------------------------------------------
-- Colorscheme
-- --------------------------------------------
vim.cmd [[colorscheme tokyonight-storm]]

-- --------------------------------------------
-- Lualine Setup (Minimal Bottom Bar)
-- --------------------------------------------
require('lualine').setup({
  options = {
    theme = 'tokyonight',
    section_separators = '',
    component_separators = '',
    icons_enabled = false,
  },
})

-- --------------------------------------------
-- LSP Setup for C++ (clangd)
-- --------------------------------------------
local lspconfig = require("lspconfig")
lspconfig.clangd.setup({
  init_options = {
    clangdFileStatus = true,
    fallbackFlags = { "--std=c++17" },
  },
})

-- --------------------------------------------
-- Autocompletion Setup
-- --------------------------------------------
local cmp = require("cmp")
cmp.setup({
  completion = {
    autocomplete = false,
  },
  mapping = {
    ["<Tab>"] = cmp.mapping.select_next_item(),
    ["<S-Tab>"] = cmp.mapping.select_prev_item(),
    ["<CR>"] = cmp.mapping.confirm({ select = true }),
  },
  sources = {
    { name = "nvim_lsp" },
  },
})

-- --------------------------------------------
-- Neoscroll Setup (Smooth Scrolling)
-- --------------------------------------------
require('neoscroll').setup({
  easing_function = "quadratic",
  hide_cursor = true,
  stop_eof = true,
})

-- --------------------------------------------
-- Keymaps for LSP
-- --------------------------------------------
vim.keymap.set("n", "gd", vim.lsp.buf.definition, { desc = "Go to definition" })
vim.keymap.set("n", "K", vim.lsp.buf.hover, { desc = "Hover Documentation" })
vim.keymap.set("n", "<leader>f", function() vim.lsp.buf.format { async = true } end, { desc = "Format file manually" })

-- --------------------------------------------
-- Turn off auto-comment on newline
-- --------------------------------------------
vim.api.nvim_create_autocmd("FileType", {
  pattern = "*",
  callback = function()
    vim.opt.formatoptions:remove({ "c", "r", "o" })
  end,
})

-- ✨ Better autoindent always active
vim.api.nvim_create_autocmd("BufEnter", {
  pattern = "*",
  callback = function()
    vim.bo.autoindent = true
    vim.bo.smartindent = true
  end,
})

vim.api.nvim_create_autocmd("BufWritePre", {
  pattern = "*.cpp,*.h,*.hpp",
  callback = function()
    vim.cmd("silent! %!clang-format")
  end,
})

