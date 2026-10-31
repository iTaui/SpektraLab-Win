# 更新记录

本项目遵循 [Keep a Changelog](https://keepachangelog.com/zh-CN/1.1.0/) 的格式，
版本号跟随上游基线（`1.3.4`），后缀 `-win.N` 表示 Windows 移植的第 N 次发布。

---

## [1.3.4-win.3] — 2026-11-01

重新构建并完整复测。

### 修复

- **交付物与源码不同步**：`Main.qml` 的液态玻璃改造（外观分组、玻璃控件）
  完成后只重编译了 exe，**没有重新打包交付物**——发布目录里的
  `SpektraLabQt.exe` 仍是改造前的旧构建，界面上看不到外观分组。
  本轮已用新构建重新组装便携目录、重新生成便携 zip、重新生成 NSIS
  安装包与单文件版，并对三份产物重新验证。

### 变更

- 重新裁剪便携目录：删掉 `Qt.labs.settings`（`Theme.qml` 已改用
  `QtCore.Settings`）与 `Qt6LabsSettings.dll`，少 39 KB。
- `spektrafilm_engine.dll` 补回便携目录，保持 4 个可执行文件 + 引擎 C ABI 齐全。
- 截图重拍（深色 / 浅色 / 130% 字号），移到 `docs/screenshots/`。

### 验证（全部重新执行）

- 重新编译 `cmake --build --parallel 8` → EXIT 0
- CTest **18 / 18**
- 引擎 Python 工具测试 **47 / 47**
- MCP 协议测试 **8 / 8**（真实 stdio + JSON-RPC，含错误路径不崩溃）
- 单文件版：首次 **4.1 s** / 二次 **1.0 s**，缓存 413 文件 / 111.9 MB
- 安装包：安装 → 启动 → 卸载闭环通过，五处残留清零
- 界面实拍三种状态，无裁切、无重叠

---

## [1.3.4-win.2] — 2026-10-31

界面重制与自动化接口版本。

### 新增

- **液态玻璃界面**：半透明玻璃面板、折射高光边、大圆角、柔和彩色光晕背景。
  光晕由 36 层同心圆叠出，避免少数几层产生的环状条纹。
- **深色 / 浅色模式**：一键切换，全界面同步换色，设置持久化到
  `HKCU\Software\SpektraLab\SpektraLab Windows\SpektraLab.Appearance`。
- **字体大小调节**：85%–140% 连续可调。字号、控件内边距、列表行高一起缩放，
  不只是文字变大。
- **玻璃控件**：滑块、下拉框、勾选框、进度条全部重做为玻璃样式；
  下拉弹层与选项高亮也是自定义的（原来在深色模式下是白底）。
- **MCP 服务器** `spektralab-mcp.exe`：8 个工具，stdio + JSON-RPC 2.0。
  上游的 MCP 只在 macOS 版存在（`modern_UI/.../Agent/MCPServer.swift`），
  Windows 版此前完全没有这个入口。
- **CLI 工具随包**：`spk_raw_render.exe`（RAW → TIFF16）、
  `SpektraLab.exe`（最小 Win32 预览窗口）、`spektrafilm_engine.dll`（C ABI）。
- **单文件免安装版** `SpektraLab.exe`：首次运行释放运行时到
  `%LOCALAPPDATA%\SpektraLab\runtime\<版本>`，之后直接复用。
  实测首次 4.6 s、二次 1.5 s。
- **外观设置分组**：右栏底部，含配色切换、字号滑块、恢复默认。
- **关于分组**：标明转译来源与许可证。
- **版本资源**：exe 文件属性带 `CompanyName`、`FileDescription`、`LegalCopyright`。

### 变更

- 窗口标题改为 `SpektraLab-Win`。
- 字号阶梯统一走 `Theme.fTiny…fHero`，主界面里 30 处硬编码字号全部替换，
  跟随字号设置缩放。
- 硬编码颜色（列表悬停、错误提示、欢迎文字）改为语义色，深浅色下都正确。
- 三栏与工具栏底色改为半透明玻璃层，让背景光晕透出。

### 修复

- **TIFF 导出失败时无法清理半成品**（真实功能缺陷）：`CreateFileW` 的共享模式
  缺 `FILE_SHARE_DELETE`，Windows 不允许该句柄设置删除标记，导致失败回滚永远
  失败、留下损坏的 `.partial` 文件。已补上该标志。
- 同一处还有第二个问题：Windows 11 24H2 上，新建文件的**首次**删除标记请求
  必返 `ERROR_ACCESS_DENIED`，第二次才成功。已加入有界重试。
- **Windows 前端独立构建失败**：`project(... LANGUAGES CXX)` 缺 C 语言，
  而引擎要编译 `third_party/volk/volk.c`，配置阶段报
  `Missing variable is: CMAKE_C_CREATE_STATIC_LIBRARY`。已改为 `LANGUAGES C CXX`。
- 消除 `Qt.labs.settings` 的废弃警告，改用 `QtCore.Settings`。

### 体积

为减小体积，删除了运行时不加载的 Qt 组件（实测用 `EnumProcessModulesEx`
枚举运行时模块后确定）：

| 项目 | 省 |
|---|---|
| 5 套未使用的 QuickControls2 样式 | 11.6 MB |
| QML 调试器插件（qmltooling） | 1.1 MB |
| 除简中/繁中/英文外的 Qt 翻译 | 7.2 MB |
| Qt 官方 SBOM（压缩为 zip） | 29.4 MB |

许可证正文一份未删。便携目录 112 MB，压缩包 47.8 MB。

### 验证

- CTest **18 / 18**（引擎 16 + Qt 前端 2）
- MCP 协议测试 **8 / 8**
- 单文件版：首次 4.6 s / 二次 1.5 s
- 安装包：安装 → 启动 → 卸载闭环通过，注册表、快捷方式、目录五处残留清零
- 深色 / 浅色 / 130% 字号三种状态实拍，无裁切、无重叠

---

## [1.3.4-win.1] — 2026-10-31

首次可运行构建。

### 新增

- 从上游 `main`（`267ee243`）构建出可运行的 Windows Qt Quick 前端。
- Vulkan 渲染管线在 RTX 4080 上验证通过，34 个 compute kernel 全部生成。
- 便携目录与 NSIS 安装包（仅写 `HKCU`，带卸载器）。

### 验证

- 引擎 CTest 16 / 16
- Qt 前端 CTest 18 / 18
- Python 工具测试 47 / 47
- 功能覆盖：8 款相纸 LUT 位精确，几何与缓存重印通过

### 已知

- 界面沿用上游移植的配色（来自上游 `Theme.swift` 的深灰 + 暖金），未做视觉调整。
- 无 MCP、无 CLI 随包。

---

## 未发布的后续计划

- `measure_latitude` 与 `place_scene` 两个 MCP 工具（依赖引擎未移植能力）
- MCP 的 PNG / JPEG 导出
- 代码签名

---

[1.3.4-win.3]: https://github.com/iTaui/SpektraLab-Win/releases/tag/v1.3.4-win.3
[1.3.4-win.2]: https://github.com/iTaui/SpektraLab-Win/releases/tag/v1.3.4-win.2
[1.3.4-win.1]: https://github.com/iTaui/SpektraLab-Win/releases/tag/v1.3.4-win.1
