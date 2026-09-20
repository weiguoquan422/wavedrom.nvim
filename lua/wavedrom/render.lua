local M = {}

local running = false

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "wavedrom.nvim" })
end

local function has_signal(path)
  local f = io.open(path, "r")
  if not f then
    return false
  end
  local content = f:read("*a")
  f:close()
  return content ~= nil and content:find('"signal"', 1, true) ~= nil
end

local function autosave(path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if
      vim.api.nvim_buf_is_valid(buf)
      and vim.bo[buf].modified
      and vim.bo[buf].buftype == ""
      and vim.api.nvim_buf_get_name(buf) == path
    then
      vim.api.nvim_buf_call(buf, function()
        vim.cmd("silent! update")
      end)
    end
  end
end

local function open_png(png)
  local opener = require("wavedrom").config.opener
  if #opener == 0 then
    return
  end
  local cmd = vim.list_extend(vim.deepcopy(opener), { png })
  vim.system(cmd, { detach = true })
end

local function on_done(res, png)
  if res.code == 0 then
    notify("已生成: " .. png)
    open_png(png)
    return
  end
  local err = vim.trim(res.stderr or res.stdout or "")
  if #err > 400 then
    err = err:sub(1, 400) .. " …"
  end
  notify(("渲染失败 (exit %d):\n%s"):format(res.code, err), vim.log.levels.ERROR)
end

function M.render(path)
  if running then
    notify("已有渲染任务在进行中，请稍候", vim.log.levels.WARN)
    return
  end

  path = path or vim.api.nvim_buf_get_name(0)
  if path == "" then
    notify("当前 buffer 未关联文件", vim.log.levels.WARN)
    return
  end
  path = vim.fn.fnamemodify(path, ":p")

  if not path:match("%.json$") then
    notify("不是 .json 文件: " .. path, vim.log.levels.WARN)
    return
  end
  if vim.fn.filereadable(path) == 0 then
    notify("文件不存在: " .. path, vim.log.levels.ERROR)
    return
  end

  local cfg = require("wavedrom").config
  if cfg.autosave then
    autosave(path)
  end

  if not has_signal(path) then
    notify('文件中未找到 "signal" 字段，可能不是 WaveDrom JSON', vim.log.levels.WARN)
    return
  end

  if vim.fn.executable(cfg.wavedrom_cmd[1]) == 0 then
    notify(("找不到可执行程序: %s (请确认已安装或修改 wavedrom_cmd 配置)"):format(cfg.wavedrom_cmd[1]), vim.log.levels.ERROR)
    return
  end

  local png = vim.fn.fnamemodify(path, ":r") .. ".png"
  local cmd = vim.list_extend(vim.deepcopy(cfg.wavedrom_cmd), { "-i", path, "-p", png })

  notify("渲染中: " .. vim.fn.fnamemodify(path, ":t") .. " …")
  running = true
  local ok, sysjob = pcall(vim.system, cmd, { text = true, cwd = vim.fn.fnamemodify(path, ":h") }, function(res)
    running = false
    vim.schedule(function()
      on_done(res, png)
    end)
  end)
  if not ok then
    running = false
    notify("启动渲染进程失败: " .. tostring(sysjob), vim.log.levels.ERROR)
  end
end

return M
