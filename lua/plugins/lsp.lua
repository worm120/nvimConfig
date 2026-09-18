return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      -- pyright 用的 python：conan 环境只在部分机器上存在，所以先判断再设置。
      -- 不判断的话，pyright 会一直拿着一个不存在的解释器（这台机器上就是如此）。
      -- 优先级：$PYRIGHT_PYTHON > ~/venvs/conan-env/bin/python；都不存在就不设
      -- pythonPath，交给 pyright 自己找（项目里的 .venv / pyrightconfig.json /
      -- 系统 python 都会按它的默认逻辑处理）。
      local venvPython = vim.env.PYRIGHT_PYTHON
        or vim.fn.expand("~/venvs/conan-env/bin/python")
      local pyrightPython = {}
      if vim.fn.executable(venvPython) == 1 then
        pyrightPython.pythonPath = venvPython
      end

      opts.servers.pyright = {
        settings = {
          python = pyrightPython,
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