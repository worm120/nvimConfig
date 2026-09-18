-- 打开项目时自动恢复上次的 session
--
-- 行为：在某个目录下直接 `nvim`（不带任何文件名参数）时，如果该目录有上次保存的
-- session（退出时由 persistence 自动写入 stdpath("state")/sessions/），就自动恢复
-- 上次的全部 buffer 和窗口布局。带了文件参数（如 `nvim foo.c`）则不恢复，保持原样。
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
          -- 只有无文件参数启动才自动恢复
          if vim.fn.argc() ~= 0 then
            return
          end
          -- 当前还是启动时的空 buffer 才恢复（避免覆盖已经打开的东西）
          local buf = vim.api.nvim_get_current_buf()
          if vim.bo[buf].buftype ~= "" or vim.api.nvim_buf_get_name(buf) ~= "" then
            return
          end
          -- require 会触发 lazy.nvim 按需加载 persistence 并执行上面的 opts
          -- 该目录没有 session 文件时 load() 什么也不做
          require("persistence").load()
        end,
      })
    end,
  },
}