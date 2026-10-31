# 构建说明

## 依赖

| 组件 | 版本 | 用途 |
|---|---|---|
| MinGW-w64 GCC | 13.1.0 posix-seh | 编译器 |
| Qt | 6.11.3 (MinGW 64-bit) | 界面框架 |
| CMake / CTest | 3.25.0（3.20+ 可用） | 构建与测试 |
| Vulkan-Headers | SDK 1.4.363.0 | 引擎 GPU 接口 |
| glslang | 16.6.0 | 把 GLSL 编译成 SPIR-V |
| LibRaw | 0.22.2 | RAW 解码 |

Vulkan 运行时来自显卡驱动（系统 `vulkan-1.dll`），**不需要装 Vulkan SDK**，
只要 headers 和 glslang 就能构建。引擎用 volk 在运行时加载 loader。

> 上游文档记录的验收工具链是 MinGW GCC 15.2。本项目在 **GCC 13.1.0**（Qt 官方
> MinGW SDK 自带的版本）上构建并通过全部测试。用 Qt 自带的编译器可以避免
> Qt 二进制与编译器 ABI 不一致的问题。

## 目录布局

```
<source>/                     上游源码（含 engine/ 与 windows_UI/）
<qt>/                         6.11.3/mingw_64 与 Tools/mingw1310_64
<vulkan>/                     Vulkan-Headers 的 include/
<glslang>/                    glslang.exe 所在目录
<libraw>/                     LibRaw-0.22.2 源码树
build/qt/                     构建输出
```

## 构建

### 1. 准备依赖

