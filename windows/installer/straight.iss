; Inno Setup Script for Straight Voice Dictation
#define MyAppName "Straight"
#define MyAppVersion "0.1.0"
#define MyAppPublisher "DarkCrossDungen"
#define MyAppURL "https://github.com/DarkCrossDungen/straight"
#define MyAppExeName "straight.exe"

[Setup]
AppId={{D8A1C52E-6493-4B9F-8CF0-67B342A9E58A}
AppName={#MyAppName}
AppVersion={#MyAppVersion}
AppPublisher={#MyAppPublisher}
AppPublisherURL={#MyAppURL}
AppSupportURL={#MyAppURL}
AppUpdatesURL={#MyAppURL}
DefaultDirName={autopf}\{#MyAppName}
DisableProgramGroupPage=yes
OutputDir=..\..\dist
OutputBaseFilename=Straight-Setup
Compression=lzma2/ultra64
SolidCompression=yes
WizardStyle=modern
ArchitecturesAllowed=x64compatible
ArchitecturesInstallIn64BitMode=x64compatible

[Languages]
Name: "english"; MessagesFile: "compiler:Default.isl"

[Tasks]
Name: "desktopicon"; Description: "{cm:CreateDesktopIcon}"; GroupDescription: "{cm:AdditionalIcons}"; Flags: unchecked

[Files]
; Main app executable and flutter runner files
Source: "..\..\build\windows\x64\runner\Release\*"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs
; Prebuilt native DLLs (whisper, qwen, llama, etc.)
Source: "..\..\native\prebuilt\*.dll"; DestDir: "{app}\native\prebuilt"; Flags: ignoreversion recursesubdirs createallsubdirs
Source: "..\..\native\prebuilt\*.dll"; DestDir: "{app}"; Flags: ignoreversion recursesubdirs createallsubdirs

[Icons]
Name: "{autoprograms}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"
Name: "{autodesktop}\{#MyAppName}"; Filename: "{app}\{#MyAppExeName}"; Tasks: desktopicon

[Run]
Filename: "{app}\{#MyAppExeName}"; Description: "{cm:LaunchProgram,{#StringChange(MyAppName, '&', '&&')}}"; Flags: nowait postinstall skipifsilent
