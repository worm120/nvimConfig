-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
vim.keymap.set("i", "jk", "<ESC>", { noremap = true, silent = true, desc = "<ESC>" })
vim.keymap.set("i", "jj", "<ESC>", { noremap = true, silent = true, desc = "<ESC>" })

vim.keymap.set({ "n", "v" }, "K", "5k", { noremap = true, desc = "Up faster" })
vim.keymap.set({ "n", "v" }, "J", "5j", { noremap = true, desc = "Down faster" })
-- Remap K and J
vim.keymap.set({ "n", "v" }, "<leader>k", "K", { noremap = true, desc = "Keyword" })
vim.keymap.set({ "n", "v" }, "<leader>j", "J", { noremap = true, desc = "Join lines" })

-- C-P classic
vim.keymap.set("n", "<C-P>", "<leader>ff")

-- Save file
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { noremap = true, desc = "Save window" })
vim.keymap.set("n", "<C-s>", "<cmd>w<cr>", { noremap = true, desc = "Save window" })

vim.keymap.set("n", "<A-s>", "<C-o>", { noremap = true, desc = "Jump back" })
vim.keymap.set("n", "<A-d>", "<gd>", { noremap = false, desc = "Jump back" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Yank to clipboard" })
-- Unmap mappings used by tmux plugin
-- TODO(vintharas): There's likely a better way to do this.
-- vim.keymap.del("n", "<C-h>")
-- vim.keymap.del("n", "<C-j>")
-- vim.keymap.del("n", "<C-k>")
-- vim.keymap.del("n", "<C-l>")
-- vim.keymap.set("n", "<C-h>", "<cmd>TmuxNavigateLeft<cr>")
-- vim.keymap.set("n", "<C-j>", "<cmd>TmuxNavigateDown<cr>")
-- vim.keymap.set("n", "<C-k>", "<cmd>TmuxNavigateUp<cr>")
-- vim.keymap.set("n", "<C-l>", "<cmd>TmuxNavigateRight<cr>")