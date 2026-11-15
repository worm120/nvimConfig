-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- `nvim .` 启动后会留下两类「等于目录参数」的空 buffer，都占 bufferline 第一格：
--   1) [No Name]：snacks.explorer 把最初那个目录 buffer 的名字清空、不删 buffer
--      （snacks/explorer/init.lua:38-40）；有 session 自动恢复时 dashboard 也不再收编它
--      （reason: window does not contain the first buffer）
--   2) 「src/」：nvim 为参数目录本身保留的 buffer，session 里的 `$argadd <目录>` 让它变 listed
-- 等启动与 session 恢复都落定后一起清掉（`:bd` 只是暂时的，下一次启动 session 又会拉回来）。
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      if vim.fn.argc(-1) ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) ~= 1 then
        return
      end
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.api.nvim_buf_is_valid(b)
          and vim.bo[b].buflisted
          and not vim.bo[b].modified
          and vim.bo[b].buftype == ""
          and (vim.api.nvim_buf_get_name(b) == "" or vim.fn.isdirectory(vim.api.nvim_buf_get_name(b)) == 1)
          and vim.api.nvim_buf_line_count(b) <= 1
          and #vim.fn.win_findbuf(b) == 0
        then
          pcall(vim.api.nvim_buf_delete, b, {})
        end
      end
    end, 200)
  end,
})

-- `nvim .` 启动时 snacks explorer 在 UIEnter 里无条件 p:focus()（snacks/explorer/init.lua:41-51，
-- 绕过 picker 的 focus/enter 配置）→ 焦点被侧栏浮窗抢走。启动落定后把焦点还给它的 main 窗口
-- （= 启动时那个文件窗口），侧栏保留：explorer 源自带 auto_close = false
-- （picker/config/sources.lua:63），焦点离开不会触发 picker 的自动关闭。
-- 必须 defer：本文件里的 UIEnter autocmd 注册得比 explorer 那个早，直接切焦点会被它随后抢回去。
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
        if picker.main and vim.api.nvim_win_is_valid(picker.main) then
          vim.api.nvim_set_current_win(picker.main)
        end
      end
    end, 200)
  end,
})

-- ── 同名符号高亮：三档，取当前 buffer 能用的最强那档 ──────────────────────────
-- ① textDocument/documentHighlight（clangd / lua_ls / nixd）：LazyVim 默认开的 snacks.words
--    （plugins/ui.lua:282）会自己请求并画出来 → 这里直接跳过，不双重高亮。
-- ② textDocument/references（glsld 提供，见 lua/plugins/lsp.lua）：异步请求后按范围自己画 extmark。
--    这是**作用域语义**版本 —— 两个函数里各自的 i 不会互相点亮。
-- ③ 都没有时兜底：用 treesitter 找同名的 identifier 节点。纯**词法**匹配（同名就亮），
--    好处是注释 / 字符串里的同名文本不会误亮（那些不是 identifier 节点）。
local ref_ns = vim.api.nvim_create_namespace("user_ts_reference_hl")
local ref_group = vim.api.nvim_create_augroup("user_ts_reference_hl", { clear = true })

-- 异步 references 回包的代际号：光标一移走就 +1，迟到的结果直接丢掉
local ref_gen = 0

local function ref_clear(buf)
  ref_gen = ref_gen + 1
  if vim.api.nvim_buf_is_valid(buf) then
    vim.api.nvim_buf_clear_namespace(buf, ref_ns, 0, -1)
  end
end

-- 第一个支持 method 的 client（按能力挑，不按名字写死）
local function ref_client(buf, method)
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = buf })) do
    if c:supports_method(method) then
      return c
    end
  end
end

-- 光标下的标识符名字；不在标识符上（空白 / 关键字 / 注释）返回 nil。
-- field_identifier 也算：GLSL 里 l.pos / l.color 是成员访问，glsld 对这些也能给出 references。
local function ref_word(buf)
  return vim.api.nvim_buf_call(buf, function()
    local ok, node = pcall(vim.treesitter.get_node, { ignore_injections = false })
    if not ok or not node then
      return nil
    end
    local kind = node:type()
    if kind ~= "identifier" and kind ~= "field_identifier" then
      return nil
    end
    return vim.treesitter.get_node_text(node, buf)
  end)
end

