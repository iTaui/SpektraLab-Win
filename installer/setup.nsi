; SpektraLab-Win 安装包
; 仅写入 HKCU（当前用户），不需要管理员权限，不触碰系统级注册表与系统目录。
Unicode true
!include "MUI2.nsh"
!include "FileFunc.nsh"

!define APPNAME "SpektraLab-Win"
!define APPVER "1.3.4-win.2"
!define EXENAME "SpektraLabQt.exe"
!define SRC "F:\AI\spk3\build\qt\app"

Name "${APPNAME}"
OutFile "F:\AI\spk3\dist\SpektraLab-Win-x64-setup.exe"
InstallDir "$LOCALAPPDATA\Programs\SpektraLab-Win"
InstallDirRegKey HKCU "Software\SpektraLab-Win" "InstallDir"
RequestExecutionLevel user
SetCompressor /SOLID lzma

VIProductVersion "1.3.4.2"
VIAddVersionKey /LANG=2052 "ProductName" "SpektraLab-Win"
VIAddVersionKey /LANG=2052 "CompanyName" "Tau"
VIAddVersionKey /LANG=2052 "FileDescription" "SpektraLab-Win 安装程序"
VIAddVersionKey /LANG=2052 "FileVersion" "1.3.4.2"
VIAddVersionKey /LANG=2052 "LegalCopyright" "GPL-3.0-or-later"

!define MUI_ABORTWARNING
!define MUI_FINISHPAGE_RUN "$INSTDIR\${EXENAME}"
!define MUI_FINISHPAGE_RUN_TEXT "启动 SpektraLab-Win"
!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${SRC}\licenses\LICENSE"
!insertmacro MUI_PAGE_DIRECTORY
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "English"

Section "${APPNAME}" SecMain
  SetOutPath "$INSTDIR"
  File /r "${SRC}\*.*"

  WriteUninstaller "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\SpektraLab-Win" "InstallDir" "$INSTDIR"

  CreateShortCut "$DESKTOP\SpektraLab-Win.lnk" "$INSTDIR\${EXENAME}"
  CreateDirectory "$SMPROGRAMS\SpektraLab-Win"
  CreateShortCut "$SMPROGRAMS\SpektraLab-Win\SpektraLab-Win.lnk" "$INSTDIR\${EXENAME}"
  CreateShortCut "$SMPROGRAMS\SpektraLab-Win\卸载 SpektraLab-Win.lnk" "$INSTDIR\Uninstall.exe"

  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "DisplayName" "${APPNAME}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "DisplayVersion" "${APPVER}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "Publisher" "Tau"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "UninstallString" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "DisplayIcon" "$INSTDIR\${EXENAME}"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "NoRepair" 1

  ${GetSize} "$INSTDIR" "/S=0K" $0 $1 $2
  IntFmt $0 "0x%08X" $0
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win" "EstimatedSize" "$0"
SectionEnd

Section "Uninstall"
  Delete "$DESKTOP\SpektraLab-Win.lnk"
  Delete "$SMPROGRAMS\SpektraLab-Win\SpektraLab-Win.lnk"
  Delete "$SMPROGRAMS\SpektraLab-Win\卸载 SpektraLab-Win.lnk"
  RMDir "$SMPROGRAMS\SpektraLab-Win"
  RMDir /r "$INSTDIR"
  DeleteRegKey HKCU "Software\SpektraLab-Win"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\SpektraLab-Win"
SectionEnd
