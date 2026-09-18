-- Nix 语言支持（nixd）
--
-- LazyVim 的 lazyvim.plugins.extras.lang.nix（已在 lazyvim.json 启用）提供：
--   - nvim-treesitter: ensure_installed 加 "nix"
--   - conform.nvim:     nix -> nixfmt
--   - nvim-lint:        nix -> statix
--   - nvim-lspconfig:   servers.nil_ls = {}
--
-- 这里做两件事：
--   1. 关掉 extra 默认的 nil_ls（enabled = false，LazyVim 会据此把它从 mason 也排除）
--   2. 换成 nixd —— 它会读 nixpkgs 做评估，能对 option 名/值补全
--
-- nixd / nixfmt / statix 全部来自 nix（见 /etc/nixos/home.nix 的 home.packages），
-- 所以 mason = false，不让 mason 再去 GitHub 下一份重复的。
--
-- 路径和主机名都不写死：
--   * flake 路径在 attach 时从 nixd 的 workspace root 得到（root_markers 命中 flake.nix，
--     见 nvim-lspconfig/lsp/nixd.lua），找不到 flake 就退回 `import <nixpkgs> {}`，
--     只做包名补全、不做 option 补全。
--   * option 树取 builtins.head (attrValues nixosConfigurations)，不按主机名匹配 ——
--     本机 networking.hostName 是 "nixos_zn"，但 hostname / builtins.hostName 报的是
--     "nixoszn"（systemd 把下划线去掉了），按名字精确匹配反而会失配。
--   * 真有多个 nixosConfigurations 时用环境变量 NIXD_HOST 指定，例如 NIXD_HOST=desktop nvim；
--     不设置就取属性名排序里的第一个。
return {
  {
    "neovim/nvim-lspconfig",
    opts = function(_, opts)
      opts.servers = opts.servers or {}

      opts.servers.nil_ls = { enabled = false }

      --- nix 字符串里的转义
      ---@param s string
      local function quote(s)
        return (s:gsub("\\", "\\\\"):gsub('"', '\\"'))
      end

      --- 找出包含 flake.nix 的目录（flake 根），找不到返回 nil
      ---@param config vim.lsp.ClientConfig
      ---@return string?
      local function find_flake_root(config)
        local candidates = { config.root_dir, vim.fn.getcwd() }
        for _, ws in ipairs(config.workspace_folders or {}) do
          candidates[#candidates + 1] = ws.name
        end
        for _, c in ipairs(candidates) do
          if type(c) == "string" and c ~= "" then
            local found = vim.fs.root(c, "flake.nix")
            if found then
              return found
            end
          end
        end
        -- 再退回当前 buffer 自身往上找
        return vim.fs.root(0, "flake.nix")
      end

      --- 生成给 nixd 的 nix 表达式
      ---@param root string?
      local function nixd_exprs(root)
        if not root then
          return { nixpkgs = { expr = "import <nixpkgs> { }" } }
        end
        local flake = ('(builtins.getFlake "%s")'):format(quote(root))
        local cfg
        if vim.env.NIXD_HOST and vim.env.NIXD_HOST ~= "" then
          cfg = ('%s.nixosConfigurations."%s"'):format(flake, quote(vim.env.NIXD_HOST))
        else
          cfg = ("(builtins.head (builtins.attrValues %s.nixosConfigurations))"):format(flake)
        end
        return {
          nixpkgs = { expr = ("import %s.inputs.nixpkgs { }"):format(flake) },
          options = {
            nixos = { expr = cfg .. ".options" },
            home_manager = {
              expr = cfg .. ".options.home-manager.users.type.getSubOptions [ ]",
            },
          },
        }
      end

      -- nixd 的配置走两条路：initialize 的 initializationOptions（init_options）
      -- 和 workspace/didChangeConfiguration（settings）。nvim 里这两处都是同一张
      -- 表引用（runtime/lua/vim/lsp/client.lua：settings/init_options 直接取 config 的表，
      -- before_init 拿到 init_params 和 config），所以 before_init 里改了就生效，送两份更保险。
      local nixd_defaults = {
        -- nixd 自带的格式化走 nixfmt（与 conform 的 nix 格式化一致）
        formatting = { command = { "nixfmt" } },
      }

      opts.servers.nixd = {
        mason = false,
        init_options = { nixd = vim.deepcopy(nixd_defaults) },
        settings = { nixd = vim.deepcopy(nixd_defaults) },
        -- 路径要等知道打开的是哪个 buffer 才能定，放在 initialize 之前填
        before_init = function(_, config)
          local exprs = nixd_exprs(find_flake_root(config))
          for _, dst in ipairs({ config.init_options.nixd, config.settings.nixd }) do
            for k, v in pairs(exprs) do
              dst[k] = v
            end
          end
        end,
      }

      return opts
    end,
  },
}
