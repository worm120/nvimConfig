# nvim 配置现状（agent.md）

给后续 AI agent / 自己看的现状快照。最后更新：2026-09-18，
本批改动 = 「nvim-treesitter 语言掉队补齐」+「session 恢复后补 filetype」+「配色：装 5 个候选主题并把默认定为 vscode」
+「去掉 `nvim .` 启动时残留的占位 buffer（[No Name] 与目录名那两格）」
+「装 nvim-treesitter-context（函数头固定在窗口顶部 = VSCode 的 sticky scroll）」。
提交主题与 hash 一律现查（`git log -1 --format=%s` / `%h`），不要抄进文档。
**不要把提交 hash 写进本文件**：amend 会改 hash，一写就自相矛盾（要 hash 用 `git log -1 --format=%h` 查）。

## 环境

- neovim 0.12.5，runtime 在 `/home/zn/nvim-linux-x86_64/share/nvim/runtime`
  （不是发行版包，**不要**读 `/usr/share/nvim`）
- 配置 = LazyVim（folke 原版，非自制 fork）+ lazy.nvim；42 个插件（含本批新装的 6 个配色主题
  + nvim-treesitter-context）
  - 插件目录 `~/.local/share/nvim/lazy/`，mason 在 `~/.local/share/nvim/mason/`
  - LazyVim 默认 spec 在 `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/*.lua`
- extras 写在两处：`lazyvim.json` 的 `extras` 数组（= `lazyvim.plugins.extras.ui.treesitter-context`）
  由 `LazyVim/lua/lazyvim/plugins/xtras.lua:32-46` 自动转成 `{ import = … }`，`:LazyExtras` 里能看到已启用；
  python / rust extra 则是在 `lua/config/lazy.lua` 里直接 `import = "lazyvim.plugins.extras.lang.python"`
  —— 那种写法在 `:LazyExtras` 界面里显示不出启用状态
- `noice.nvim` 没有任何自定义覆盖 → 行为即 LazyVim 默认
- 这份配置的 git 仓库 origin 仍是 `https://github.com/LazyVim/starter`（上游 starter，不是自有远端）：
  只做本地提交，不要 push

## 文件结构与本地定制

```
init.lua
lua/config/{options,keymaps,autocmds,lazy}.lua
lua/plugins/{lsp,persistence,snacks,colorscheme,example,treesitter,bufferline}.lua
lua/xmake-ls/{gen.py,globals.lua,defs/xmake-defs.lua}   # lua_ls 认 xmake 用，见下
```

- `lua/config/options.lua`：`wrap`、`linebreak`、`breakindent` = true（长行按词换行，保持缩进）；
  `relativenumber = false`（行号显示绝对行号，见"编辑器行为备忘"）
- `lua/config/keymaps.lua`：Alt 系键位
  - `<A-d>` 定义、`<A-s>` 跳回（`<C-o>`）
  - `<A-r>` 引用 → `Snacks.picker.lsp_references()` 浮窗（Esc 关）；**别改回** `vim.lsp.buf.references`，那是底部 quickfix
  - `<A-]>` / `<A-[>` 下/上一个 buffer，`<A-a>` 上一次 buffer（`b#`）
  - `<A-j>` / `<A-k>` 不移动光标滚屏（`<C-E>` / `<C-Y>`）
  - 插入模式连按 `jj` = `<Esc>`（只绑 `i` 模式，命令行不受影响）
- `lua/config/lazy.lua`：import python extra、**rust extra**；
  禁用 rtp 插件 gzip / tarPlugin / tohtml / tutor / zipPlugin
- `lua/config/autocmds.lua`：两条自定义 autocmd —— `UIEnter` 后清掉 `nvim .` 残留的占位 buffer
  （[No Name] 与目录名那格，见"功能 6"），以及 `UIEnter` 后把焦点从 explorer 侧栏还给文件窗口
  （见"功能 10"）；session 恢复的 autocmd 仍在 plugins/persistence.lua 里
- `lua/plugins/snacks.lua`：explorer 显示 gitignored + 隐藏文件，固定宽度 40；
  picker 全局 `focus = "list"`（打开停在结果列表 = normal 态，按 `i` 才进输入框）—— 见"功能 9"
- `lua/plugins/lsp.lua`：opts 用 `function(_, opts)` 形式（为了保留其它 server 的设置不被覆盖）
  - pyright → `~/venvs/conan-env/bin/python`
  - lua_ls → 喂 xmake 的 API 名单和定义库（见"功能 2"）
- `lua/plugins/treesitter.lua`：把手工装过的语言补进 nvim-treesitter 的 `ensure_installed`
  （LazyVim 的 spec 带 `opts_extend = { "ensure_installed" }`，是追加不是覆盖）—— 见"功能 3"
- `lua/plugins/colorscheme.lua`：默认配色 everforest（hard 对比度）+ 4 个备选主题 —— 见"功能 5"
- `lua/plugins/bufferline.lua`：只关掉 tab 名字截断（`truncate_names = false`）—— 见"功能 8"

## 功能 1：打开项目自动恢复上次 session

- 实现在 `lua/plugins/persistence.nvim`（LazyVim 自带插件）的覆盖：`lua/plugins/persistence.lua`
  - `VimEnter` autocmd（`once = true`，**`nested = true`**）：满足触发条件、且当前 buffer 不是
    真实文件（无名 buffer / 目录 buffer 都算可以覆盖）时 `require("persistence").load()`
