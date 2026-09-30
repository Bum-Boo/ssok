Unicode true
!include "MUI2.nsh"
!include "x64.nsh"

Name "ssok"
OutFile "${OUTPUT}"
InstallDir "$LOCALAPPDATA\Programs\ssok"
InstallDirRegKey HKCU "Software\Bum-Boo\ssok" "InstallLocation"
RequestExecutionLevel user
SetCompressor /SOLID zlib
VIProductVersion "0.1.0.0"
VIAddVersionKey /LANG=1033 "ProductName" "ssok"
VIAddVersionKey /LANG=1033 "FileDescription" "ssok Setup"
VIAddVersionKey /LANG=1033 "FileVersion" "${APP_VERSION}"
VIAddVersionKey /LANG=1033 "LegalCopyright" "Bum-Boo. All rights reserved."

!insertmacro MUI_PAGE_WELCOME
!insertmacro MUI_PAGE_LICENSE "${PAYLOAD}\LICENSE"
!insertmacro MUI_PAGE_INSTFILES
!insertmacro MUI_PAGE_FINISH
!insertmacro MUI_UNPAGE_CONFIRM
!insertmacro MUI_UNPAGE_INSTFILES
!insertmacro MUI_UNPAGE_FINISH
!insertmacro MUI_LANGUAGE "English"
!insertmacro MUI_LANGUAGE "Korean"
!insertmacro MUI_LANGUAGE "SimpChinese"
!insertmacro MUI_LANGUAGE "Japanese"

LangString UnsupportedArchitecture ${LANG_ENGLISH} "This package requires 64-bit Windows."
LangString UnsupportedArchitecture ${LANG_KOREAN} "이 설치 프로그램에는 64비트 Windows가 필요해요."
LangString UnsupportedArchitecture ${LANG_SIMPCHINESE} "此安装包需要 64 位 Windows。"
LangString UnsupportedArchitecture ${LANG_JAPANESE} "このインストーラーには64ビット版Windowsが必要です。"

Function .onInit
  SetShellVarContext current
  !insertmacro MUI_LANGDLL_DISPLAY
  ${IfNot} ${RunningX64}
    MessageBox MB_OK|MB_ICONSTOP "$(UnsupportedArchitecture)"
    Abort
  ${EndIf}
FunctionEnd

Section "ssok"
  SetOutPath "$INSTDIR"
  File /r "${PAYLOAD}\*"
  WriteUninstaller "$INSTDIR\Uninstall.exe"
  CreateDirectory "$SMPROGRAMS\ssok"
  CreateShortCut "$SMPROGRAMS\ssok\ssok.lnk" "$INSTDIR\ssok.exe"
  CreateShortCut "$SMPROGRAMS\ssok\Uninstall.lnk" "$INSTDIR\Uninstall.exe"
  WriteRegStr HKCU "Software\Bum-Boo\ssok" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "DisplayName" "ssok"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "DisplayVersion" "${APP_VERSION}"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "UninstallString" '$\"$INSTDIR\Uninstall.exe$\"'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "QuietUninstallString" '$\"$INSTDIR\Uninstall.exe$\" /S'
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "InstallLocation" "$INSTDIR"
  WriteRegStr HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "DisplayIcon" "$INSTDIR\ssok.exe"
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "NoModify" 1
  WriteRegDWORD HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok" "NoRepair" 1
SectionEnd

Section "Uninstall"
  SetShellVarContext current
  !include "${UNINSTALL_FILES}"
  Delete "$SMPROGRAMS\ssok\ssok.lnk"
  Delete "$SMPROGRAMS\ssok\Uninstall.lnk"
  RMDir "$SMPROGRAMS\ssok"
  DeleteRegKey HKCU "Software\Microsoft\Windows\CurrentVersion\Uninstall\ssok"
  DeleteRegKey HKCU "Software\Bum-Boo\ssok"
  Delete "$INSTDIR\Uninstall.exe"
  RMDir "$INSTDIR"
SectionEnd
