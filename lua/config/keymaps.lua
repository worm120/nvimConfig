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

-- 悬浮窗显示当前文件完整路径（nvim 自带 hover 浮窗的实现，不依赖插件）
-- 不聚焦浮窗：光标一动即关（close_events 默认含 CursorMoved）；要按住看就 <C-w>w 跳到浮窗再 q
vim.keymap.set("n", "<A-f>", function()
  local path = vim.api.nvim_buf_get_name(0)
  if path == "" then
    path = "(no name)"
  end
  local lines = { path }
  local real = vim.fn.resolve(path) -- 软链/.. 的真身，只有不同时才多一行
  if real ~= path then
    lines[#lines + 1] = "-> " .. real
  end
  vim.lsp.util.open_floating_preview(lines, "", {
    border = "rounded",
    max_width = math.min(vim.o.columns - 4, 100), -- 长路径折行，超宽不裁
    title = " current file ",
    title_pos = "center",
  })
end, { desc = "Show full file path" })

-- 复制当前 buffer 的文件名到系统剪贴板（+ 寄存器，X11 下走 xclip）
-- 想复制完整路径把 %:t 改成 %:p；想复制相对 cwd 的路径改成 %:.
vim.keymap.set("n", "<A-y>", function()
  local name = vim.fn.expand("%:t")
  if name == "" then
    vim.notify("Buffer has no file name", vim.log.levels.WARN)
    return
  end
  vim.fn.setreg("+", name)
  vim.notify("Copied: " .. name)
end, { desc = "Copy file name" })
