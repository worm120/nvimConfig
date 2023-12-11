return {
  "nvim-telescope/telescope.nvim",
  dependencies = {
    "nvim-telescope/telescope-fzf-native.nvim",
    build = "make",
    config = function()
      require("telescope").load_extension("fzf")
    end,
  },
  keys = {
    { "<C-p>", "<cmd>Telescope find_files<CR>", desc = "Find Files" },
    {
      "<leader>fp",
      function()
        require("telescope.builtin").find_files({ cwd = require("lazy.core.config").options.root })
      end,
      desc = "Find Plugin File",
    },
    {
      "<A-d>",
      function()
        return require("telescope.builtin").lsp_definitions({ reuse_win = true })
      end,
      desc = "Goto Definition",
    },
    {
      "<A-f>",
      "<cmd>Telescope lsp_references<cr>",
      desc = "References",
    },
  },
  opts = {
    defaults = {
      mappings = {
        i = {
          -- ["<A-d>"] = function()
          --     return require("telescope.builtin").lsp_definitions({ reuse_win = true })
          --   end,
        },
      },
    },
  },
}
