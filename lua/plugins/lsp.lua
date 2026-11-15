-- 词级折行（用 strchars 计宽，中文也不会算错）
local function wrap(s, w)
  local out, cur = {}, ""
  for word in s:gmatch("%S+") do
    if cur == "" then
      cur = word
    elseif vim.fn.strchars(cur) + 1 + vim.fn.strchars(word) <= w then
      cur = cur .. " " .. word
    else
      out[#out + 1] = cur
      cur = word
    end
  end
  if cur ~= "" then
    out[#out + 1] = cur
  end
  return #out > 0 and out or { "" }
end

-- 行内诊断（virtual_lines）的文本：
-- 1) 默认只渲染 message，而 clangd/clang-tidy 把「调用链」等补充信息放在 relatedInformation
--    （浮窗 <leader>cd 会显示，virtual_lines 不会）→ 接在 message 后面；
-- 2) virt_lines 不折行，超宽会被窗口右缘静默裁掉 → 按窗口实际可用宽度自己折行。
-- 3) 检查名放方括号里：clang 的 -Wxxx 与 clang-tidy 的 misc-xxx 统一成 [xxx]；
--    不括起来的话 clang 那条开头就是个 "-"，容易被读成运算符符号。
local function diag_lines(d)
  local win = vim.fn.win_findbuf(d.bufnr)[1]
  local width = win and vim.api.nvim_win_get_width(win) or vim.o.columns
  local left = vim.api.nvim_buf_call(d.bufnr, function()
    return vim.fn.virtcol({ d.lnum + 1, d.col + 1 }) - 1 -- 树形前缀吃掉的列数
  end)
  local avail = math.max(30, width - left - 20) -- 20 = 缩进前缀 / 行号 / 符号列的余量
  local self = vim.fn.fnamemodify(vim.api.nvim_buf_get_name(d.bufnr), ":t")
  local lines = {}
  for _, ml in ipairs(vim.split((d.code and ("[" .. d.code .. "] ") or "") .. d.message, "\n")) do
    vim.list_extend(lines, wrap(ml, avail))
  end
  for _, info in ipairs(vim.tbl_get(d, "user_data", "lsp", "relatedInformation") or {}) do
    local loc = info.location
    local name = vim.fs.basename(vim.uri_to_fname(loc.uri))
    -- 同一文件里只写 L<行>:<列>，省下的宽度留给消息本身
    local where = name == self and ("L%d:%d"):format(loc.range.start.line + 1, loc.range.start.character + 1)
      or ("%s:%d:%d"):format(name, loc.range.start.line + 1, loc.range.start.character + 1)
    local head = ("    %s: "):format(where)
    local segs = wrap(info.message, math.max(20, avail - vim.fn.strchars(head)))
    for i, seg in ipairs(segs) do
      lines[#lines + 1] = (i == 1 and head or string.rep(" ", vim.fn.strchars(head))) .. seg
    end
  end
  return table.concat(lines, "\n")
end

return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- pyright 用的 python：conan 环境只在部分机器上存在，所以先判断再设置。
      -- 不判断的话，pyright 会一直拿着一个不存在的解释器（这台机器上就是如此）。
      -- 优先级：$PYRIGHT_PYTHON > ~/venvs/conan-env/bin/python；都不存在就不设
      -- pythonPath，交给 pyright 自己找（项目里的 .venv / pyrightconfig.json /
      -- 系统 python 都会按它的默认逻辑处理）。
      local venvPython = vim.env.PYRIGHT_PYTHON
        or vim.fn.expand("~/venvs/conan-env/bin/python")
      local pyrightPython = {}
      if vim.fn.executable(venvPython) == 1 then
        pyrightPython.pythonPath = venvPython
      end

      opts.servers.pyright = {
        settings = {
          python = pyrightPython,
        },
      }

      -- bash: bashls（sh/bash filetype），shellcheck 由 mason 装在 bin 里，bashls 会自动调用做 lint。
      -- 注意 filetype 是 sh，别只写 bash。
      opts.servers.bashls = {
        filetypes = { "sh" },
      }

      -- C/C++: clangd。LazyVim 的默认 servers 表里没有 clangd（只给 "*" 建 capabilities），
      -- 所以没在 opts.servers 里点名 = 压根不 enable（vim.lsp.is_enabled("clangd") == false），
      -- cpp buffer 上一个 client 都没有：不高亮、不补全、不跳转，全是「静默不生效」。
      -- clangd 由 nix 提供（clang-tools 21.x）→ mason = false；
      -- --clang-tidy 让诊断带上检查名（插件里 diag_lines 已经把 relatedInformation 一起渲染了）。
      opts.servers.clangd = {
        mason = false,
        cmd = {
          "clangd",
          "--background-index",
          "--clang-tidy",
          "--header-insertion=never",
          "--completion-style=detailed",
        },
      }

      -- GLSL: glsl_analyzer（.glsl / .vert / .frag / .comp / .geom / .tesc / .tese）。
      -- 同 clangd：LazyVim 的 servers 表里没有它，不点名就永远不 enable。
      -- 二进制由 nix 提供（pkgs.glsl_analyzer）→ mason = false。
      opts.servers.glsl_analyzer = {
        mason = false,
      }

      -- GLSL 语义高亮：glsld（二进制由 /etc/nixos/pkgs/glsld.nix 提供 → mason = false）。
      -- 起因：glsl_analyzer 1.7.1 的能力表只有 completion / definition / hover / formatting，
      -- 没有 semanticTokensProvider，而 nvim-treesitter 的 glsl 查询只抓 keyword.function /
      -- keyword.modifier / variable.builtin → 普通变量在 GLSL 里一直是素色，只有词法级同名高亮兜底。
      -- glsld 发真语义 token（legend: type/struct/parameter/variable/function/keyword/comment/
      -- number/macro/string）外加 references，但它**没有诊断和格式化**，所以两个 client 并存：
      -- 补全/hover/跳转/诊断/格式化仍归 glsl_analyzer，glsld 只管上色 + 同名符号
      -- （重叠能力在 lua/config/autocmds.lua 的 LspAttach 里关掉）。
      -- lspconfig 里没有 glsld，cmd/filetypes 必须自己写。
      opts.servers.glsld = {
        mason = false,
        cmd = { "glsld", "--stdio" },
        filetypes = { "glsl", "vert", "tesc", "tese", "frag", "geom", "comp" },
        root_markers = { ".git" },
      }

      -- xmake.lua 用的是 xmake 的 DSL（target/add_files/namespace...），不是标准 Lua，
      -- 不喂给 lua_ls 就会刷一片 undefined-global / undefined-field。
      -- 名单与定义文件由 lua/xmake-ls/gen.py 从 `xmake show -l apis` 生成。
      opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
        settings = {
          Lua = {
            diagnostics = { globals = require("xmake-ls.globals") },
            workspace = {
              -- xmake 对 os/path/table/string 等内建模块的扩展（os.projectdir 之类）
              library = { vim.fn.stdpath("config") .. "/lua/xmake-ls/defs" },
            },
          },
        },
      })

      -- 诊断看全：LazyVim 默认只有 virtual_text（消息里的换行被替换成空格压成一行，还被窗口裁掉）。
      -- virtual_lines 会把 message 按换行渲染成光标行下方的多行；diag_lines 再补上
      -- relatedInformation（调用链等）并折行。同时关掉光标行的单行摘要避免重复。
      opts.diagnostics = opts.diagnostics or {}
      opts.diagnostics.virtual_lines = { current_line = true, format = diag_lines }
      opts.diagnostics.virtual_text = vim.tbl_deep_extend(
        "force",
        opts.diagnostics.virtual_text or {},
        { current_line = false }
      )

      return opts
    end,
  },
}