- 触发条件（2026-09-18 起）：**无参数，或单个目录参数**（`nvim .` / `nvim <目录>`）都自动恢复；
  带真实文件参数或参数多于一个则不恢复
  - 为什么必须支持 `nvim .`：这个用户的实际习惯就是 `nvim .`（zsh history 里几乎每次），
    老守卫 `argc() ~= 0 → return` 把他最主要的启动方式全挡掉了
  - 老守卫第二重（`buftype ~= "" or 名字非空 → return`）也会误杀：`nvim .` 时 VimEnter 那一刻
    当前 buffer 已经是 snacks explorer 的临时 buffer（`buftype=nofile`, `ft=snacks_picker_list`，
    名字为空）→ 新守卫只看"名字非空且不是目录"才拒绝
  - 恢复后 explorer 侧栏（`snacks_picker_list` / `snacks_picker_input` 浮窗）仍在，**且仍是当前窗口**
    （tmux 实测光标 `cursor=0,4` 落在侧栏里）；按一次 `Esc` 关掉侧栏、焦点回到文件窗口，
    `<C-w>w` 无效（那时只剩一个非浮动窗口）；与手按 `<leader>ql` 的效果一致
  - `opts = { branch = false }`
- session 键 = **启动 nvim 时的工作目录**（路径转义，如 `%home%zn%tmp.vim`），存在
  `~/.local/state/nvim/sessions/`
  - `branch = false` 表示**不**按 git 分支区分。LazyVim/上游默认是"目录%分支"，
    切到没存过的分支就永远恢复不了，与"打开项目即续上"的目标相悖
- 退出时保存（`need = 1`：至少一个"有名字且非常规 buftype"的 buffer，否则不落盘）
- 手动键不变（`<leader>` = 空格）：`<leader>qs` 恢复当前目录、`<leader>qS` 选择 session、
  `<leader>ql` 上次、`<leader>qd` 本次退出不保存
- **恢复后补 filetype**（2026-09-18 加，修"`nvim .` 恢复出来的文件没高亮、clangd 也不启动"）：
  session 恢复出来的 buffer 是 bufload 来的，**不触发 BufRead** → filetype 检测没跑
  （`vim.bo.filetype` / `syntax` / `b:did_filetype_lua` 全空）→ treesitter 不挂、LSP 也不启动。
  `require("persistence").load()` 之后跑 `fix_session_buffers()`：先对第一个"真实文件"buffer
  触发一次 `BufReadPre`（lazy.nvim 靠这个事件懒加载 nvim-lspconfig，不先加载则后面 filetype
  设好了也轮不到 LSP），再给所有"已加载 + filetype 空 + 名字非空且不是目录"的 buffer 用
  `vim.filetype.match({ buf = …, filename = … })` 补 filetype（设置 'filetype' 会触发 FileType）
  实测（tmux 真 TTY，`nvim .` in modules/drivers/src）：恢复后 `ft=cpp`、`clients={clangd}`、
  `hl_active=true`；补丁前是 `ft=""`、`clients=0`、`hl_active=false`
  只在走了"自动恢复"那条路径时执行（守卫的 return 在它之前），`nvim <file>` 不受影响
- 为什么用 autocmd 而不是插件自带开关：persistence.nvim 这个 commit **没有** autoload 选项
  （README 明说"永不自动恢复，但你可以自己写 autocmd"）；LazyVim 只把它挂在 `BufReadPre`，
  无参数启动时那次 `require("persistence")` 靠 lazy.nvim 的 module loader
  （`lazy/core/loader.lua` 的 `M.loader`/`M.auto_load`）按需加载插件并执行 opts
- **历史遗留（仍在生效，注意）**：`branch = false` 之前存的 session 文件名带分支
  （如 `...byd_adas_vcpb%%dev%ovrs_vcpb%arlp.vim`），而 `M.load()` 现在只看**目录键**：
  旧文件不可达。**项目根目录目前就处于这个状态**（只有旧的分支键文件），所以在根目录自动恢复
  依然不生效，直到根目录键生成一次。两种解法：
  - 在根目录 `nvim .` → `<leader>qS` 选那个旧 session → 正常退出（退出时按 cwd 写成目录键）
  - 或直接把旧文件复制成目录键（等价，原文件保留）
- **这个 bug 会自锁**：载入的 session 自己带 `cd <它记录的目录>`，退出时按**新的 cwd** 存 →
  在 A 目录启动、载入 B 目录的 session，退出就写成 B 键，A 键永远生不出来（实测就是这么循环的）
- 存什么内容由 `sessionoptions` 决定，LazyVim 设的是
  `buffers,curdir,tabpages,winsize,help,globals,skiprtp,folds`
  （`LazyVim/lua/lazyvim/config/options.lua:91`）

## 功能 2：lua_ls 认识 xmake.lua（xmake DSL）

- 症状（改之前）：打开 `xmake.lua` 一片告警 —— 16 个 `undefined-global`
  （`namespace` / `includes` / `target` / `set_kind` / `set_toolchains` / `add_deps` / `add_files` …）
  + 1 个 `undefined-field`（`os.projectdir`）。`vim.lsp.get_clients()` 里只有 `lua_ls`，
  与 clangd / pyright 无关 —— xmake 的 DSL 是脚本沙箱里动态注入的全局，lua_ls 不认识
- 修法（`lua/plugins/lsp.lua`）：
  - `Lua.diagnostics.globals = require("xmake-ls.globals")` —— 268 个 xmake API 名
  - `Lua.workspace.library = { <config>/lua/xmake-ls/defs }` —— 330 条 `---@meta`，
    声明 xmake 对 `os` / `path` / `table` / `string` 等内建模块的扩展（`os.projectdir()` 之类）
