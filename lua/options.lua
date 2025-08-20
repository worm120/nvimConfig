require "nvchad.options"

-- add yours here!

local o = vim.opt
-- o.cursorlineopt ='both' -- to enable cursorline!
o.tabstop = 4
o.softtabstop = 4

-- 用来控制你滚动时上下至少要在视图里保留多少行
-- 默认这项是不配置的，所以你的光标可以滚动到当前视图的最后一行
-- 我不太习惯配置这个选项，所以默认注释掉了，你可以取消注释试试看看喜不喜欢
o.scrolloff = 10

o.relativenumber = true -- Use relative line number

-- Display special characters (e.g., tabs, trailing spaces)
o.list = true
-- o.listchars = { tab = "» ", trail = "·", nbsp = "␣" }
