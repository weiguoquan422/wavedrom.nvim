local M = {}

M.defaults = {
  -- WaveDrom 渲染命令
  wavedrom_cmd = { "npx", "wavedrom-cli" },
  -- 渲染成功后用哪个程序打开 PNG（设为 {} 则不打开）
  opener = { "google-chrome" },
  -- 渲染前自动保存已修改的 buffer
  autosave = true,
}

M.config = vim.deepcopy(M.defaults)

function M.setup(opts)
  M.config = vim.tbl_deep_extend("force", M.defaults, opts or {})
end

function M.render(path)
  return require("wavedrom.render").render(path)
end

return M