- 两个数据文件由 `lua/xmake-ls/gen.py` 生成，数据来源：
  1. `xmake show -l apis` —— xmake 自己的 API 注册表（`core/project/project.lua` 的 `project.apis()`）
  2. 一个临时 xmake 项目，逐个"字面引用"探测候选名在本版本里是否真是脚本作用域的全局
- 重新生成（xmake 升级后跑一次，约 0.4s）：
  ```bash
  python3 ~/.config/nvim/lua/xmake-ls/gen.py
  ```
- 实测（真配置，无头）：5 个 `xmake.lua` 的诊断 17 → **0**，`globals=268`，`lib=.../lua/xmake-ls/defs`；
  普通 lua 文件诊断数不变；pyright 的 `pythonPath` 仍生效

### 做这件事踩过的坑

- `xmake show -l apis` 的输出带 ANSI 颜色码，必须先用 `\x1b\[[0-9;]*[A-Za-z]` 剥掉再切词，
  否则 token 匹配失败（曾因此漏掉 `os.projectdir`，害得 stub 里没有它）
- xmake 沙箱里 `_G`、`getmetatable`、`io` 都是 nil：探测只能写
  `if add_files ~= nil then … end` 这种字面引用，且要在项目作用域与 `target("x")` 块里各探一遍
  （root scope 就是 target，见 `core/project/project.lua` 的 `rootscope_set("target")`）；
  沙箱脚本里 `target("x")` 块**不用** `end` 收尾
- `namespace` / `includes` / `target` / `option` 这些构造器**不在** `show -l apis` 里，
  得从 `project.apis()` 取再探测确认
- 给 lua_ls 设 `workspace.library` 不会顶掉 lazydev.nvim 的 vim 类型：lazydev 是
  `table.insert` 往已有 library 里追加（`lazydev/workspace.lua:181-184`），且 LazyVim 自己没设这个键
- 覆盖 LazyVim 的 server 设置要用 `opts = function(_, opts)` 并把原有设置（如 pyright）写进函数体，
  否则 table 合并语义可能把原有设置换掉

## 功能 3：nvim-treesitter 的语言不掉队（ensure_installed）

- 症状：更新 LazyVim/插件后，某个语言（这次是 cpp）的文件**完全没有语法高亮**，
  而同会话里 clangd 照常工作（inlay hints、诊断都在）→ 极易误判成"clangd 不工作"
- 机制：nvim-treesitter main 新版把 parser 编译到 `~/.local/share/nvim/site/parser/*.so`，
  queries 用 `site/queries/<lang>` 软链指向插件的 `runtime/queries/<lang>`（插件根目录的
  `queries/` 已不存在，`runtime/` 不在 rtp 上）；插件更新时只重建 `ensure_installed` 里的
  语言，手工 `:TSInstall` 过的语言会掉队 —— 旧 `.so` 留在插件老目录（`get_parser` 仍返回 OK），
  但 highlights query 找不到，高亮静默失效
- 诊断（nvim 内）：`vim.api.nvim_get_runtime_file("queries/cpp/highlights.scm", true)` 为空；
  `nvim_get_runtime_file("parser/cpp.so", true)` 只命中 `lazy/nvim-treesitter/parser/cpp.so`
- 修：`:TSInstall <lang>`（从 github 拉源码本地编译 → **国内必须走代理**：让 nvim 带
  `HTTPS_PROXY=http://127.0.0.1:7890` 启动，否则 curl 卡在 0 字节）。产物三件套：
  `site/parser/<lang>.so`、`site/parser-info/<lang>.revision`、`site/queries/<lang>`
- 持久化：写进 `lua/plugins/treesitter.lua` 的 `opts.ensure_installed`。
  验证：`LazyVim.opts("nvim-treesitter").ensure_installed` = 49 个（默认 25 + 本次补的 24）
- 2026-09-18 补齐：comment cpp css csv cue editorconfig fish gitattributes gitcommit git_config
  gitignore git_rebase graphql haskell http json5 just make readline scss sql ssh_config svelte zig
  （`jsonc` 已并入 `json`、nvim-treesitter 里没有它的 parser 定义，别写进列表）
- 插件老目录 `lazy/nvim-treesitter/parser/*.so` 暂时**别删**：掉队语言当时只有那份可用

## 功能 4：Rust 支持（2026-09-18 配）

- 三块拼起来：treesitter `rust` + `ron`、系统的 rust-analyzer、LazyVim 的
  `lazyvim.plugins.extras.lang.rust`（在 `lua/config/lazy.lua` 里 import，和 python extra 一样）
- rust-analyzer 来自 rustup：`rustup component add rust-analyzer`（本机 1.97.1）。
  **坑**：`~/.cargo/bin/rust-analyzer` 是 rustup 的 shim，组件没装时文件存在、`executable()`
  也返回 1，但一执行就报 `Unknown binary 'rust-analyzer' in official toolchain` —— 判断是否
  可用要真的跑一次 `rust-analyzer --version`。国内装组件走镜像：
  `RUSTUP_DIST_SERVER=https://mirrors.ustc.edu.cn/rust-static rustup component add rust-analyzer`
- extra 带来：crates.nvim（Cargo.toml 补全/hover）、rustaceanvim（LSP 集成、`<leader>cR`、
  `<leader>dr`）、mason 里的 codelldb（DAP 调试）；treesitter 的 rust/ron 由 extra 的
  `ensure_installed` 管，**不用**再写进 `lua/plugins/treesitter.lua`
