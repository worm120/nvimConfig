-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- `nvim .` 启动后会留下两类「等于目录参数」的空 buffer，都占 bufferline 第一格：
--   1) [No Name]：snacks.explorer 把最初那个目录 buffer 的名字清空、不删 buffer
--      （snacks/explorer/init.lua:38-40）；有 session 自动恢复时 dashboard 也不再收编它
--      （reason: window does not contain the first buffer）
--   2) 「src/」：nvim 为参数目录本身保留的 buffer，session 里的 `$argadd <目录>` 让它变 listed
-- 等启动与 session 恢复都落定后一起清掉（`:bd` 只是暂时的，下一次启动 session 又会拉回来）。
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      if vim.fn.argc(-1) ~= 1 or vim.fn.isdirectory(vim.fn.argv(0)) ~= 1 then
        return
      end
      for _, b in ipairs(vim.api.nvim_list_bufs()) do
        if
          vim.api.nvim_buf_is_valid(b)
          and vim.bo[b].buflisted
          and not vim.bo[b].modified
          and vim.bo[b].buftype == ""
          and (vim.api.nvim_buf_get_name(b) == "" or vim.fn.isdirectory(vim.api.nvim_buf_get_name(b)) == 1)
          and vim.api.nvim_buf_line_count(b) <= 1
          and #vim.fn.win_findbuf(b) == 0
        then
          pcall(vim.api.nvim_buf_delete, b, {})
        end
      end
    end, 200)
  end,
})

-- `nvim .` 启动时 snacks explorer 在 UIEnter 里无条件 p:focus()（snacks/explorer/init.lua:41-51，
-- 绕过 picker 的 focus/enter 配置）→ 焦点被侧栏浮窗抢走。启动落定后把焦点还给它的 main 窗口
-- （= 启动时那个文件窗口），侧栏保留：explorer 源自带 auto_close = false
-- （picker/config/sources.lua:63），焦点离开不会触发 picker 的自动关闭。
-- 必须 defer：本文件里的 UIEnter autocmd 注册得比 explorer 那个早，直接切焦点会被它随后抢回去。
vim.api.nvim_create_autocmd("UIEnter", {
  once = true,
  callback = function()
    vim.defer_fn(function()
      for _, picker in ipairs(Snacks.picker.get({ source = "explorer" })) do
        if picker.main and vim.api.nvim_win_is_valid(picker.main) then
          vim.api.nvim_set_current_win(picker.main)
        end
      end
    end, 200)
  end,
})
