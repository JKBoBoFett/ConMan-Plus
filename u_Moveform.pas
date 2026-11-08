unit u_Moveform;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  StdCtrls, files;

type
  TMoveForm = class(TForm)
    CBDirs: TComboBox;
    Label1: TLabel;
    BNMove: TButton;
    BNCancel: TButton;
    procedure FormCreate(Sender: TObject);
  private
    { Private declarations }
  public
    Function GetMoveToDir(dir:TContainerFile;var subdir:string):boolean;
    { Public declarations }
  end;

var
  MoveForm: TMoveForm;

implementation

{$R *.DFM}

procedure TMoveForm.FormCreate(Sender: TObject);
begin
 ClientWidth:=CBDirs.Left*2+CBDirs.Width;
 ClientHeight:=BNMove.Top+BNMove.Height+Label1.Top;
end;

Function TMoveForm.GetMoveToDir(dir:TContainerFile;var subdir:string):boolean;
begin
 CBDirs.Items.Assign(dir.Dirs);
 CBDirs.Text:=subdir;
 result:=ShowModal=MrOK;
 if result then subdir:=CBDirs.Text;
end;

end.
