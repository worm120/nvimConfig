---@type LazySpec
return {
  {
    "neovim/nvim-lspconfig",
    event = "User FilePost",
  },

  {
    "mason-org/mason.nvim",
    cmd = { "Mason", "MasonInstall", "MasonInstallAll", "MasonUpdate" },
  },

  {
    "mason-org/mason-lspconfig.nvim",
    event = "VimEnter",
    dependencies = {
      "neovim/nvim-lspconfig",
      { "mason-org/mason.nvim", opts = {} },
      "mason-org/mason.nvim",
    },
    opts = function()
      require "configs.lsp"
      return {}
    end,
  },
}
