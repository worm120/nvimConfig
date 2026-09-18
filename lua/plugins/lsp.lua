return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- pyright 用 conan 环境的 python
      opts.servers.pyright = {
        settings = {
          python = {
            pythonPath = "~/venvs/conan-env/bin/python",
          },
        },
      }

      -- xmake.lua 用的是 xmake 的 DSL（target/add_files/namespace...），不是标准 Lua，
      -- 不喂给 lua_ls 就会刷一片 undefined-global / undefined-field。
      -- 名单与定义文件由 lua/xmake-ls/gen.py 从 `xmake show -l apis` 生成。
      opts.servers.lua_ls = vim.tbl_deep_extend("force", opts.servers.lua_ls or {}, {
        settings = {
          Lua = {
            diagnostics = { globals = require("xmake-ls.globals") },
            workspace = {
              -- xmake 对 os/path/table/string 等内建模块的扩展（os.projectdir 之类）
              library = { vim.fn.stdpath("config") .. "/lua/xmake-ls/defs" },
            },
          },
        },
      })

      return opts
    end,
  },
}