-- nvim-treesitter（main 分支）现在把 parser 和 queries 装在 stdpath("data")/site 下：
-- parser 编译到 site/parser/*.so，queries 用 site/queries/<lang> 的软链接指向插件的
-- runtime/queries/<lang>。更新插件时只会重建/迁移 LazyVim 默认 ensure_installed 里的语言，
-- 手工装过、不在那个列表里的语言会“掉队”：parser 还留在插件老目录（旧 ABI），
-- queries 软链接压根不建 → 表现就是打开该语言的文件没有任何语法高亮。
--
-- LazyVim 的 nvim-treesitter spec 带 opts_extend = { "ensure_installed" }
-- （LazyVim/lua/lazyvim/plugins/treesitter.lua:25），所以这里的列表是追加，不是覆盖。
-- 列表 = 2026-09-18 那次更新后掉队的全部语言（jsonc 已并入 json，nvim-treesitter 里没有这个 parser）。
return {
  {
    "nvim-treesitter/nvim-treesitter",
    opts = {
      ensure_installed = {
        "comment",
        "cpp",
        "css",
        "csv",
        "cue",
        "editorconfig",
        "fish",
        "gitattributes",
        "gitcommit",
        "git_config",
        "gitignore",
        "git_rebase",
        "graphql",
        "haskell",
        "http",
        "json5",
        "just",
        "make",
        "readline",
        "scss",
        "sql",
        "ssh_config",
        "svelte",
        "zig",
      },
    },
  },
}