- 实测（tmux 真 TTY，`~/tmp-disk1/Document/program/nil/crates/ssr/src/tests.rs`）：
  `FT=rust`、`HL_ACTIVE=true`、`QUERY=true`、`CLIENT=rust-analyzer`，屏幕上能看到它的 inlay hints
- **坑**：同一个会话里先打开 .rs、之后才 `:TSInstall rust` → LazyVim 在 FileType 那一刻判定
  "parser 不存在"就不启动高亮器，装完不会重试（重开文件/会话才生效；老会话里手动
  `vim.treesitter.start(0)` 也能救）。本次就踩了这个：老会话 `HL_ACTIVE=false`、新会话 `true`

## 功能 5：配色 / 对比度（2026-09-18 换 everforest）

- 起因：LazyVim 默认 tokyonight（`style = "moon"`）的注释/行号对比度偏低。实测 WCAG 相对亮度比
  （注释 / 行号 / 隐藏字符 vs 背景，数字由下面的"无头配色探针" dump 后算出）：
  - tokyonight-moon **3.11 / 1.56 / 2.34**（night 2.76、storm 2.35 → 换 tokyonight 变体只会更糊）
  - melange 6.65 / 3.39 / 3.39、catppuccin-mocha 5.81 / 1.80 / 3.36、gruvbox(hard) 4.47 / 3.37 / 1.86、
    **everforest(hard) 4.24 / 1.95 / 1.70**、kanagawa-dragon 4.17、onedark 2.32（比 tokyonight 还差）
  - vscode.nvim（VS Code 深色复刻，bg `#1f1f1f`）4.95 / 2.39 / 2.39 —— 实测比 everforest 还高，
    语法色 Function 11.66 / Identifier 11.05 / Number 9.70 也最亮
- 当前选择：**vscode**（`Mofiqul/vscode.nvim`，bg `#1f1f1f`；真 TTY 实测 `colors_name=vscode`），
  写在 `lua/plugins/colorscheme.lua`：`{ "LazyVim/LazyVim", opts = { colorscheme = "vscode" } }`
  —— 覆盖 LazyVim 默认的 `function() require("tokyonight").load() end`
  （`LazyVim/lua/lazyvim/config/init.lua:11`；传字符串时走 `vim.cmd.colorscheme`，同文件 252）
- 主题自己的 `g:` 开关写在该主题 spec 的 `init` 里即可（上一版默认 everforest 的 hard 档 =
  `vim.g.everforest_background = "hard"`）：spec 的 `init` 早于 LazyVim 加载配色（实测读回
  `g:everforest_background=hard`、Normal bg `#272e33`），**不需要**挪进 `lua/config/options.lua`
  （`vim.g.gruvbox_contrast_dark = "hard"` 同理）
- 换主题的先后：LazyVim 默认 tokyonight(moon) → everforest(hard) → **vscode**（当前）
- 备选主题（同一个文件里、已装、随时可切）：everforest（spec 里已设 hard）、gruvbox（contrast hard）、
  kanagawa（三个名字：`kanagawa`/`-wave`、`kanagawa-dragon`、`kanagawa-lotus`）、melange、onedark
  （`vscode.nvim` 只提供名字 `vscode`，颜色文件就一个 `colors/vscode.lua`）
- 预览 / 临时切换：`<leader>uC` → `Snacks.picker.colorschemes()`（LazyVim 的 snacks picker extra，
  `extras/editor/snacks_picker.lua:111`；`install_version ≥ 8` 时 picker 默认就是 snacks，
  见 `lazyvim/config/init.lua` 的 `get_defaults`）—— 松手即恢复，不写配置
- **新建配色主题插件不要设 `lazy = true`**：lazy 时插件目录不进 runtimepath，
  `:colorscheme <name>` 和上面那个 picker 都看不到它（LazyVim 自带的 tokyonight/catppuccin
  是 lazy 的，靠 `require("tokyonight").load()` 才被拉起来）
- 装主题/插件走代理（本机 github 直连不通）：
  `HTTPS_PROXY=http://127.0.0.1:7890 nvim --headless -c 'lua require("lazy").install({ wait = true })' -c 'lua pcall(function() require("persistence").stop() end)' -c 'qa!'`

## 功能 6：`nvim .` 启动时 bufferline 前几格的占位 buffer（[No Name] / 目录名）（2026-09-18 修）

- 现象：`nvim .` 打开目录后，bufferline 前几格总被「参数目录」相关的占位 buffer 占掉 ——
  先是 `[No Name]`，再是目录名（`src/`），然后才是真文件
