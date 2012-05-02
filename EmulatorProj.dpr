program EmulatorProj;

uses
  Forms,
  Main in 'Main.pas' {Form1},
  Emulator in 'Emulator.pas',
  Operations in 'Operations.pas',
  D16Operations in 'D16Operations.pas',
  EmuTypes in 'EmuTypes.pas',
  VirtualDevice in 'VirtualDevice.pas',
  LEM1802 in 'LEM1802.pas',
  BasicScreenForm in 'BasicScreenForm.pas' {BasicScreen},
  TaskThread in 'TaskThread.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TForm1, Form1);
  Application.CreateForm(TBasicScreen, BasicScreen);
  Application.Run;
end.
