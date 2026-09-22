return {
  {
    "nvim-mini/mini.jump2d",
    event = "VeryLazy",
    opts = {
      -- 标签字符（第一步的候选字符），顺序即分配顺序
      labels = "abcdefghijklmnopqrstuvwxyz",
      -- 1 = 把第二步要按的字符也提前显示出来（较暗的高亮），减少来回
      view = { n_steps_ahead = 1 },
    },
    keys = {
      -- 整屏每个词首一个（可多步）标签：按 1~3 个字符就能落到任意词
      {
        "<leader>j",
        function()
          local j2d = require("mini.jump2d")
          j2d.start(j2d.builtin_opts.word_start)
        end,
        mode = "n",
        desc = "Jump2d Word Start",
      },
    },
  },
}