从 [Qt 在线仓库](https://download.qt.io/online/qtsdkrepository/windows_x86/desktop/qt6_6113/qt6_6113_mingw/qt.qt6.6113.win64_mingw/)
取 `qtbase`、`qtdeclarative`、`qttools`、`qtsvg`、`qttranslations`、`qtshadertools`
与 `MinGW-w64 13.1.0` 工具链，用 `bsdtar`（Windows 自带 `tar.exe`）解压：

```bat
tar -xf <mingw>.7z -C <qt>
tar -xf <qtbase>.7z -C <qt>\mingw_64
```

### 2. 配置

```bat
cmake -S windows_UI -B build/qt -G "MinGW Makefiles" ^
  -DCMAKE_BUILD_TYPE=Release ^
  -DCMAKE_C_COMPILER=<mingw>/gcc.exe ^
  -DCMAKE_CXX_COMPILER=<mingw>/g++.exe ^
  -DCMAKE_MAKE_PROGRAM=<mingw>/mingw32-make.exe ^
  -DCMAKE_PREFIX_PATH=<qt>/mingw_64 ^
  -DSPEKTRALAB_SOURCE_ROOT=<source> ^
  -DBUILD_TESTING=ON ^
  -DSPEKTRALAB_REQUIRE_VULKAN=ON ^
  -DSPEKTRALAB_VULKAN_INCLUDE_DIR=<vulkan>/include ^
  -DSPEKTRALAB_VULKAN_LIBRARY=C:/Windows/System32/vulkan-1.dll ^
  -DSPEKTRALAB_GLSLANG=<glslang>/glslang.exe ^
  -DSPEKTRALAB_LIBRAW_SOURCE=<libraw>
```

配置阶段会打印两条 `Manually-specified variables were not used` 警告
（`SPEKTRALAB_VULKAN_INCLUDE_DIR` / `SPEKTRALAB_VULKAN_LIBRARY`）——这是上游
`build.ps1` 传的变量名与 `CMakeLists.txt` 实际读的不一致，**不影响构建**，
Vulkan headers 通过 `VULKAN_SDK` 环境变量或 `SPEKTRALAB_VULKAN_HEADERS` 找到。

若 headers 找不到，设置：

```bat
set VULKAN_SDK=<vulkan 的父目录>
```

### 3. 编译

```bat
cmake --build build/qt --parallel 8
```

产物落在 `build/qt/app/`，包含：

| 文件 | 说明 |
|---|---|
| `SpektraLabQt.exe` | 主界面 |
| `spektralab-mcp.exe` | MCP 服务器 |
| `SpektraLab.exe` | 最小 Win32 预览窗口 |
| `spk_raw_render.exe` | RAW → TIFF CLI |

### 4. 部署

```bat
<qt>/bin/windeployqt.exe --release --compiler-runtime ^
  --qmldir <source>/windows_UI/qml build/qt/app/SpektraLabQt.exe
```

`windeployqt` 会按 QML 里的 `import` 自动挑需要的模块，只部署实际用到的
QuickControls2 样式（Basic）。

### 5. 测试

```bat
set QT_QPA_PLATFORM=offscreen
set QT_QUICK_BACKEND=software
ctest --test-dir build/qt --output-on-failure
```

预期 **18 / 18 通过**：引擎 16 项（Vulkan compute、几何、LUT、RAW 解码、C ABI）
加 Qt 前端 2 项（帧输出、编辑存储）。

---

## 关键陷阱

### 构建路径必须是纯 ASCII

这是本项目耗时最久的问题。路径里含中文时：

- CMake 把自身安装路径写进 Makefile 时按 GBK 误解 UTF-8
  （`PC类` → `PC绫?`）
- 链接器 `ld.exe` 因此连自己的 `libmingwex` 都找不到

**已逐个排除的无效方案**：

| 方案 | 为什么不行 |
|---|---|
| 8.3 短名 | 本机已禁用，`GetShortPathNameW` 原样返回长名 |
| `subst` 盘符 | CMake 用 `GetLongPathName` 之类解析回真实路径 |
| 目录 junction | 同样被解析回真实路径 |
| Ninja 生成器 | 一样失败——乱码在工具链自身，不是 GNU Make 的问题 |

**唯一解**：真实纯 ASCII 路径。

注意区分：**构建必须 ASCII，但产物运行不受影响**——放在中文目录下跑得好好的。

### PowerShell 5.1 会把 stderr 当致命错误

上游的 `build-windows.ps1` / `build.ps1` 设了 `$ErrorActionPreference = 'Stop'`，
再用 `& $exe @args 2>&1 | Tee-Object`。native 程序往 stderr 打的**普通警告**
会被包成 `NativeCommandError` 并触发 Stop，脚本在 `Generating done` 之后
立刻退出（实测 9 秒），看起来像构建失败，其实是假失败。

规避：按上面的步骤手动跑 configure / build / test 三步，参数与脚本一致。

### `windeployqt` 后立刻启动会拿到异常窗口尺寸

`windeployqt` 刚写完 DLL，立即启动可能因文件占用得到 160×28 的窗口。
等几秒再启动即可。

---

## 打包

### 便携目录

直接把 `build/qt/app/` 整个复制走。目录自包含，不需要安装 Qt。

### 便携 zip

```bat
powershell -c "Compress-Archive -Path build\qt\app\* -DestinationPath dist\portable.zip"
```

### 单文件版

用 NSIS 做一个自解压启动器，见 [`installer/onefile.nsi`](../installer/onefile.nsi)：

- 释放到 `%LOCALAPPDATA%\SpektraLab\runtime\<版本>`
- 版本号进路径，升级天然隔离、不会串版本
- 已存在则直接 `Exec`，不再解压

首次约 4.6 秒（解压 112 MB），之后 1.5 秒。

### 安装包

见 [`installer/setup.nsi`](../installer/setup.nsi)：只写 `HKCU`，不需管理员，
带卸载器。

> `.nsi` 脚本**必须带 UTF-8 BOM**，否则 NSIS 报 `Bad text encoding`。

### 裁剪（可选）

用 `EnumProcessModulesEx` 枚举运行时实际加载的模块，再据此删除未加载的 Qt 组件：

| 项目 | 省 |
|---|---|
| 未使用的 QuickControls2 样式 | 11.6 MB |
| `qmltooling/`（QML 调试器插件） | 1.1 MB |
| 除简中/繁中/英文外的翻译 | 7.2 MB |
| Qt SBOM（压成 zip） | 29.4 MB |

**许可证正文一份都不能删。**

---

## 常见问题

**Q：画布空白 / 提示无法创建设备**

Vulkan 驱动不可用。更新显卡驱动。可用下面的脚本检查：

```python
import ctypes
k = ctypes.WinDLL("vulkan-1.dll")
app = ctypes.create_string_buffer(64)
# 见仓库 audit/ 里的 vk_probe.py
```

**Q：`ld.exe: cannot find -lmingwex`**

构建路径含非 ASCII 字符。换成纯 ASCII 路径。

**Q：CMake 报 `Missing variable is: CMAKE_C_CREATE_STATIC_LIBRARY`**

`windows_UI/CMakeLists.txt` 的 `LANGUAGES CXX` 需要改成 `LANGUAGES C CXX`
（引擎要编译 `volk.c`）。本项目已修，用上游原始源码时会遇到。

**Q：导出的 TIFF 残留半成品文件**

上游原版的问题，本项目已修（`FILE_SHARE_DELETE` + 删除重试）。
