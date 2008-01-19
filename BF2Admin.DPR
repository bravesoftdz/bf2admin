program BF2Admin;

uses
  Forms,
  Main in 'Main.pas' {MainForm},
  UMD5 in '..\..\Units\UMD5.pas';

{$R *.RES}

begin
  Application.Initialize;
  Application.Title := 'BF2 Game-Admin Utility';
  Application.CreateForm(TMainForm, MainForm);
  Application.Run;
end.
