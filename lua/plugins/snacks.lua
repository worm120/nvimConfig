return {
  {
    "folke/snacks.nvim",
    opts = {
      picker = {
        -- 打开就停在结果列表（normal 态），按 i 再进输入框打字
        focus = "list",
        sources = {
          explorer = {
            -- 显示被 git 忽略的目录（包括 repo 管理的 git worktree）
            ignored = true,
            hidden = true,  -- 同时显示隐藏文件
            -- 固定宽度设置
            layout = {
              layout = {
                width = 40,  -- 设置宽度（字符数）
              },
            },
          },
        },
      },
    },
  },
}