- 两类来源（tmux + 启动探针实测；探针把 `vim.api.nvim_create_buf` / `nvim_buf_set_name` / `vim.fn.bufadd`
  全包了一层打 traceback，所以下面每条的归属都有调用栈证据）：
  - `[No Name]`：nvim 为参数「目录」建 1 号 buffer；LazyVim 的文件树是 snacks.explorer，其
    `replace_netrw` 默认 true → 删掉 netrw 的 FileExplorer augroup，自己挂 `BufEnter` 处理目录 buffer
    （`snacks.nvim/lua/snacks/explorer/init.lua:27-69`）。**启动阶段**（`vim.v.vim_did_enter == 0`）
    它只把该 buffer 的**名字清空**、不删 buffer：`nvim_buf_set_name(ev.buf, "")`
    （init.lua:38-40，原注释 "clear bufname so we don't try loading this one again"）→ 名字空了就是
    [No Name]；**启动之后**（如 `:e .`）才走 `Snacks.bufdelete.delete(ev.buf)`（init.lua:51-54）
    → 所以只有启动那一次会冒出来
  - 平时连 [No Name] 都看不见，是因为 snacks dashboard 在 UIEnter 时把 1 号 buffer 收编成自己的
    scratch（`snacks/dashboard.lua:1183` `M.open({ buf = buf, win = wins[1] })` → buftype=nofile +
    unlisted）；**有 session 自动恢复时**（VimEnter 已把真文件放进那个窗口）dashboard 直接放弃，实测
    `Snacks.dashboard.status = { did_setup=true, opened=false, reason="window does not contain the
    first buffer" }` → 1 号 buffer 原样留着，才在 bufferline 上现身
  - 目录名那格（`src/`）：**nvim 自己**为参数目录保留的 buffer（C 侧创建，探针里没有任何 Lua 调用
    捕获到它的创建），session 文件里存着 `%argdel` + `$argadd <目录>`（旧版是 `badd +1 <目录>`），
    恢复时把它变 `listed=true` → 上 bufferline。**A/B 实测**：同一个干净目录，没有 session 时那个
    目录 buffer `listed=false`、bufferline 根本不显示；一旦该目录有 session，第一格就是 `src/`
- 修法（`lua/config/autocmds.lua`，本配置唯一的自定义 autocmd）：`UIEnter`（once）+ `defer_fn(…, 200)`
  后，若参数是单个目录，删除满足「listed + 未修改 + buftype 空 + **（名字空 或 名字是目录）** + 行数 ≤ 1
  + 不在任何窗口里」的 buffer；这些条件正好把 dashboard 的 scratch buffer（buftype=nofile）与有名字的
  真文件排除在外
- 实测（tmux 真 TTY，`nvim .` in `modules/drivers/src`）：bufferline 只剩
  `canbus_receiver_p… | canbus_data_colle…`；`ls!` 里 1 号与 2 号 buffer 都已删除（从 3 号开始），
  参数表仍留着那个目录（`argv` 不变）、文件 buffer 与窗口布局不变；
  收尾 `persistence.stop()` → `:qa!`，session 文件 sha1 前后一致
- 想临时手动清（没改配置时）：对着那个 tab 按 `<leader>bd`，或 `:bd1` / `:bd2`（session 在的话下次启动还会回来）
- 定位这类问题的现成手段：查正在跑的 nvim 时顺手读
  `require("snacks.dashboard").status`（opened / reason）与每个 buffer 的
  `buflisted` / `buftype` / `win_findbuf` —— "为什么这个 buffer 在/不在 bufferline" 基本就看这三样

## 功能 7：函数头固定在窗口顶部（sticky scroll，2026-09-18 装）

- 起因：用户问「能不能让第一行始终保持在函数名那一行（VSCode 默认行为）」。nvim **本体没有**这个功能
  （0.12.5：`grep -ri sticky $VIMRUNTIME/doc` 无命中；syntax 文件里的 sticky 是关键词，无关）
- 用插件 `nvim-treesitter/nvim-treesitter-context`，LazyVim 自带 extra
  `lazyvim.plugins.extras.ui.treesitter-context`（默认不启用），spec 见
  `LazyVim/lua/lazyvim/plugins/extras/ui/treesitter-context.lua`
- 启用：把 extra 名写进 `lazyvim.json` 的 `extras` 数组（不要改 lazy.lua）→ `:LazyExtras` 也显示为启用
- LazyVim 给的默认 `opts = { mode = "cursor", max_lines = 3 }`，切换键 `<leader>ut`
  （`Snacks.toggle`，实测 `maparg("<leader>ut","n",0,1).desc` = "Toggle Treesitter Context"）；
  插件自身默认 `max_lines = 0`（不限行），要求 nvim ≥ 0.9 + 该语言的 parser
- 实测（tmux 真 TTY，`/tmp/tsc_test.cpp`，光标 line 45，窗口 30 行）：屏幕顶部依次是
  `2 namespace demo {` / `4 class Widget {` / `6 int LongMethod(int seed) {`，其下才是真正的 line 24 起的函数体
  → 三层祖先各占一行；`require("treesitter-context.config")` 读回 `mode=cursor max_lines=3`
- 只想要一行函数签名（丢掉外层 namespace/class）：spec 的 `opts` 改 `max_lines = 1`
  （`trim_scope` 默认 `outer`，超行数先丢最外层 = 留下的正是最内层函数签名）
- 只影响显示：`enabled=true` 时由插件维护一个浮窗，`<leader>ut` 可随时关掉；收尾照例
  `persistence.stop()` → `:qa!`（sessions sha1 前后一致）

## 功能 8：bufferline 显示完整文件名（2026-09-20 改）

- 症状：顶部 tab 行里长文件名被砍成 `canbus_receiver_p…`
- 原因：bufferline 默认 `truncate_names = true` + `max_name_length = 18`（`tab_size = 18`）——
  `bufferline.nvim/lua/bufferline/config.lua:651-653`；`get_max_length()`（`bufferline/ui.lua:358-372`）
  在 `truncate_names` 为 true 时返回 18，`utils.truncate_name`（`utils/init.lua:262`）按宽度截断再加 `…`
  （`constants.ELLIPSIS`，U+2026）。LazyVim 的 spec（`lazyvim/plugins/ui.lua:20-52`）没有覆盖这两项
