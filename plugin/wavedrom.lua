if vim.g.loaded_wavedrom then
  return
end
vim.g.loaded_wavedrom = true

vim.api.nvim_create_user_command("WaveDrom", function(opts)
  require("wavedrom").render(opts.args ~= "" and opts.args or nil)
end, {
  nargs = "?",
  complete = "file",
  desc = "Render WaveDrom JSON (current buffer or given path) to PNG and open it",
})
