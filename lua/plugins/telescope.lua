local Util = require("lazyvim.util")
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
        { "<leader>fF", Util.telescope("files"), desc = "Find Files (root dir)" },
        { "<leader>ff", Util.telescope("files", { cwd = false }), desc = "Find Files (cwd)" },
        { "<leader>fR", "<cmd>Telescope oldfiles<cr>", desc = "Recent" },
        { "<leader>fr", Util.telescope("oldfiles", { cwd = vim.loop.cwd() }), desc = "Recent (cwd)" },
        { "<A-g>", Util.telescope("oldfiles", { cwd = vim.loop.cwd() }), desc = "Recent (cwd)" },
        { "<leader>sW", Util.telescope("grep_string", { word_match = "-w" }), desc = "Word (root dir)" },
        { "<leader>sw", Util.telescope("grep_string", { cwd = false, word_match = "-w" }), desc = "Word (cwd)" },
        { "<leader>sW", Util.telescope("grep_string"), mode = "v", desc = "Selection (root dir)" },
        { "<leader>sw", Util.telescope("grep_string", { cwd = false }), mode = "v", desc = "Selection (cwd)" },
        { "<leader>sG", Util.telescope("live_grep"), desc = "Grep (root dir)" },
        { "<leader>sg", Util.telescope("live_grep", { cwd = false }), desc = "Grep (cwd)" },
        -- {"<C<tab>>"}
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
            layout_strategy = "horizontal",
            layout_config = { height = 0.95, width = 0.95, preview_width = 0.6 },
            mappings = {
                i = {
                    -- ["<A-g>"] = function()
                    --     -- return require("telescope.builtin").lsp_definitions({ reuse_win = true })
                    --     return Util.telescope("oldfiles", { cwd = vim.loop.cwd() })
                    -- end,
                },
            },
        },
    },
}
