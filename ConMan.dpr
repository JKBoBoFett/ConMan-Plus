program ConMan;

uses
  Forms,
  ContManager in 'ContManager.pas' {ConManForm},
  Files in 'Files.pas',
  DragOut in 'DragOut.pas',
  FileOperations in 'FileOperations.pas',
  misc_utils in 'misc_utils.pas',
  ProgressDialog in 'ProgressDialog.pas' {Progress},
  AboutCntMan in 'AboutCntMan.pas' {AboutContMan},
  u_options in 'u_options.pas',
  u_Containers in 'u_Containers.pas',
  u_BAF in 'u_BAF.pas',
  u_CND in 'u_CND.pas',
  u_Moveform in 'u_Moveform.pas' {MoveForm};

{$R *.RES}
{$R CMAN_VER.RES}
begin
  Application.Initialize;
  Application.HelpFile := 'Conman.hlp';
  Application.CreateForm(TConManForm, ConManForm);
  Application.CreateForm(TProgress, Progress);
  Application.CreateForm(TAboutContMan, AboutContMan);
  Application.CreateForm(TMoveForm, MoveForm);
  Application.Run;
end.