- 改法：`lua/plugins/bufferline.lua` 只写 `opts.options.truncate_names = false`；lazy.nvim 与 LazyVim 的
  spec 深度合并 —— 实测 `close_command` 仍是 function、`offsets` 仍是 2 个、`diagnostics = nvim_lsp` 都在
- 实测（tmux 真 TTY，120 列，两个 34 字符文件名）：改前 `canbus_receiver_p… / raw_can_to_uplink…`，
  改后两格都是完整名；`require("bufferline.config").options.truncate_names == false`
- 取舍：名字不再截断后，整行超出窗口宽度时 bufferline **不改名字**，而是整块隐藏靠边的 tab 并显示
  `left_trunc_marker` / `right_trunc_marker`（默认 U+F0A8 / U+F0A9，config.lua:647-648）。
  想折中：删掉这行、改成 `max_name_length = 40`（保留截断但放宽阈值）
- 生效：bufferline 是 `event = "VeryLazy"`，改完要新开一个 nvim；只想临时看效果用运行时
  `:lua require("bufferline.config").options.truncate_names=false` + `:redrawtabline`（不用改文件）
- 别把 `enforce_regular_tabs` 设 true：那会让 `get_max_length` 走 `tab_size - icon - padding`，名字又被 18 卡住

## 功能 9：picker 打开时停在结果列表（normal 态）（2026-09-20 改）

- 需求：打开 snacks picker 不要直接进插入模式，先能 `j`/`k` 选，要打字再按 `i`
- 机制：`picker:show()` 只聚焦一次（`picker/core/picker.lua:484-496`，条件是
  `opts.focus ~= false and opts.enter ~= false`），焦点目标 = `opts.focus`（默认 `"input"`）；
  **输入框一进窗口就强制插入** —— `picker/core/input.lua:54-63` 的 buffer-local `BufEnter` 无条件
  `vim.cmd("startinsert!")`，没有配置开关 → 想让 picker 以 normal 态打开，只能把焦点交给**结果列表窗口**
  （普通窗口，不触发那段 autocmd）
- 改法：`lua/plugins/snacks.lua` 的 `opts.picker.focus = "list"`（全局生效；实测运行时改
  `Snacks.config.picker.focus` 对不传 opts 的 picker 也生效）。只想给某一个 picker 用：
  `Snacks.picker.lsp_references({ focus = "list" })`
- 实测（tmux 真 TTY，**全新**启动的 nvim + 真按键）：`Alt+R` 引用 → `mode=n ft=snacks_picker_list`；
  按 `i` → `mode=i ft=snacks_picker_input`；`Space e` explorer 侧栏同样 `mode=n` 落在 list 窗口
- 副作用：打开后直接敲字母不再进搜索框（列表窗口里那些键另有含义：`q` = 关闭、`j`/`k` = 上下选、
  `G`/`gg` = 首尾）；必须按 `i`（列表窗口 `i` = `focus_input`，`config/defaults.lua:322`）才进输入框
- `enter = false` **不是**这个用途：那是不聚焦任何 picker 窗口（焦点留在原文件窗口，只能鼠标点进去）

## 功能 10：`nvim .` 启动后焦点落在文件 buffer 上（2026-09-20 加）

- 现象：`nvim .` 启动后焦点被 snacks explorer 侧栏浮窗抢走（实测从启动 775ms 起，当前窗口一直是
  `relative="win"` + `ft=snacks_picker_list`）；以前靠手动按一次 Esc，但 Esc 会把侧栏也一起关掉
- 根因：启动路径里 explorer **自己**注册了一个 UIEnter autocmd 并无条件 `p:focus()`
  （`snacks/explorer/init.lua:41-51`，注释原文 "focus on UIEnter, since focusing before doesn't work"），
  绕过 picker 的 `focus` / `enter` 配置 —— 所以 `focus = false` 之类配置在**启动时无效**（实测只在启动
  之后手动开 explorer 时才生效），官方没有"保留侧栏但不抢焦点"的开关
- 修法（`lua/config/autocmds.lua`）：UIEnter + `defer_fn(…, 200)` 后，对
  `Snacks.picker.get({ source = "explorer" })` 逐个 `vim.api.nvim_set_current_win(picker.main)`
  （`picker.main` = 启动时那个文件窗口）。**必须 defer**：本文件的 UIEnter autocmd 注册得比 explorer
  那个早，同步切焦点会被它随后的 `p:focus()` 抢回去
- 侧栏保留不需要额外配置：explorer 源自带 `auto_close = false`（`picker/config/sources.lua:50-65`，
  还有 `focus = "list"`、`layout = { preset = "sidebar", preview = false }`），焦点离开不会触发 picker
  的自动关闭。反过来说，**通用 picker 的 `auto_close` 默认是 true**（一离开就自己关），所以这套别照搬到别的 picker
- 冷启动实测（tmux 真 TTY，`nvim .` + session）：1000/2000/3500/6000/15000/25000ms 全部是
  `win=1000 relative="" ft=cpp explorer_open=true`；屏幕上左侧侧栏在、文件内容在右侧，
  按 `j` 光标动在文件窗口（`cursor=305`，状态栏是 .cc 文件）
- 想恢复旧行为（启动焦点在侧栏）：删掉这条 autocmd 即可

## 编辑器行为备忘

- 滚动时窗口顶部钉住的函数/类签名（sticky scroll，VSCode 的效果）来自插件
  nvim-treesitter-context，**不是** nvim 本体功能（见"功能 7"）；`<leader>ut` 可随时开关
