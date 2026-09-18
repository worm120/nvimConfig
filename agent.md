# nvim 配置现状（agent.md）

给后续 AI agent / 自己看的现状快照。最后更新：2026-09-18，
与本文件同批的提交是 `feat(nvim): nvim . 也自动恢复 session，行号改为绝对行号`。
**不要把提交 hash 写进本文件**：amend 会改 hash，一写就自相矛盾（要 hash 用 `git log -1 --format=%h` 查）。

## 环境

- neovim 0.12.5，runtime 在 `/home/zn/nvim-linux-x86_64/share/nvim/runtime`
  （不是发行版包，**不要**读 `/usr/share/nvim`）
- 配置 = LazyVim（folke 原版，非自制 fork）+ lazy.nvim；33 个插件
  - 插件目录 `~/.local/share/nvim/lazy/`，mason 在 `~/.local/share/nvim/mason/`
  - LazyVim 默认 spec 在 `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/*.lua`
- `lazyvim.json` 里 `extras` 列表是**空**的；实际额外启用的 extras 是在
  `lua/config/lazy.lua` 里直接 `import = "lazyvim.plugins.extras.lang.python"`
- `noice.nvim` 没有任何自定义覆盖 → 行为即 LazyVim 默认
- 这份配置的 git 仓库 origin 仍是 `https://github.com/LazyVim/starter`（上游 starter，不是自有远端）：
  只做本地提交，不要 push

## 文件结构与本地定制

```
init.lua
lua/config/{options,keymaps,autocmds,lazy}.lua
lua/plugins/{lsp,persistence,snacks,example}.lua
lua/xmake-ls/{gen.py,globals.lua,defs/xmake-defs.lua}   # lua_ls 认 xmake 用，见下
```

- `lua/config/options.lua`：`wrap`、`linebreak`、`breakindent` = true（长行按词换行，保持缩进）；
  `relativenumber = false`（行号显示绝对行号，见"编辑器行为备忘"）
- `lua/config/keymaps.lua`：Alt 系键位
  - `<A-d>` 定义、`<A-r>` 引用、`<A-s>` 跳回（`<C-o>`）
  - `<A-]>` / `<A-[>` 下/上一个 buffer，`<A-a>` 上一次 buffer（`b#`）
  - `<A-j>` / `<A-k>` 不移动光标滚屏（`<C-E>` / `<C-Y>`）
- `lua/config/lazy.lua`：import python extra；禁用 rtp 插件 gzip / tarPlugin / tohtml / tutor / zipPlugin
- `lua/config/autocmds.lua`：空模板，**没有**自定义 autocmd（session 恢复的 autocmd 在 plugins/persistence.lua 里）
- `lua/plugins/snacks.lua`：explorer 显示 gitignored + 隐藏文件，固定宽度 40
- `lua/plugins/lsp.lua`：opts 用 `function(_, opts)` 形式（为了保留其它 server 的设置不被覆盖）
  - pyright → `~/venvs/conan-env/bin/python`
  - lua_ls → 喂 xmake 的 API 名单和定义库（见"功能 2"）

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

## 编辑器行为备忘

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
- 回答"某个键是什么"这类问题：去 `~/.local/share/nvim/lazy/LazyVim/lua/lazyvim/plugins/*.lua`
  和插件源码里读，不要凭记忆或上游网页

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

- 最新本地提交：`feat(nvim): nvim . 也自动恢复 session，行号改为绝对行号`（含本文件）；
  hash 用 `git log -1 --format=%h` 现查，不要抄进文档；改动行数同理不要写，amend 会让它立刻过时
- `main` 领先 `origin/main` 2 个提交（origin = LazyVim/starter 上游，未 push）
- 全局 `~/.gitconfig` 有 `commit.template=commit_template`，那是**工作仓**（BYD ADAS）的模板，
  本仓没有该文件 → 本仓按 Conventional Commits 写（参考本仓历史 `docs:` / `fix:` 风格）
- 提交信息必须用 `git commit -F <file>`（或 heredoc），**不要** `-m`：
  `-m` 会把多行压成一行；提交后用 `git log -1 --format=%B | cat -A` 复查换行

## 待办 / 已知取舍

- 项目根那条旧的分支键 session 已按用户确认复制成目录键（旧文件保留），根目录现在能自动恢复；
  其它目录若还有 `…%%<branch>.vim` 旧文件，同样处理（见"功能 1 / 历史遗留"）
- 本仓未设置自有远端，未 push
- `lazyvim.json` 的 `extras` 为空但 `lazy.lua` 直接 import 了 python extra：
  `:LazyExtras` 界面里不会显示它是启用状态（仅影响 UI 显示，不影响实际生效）