-- 现场取证：查"正在跑的" nvim 里某个 LSP 客户端的真实状态 + 手动同步发请求
--
-- 用法（只读，不改 buffer、不动文件）：
--   S=/run/user/$(id -u)/nvim.<pid>.0                  # 见 agent.md「无头验证配方」
--   nvim --server $S --remote-expr "luaeval('dofile(\"$HOME/.config/nvim/tools/probe_nvim_lsp.lua\")')"
--
-- 打印：buffer / 光标 / 光标下的词、attached clients、vim.lsp.status()、
--       光标处符号的 references（条数 + 前若干条位置）、definition、workspace/symbol（光标下的词）
--
-- 说明：`luaeval` 只接受**表达式**，所以本文件尾部是 `return <字符串>`（用 dofile 包起来才合法）。
local buf = vim.api.nvim_get_current_buf()
local out = {}

local cur = vim.api.nvim_win_get_cursor(0)
local cword = vim.fn.expand("<cword>")
out[#out + 1] = ("buffer  = %s"):format(vim.api.nvim_buf_get_name(buf))
out[#out + 1] = ("cursor  = line %d col %d, word=%q, modified=%s, ft=%s"):format(
  cur[1], cur[2], cword, tostring(vim.bo[buf].modified), tostring(vim.bo[buf].filetype))
out[#out + 1] = ("lsp.status() = %s"):format(tostring(vim.lsp.status and vim.lsp.status() or "n/a"))

local ds = vim.diagnostic.get(buf)
out[#out + 1] = ("diagnostics = %d"):format(#ds)
for i, d in ipairs(ds) do
  if i > 5 then break end
  out[#out + 1] = ("    L%d [%s] %s"):format(d.lnum + 1, tostring(d.source or "?"),
    tostring(d.message or ""):gsub("\n", " "):sub(1, 120))
end

local cs = vim.lsp.get_clients({ bufnr = buf })
out[#out + 1] = ("clients attached = %d"):format(#cs)
for _, c in ipairs(cs) do
  out[#out + 1] = ("    %s id=%s root=%s refsProvider=%s"):format(c.name, tostring(c.id),
    tostring(c.config.root_dir),
    tostring(c.server_capabilities and c.server_capabilities.referencesProvider ~= nil))
end

-- 只把 http(s)/file 之外的东西也留着：位置统一裁成相对 project root 更好读
local function fmt_loc(uri, range)
  local p = tostring(uri):gsub("^file://", "")
  local line = ((range or {}).start or {}).line
  return ("%s:%s"):format(p, line ~= nil and (line + 1) or "?")
end

for _, c in ipairs(cs) do
  local params = vim.lsp.util.make_position_params(0, c.offset_encoding)
  params.context = { includeDeclaration = true }
  local ok, res = pcall(function()
    return c:request_sync("textDocument/references", params, 8000, buf)
  end)
  local n = 0
  if ok and type(res) == "table" and res.result then n = #res.result end
  out[#out + 1] = ("references @ cursor via %s -> count=%d"):format(c.name, n)
  if ok and type(res) == "table" and res.result then
    for i, it in ipairs(res.result) do
      if i > 15 then break end
      local loc = it.location or it
      out[#out + 1] = "    " .. fmt_loc(loc.uri, loc.range)
    end
  elseif not ok then
    out[#out + 1] = "    ERR " .. tostring(res)
  end

  local ok2, res2 = pcall(function()
    return c:request_sync("textDocument/definition", vim.lsp.util.make_position_params(0, c.offset_encoding), 8000, buf)
  end)
  local d = "?"
  if ok2 and type(res2) == "table" and res2.result then
    local r = res2.result
    if type(r) == "table" and r[1] then r = r[1] end
    d = (type(r) == "table" and r.uri) and fmt_loc(r.uri, r.range) or tostring(r)
  elseif not ok2 then
    d = "ERR " .. tostring(res2)
  end
  out[#out + 1] = "definition @ cursor -> " .. tostring(d):gsub("%s+", " "):sub(1, 160)

  -- workspace/symbol：光标下的词（看索引里到底有没有这个符号）
  for _, q in ipairs({ cword }) do
    if q ~= "" then
      local ok3, res3 = pcall(function() return c:request_sync("workspace/symbol", { query = q }, 8000, buf) end)
      local n3, names = 0, {}
      if ok3 and type(res3) == "table" and res3.result then
        n3 = #res3.result
        for i, s in ipairs(res3.result) do
          if i > 4 then break end
          names[#names + 1] = fmt_loc((s.location or {}).uri, (s.location or {}).range)
        end
      end
      out[#out + 1] = ("workspace/symbol %q -> %d  %s"):format(q, n3, table.concat(names, " "))
    end
  end
end

return table.concat(out, "\n")