- `shift+K` 的 LSP hover 是 noice 浮窗（view hover，`enter = false` 不可聚焦）：
  滚动靠鼠标滚轮，键盘用 LazyVim 内置 `<C-f>` / `<C-b>`（→ `noice.lsp.scroll(±4)`）；
  光标一移动（`CursorMoved`）窗口就 autohide 关闭，所以 `j`/`k` 没用
- 行号是**绝对行号**（`lua/config/options.lua` 里 `vim.opt.relativenumber = false`，覆盖 LazyVim
  默认的 `number` + `relativenumber` 双开）；行号栏由 `snacks.statuscolumn` 渲染，
  `rnu = false` 时取 `vim.v.lnum`（`snacks/statuscolumn.lua:264-273`）
  - `<leader>uL`（`Snacks.toggle.option("relativenumber")`，LazyVim keymaps.lua:146）是 **local scope**，
    只切换**当前窗口**，新开的分屏还是绝对行号、重启也恢复 → 想临时看相对行号可以，但别指望它全局生效
  - 别用 `<leader>ul`：`Snacks.toggle.line_number()` 是把 `number` 和 `relativenumber` **一起关掉**，
    行号会整个消失（`snacks/toggle.lua:186-203`）
- 「查找引用的窗口怎么关」（2026-09-20）：`<A-r>` 已改用 `Snacks.picker.lsp_references()` → 浮窗，`Esc` /
  `<C-c>` / `q` 关。**若按成 LazyVim 的 `gr`**（LSP buffer 里是 buffer-local 的 `vim.lsp.buf.references`），
  它是 nvim 原生默认行为 `setqflist` + `:botright copen`（`$VIMRUNTIME/lua/vim/lsp/buf.lua:909-910`）
  → 底部 quickfix 普通分屏，**Esc 关不掉**，用 `:q` / `<C-w>c` / `<leader>xq`（LazyVim `keymaps.lua:108-114`
  的 cclose/copen 开关）；`<leader>sq` 是 picker 版 quickfix，`[q`/`]q` 上下条跳。本机 nvim 里 `<C-r>`
  六种模式全无映射（就是 redo），"查找引用" 从来不是 Ctrl+R
- 插入模式连按 `jj` 退出到 normal（`lua/config/keymaps.lua`，rhs 是 `<Esc>` 而不是 `<C-c>` —— 后者不触发
  `InsertLeave`，`doc/insert.txt:45-48`）：单敲一个 `j` 要等 `timeoutlen` 才落字（LazyVim = 300ms，
  `lazyvim/config/options.lua:108`）；picker 输入框也是 insert 态，所以在搜索框里敲 `jj` 会先退出插入（按 `i` 回去）。
  blink.cmp 默认 insert 键位没有 `j`/`k`，不会截胡
- 回答"某个键是什么"这类问题：去 `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/*.lua`
  和插件源码里读，不要凭记忆或上游网页
- "文件没高亮 / clangd 不工作"的诊断顺序：先 `vim.bo.filetype`（空 → filetype 检测没跑，
  见"功能 1"的 `fix_session_buffers`，或手动 `:e` 一次），再看
  `vim.treesitter.query.get(lang, "highlights")`（空 → treesitter 掉队，见"功能 3"），
  最后才看 `vim.lsp.get_clients()`。clangd 由 FileType 驱动，filetype 空时它也不会启动

## 无头验证配方（改配置前后都用它，别靠肉眼）

```bash
# 1) 打开文件看诊断 / 客户端
nvim --headless <file> -c 'lua vim.defer_fn(function()
  local ds = vim.diagnostic.get(0); local cs = {}
  for _, c in ipairs(vim.lsp.get_clients({ bufnr = 0 })) do cs[#cs+1] = c.name end
  io.write(("%s diag=%d clients={%s}\n"):format(vim.fn.expand("%:."), #ds, table.concat(cs, ",")))
  for i, d in ipairs(ds) do if i <= 5 then io.write(("%d:%d %s %s\n"):format(d.lnum+1, d.col+1, tostring(d.code), d.message)) end end
  pcall(vim.api.nvim_del_augroup_by_name, "persistence")   -- 别让这次运行写 session
  vim.cmd("qall!")
end, 9500)'
```

- 打印一律放进 `vim.defer_fn(…, 9000+)`：`-c` 命令与 `VimEnter` 的先后不确定，
  直接 `print` 会读到 LSP 还没反应的状态
- **副作用提醒**：无头打开文件后退出，persistence 也会按 cwd 写 session（`qall` 前
  `pcall(vim.api.nvim_del_augroup_by_name, "persistence")` 可避免）；
  同理，Hermes 的 `write_file` / `patch` 工具会用 headless nvim（cwd = `$HOME`）做 lint，
  它退出时会写 `~/.local/state/nvim/sessions/%home%zn.vim` —— 那个不是真项目 session
- **看/比配色（对比度）用无头就够**（配色只依赖高亮表，不需要 UI）：`:colorscheme <name>` 之后 dump
  `vim.api.nvim_get_hl(0, { name = "Comment", link = false })` 的 fg + `Normal` 的 bg，
  再按 WCAG 相对亮度算 `(L1 + 0.05) / (L2 + 0.05)`；`--clean` + `--cmd 'set rtp+=<插件>'` 也能只看
  单个主题（不加载用户配置）。**坑：同一进程里连续切多个配色会串味** —— 先 `:colorscheme tokyonight-day`
  会把 `background` 设成 light，后面的 `catppuccin` 就跟着变 latte（实测差了一整档）→ 每轮开头
  `vim.o.background = "dark"` 复位；跑完照例 `pcall(require("persistence").stop())` 再 `qa!`
