; SpektraLab-Win 单文件免安装版
;
; 一个 exe，双击即运行：
;   首次运行把 Qt 运行时、QML 模块、引擎资源释放到
;   %LOCALAPPDATA%\SpektraLab\runtime\<版本>，然后启动主程序；
;   之后每次启动直接复用，不再解压。
;
; 不写注册表、不建快捷方式、不申请管理员权限。
; 彻底删除：删掉本 exe，再删 %LOCALAPPDATA%\SpektraLab 即可。

Unicode true
Name "SpektraLab-Win"
OutFile "F:\AI\spk3\dist\SpektraLab.exe"
RequestExecutionLevel user
SilentInstall silent
AutoCloseWindow true
SetCompressor /SOLID lzma

!define APPVER "1.3.4-win.2"
!define RUNTIME "$LOCALAPPDATA\SpektraLab\runtime\${APPVER}"
!define SRC "F:\AI\spk3\build\qt\app"

VIProductVersion "1.3.4.2"
VIAddVersionKey /LANG=2052 "ProductName" "SpektraLab-Win"
VIAddVersionKey /LANG=2052 "CompanyName" "Tau"
VIAddVersionKey /LANG=2052 "FileDescription" "SpektraLab-Win 单文件启动器"
VIAddVersionKey /LANG=2052 "FileVersion" "1.3.4.2"
VIAddVersionKey /LANG=2052 "LegalCopyright" "GPL-3.0-or-later"

Section "Run"
  ; 已释放过同一版本就直接启动
  IfFileExists "${RUNTIME}\SpektraLabQt.exe" 0 extract
  Goto launch

extract:
  SetOutPath "${RUNTIME}"
  File /r "${SRC}\*.*"

launch:
  Exec '"${RUNTIME}\SpektraLabQt.exe"'
SectionEnd