local function ref_draw(buf)
  ref_clear(buf)
  local gen = ref_gen
  if not vim.api.nvim_buf_is_valid(buf) or vim.api.nvim_buf_line_count(buf) > 20000 then
    return
  end
  -- ① 有 documentHighlight 的 server 由 snacks.words 画，这里不抢活
  if ref_client(buf, "textDocument/documentHighlight") then
    return
  end
  -- 光标不在 identifier 上就别发请求（空白处空跑请求既浪费又会闪）
  local word = ref_word(buf)
  if not word then
    return
  end

  -- ② 有 references 的 server（glsld）→ 作用域语义版
  local rclient = ref_client(buf, "textDocument/references")
  if rclient then
    local uri = vim.uri_from_bufnr(buf)
    local params = vim.lsp.util.make_position_params(0, rclient.offset_encoding)
    params.context = { includeDeclaration = true }
    vim.lsp.buf_request(buf, "textDocument/references", params, function(err, result)
      -- gen 变了 = 光标早已移走，画上去就是错的
      if err or type(result) ~= "table" or gen ~= ref_gen then
        return
      end
      if not vim.api.nvim_buf_is_valid(buf) then
        return
      end
      vim.api.nvim_buf_clear_namespace(buf, ref_ns, 0, -1)
      for _, item in ipairs(result) do
        if item.uri == uri then
          local s, e = item.range.start, item.range["end"]
          vim.api.nvim_buf_set_extmark(buf, ref_ns, s.line, s.character, {
            end_row = e.line,
            end_col = e.character,
            hl_group = "LspReferenceText",
          })
        end
      end
    end)
    return
  end

  -- ③ 兜底：treesitter 词法同名匹配。
  -- 单个字符的标识符（i / n / d 这类）在词法匹配下噪音太大，只有语义版（②）才画。
  if #word < 2 then
    return
  end
  vim.api.nvim_buf_call(buf, function()
    local lang = vim.bo[buf].filetype
    local ok2, parser = pcall(vim.treesitter.get_parser, buf, lang)
    local ok3, query = pcall(vim.treesitter.query.parse, lang, "(identifier) @id")
    if not ok2 or not ok3 then
      return -- 该语言没有 treesitter parser（或 grammar 里没有 identifier 节点）
    end
    for _, tree in ipairs(parser:parse()) do
      for _, n in query:iter_captures(tree:root(), buf) do
        if vim.treesitter.get_node_text(n, buf) == word then
          local sr, sc, er, ec = n:range()
          vim.api.nvim_buf_set_extmark(buf, ref_ns, sr, sc, {
            end_row = er,
            end_col = ec,
            hl_group = "LspReferenceText",
          })
        end
      end
    end
  end)
end

-- 100ms debounce：每次移动都全量扫太浪费，但比 snacks 的 200ms 短一点，观感跟手
local ref_timer = (vim.uv or vim.loop).new_timer()
local function ref_schedule(buf)
  ref_timer:stop()
  ref_timer:start(100, 0, vim.schedule_wrap(function()
    if vim.api.nvim_get_current_buf() == buf then
      ref_draw(buf)
    end
  end))
end

vim.api.nvim_create_autocmd({ "CursorMoved", "CursorMovedI" }, {
  group = ref_group,
  callback = function(event)
    ref_clear(event.buf) -- 旧位置的标记立刻清掉，别留在屏幕上
    ref_schedule(event.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufEnter", "InsertLeave" }, {
  group = ref_group,
  callback = function(event)
    ref_schedule(event.buf)
  end,
})

vim.api.nvim_create_autocmd({ "BufLeave", "InsertEnter" }, {
  group = ref_group,
  callback = function(event)
    ref_clear(event.buf)
  end,
})

-- ── glsld 只留语义能力，重叠的交给 glsl_analyzer ──────────────────────────────
-- 两个 client 挂在同一个 GLSL buffer 上：glsl_analyzer 管补全 / hover / 跳转 / 格式化 / 诊断，
-- glsld 只管 semanticTokens（变量上色）+ references（同名符号高亮，见上面第 ② 档）。
-- 不关的话 hover 会叠两份浮窗、补全候选重复。
-- 这里改 server_capabilities 而不是给 glsld 写 on_attach：能力在初始化之后才定稿，
-- LspAttach 里改完对后续所有请求分发都生效，也省掉一份和 lspconfig 默认值合并的 on_attach。
local glsld_overlap = { "hoverProvider", "definitionProvider", "completionProvider", "documentSymbolProvider" }
vim.api.nvim_create_autocmd("LspAttach", {
  callback = function(event)
    local client = vim.lsp.get_client_by_id(event.data.client_id)
    if not client or client.name ~= "glsld" then
      return
    end
    for _, cap in ipairs(glsld_overlap) do
      client.server_capabilities[cap] = nil
    end
  end,
})
