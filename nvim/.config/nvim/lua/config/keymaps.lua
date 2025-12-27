-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local map = vim.keymap.set
local opts = { noremap = true, silent = true }

-- Ctrl+A -> Select all
map("n", "<C-a>", "ggVG", opts)

-- Ctrl+C -> Copy to system clipboard (visual mode only)
map("v", "<C-c>", '"+y', opts)

-- Ctrl+V -> Paste from system clipboard
map("n", "<C-v>", '"+p', opts)
map("v", "<C-v>", '"+p', opts)
map("i", "<C-v>", '<Esc>"+pa', opts)
