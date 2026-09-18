-- Options are automatically loaded before lazy.nvim startup
-- Default options that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/options.lua
-- Add any additional options here

-- 自动换行设置
vim.opt.wrap = true        -- 启用自动换行
vim.opt.linebreak = true   -- 在单词边界换行，不会把单词截断
vim.opt.breakindent = true -- 换行时保持缩进

-- 行号显示为绝对行号（关掉 LazyVim 默认的相对行号）
-- LazyVim 默认 opt.number = true + opt.relativenumber = true，
-- 本文件在 lazyvim.config.options 之后加载，故此处覆盖生效；
-- 行号栏由 snacks.statuscolumn 渲染，rnu=false 时取 v:lnum 即绝对行号。
-- 想临时切回相对行号：<leader>uL（只影响当前窗口，重启失效）
vim.opt.relativenumber = false
