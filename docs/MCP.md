# MCP 接口

让 AI agent 通过 stdio + JSON-RPC 2.0 驱动 SpektraLab。

## 背景

上游的 MCP 入口 `spektralab mcp` 只存在于 macOS 版
（`modern_UI/Spektrafilm/Spektrafilm/Agent/MCPServer.swift`）。
Windows 版此前**没有任何 MCP 实现**——客户端调用不会有返回，也不会有报错，
因为根本没有人接。

本项目补上了这一层：`spektralab-mcp.exe`。

## 配置

在客户端的 MCP 配置文件里加一项：

```json
{
  "mcpServers": {
    "spektralab": {
      "command": "C:\\Program Files\\SpektraLab\\spektralab-mcp.exe"
    }
  }
}
```

exe 默认用自己同级的 `resources/` 目录，所以 **exe 必须和 `resources/` 放在一起**
（安装包与便携包都已这样布置）。

从别处调用时显式指定：

```json
{
  "mcpServers": {
    "spektralab": {
      "command": "…\\spektralab-mcp.exe",
      "args": ["--resources", "D:\\SpektraLab\\resources",
               "--edit-store", "D:\\SpektraLab\\edits"]
    }
  }
}
```

| 参数 | 默认 | 说明 |
|---|---|---|
| `--resources` | exe 同级 `resources/` | 引擎资源目录（profiles、print_luts、SPIR-V） |
| `--edit-store` | `%LOCALAPPDATA%\SpektraLab\McpEdits` | 参数 sidecar 存储目录 |

## 工具

### `get_schema`

返回全部可编辑参数的字段名、类型与取值范围。

```json
{}
```

结果里的 `schema.fields` 是字段表，`edit_image` 的 `patch` 键名取自这里。

### `list_stocks`

列出可用的胶片与相纸。

```json
{}
```

返回 `films`（20 款）与 `papers`（8 款），每项含 `id`、`name`、`type`、
`support`、`stage`、`antihalation`、`target_print`。

### `describe_image`

读一张 RAW 的元信息。

```json
{"path": "D:\\photos\\DSC0001.ARW"}
```

返回 `input`（路径、尺寸、色彩空间）、`decode`（LibRaw 版本、解码模式）、
`resolved_params`（解析后的完整参数）。

> 内部会完整渲染一次到临时文件以取得 report，然后删除。
> 大文件首次调用需要几秒。

### `get_edit`

```json
{"path": "D:\\photos\\DSC0001.ARW"}
```

返回该照片已保存的参数（`params`）与 sidecar 文件路径。

### `edit_image`

合并一组参数并保存，**不会立即渲染**。

```json
{
  "path": "D:\\photos\\DSC0001.ARW",
  "patch": {
    "film_stock": "kodak_portra_400",
    "print_stock": "kodak_portra_endura"
  }
}
```

字段名取自 `get_schema`。合并是浅合并（键级覆盖）。

### `reset_edit`

```json
{"path": "D:\\photos\\DSC0001.ARW"}
```

删除该照片的 sidecar，回到默认参数。

### `process_image`

按已保存参数渲染并导出 sRGB 16 位 TIFF。

```json
{
  "path": "D:\\photos\\DSC0001.ARW",
  "output": "D:\\out\\DSC0001.tif",
  "decode_mode": "compatible16"
}
```

- `output` 省略时，输出到当前工作目录的 `<源文件名>.tif`
- `decode_mode`：`compatible16`（默认，AHD + as-shot WB）或 `headroom`（保留部分高光）
- **不覆盖已有文件**（引擎层保证）
- 返回 `ok`、`output`、`report`（引擎的完整报告）

### `export_image`

与 `process_image` 相同，额外允许在渲染时临时覆盖部分参数（不写入 sidecar）：

```json
{
  "path": "D:\\photos\\DSC0001.ARW",
  "output": "D:\\out\\DSC0001.tif",
  "patch": {"film_exposure_ev": 0.5}
}
```

## 典型流程

```
1. get_schema       → 拿到参数名与范围
2. list_stocks      → 选胶片与相纸的 id
3. describe_image   → 确认 RAW 可读
4. edit_image       → {"film_stock":"kodak_portra_400","print_stock":"kodak_portra_endura"}
5. process_image    → 渲染并导出
```

## 参数存储

`edit_image` 保存的参数在：

```
%LOCALAPPDATA%\SpektraLab\McpEdits\<照片绝对路径的哈希>.json
```

纯 JSON，键名与 `get_schema` 的 `fields` 一致。可用 `--edit-store` 改位置。

sidecar 与 GUI 的编辑库（`Edits` 目录）**互相独立**：
同一个文件在两边各自维护参数，互不覆盖。

## 渲染路径

`process_image` / `export_image` 调度同目录的 `spk_raw_render.exe`，
用的是和 GUI 完全相同的 RAW 解码与色彩管线。

MCP 服务器本身**不链接 Vulkan**（只链纯算法库 `spektralab_core`），
所以启动不需要 GPU，`get_schema` / `list_stocks` 这类纯查询是毫秒级的。

## 限制

- **每次完整渲染，没有负片缓存**；批量处理比在界面里慢
- **只输出 TIFF16**；PNG / JPEG 只在 GUI 里提供
- 相比 macOS 版缺 `measure_latitude`（场景宽容度）与 `place_scene`（场景放置）
  两个工具——Windows 引擎把这两项列为未移植能力，调用会被拒绝

## 自检

```bat
echo {"jsonrpc":"2.0","id":1,"method":"initialize","params":{}} | spektralab-mcp.exe
```

期望输出：

```json
{"jsonrpc":"2.0","id":1,"result":{
  "protocolVersion":"2024-11-05",
  "capabilities":{"tools":{"listChanged":false}},
  "serverInfo":{"name":"spektralab","version":"1.3.4-windows-glass"}}}
```

## 协议细节

- 传输：stdio，**每行一个 JSON 对象**（`\n` 分帧，不接受 `\r\n` 混入内容）
- 协议版本：`2024-11-05`
- 通知类消息（无 `id`）不产生响应
- 工具结果同时放在 `content[].text`（字符串化的 JSON）与 `structuredContent`（对象）
