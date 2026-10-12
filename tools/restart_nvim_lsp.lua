-- 在"正在跑的" nvim 里重启当前 buffer 的 LSP 客户端（<A-r> 引用为空时的一键修复）
--
-- 用法：
--   S=/run/user/$(id -u)/nvim.<pid>.0
--   nvim --server $S --remote-expr "luaeval('dofile(\"$HOME/.config/nvim/tools/restart_nvim_lsp.lua\")')"
--
-- 做什么：停掉当前 buffer 的 LSP 客户端 → `silent! edit` 重新触发 FileType → 等新客户端 attach + 诊断回来
-- 安全：buffer 有未保存改动时**拒绝执行**（`:edit` 会丢改动）；确实要强制时可先
--   nvim --server $S --remote-expr 'luaeval("_G.force_restart_lsp = true")'
-- 注意：本机 nvim 0.12 没有 `:LspRestart` / `:LspInfo`（nvim-lspconfig 已移除）。
local buf = vim.api.nvim_get_current_buf()
local name = vim.api.nvim_buf_get_name(buf)
local out = {}

if vim.bo[buf].modified and not _G.force_restart_lsp then
  return ("拒绝执行：buffer 有未保存改动 -> " .. name ..
    "\n（强制：先 luaeval(\"_G.force_restart_lsp = true\") 再跑本脚本；或自己保存后重试）")
end

local before = vim.lsp.get_clients({ bufnr = buf })
out[#out + 1] = ("buffer = %s (clean=%s)"):format(name, tostring(not vim.bo[buf].modified))
out[#out + 1] = ("restart 前 clients = %d"):format(#before)
for _, c in ipairs(before) do
  out[#out + 1] = ("    stopping %s id=%s"):format(c.name, tostring(c.id))
  c:stop()
end
vim.wait(5000, function() return #vim.lsp.get_clients({ bufnr = buf }) == 0 end, 100)

vim.cmd("silent! edit")
vim.wait(30000, function() return #vim.lsp.get_clients({ bufnr = buf }) > 0 end, 200)
local after = vim.lsp.get_clients({ bufnr = buf })
out[#out + 1] = ("重新 attach 后 clients = %d"):format(#after)
for _, c in ipairs(after) do
  out[#out + 1] = ("    %s id=%s root=%s"):format(c.name, tostring(c.id), tostring(c.config.root_dir))
end

vim.wait(20000, function() return #vim.diagnostic.get(buf) > 0 end, 300)
out[#out + 1] = "lsp.status() = " .. tostring(vim.lsp.status and vim.lsp.status() or "n/a")
out[#out + 1] = "下一步：再跑 probe_nvim_lsp.lua 看 references 条数是否恢复"
return table.concat(out, "\n")