; Установщик Transmitter для Windows (Inno Setup 6).
;
; Собирается скриптом tool/build_release.ps1:
;   ISCC.exe /DAppVersion=0.4.0 /DSourceDir=<…\Release> /DOutputDir=<…\dist> installer\transmitter.iss
;
; Ставится для текущего пользователя (без прав администратора) в
; %LOCALAPPDATA%\Programs\Transmitter. AppId менять нельзя: по нему новая
; версия ставится поверх старой и находится в «Параметры → Приложения».

#ifndef AppVersion
  #define AppVersion "0.0.0"
#endif
#ifndef SourceDir
  #define SourceDir "..\build\windows\x64\runner\Release"
#endif
#ifndef OutputDir
  #define OutputDir "..\build\dist"
#endif

[Setup]
AppId={{C8803338-00D0-499B-A46D-90EA2572EC00}
AppName=Transmitter
AppVersion={#AppVersion}
AppVerName=Transmitter {#AppVersion}
AppPublisher=Kernien
AppPublisherURL=https://github.com/Kernien/Transmitter
AppSupportURL=https://github.com/Kernien/Transmitter/issues
AppUpdatesURL=https://github.com/Kernien/Transmitter/releases
DefaultDirName={autopf}\Transmitter
DefaultGroupName=Transmitter
DisableProgramGroupPage=yes
DisableDirPage=auto
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
OutputDir={#OutputDir}
OutputBaseFilename=Transmitter-{#AppVersion}-windows-setup
SetupIconFile=..\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\transmitter.exe
UninstallDisplayName=Transmitter
VersionInfoVersion={#AppVersion}
VersionInfoCompany=Kernien
VersionInfoProductName=Transmitter
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
; Запущенный Transmitter установщик предложит закрыть сам.
CloseApplications=yes
RestartApplications=no

[Languages]
Name: "ru"; MessagesFile: "compiler:Languages\Russian.isl"
Name: "en"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[InstallDelete]
; Ресурсы приложения заменяются целиком: от прошлой версии не остаётся
; устаревших файлов (шрифтов, ассетов).
Type: filesandordirs; Name: "{app}\data"

[Files]
Source: "{#SourceDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\Transmitter"; Filename: "{app}\transmitter.exe"
Name: "{autodesktop}\Transmitter"; Filename: "{app}\transmitter.exe"; Tasks: desktopicon

[Run]
Filename: "{app}\transmitter.exe"; Description: "{cm:LaunchProgram,Transmitter}"; Flags: nowait postinstall skipifsilent
