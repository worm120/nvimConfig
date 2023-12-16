--https://github.com/nvim-treesitter/nvim-treesitter/issues/1888
--treesitter下载可以通过git,即开了代理也可以
require("nvim-treesitter.install").prefer_git = true

return {

    {
        "telescope.nvim",
        dependencies = {
            "nvim-telescope/telescope-fzf-native.nvim",
            build = "make",
            config = function()
                require("telescope").load_extension("fzf")
            end,
        },
    },

    -- add pyright to lspconfig
    {
        "neovim/nvim-lspconfig",
        ---@class PluginLspOpts
        opts = {
            ---@type lspconfig.options
            servers = {
                -- pyright will be autcmatically installed with mason and loaded with lspconfig
                pyright = {},
                clangd = {},
                cmake = {},
                java = {},
                jsonls = {},
                tsserver = {},
                ltex = {},
                marksman = {},
                rust_analyzer = {},
                yamlls = {},
            },
        },
    },
    { import = "lazyvim.plugins.extras.lang.python" },
    { import = "lazyvim.plugins.extras.lang.clangd" },
    { import = "lazyvim.plugins.extras.lang.cmake" },
    { import = "lazyvim.plugins.extras.lang.java" },
    { import = "lazyvim.plugins.extras.lang.json" },
    { import = "lazyvim.plugins.extras.lang.typescript" },
    { import = "lazyvim.plugins.extras.lang.rust" },
}
