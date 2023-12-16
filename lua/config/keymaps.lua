-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here
local function map(mode, lhs, rhs, opts)
    local keys = require("lazy.core.handler").handlers.keys
    ---@cast keys LazyKeysHandler
    -- do not create the keymap if a lazy keys handler exists
    if not keys.active[keys.parse({ lhs, mode = mode }).id] then
        opts = opts or {}
        opts.silent = opts.silent ~= false
        if opts.remap and not vim.g.vscode then
            opts.remap = nil
        end
        vim.keymap.set(mode, lhs, rhs, opts)
    end
end

vim.keymap.set("i", "jk", "<ESC>", { noremap = true, silent = true, desc = "<ESC>" })
vim.keymap.set("i", "jj", "<ESC>", { noremap = true, silent = true, desc = "<ESC>" })
vim.keymap.set("i", "<A-l>", "<ESC>la", { noremap = true, silent = true, desc = "jump to next next charactor" })
vim.keymap.set("i", "<A-h>", "<ESC>ha", { noremap = true, silent = true, desc = "jump to prev prev charactor" })
-- vim.keymap.set({ "n", "i" }, "<A-v>", "<C-v>", { noremap = true, silent = true, desc = "jump to next next charactor" })

vim.keymap.set({ "n", "v" }, "K", "5k", { noremap = true, desc = "Up faster" })
vim.keymap.set({ "n", "v" }, "J", "5j", { noremap = true, desc = "Down faster" })
-- Remap K and J
vim.keymap.set({ "n", "v" }, "<leader>k", "K", { noremap = true, desc = "Keyword" })
vim.keymap.set({ "n", "v" }, "<leader>j", "J", { noremap = true, desc = "Join lines" })

vim.keymap.set(
    { "n", "v" },
    "<A-k>",
    "10<C-y>",
    { noremap = true, desc = " 	Move the view port up 10 lines without moving the cursor" }
)

vim.keymap.set(
    { "n", "v" },
    "<A-j>",
    "10<C-e>",
    { noremap = true, desc = " 	Move the view port down 10 lines without moving the cursor" }
)

-- C-P classic
-- vim.keymap.set("n", "<C-p>", "<leader>ff")

-- Save file
vim.keymap.set("n", "<leader>w", "<cmd>w<cr>", { noremap = true, desc = "Save window" })
vim.keymap.set({ "n", "i" }, "<C-s>", "<cmd>w<cr>", { noremap = true, desc = "Save window" })

vim.keymap.set({ "n", "i" }, "<A-s>", "<C-o>", { noremap = true, desc = "Jump back" })
vim.keymap.set({ "n", "i" }, "<A-a>", "<C-i>", { noremap = true, desc = "Jump forward" })
-- vim.keymap.set("n", "<A-h>", "<C-h>", { noremap = true, desc = "Jump forward" })
vim.keymap.set("v", "<leader>y", '"+y', { desc = "Yank to clipboard" })

map({ "n", "i" }, "<A-o>", "<cmd>e #<cr>", { desc = "Switch to Other Buffer" })
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
--
