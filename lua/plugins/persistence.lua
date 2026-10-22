-- 打开项目时自动恢复上次的 session
--
-- 行为：在某个目录下 `nvim` 或 `nvim .` / `nvim <目录>`（只有目录参数）时，如果该目录有
-- 上次保存的 session（退出时由 persistence 自动写入 stdpath("state")/sessions/），
-- 就自动恢复上次的全部 buffer 和窗口布局。
-- 带了真实文件参数（如 `nvim foo.c`）或参数多于一个则不恢复，保持原样。
-- 手动操作不变：<leader>qs 恢复当前目录 / <leader>qS 选择 / <leader>ql 上次 / <leader>qd 本次不保存
return {
  {
    "folke/persistence.nvim",
    -- LazyVim 默认 spec：event = "BufReadPre", opts = {}
    opts = {
      -- 默认 true 时 session 会按 git 分支分开存（目录%分支），
      -- 切分支后就找不到上次的 session 了；这里按目录存，切分支回来照样恢复。
      branch = false,
    },
    init = function()
      vim.api.nvim_create_autocmd("VimEnter", {
        once = true,
        -- 必须 nested：session 文件里是一堆 :edit / :badd，不加 nested 时
        -- 这些命令不会触发 BufRead / FileType 等 autocmd，文件类型和 LSP 都不会生效
        nested = true,
        callback = function()
          -- 参数只允许：无参数，或单个目录参数（`nvim .` 是最常见的用法）
          local argc = vim.fn.argc()
          if argc > 1 then
            return
          end
          if argc == 1 then
            local arg = vim.fn.argv(0)
            if arg == "" or vim.fn.isdirectory(arg) ~= 1 then
              return
            end
          end
          -- 当前 buffer 已经是真实文件就不覆盖
          -- （启动空 buffer 无名字；`nvim .` 时当前是 explorer 的 nofile buffer，名字也为空；
          --   目录 buffer 的名字是目录，同样视为可覆盖）
          local buf = vim.api.nvim_get_current_buf()
          local name = vim.api.nvim_buf_get_name(buf)
          if name ~= "" and vim.fn.isdirectory(name) ~= 1 then
            return
          end
          -- require 会触发 lazy.nvim 按需加载 persistence 并执行上面的 opts
          -- 该目录没有 session 文件时 load() 什么也不做
          require("persistence").load()

          -- session 恢复出来的 buffer 是 bufload 出来的，不触发 BufRead →
          -- filetype 检测没跑：文件没有语法高亮，clangd 之类的 LSP 也不会启动
          -- （在那个 buffer 里手动 :e 重载一次就恢复正常）。这里把这两件事补上。
          local function fix_session_buffers()
            local bufs = vim.api.nvim_list_bufs()
            local function is_real_file(b)
              local name = vim.api.nvim_buf_get_name(b)
              return vim.api.nvim_buf_is_loaded(b)
                and vim.bo[b].buftype == ""
                and name ~= ""
                and vim.fn.isdirectory(name) ~= 1
            end
            -- 先触发一次 BufReadPre：lazy.nvim 靠这个事件懒加载 nvim-lspconfig，
            -- 不先加载的话，下面 filetype 设好了也轮不到 LSP 启动
            for _, b in ipairs(bufs) do
              if is_real_file(b) then
                vim.api.nvim_exec_autocmds("BufReadPre", { buffer = b, modeline = false })
                break
              end
            end
            -- 走真实的检测路径（:filetype detect 还会看 shebang），match 只作兜底
            local function detect_filetype(b)
              vim.api.nvim_buf_call(b, function()
                vim.cmd("silent! filetype detect")
              end)
              if vim.bo[b].filetype == "" then
                vim.bo[b].filetype = vim.filetype.match({ buf = b, filename = vim.api.nvim_buf_get_name(b) }) or ""
              end
            end
            for _, b in ipairs(bufs) do
              if is_real_file(b) and vim.bo[b].filetype == "" then
                -- 设置 'filetype' 会触发 FileType autocmd → treesitter / ftplugin / LSP 都跟上
                detect_filetype(b)
              end
            end
          end
          -- 必须丢到下一拍。这一拍是 session 里 :edit 触发的 autocmd 上下文，
          -- did_filetype() 还是 1，而 nvim 自带的 sh/bash/ksh 检测函数
          -- （runtime/lua/vim/filetype/detect.lua 的 sh()）开头就是
          --   if fn.did_filetype() ~= 0 then return end
          -- → match/ :filetype detect 一律返回 nil，.sh buffer 的 filetype 就留空
          -- （表现：没有语法高亮、LSP 也不挂）。.c/.py 是纯字符串映射，不受影响，
          -- 所以这个坑只在 shell 脚本上露出来。schedule 之后 did_filetype()=0，检测正常。
          vim.schedule(fix_session_buffers)
        end,
      })
    end,
  },
}