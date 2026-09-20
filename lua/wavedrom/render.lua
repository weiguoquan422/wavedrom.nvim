local M = {}

local running = false

local QF_TITLE = "wavedrom.nvim"

local function notify(msg, level)
  vim.notify(msg, level or vim.log.levels.INFO, { title = "wavedrom.nvim" })
end

local function bufnr_for(path)
  for _, buf in ipairs(vim.api.nvim_list_bufs()) do
    if vim.api.nvim_buf_is_valid(buf) and vim.api.nvim_buf_get_name(buf) == path then
      return buf
    end
  end
  return vim.fn.bufadd(path)
end

-- 只清理本插件写入的 quickfix 列表（title 匹配才动，避免误清用户内容）
local function clear_own_qf()
  if vim.fn.getqflist({ title = 0 }).title == QF_TITLE then
    vim.fn.setqflist({}, " ", { title = QF_TITLE })
  end
end

-- vim.json.decode 报错给的是字节偏移 ("at character N")，换算成行列
local function offset_to_lnum_col(content, offset)
  local line, col = 1, 1
  for i = 1, math.min(offset, #content) do
    if content:byte(i) == 10 then
      line = line + 1
      col = 1
    else
      col = col + 1
    end
  end
  return line, col
end

local function report_json_error(path, content, errmsg)
  errmsg = tostring(errmsg)
  local lnum, col = errmsg:match("line (%d+) column (%d+)")
  if not lnum then
    local offset = errmsg:match("character (%d+)")
    if offset then
      lnum, col = offset_to_lnum_col(content, tonumber(offset))
    end
  end
  lnum = tonumber(lnum) or 1
  col = tonumber(col) or 1
  vim.fn.setqflist({}, " ", {
    title = QF_TITLE,
    items = {
      {
        bufnr = bufnr_for(path),
        lnum = lnum,
        col = col,
        text = errmsg,
        type = "E",
      },
    },
  })
  vim.cmd("botright copen")
  notify("JSON 语法错误，详见 quickfix", vim.log.levels.ERROR)
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
    clear_own_qf()
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

  -- 1. 本地 JSON 语法校验（失败写 quickfix，不启动 npx）
  local f = io.open(path, "r")
  if not f then
    notify("无法读取文件: " .. path, vim.log.levels.ERROR)
    return
  end
  local content = f:read("*a")
  f:close()
  if content == "" then
    notify("文件为空: " .. path, vim.log.levels.WARN)
    return
  end

  local ok, decoded = pcall(vim.json.decode, content)
  if not ok then
    report_json_error(path, content, decoded)
    return
  end

  -- 2. WaveDrom 格式检查
  if type(decoded) ~= "table" or decoded.signal == nil then
    notify('JSON 中未找到 "signal" 字段，可能不是 WaveDrom 配置', vim.log.levels.WARN)
    return
  end

  -- 3. 启动渲染
  if vim.fn.executable(cfg.wavedrom_cmd[1]) == 0 then
    notify(("找不到可执行程序: %s (请确认已安装或修改 wavedrom_cmd 配置)"):format(cfg.wavedrom_cmd[1]), vim.log.levels.ERROR)
    return
  end

  local png = vim.fn.fnamemodify(path, ":r") .. ".png"
  local cmd = vim.list_extend(vim.deepcopy(cfg.wavedrom_cmd), { "-i", path, "-p", png })

  notify("渲染中: " .. vim.fn.fnamemodify(path, ":t") .. " …")
  running = true
  local ok2, sysjob = pcall(vim.system, cmd, { text = true, cwd = vim.fn.fnamemodify(path, ":h") }, function(res)
    running = false
    vim.schedule(function()
      on_done(res, png)
    end)
  end)
  if not ok2 then
    running = false
    notify("启动渲染进程失败: " .. tostring(sysjob), vim.log.levels.ERROR)
  end
end

return M