- 改配置**不用拷副本**：本仓有 git，直接改真配置 → `git diff` 看改动、`git checkout -- <file>` 回退。
  只有需要"同一文件改前/改后各跑一遍"的 A/B 对比才用 `NVIM_APPNAME` 隔离，且必须一起软链 cache：
  ```bash
  cp -r ~/.config/nvim ~/.config/nvim-<copy>
  mkdir -p ~/.local/share/nvim-<copy> ~/.local/state/nvim-<copy>
  ln -s ~/.local/share/nvim/{lazy,mason} ~/.local/share/nvim-<copy>/
  ln -s ~/.cache/nvim ~/.cache/nvim-<copy>   # 不软链 cache → nvim-treesitter 重下+重编所有 parser（实测卡 47s）
  cp -r ~/.local/state/nvim/sessions ~/.local/state/nvim-<copy>/  # sessions 目录也按 APPNAME 分开
  NVIM_APPNAME=nvim-<copy> nvim …            # 用完把四处目录都删掉
  ```
- **读用户正在跑的那个 nvim**（最快的现场取证）：GUI/终端 nvim 都有 server socket
  （`ls /run/user/1000/nvim.<pid>.0`），只读查询用
  `nvim --server <sock> --remote-expr 'luaeval("vim.inspect(...)")'`：luaeval 里嵌套引号用
  `[[...]]`，多语句用 `pcall(dofile, [[/tmp/x.lua]])`（脚本把结果写文件再读，`io.write` 不进消息区）
- 复现"真交互"问题要**真 TTY**：`nvim --headless` 没有 UI（UIEnter 不发、dashboard/explorer 不出现），
  结论会失真。**首选 tmux**（本机已装 3.4）：能真按键 + 直接读屏幕文字（`script` 只能存转义字节流）：
  ```bash
  tmux new-session -d -s tv -x 200 -y 50 -c <dir> 'nvim .'
  sleep 25                                    # 项目根 explorer 扫描会占住主循环 ~20s，别急着读
  tmux capture-pane -p -t tv                  # 读屏幕：bufferline / 状态线 / 行号 / 侧栏
  tmux display -p -t tv 'cursor=#{cursor_x},#{cursor_y}'   # 光标在侧栏还是文件窗口
  tmux send-keys -t tv Space q l              # 真按键（leader=space 就是 Space）
  tmux send-keys -t tv ':lua require("persistence").stop()' Enter   # 等价 <leader>qd，先停保存
  tmux send-keys -t tv ':qa!' Enter           # 干净退出，别写坏真实 session
  ```
  没有 tmux 时才退回 `timeout 60 script -qec "cd <dir> && nvim --cmd 'luafile /tmp/nvimdiag.lua' ." /dev/null`
  - 诊断 lua 挂 `--cmd 'luafile …'`（`-c` 太晚：VimEnter 早过了），里面注册 `VimEnter` /
    `SessionLoadPost` / `User Persistence*` 三个 autocmd，把当前 buffer、窗口（id/float/ft）、
    session 键的可读性写进日志
  - **收尾清理必须可重入**：`pcall(require("persistence").stop())` 之后再无条件
    `nvim_del_augroup_by_name("persistence")` 会抛错 → 回调中断、`qall!` 不执行 → nvim 永不退出
    （实测就是卡到超时，看着像卡死）。清理全部 pcall 包住，并在退出前写一行 "quit" 日志当断言
  - 跑完 `sha1sum` 对比 sessions 目录，确认诊断没写坏真实 session
- 项目根这种大目录里 `nvim .`，explorer（配了 hidden + ignored 全开）扫描会占住主循环约 20s：
  启动后立刻看会像"没反应"，等 20~30s 再读屏幕/日志；这与 session 恢复无关
  （改动前后、有/无目录键的对照实验都能复现）

## Git 与提交

- 最近提交用 `git log -1 --format=%s` 现查，hash 用 `%h`；**别把 hash / 改动行数抄进文档**
  （amend 会让它们立刻过时）。本文件应与配置改动同批提交
- 领先 `origin/main` 若干本地提交（origin = LazyVim/starter 上游，**不 push**）；
  具体数量用 `git rev-list --count origin/main..HEAD` 现查，别写死在文档里
- 全局 `~/.gitconfig` 有 `commit.template=commit_template`，那是**工作仓**（BYD ADAS）的模板，
  本仓没有该文件 → 本仓按 Conventional Commits 写（参考本仓历史 `docs:` / `fix:` 风格）
- 提交信息必须用 `git commit -F <file>`（或 heredoc），**不要** `-m`：
  `-m` 会把多行压成一行；提交后用 `git log -1 --format=%B | cat -A` 复查换行

## 待办 / 已知取舍

- 项目根那条旧的分支键 session 已按用户确认复制成目录键（旧文件保留），根目录现在能自动恢复；
  其它目录若还有 `…%%<branch>.vim` 旧文件，同样处理（见"功能 1 / 历史遗留"）
- 本仓未设置自有远端，未 push
- `lazy.lua` 里直接 import 的 python / rust extra 在 `:LazyExtras` 界面里不会显示为启用
  （仅影响 UI 显示，不影响实际生效）；写进 `lazyvim.json` extras 的 treesitter-context 显示正常