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
; Transmitter запущен — установщик просит его закрыть (имя «замка» — windows/runner/main.cpp).
AppMutex=Local\app.transmitter.transmitter
DefaultDirName={autopf}\Transmitter
DefaultGroupName=Transmitter
DisableProgramGroupPage=yes
DisableDirPage=auto
ShowLanguageDialog=auto
UsePreviousLanguage=yes
UsePreviousAppDir=yes
UsePreviousGroup=yes
UsePreviousTasks=yes
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

[Registry]
; Положение окна (windows/runner/window_state.cpp) — удаляется вместе с программой.
Root: HKCU; Subkey: "Software\Transmitter"; Flags: uninsdeletekey dontcreatekey

[CustomMessages]
ru.WelcomeUpgradeTitle=Обновление Transmitter
ru.WelcomeUpgradeText=Обнаружена установленная версия Transmitter: %1.%n%nМастер обновит программу до актуальной версии %2.%n%nВсе ваши базы, доски, ключи и файлы будут полностью сохранены.%n%nНажмите «Обновить», чтобы продолжить.
ru.WelcomeReinstallText=У вас уже установлена версия Transmitter %1.%n%nМастер переустановит и обновит файлы программы до актуального состояния.%n%nВсе ваши данные и настройки сохранятся.%n%nНажмите «Обновить», чтобы продолжить.
ru.ButtonUpdate=Обновить
ru.StatusUpdating=Обновление Transmitter...
ru.FinishedUpgradeTitle=Обновление Transmitter завершено
ru.FinishedUpgradeText=Transmitter успешно обновлён до актуальной версии %1.%n%nНажмите «Завершить» для запуска приложения.

en.WelcomeUpgradeTitle=Update Transmitter
en.WelcomeUpgradeText=An existing installation of Transmitter (%1) was found on your computer.%n%nSetup will update Transmitter to version %2.%n%nAll your boards, keys, and settings will remain completely safe.%n%nClick "Update" to continue.
en.WelcomeReinstallText=Transmitter %1 is already installed on your computer.%n%nSetup will reinstall and refresh the application files to the current state.%n%nAll your data and settings will remain safe.%n%nClick "Update" to continue.
en.ButtonUpdate=Update
en.StatusUpdating=Updating Transmitter...
en.FinishedUpgradeTitle=Transmitter Update Complete
en.FinishedUpgradeText=Transmitter has been successfully updated to version %1.%n%nClick "Finish" to launch the application.

[Code]
var
  IsUpgradeMode: Boolean;
  PrevVersion: String;
  PrevAppDir: String;

function GetUninstallKey(): String;
begin
  Result := 'Software\Microsoft\Windows\CurrentVersion\Uninstall\{#SetupSetting("AppId")}_is1';
end;

function InitializeSetup(): Boolean;
var
  Key: String;
begin
  Result := True;
  IsUpgradeMode := False;
  PrevVersion := '';
  PrevAppDir := '';
  Key := GetUninstallKey();

  if RegQueryStringValue(HKCU, Key, 'DisplayVersion', PrevVersion) or
     RegQueryStringValue(HKLM, Key, 'DisplayVersion', PrevVersion) then
  begin
    if RegQueryStringValue(HKCU, Key, 'InstallLocation', PrevAppDir) or
       RegQueryStringValue(HKLM, Key, 'InstallLocation', PrevAppDir) or
       RegQueryStringValue(HKCU, Key, 'Inno Setup: App Path', PrevAppDir) or
       RegQueryStringValue(HKLM, Key, 'Inno Setup: App Path', PrevAppDir) then
    begin
      if (PrevAppDir <> '') and DirExists(PrevAppDir) then
      begin
        IsUpgradeMode := True;
      end;
    end;
  end;
end;

procedure InitializeWizard();
begin
  if IsUpgradeMode then
  begin
    WizardForm.Caption := ExpandConstant('{cm:WelcomeUpgradeTitle}') + ' - Transmitter {#AppVersion}';
    WizardForm.WelcomeLabel1.Caption := ExpandConstant('{cm:WelcomeUpgradeTitle}');
    if (PrevVersion <> '') and (PrevVersion <> '{#AppVersion}') then
      WizardForm.WelcomeLabel2.Caption := FmtMessage(ExpandConstant('{cm:WelcomeUpgradeText}'), [PrevVersion, '{#AppVersion}'])
    else if PrevVersion = '{#AppVersion}' then
      WizardForm.WelcomeLabel2.Caption := FmtMessage(ExpandConstant('{cm:WelcomeReinstallText}'), ['{#AppVersion}'])
    else
      WizardForm.WelcomeLabel2.Caption := FmtMessage(ExpandConstant('{cm:WelcomeUpgradeText}'), ['?', '{#AppVersion}']);

    WizardForm.NextButton.Caption := ExpandConstant('{cm:ButtonUpdate}');
    WizardForm.FinishedHeadingLabel.Caption := ExpandConstant('{cm:FinishedUpgradeTitle}');
    WizardForm.FinishedLabel.Caption := FmtMessage(ExpandConstant('{cm:FinishedUpgradeText}'), ['{#AppVersion}']);
    WizardForm.StatusLabel.Caption := ExpandConstant('{cm:StatusUpdating}');
  end;
end;

procedure CurPageChanged(CurPageID: Integer);
begin
  if IsUpgradeMode then
  begin
    if (CurPageID = wpWelcome) or (CurPageID = wpReady) then
    begin
      WizardForm.NextButton.Caption := ExpandConstant('{cm:ButtonUpdate}');
    end;
  end;
end;

function ShouldSkipPage(PageID: Integer): Boolean;
begin
  Result := False;
  if IsUpgradeMode then
  begin
    // В режиме полноценного обновления пропускаем выбор директории, группы и задач
    if (PageID = wpSelectDir) or 
       (PageID = wpSelectProgramGroup) or 
       (PageID = wpSelectTasks) or
       (PageID = wpReady) then
    begin
      Result := True;
    end;
  end;
end;
