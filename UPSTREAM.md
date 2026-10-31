# 与上游的关系

## 上游是什么

[SpektraLab](https://github.com/JamesQiu2005/SpektraLab) 是一个 macOS 的胶片与相纸模拟器。

它的核心不是滤镜，而是**光谱计算**：光线以 81 个波长穿过胶片与相纸各自的染料层，
按物理量（微米级的颗粒、光晕、成色剂扩散）算出最终画面。约一秒内出一张相片。

胶片过程模型与 28 款实测配置来自 [Andrea Volpato 的 spektrafilm](https://github.com/andreavolpato/spektrafilm)，
SpektraLab 是该引擎的原生 C++/Metal 移植，以及围绕它构建的应用。

## 上游的架构：四端共构

上游仓库里其实有四套前端和一套引擎：

| 目录 | 技术 | 目标 |
|---|---|---|
| `modern_UI/` | SwiftUI + AppKit + Metal | **macOS 产品**（上游的主线） |
| `windows_UI/` | Qt Quick 6 + C++ | Windows 原生界面 |
| `desktop/` | Tauri + TypeScript | 第三套跨平台前端 |
| `engine/` | C++20，Metal + **Vulkan** 双后端，34 个 compute kernel | 渲染引擎 |

上游 README 明确写着：Windows/Linux 相关工作走 `Windows_Linux` 分支，`main` 是 macOS 产品。

## 本项目的范围

**只构建 `windows_UI` + `engine` 这一条路线。**

- 不碰 `modern_UI/`（macOS SwiftUI，没有 Xcode 环境也无从构建）
- 不碰 `desktop/`（Tauri 前端，与 Windows 原生路线冗余）

`engine/` 的 Vulkan 后端、`windows_UI/` 的 Qt 前端都是上游自己维护的，
不是第三方魔改。本项目的价值在于：

1. **把这条路线真正编译出来并验证**（上游的 Windows 支持标注为 prerelease）
2. **界面按液态玻璃重制**（上游 Windows 界面的配色直接沿用 macOS 的深灰 + 暖金）
3. **补上自动化接口**（上游的 MCP 只在 macOS 版存在）

## Windows 支持的真实状态

上游 `engine/WINDOWS_FEATURE_COVERAGE.md` 对 Windows 移植的描述是**分级验收**的，
不是「全部等价」：

- 验收硬件：Windows + MinGW GCC 15.2 + Vulkan + RTX 5070 Ti
- 通过的本地门禁：16 项 CTest + 47 项 Python 工具测试
- **明确声明**：本地测试通过**不等于**与 Metal 参考实现的整图一致性

本项目在 RTX 4080 + MinGW GCC 13.1 上重新验证，18 项 CTest 全过。

## 功能对照

| 能力 | macOS 版 | 本 Windows 版 |
|---|---|---|
| 光谱渲染（81 波长） | ✅ | ✅ |
| 28 款胶片 + 8 款相纸 | ✅ | ✅ |
| 曝光 / 滤色 / 颗粒 / 光晕 / 眩光 | ✅ | ✅ |
| 裁切 / 旋转 / 翻转 / 拉直 | ✅ | ✅ |
| 多图库、胶片条、同步设置 | ✅ | ✅ |
| TIFF16 / PNG8 / PNG16 / JPEG8 导出 | ✅ | ✅ |
| 撤销 / 重做（每张 64 步） | ✅ | ✅ |
| 编辑自动保存 | ✅ | ✅ |
| 全中文界面 | ✅ | ✅ |
| 片边（Film Edge） | ✅ | ❌ 未移植 |
| 日期后背（Date Back） | ✅ | ❌ 未移植 |
| 半格拼接 | ✅ | ❌ 未移植 |
| Cineon DI | ✅ | ❌ 明确拒绝 |
| 场景宽容度映射 | ✅ | ❌ 明确拒绝 |
| 对比蒙版 | ✅ | ❌ 明确拒绝 |
| EDR / HDR、广色域 | ✅ | ❌ 仅 8 位 SDR |
| 色彩软打样 | ✅ | ❌ |
| CLI | ✅ `spektralab` | ⚠️ `spk_raw_render.exe`（仅渲染） |
| MCP 服务器 | ✅ 12 个工具 | ⚠️ 8 个工具 |
| 液态玻璃界面 | ❌（上游用深灰 + 暖金） | ✅ 本项目新增 |

「明确拒绝」的意思是：引擎会返回错误而不是静默降级。这是上游有意的设计——
没移植的能力不能被误认为可用。

## 对上游源码的修改

**只改了 3 处，全是 Windows 移植缺陷，不涉及算法、色彩模型、profile 数据或着色器。**

### 1. `engine/src/io/image_writer.cpp`

**问题**：`CreateFileW` 的共享模式写成 `0`（独占）。Windows 要求句柄的共享模式
包含 `FILE_SHARE_DELETE`，才允许对它自己设置删除标记。

对照实验：

| 共享模式 | `SetFileInformationByHandle(FileDispositionInfo)` |
|---|---|
| `0`（原代码） | 失败，`ERROR_ACCESS_DENIED (5)` |
| `FILE_SHARE_DELETE` | 成功 |

**后果**：`NewFile` 析构函数靠这个调用删除写了一半的 TIFF。原代码下**任何导出失败
都会残留损坏的 `.partial` 文件**，与代码注释声明的「失败即清理」正好相反。

**第二个问题**：修好共享模式后，实测在 Windows 11 24H2 build 26100 上，
新建文件的**第一次**删除标记请求必然返回 `ERROR_ACCESS_DENIED`，第二次必成。
已用 8 组独立实验排除磁盘类型、目录层级、Defender（实测实时保护已关闭）、
`check_exclusive` 干扰等因素。

**修复**：加 `FILE_SHARE_DELETE`，并给删除加有界重试（20 次 × 5 ms，
且只在 `ERROR_ACCESS_DENIED` / `ERROR_SHARING_VIOLATION` 时重试）。

### 2. `engine/tests/image_writer_test.cpp`

同一断言的测试侧对齐：原断言要求「一次调用即成功」，改为有界重试后判定。
测的仍是「转移出来的句柄能否回滚删除」这个属性，而不是「一次就够」。

### 3. `windows_UI/CMakeLists.txt`

**问题**：`project(SpektraLabWindowsUI LANGUAGES CXX)` 只启用 C++，
但它 `add_subdirectory` 引入的引擎要编译 `third_party/volk/volk.c`。
独立配置时直接失败：

```
CMake Error: Missing variable is: CMAKE_C_CREATE_STATIC_LIBRARY
```

**修复**：改为 `LANGUAGES C CXX`。

同一文件里还把 `src/app.rc` 加进可执行文件源，用于写入版本信息。这是新增，
不是修改。

## 界面改造的范围

全部改动在 `windows_UI/qml/`，只改视觉：

| 文件 | 改动 |
|---|---|
| `Theme.qml` | 重写：深浅双套颜色、字号阶梯、玻璃材质参数、圆角阶梯、可持久化的 `darkMode` / `fontScale` |
| `ActionButton.qml` | 重写：玻璃胶囊按钮 |
| `Section.qml` | 重写：玻璃分组卡片 |
| `Main.qml` | 背景、三栏、工具栏、状态栏玻璃化；新增 4 个玻璃控件组件；新增「外观」「关于」分组；30 处字号改为阶梯引用；硬编码颜色改语义色 |

**QML 里所有信号连接、属性绑定、函数定义原样保留。**
MCP、编辑存储、导出、RAW 解码、色彩管线全部保持上游实现。

## 未采用的方案

| 方案 | 为什么不用 |
|---|---|
| 直接发布上游的 Windows 预编译产物 | 拿不到可复现的构建，且无法改界面 |
| 用 Tauri `desktop/` 前端 | 与 Windows 原生路线冗余，且体积更大 |
| 静态链接 Qt 做单文件 | 需要重新编译整个 Qt（数小时），改用自解压方案 |
| Python 写 MCP | 客户端要额外配 Python 环境；C++ exe 零依赖 |

## 如何核对

```bat
:: 拉上游
git clone https://github.com/JamesQiu2005/SpektraLab.git
cd SpektraLab
git checkout 267ee24380091e5bee87658d00f6c33d77321194

:: 打本项目的补丁
git apply <本仓库>/patches/*.patch

:: 把 本仓库/windows_UI/qml/ 覆盖过去，然后按 docs/BUILD.md 构建
```
