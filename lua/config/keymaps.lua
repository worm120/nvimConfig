-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- LSP navigation keymaps
vim.keymap.set("n", "<A-d>", vim.lsp.buf.definition, { desc = "Go to Definition" })
vim.keymap.set("n", "<A-s>", "<C-o>", { desc = "Jump Back" })
-- 引用列表用 snacks picker 浮窗（Esc 即可关闭），不用 vim.lsp.buf.references（默认会 botright copen 弹底部 quickfix）
vim.keymap.set("n", "<A-r>", function() Snacks.picker.lsp_references() end, { desc = "Find References" })

-- Buffer navigation keymaps
vim.keymap.set("n", "<A-]>", ":bnext<CR>", { desc = "Next Buffer" })
vim.keymap.set("n", "<A-[>", ":bprev<CR>", { desc = "Previous Buffer" })
vim.keymap.set("n", "<A-a>", ":b#<CR>", { desc = "Switch to Last Buffer" })

-- Screen scroll without moving cursor
vim.keymap.set("n", "<A-j>", "<C-E>", { desc = "Scroll screen down" })
vim.keymap.set("n", "<A-k>", "<C-Y>", { desc = "Scroll screen up" })

-- Insert mode: 连按两次 j 退出到 normal（用 <Esc> 而非 <C-c>，前者会触发 InsertLeave）
vim.keymap.set("i", "jj", "<Esc>", { desc = "Exit insert mode" })
