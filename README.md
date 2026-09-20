# wavedrom.nvim

在 Neovim 中渲染 [WaveDrom](https://wavedrom.com) 时序图：对当前 buffer 的 WaveDrom JSON
调用 `wavedrom-cli` 异步生成同名 PNG，并用 Chrome 打开查看。

对应脚本的等价命令：`npx wavedrom-cli -i xxx.json -p xxx.png && google-chrome xxx.png`

## 依赖

- Neovim >= 0.10
- Node.js / npx（`npx wavedrom-cli` 可用，首次运行会自动下载）
- google-chrome（或通过配置改用其他查看器）

## 安装

lazy.nvim:

```lua
{
  "weiguoquan422/wavedrom.nvim",
  cmd = "WaveDrom",
  config = function()
    require("wavedrom").setup({})
  end,
}
```

按键映射（放自己的配置里，例如 init.vim）:

```vim
nnoremap <leader>wf :WaveDrom<CR>
```

## 使用

- 编辑 WaveDrom JSON 时执行 `:WaveDrom`（或你的映射键），渲染成功后自动打开 PNG
- `:WaveDrom path/to/xxx.json` 可渲染指定文件
- 仅手动触发；文件需包含 `"signal"` 字段才认为是 WaveDrom JSON
- 渲染前本地校验 JSON 语法：有语法错误时不启动渲染，错误（含行列定位）写入
  quickfix 并自动打开窗口，回车跳转到出错位置；渲染成功后自动清理相应条目

## 配置

```lua
require("wavedrom").setup({
  wavedrom_cmd = { "npx", "wavedrom-cli" }, -- 渲染命令
  opener = { "google-chrome" },             -- PNG 查看器，设为 {} 不自动打开
  autosave = true,                          -- 渲染前自动保存已修改的 buffer
})
```
