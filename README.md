4. Ctrl+E 导出：TIFF16 / PNG8 / PNG16 / JPEG8

编辑会按照片自动保存，**RAW 文件与所在目录不会被修改**。

### 界面说明

| 区域 | 内容 |
|---|---|
| 左栏 | 导航图、胶片、相纸、裁切、放大机 |
| 中间 | 画布（滚轮缩放，拖动平移，Ctrl+0 适合，Ctrl+1 物理 100%） |
| 右栏 | 参数、RAW 解码、照片信息、状态、**外观**、**关于** |
| 底部 | 胶片条，可多选与同步设置 |

「外观」在右栏底部：配色模式切换、字体大小滑块、恢复默认。

---

## MCP 接口

让 AI agent 驱动 SpektraLab。客户端配置：

```json
{
  "mcpServers": {
    "spektralab": {
      "command": "<安装目录>\\spektralab-mcp.exe"
    }
  }
}
```

提供 8 个工具：

| 工具 | 作用 |
|---|---|
| `get_schema` | 全部参数名、类型、取值范围 |
| `list_stocks` | 20 款胶片 + 8 款相纸 |
| `describe_image` | RAW 元信息 |
| `get_edit` | 读取照片参数 |
| `edit_image` | 合并参数并保存 |
| `reset_edit` | 清除参数 |
| `process_image` | 渲染导出 TIFF16 |
| `export_image` | 同上，可临时覆盖参数 |

详见 [docs/MCP.md](docs/MCP.md)。

---

## 命令行

```bat
spk_raw_render.exe --input photo.arw --output out.tif ^
                   --report out.json --resources resources ^
                   [--params edit.json] ^
                   [--decode-mode compatible16|headroom]
```

- 输出 sRGB 16 位 TIFF，**不覆盖已有文件**
- `--params` 传一组参数覆盖（字段名见 `get_schema`）
- `headroom` 模式保留部分高光，但仍是整数去马赛克

---

## 与上游的关系

| | |
|---|---|
| 上游 | [JamesQiu2005/SpektraLab](https://github.com/JamesQiu2005/SpektraLab) |
| 基线提交 | `267ee24380091e5bee87658d00f6c33d77321194` |
| 上游原型 | [andreavolpato/spektrafilm](https://github.com/andreavolpato/spektrafilm)（胶片模型与实测配置） |

上游本身是四端共构：`modern_UI/` 是 macOS SwiftUI，`windows_UI/` 是 Qt Quick，`engine/` 是 C++20 引擎（Metal + Vulkan 双后端），`desktop/` 是 Tauri。

本项目构建的是 **`windows_UI` + `engine`** 这条路线。

### 对上游源码的修改

只改了 3 处，都是 Windows 移植缺陷，不涉及算法：

| 文件 | 改动 | 原因 |
|---|---|---|
| `engine/src/io/image_writer.cpp` | `dwShareMode` 加 `FILE_SHARE_DELETE`；回滚删除加有界重试 | Windows 要求共享模式含该标志才能设删除标记，否则导出失败无法清理半成品；24H2 上首次删除标记请求必返 `ERROR_ACCESS_DENIED` |
| `engine/tests/image_writer_test.cpp` | 同一断言的测试侧对齐 | 同上 |
| `windows_UI/CMakeLists.txt` | `LANGUAGES CXX` → `LANGUAGES C CXX` | 引擎要编译 `volk.c`，缺 C 语言独立配置会失败 |

补丁在 [patches/](patches/)。界面改造集中在 `windows_UI/qml/`，逻辑未动。

详见 [UPSTREAM.md](UPSTREAM.md)。

---

## 构建

需要 MinGW GCC 13.1+、CMake 3.25+、Vulkan headers、glslang、LibRaw 0.22.2、Qt 6.11.3 MinGW SDK。

```bat
cmake -S windows_UI -B build/qt -G "MinGW Makefiles" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=<mingw>/gcc.exe ^
  -DCMAKE_CXX_COMPILER=<mingw>/g++.exe ^
  -DCMAKE_PREFIX_PATH=<qt>/mingw_64 ^
  -DSPEKTRALAB_SOURCE_ROOT=<source> ^
  -DBUILD_TESTING=ON -DSPEKTRALAB_REQUIRE_VULKAN=ON ^
  -DSPEKTRALAB_VULKAN_INCLUDE_DIR=<vulkan>/include ^
  -DSPEKTRALAB_GLSLANG=<glslang>/glslang.exe ^
  -DSPEKTRALAB_LIBRAW_SOURCE=<libraw>
cmake --build build/qt --parallel 8
<qt>/bin/windeployqt.exe --release --compiler-runtime ^
  --qmldir <source>/windows_UI/qml build/qt/app/SpektraLabQt.exe
```

> **构建路径必须是纯 ASCII。** 实测含中文的路径会让 CMake 按 GBK 误解 UTF-8，
> 链接器找不到自己的运行库；`subst` 盘符、目录 junction、Ninja 生成器都无效。
> 但**产物在中文路径下运行正常**。

完整步骤与踩坑见 [docs/BUILD.md](docs/BUILD.md)。

---

## 已知限制

以下 macOS 功能**未移植**，界面中不会出现：

- 片边（Film Edge）、日期后背（Date Back）、半格拼接
- Cineon DI、场景宽容度映射、对比蒙版
- EDR / HDR、广色域显示、色彩软打样

另外：

- Nikon HE / HE\* 压缩 RAW 不受支持，会明确拒绝打开
- MCP 的 `measure_latitude` / `place_scene` 依赖上述未移植能力，暂缺
- 安装包与 exe 均未做代码签名，SmartScreen 会提示

---

## 许可证

| 组件 | 许可证 |
|---|---|
| 应用与引擎 | **GPL-3.0-or-later** |
| 胶片与相纸配置、放大 LUT | **CC BY-SA 4.0**（Andrea Volpato / spektrafilm） |
| Qt 6.11.3 | LGPL-3.0 / GPL 等 |
| LibRaw 0.22.2 | LGPL-2.1 或 CDDL-1.0 |

完整许可证文本随发行包附在 `licenses/` 目录。

本项目遵循 GPL-3.0：对应源码即本仓库（上游提交 + `patches/` 里的 3 个补丁）。

---

## 致谢

- **James Qiu** — [SpektraLab](https://github.com/JamesQiu2005/SpektraLab) 原作者，本项目的全部渲染能力来自这里
- **Andrea Volpato** — [spektrafilm](https://github.com/andreavolpato/spektrafilm) 的胶片过程模型与 28 款实测配置
- **Qt Project** — Qt 6.11.3
- **LibRaw** — RAW 解码

---

## 作者

Windows 移植与界面重制：**Tau**
