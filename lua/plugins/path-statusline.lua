return {
  {
    "nvim-lualine/lualine.nvim",
    opts = function(_, opts)
      -- 状态栏路径格 = lualine_c 里"只有一个函数、无额外键"的那个组件（= lualine_c[4]）。
      -- LazyVim 默认用 pretty_path()：剥掉 root/cwd 前缀、并把超过 3 段折叠成 …。
      -- 这里 length = 0 只关掉折叠 → 显示相对启动目录（项目根）的完整路径；
      -- 仓外文件回退绝对路径。继续用官方组件，保住那格的目录/文件名高亮与修改标记。
      for i, c in ipairs(opts.sections.lualine_c) do
        if type(c) == "table" and type(c[1]) == "function" and vim.tbl_count(c) == 1 then
          opts.sections.lualine_c[i] = { LazyVim.lualine.pretty_path({ length = 0 }) }
        end
      end
    end,
  },
}