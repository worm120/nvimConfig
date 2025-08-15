require "nvchad.mappings"

-- add yours here
local map = vim.keymap.set

map("n", ";", ":", { desc = "CMD enter command mode" })
map("i", "jk", "<ESC>")
map("i", "jj", "<ESC>")

map({ "n", "i", "v" }, "<C-s>", "<cmd> w <cr>")

map({ "n", "i", "v" }, "<C-z>", "<cmd> undo <cr>", { desc = "history undo" })
map({ "n", "i", "v" }, "<C-y>", "<cmd> redo <cr>", { desc = "history redo" })
map("n", "<C-_>", "gcc", { desc = "comment toggle", remap = true })
map("i", "<C-_>", "<Esc>gcc^i", { desc = "comment toggle", remap = true })
map("v", "<C-_>", "gc", { desc = "comment toggle", remap = true })

---@param cmd string
local execCmd = function (cmd)
  if vim.bo.filetype == "telescopeprompt" then
    vim.cmd "q!"
  else
    vim.cmd (cmd)
  end
end

map({ "n", "i", "v" }, "<A-f>", function()
  execCmd("Telescope live_grep")
end, { desc = "search search across project" })

map("n", "<A-s>", "<C-o>", { desc = "jump jump back"})
map("n", "<A-e>", vim.diagnostic.open_float, { desc = "LSP show diagnostics" }) -- 唤出诊断信息，这个没有默认快捷键，我推荐大家都映射一下
map({ "n", "i", "v" }, "<A-d>", vim.lsp.buf.definition, { desc = "LSP rename" }) -- 跳转到定义，等同于 `gd`
