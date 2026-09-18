-- 配色主题：当前用 vscode，其余几个（everforest / gruvbox / kanagawa / melange / onedark）装在这里当备选。
-- 刻意都不设 lazy，让它们启动时进 runtimepath，<leader>uC（Snacks.picker.colorschemes）才能预览切换。
return {
  -- 选定的默认配色：vscode。LazyVim 默认是 function() require("tokyonight").load() end，
  -- 这里改成字符串名 → LazyVim 走 vim.cmd.colorscheme("vscode")（LazyVim/lua/lazyvim/config/init.lua:11,252）
  {
    "LazyVim/LazyVim",
    opts = { colorscheme = "vscode" },
  },

  -- gruvbox：暖色系，contrast = "hard" 时背景 #1d2021（比 soft/medium 更硬）
  {
    "ellisonleao/gruvbox.nvim",
    init = function()
      vim.g.gruvbox_contrast_dark = "hard"
      vim.g.gruvbox_contrast_light = "hard"
    end,
    opts = { contrast = "hard" },
  },

  -- kanagawa：wave（默认）/ dragon（更暗更硬）/ lotus（浅色）
  {
    "rebelot/kanagawa.nvim",
    opts = { background = { dark = "wave", light = "lotus" } },
  },

  -- everforest：background = "hard" 提高对比
  {
    "sainnhe/everforest",
    init = function()
      vim.g.everforest_background = "hard"
    end,
  },

  -- melange：暖灰底 + 高饱和语法色（savq 出品）
  { "savq/melange-nvim" },

  -- onedark：经典的 Atom One Dark 系
  { "navarasu/onedark.nvim", opts = { style = "dark" } },

  -- vscode.nvim：VS Code 默认深色主题的复刻（Mofiqul）
  { "Mofiqul/vscode.nvim" },
}