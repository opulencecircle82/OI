; A320 FAP Simulator - Windows installer (Inno Setup 6).
; Build the app first:  cd a320_fap && flutter build windows --release
; Then compile:         ISCC.exe windows_installer\A320_FAP.iss
; Output:               Windows_Setup\A320_FAP_Setup_v<version>.exe

#define AppName "A320 FAP Simulator"
#define AppVersion "4.1"
#define AppExe "A320_FAP.exe"
#define SrcDir "..\a320_fap\build\windows\x64\runner\Release"

[Setup]
; Keep this AppId forever: updates install over the previous version.
AppId={{8F3C6A2E-4B1D-4E7A-9C55-0A320FA00001}
AppName={#AppName}
AppVersion={#AppVersion}
AppVerName={#AppName} {#AppVersion}
AppPublisher=Overdrive Interactive
AppPublisherURL=https://opulencecircle82.github.io/OI/fap/
AppSupportURL=https://opulencecircle82.github.io/OI/fap/
VersionInfoVersion={#AppVersion}.0.0
VersionInfoCompany=Overdrive Interactive
VersionInfoDescription={#AppName} Setup
DefaultDirName={autopf}\{#AppName}
DefaultGroupName={#AppName}
DisableProgramGroupPage=yes
; No admin rights needed by default ("only for me"); the user can choose
; "all users" (asks for admin) in the first dialog.
PrivilegesRequired=lowest
PrivilegesRequiredOverridesAllowed=dialog
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible
MinVersion=10.0
LicenseFile=notice.txt
OutputDir=..\Windows_Setup
OutputBaseFilename=A320_FAP_Setup_v{#AppVersion}
SetupIconFile=..\a320_fap\windows\runner\resources\app_icon.ico
UninstallDisplayIcon={app}\{#AppExe}
UninstallDisplayName={#AppName}
Compression=lzma2/max
SolidCompression=yes
WizardStyle=modern
CloseApplications=yes

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"

[Files]
Source: "{#SrcDir}\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#AppName}"; Filename: "{app}\{#AppExe}"
Name: "{autodesktop}\{#AppName}"; Filename: "{app}\{#AppExe}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#AppExe}"; Description: "{cm:LaunchProgram,{#AppName}}"; Flags: nowait postinstall skipifsilent
