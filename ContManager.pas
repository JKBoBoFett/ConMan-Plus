unit ContManager;

interface

uses
  Windows, Messages, SysUtils, Classes, Graphics, Controls, Forms, Dialogs,
  Menus, ComCtrls, CommCtrl, Files, FileOperations, ExtCtrls, misc_utils,
  ShellApi, u_Containers, u_BAF, FileCtrl, Clipbrd, DragOut, Registry,u_options, Math,
  System.ImageList, Vcl.ImgList;

const MinPanelSize=40;

type
  TConManForm = class(TForm)
    StatusBar: TStatusBar;
    MainMenu: TMainMenu;
    File1: TMenuItem;
    Close1: TMenuItem;
    N1: TMenuItem;
    Edit1: TMenuItem;
    Copy1: TMenuItem;
    Paste1: TMenuItem;
    N2: TMenuItem;
    SelectAll1: TMenuItem;
    InvertSelection1: TMenuItem;
    T1: TMenuItem;
    Toolbar1: TMenuItem;
    Statusbar2: TMenuItem;
    N3: TMenuItem;
    LargeIcons: TMenuItem;
    SmallIcons: TMenuItem;
    List: TMenuItem;
    Details: TMenuItem;
    N4: TMenuItem;
    ArrageIcons1: TMenuItem;
    ByName1: TMenuItem;
    ByType1: TMenuItem;
    BySize1: TMenuItem;
    LineupIcons1: TMenuItem;
    N5: TMenuItem;
    Refresh1: TMenuItem;
    Options1: TMenuItem;
    Help1: TMenuItem;
    HelpTopics1: TMenuItem;
    N6: TMenuItem;
    AboutContainermanager1: TMenuItem;
    Openanothercontainer1: TMenuItem;
    NewContainer1: TMenuItem;
    GOB1: TMenuItem;
    LFD1: TMenuItem;
    AddFiles: TMenuItem;
    N7: TMenuItem;
    Extractfiles: TMenuItem;
    AddDialog: TOpenDialog;
    LVDir: TListView;
    LargeImages: TImageList;
    SmallImages: TImageList;
    SaveDialog: TSaveDialog;
    LAB1: TMenuItem;
    NewConDialog: TSaveDialog;
    OpenDialog: TOpenDialog;
    DeleteFiles: TMenuItem;
    TVDirs: TTreeView;
    JKGOB1: TMenuItem;
    GOO1: TMenuItem;
    AssociatecontainerswithConMan1: TMenuItem;
    OpenFiles: TMenuItem;
    PAK1: TMenuItem;
    ReopenContainer: TMenuItem;
    MoveFiles: TMenuItem;
    PopupMenu1: TPopupMenu;
    OpenFiles1: TMenuItem;
    MoveFiles1: TMenuItem;
    AddFiles1: TMenuItem;
    ExtractFiles1: TMenuItem;
    DeleteFiles1: TMenuItem;
    PNResizeTVDirs: TPanel;
    procedure FormCreate(Sender: TObject);
    procedure IconArrage(Sender: TObject);
    procedure Close1Click(Sender: TObject);
    procedure Openanothercontainer1Click(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure AboutContainermanager1Click(Sender: TObject);
    procedure ByName1Click(Sender: TObject);
    procedure ByType1Click(Sender: TObject);
    procedure BySize1Click(Sender: TObject);
    procedure ExtractfilesClick(Sender: TObject);
    procedure Refresh1Click(Sender: TObject);
    procedure SelectAll1Click(Sender: TObject);
    procedure InvertSelection1Click(Sender: TObject);
    procedure LVDirColumnClick(Sender: TObject; Column: TListColumn);
    procedure HelpTopics1Click(Sender: TObject);
    procedure NewContainerClick(Sender: TObject);
    procedure AddFilesClick(Sender: TObject);
    procedure DeleteFilesClick(Sender: TObject);
    procedure Paste1Click(Sender: TObject);
    procedure Copy1Click(Sender: TObject);
    procedure FormHide(Sender: TObject);
    procedure LVDirMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
    procedure FormShow(Sender: TObject);
    procedure TVDirsChange(Sender: TObject; Node: TTreeNode);
    procedure AssociatecontainerswithConMan1Click(Sender: TObject);
    procedure LVDirDblClick(Sender: TObject);
    procedure ReopencontainerClick(Sender: TObject);
    procedure MoveFilesClick(Sender: TObject);
    procedure LVDirEdited(Sender: TObject; Item: TListItem; var S: string);
    procedure PNResizeTVDirsMouseMove(Sender: TObject; Shift: TShiftState; X,
      Y: Integer);
  private
    Dir:TContainerFile;
    DirControl:TMaskedDirectoryControl;
    FGiver:TGiveFiles;
    { Private declarations }
    FilesToDelete:TStringList;
   ExtractAllItems:array[0..1] of TMenuItem;
   Procedure ExtractFile(inFile:TFile;outFile:String);
   Procedure AskConvertBAFMats(all:boolean);
   Procedure AddExtractAllItem(after:TMenuItem;idx:integer);
   procedure ExtractAllClick(Sender:TObject);
   Procedure ExtractSelectedFiles(const destdir:string);
   Procedure WMDropFiles(var msg:TWMDropFiles);message WM_DROPFILES;
   Procedure DoAddFiles(newfiles:TStrings);
   Procedure ProcessHDrop(Hdrop:Integer);
   Procedure LoadTree;
   Function GetCurPath(node:TTreeNode):String;
   Procedure MakeLists(files:TStrings;flist,names:TStringList);
   Procedure SetStatusBar;
   Procedure RefreshRecents;
   Procedure AddRecent(const recent:string);
   Procedure ExceptionHandler(Sender: TObject; E: Exception);
  public
   Procedure OpenFile(name:String);
    { Public declarations }
  end;

var
  ConManForm: TConManForm;

implementation

uses ProgressDialog, AboutCntMan, u_Moveform;

{$R *.DFM}

Procedure TConManForm.LoadTree;

Procedure AddDirs(branch:TTreeNode;const path:string);
var dl:TstringList;i:integer;
    node:TTreeNode;
begin
 if not Dir.ChDir(path) then exit;
 dl:=TStringList.Create;
 dl.Assign(Dir.ListDirs);
 for i:=0 to dl.count-1 do
 begin
  node:=TVDirs.Items.AddChild(branch,dl[i]);
  if Path='' then AddDirs(node,dl[i]) else
  AddDirs(node,path+'\'+dl[i]);
 end;
 dl.free;
end;
var root:TTreeNode;
begin
 root:=TVDirs.Items.Add(Nil,ExtractName(Dir.Name));
 AddDirs(root,'');
 PNResizeTVDirs.Visible:=Dir.HasDirs;
 TVDirs.Visible:=Dir.HasDirs;
 Dir.ChDir('');
 TVDirs.FullExpand;
end;

Procedure TConManForm.OpenFile(name:String);
begin
 if FGiver<>nil then begin Fgiver.Free; FGiver:=nil; end;
 if Dir<>nil then begin Dir.Free; Dir:=nil; end;
 LVDir.Items.BeginUpdate;
 LVDir.Items.Clear;
 LVDir.Items.EndUpdate;

 TVDirs.Items.Clear;
 PNResizeTVDirs.Visible:=false;
 TVDirs.Visible:=false;

 try
 Dir:=OpenContainer(name);
 LoadTree;

 DirControl.SetDir(Dir);
 DirControl.SetMask('*');
 SetStatusBar;
 Caption:='Container Manager - '+Name;
 AddFiles.Enabled:=true;
 AddFiles1.Enabled:=true;
 DeleteFiles.Enabled:=true;
 DeleteFiles1.Enabled:=true;
 OpenFiles.Enabled:=true;
 OpenFiles1.Enabled:=true;
 ExtractFiles.Enabled:=true;
 ExtractFiles1.Enabled:=true;
 if ExtractAllItems[0]<>nil then ExtractAllItems[0].Enabled:=true;
 if ExtractAllItems[1]<>nil then ExtractAllItems[1].Enabled:=true;
 MoveFiles.Enabled:=Dir.CanRename and Dir.HasDirs;
 MoveFiles1.Enabled:=Dir.CanRename and Dir.HasDirs;
 LVDir.ReadOnly:=not Dir.CanRename;
 AddRecent(name);
except
 On e:Exception do ShowMessage(e.message);
end;
end;

procedure TConManForm.FormCreate(Sender: TObject);
begin
 {poDefault lets Windows pick the window SIZE too (huge on big screens); keep the designed size}
 Position:=poDefaultPosOnly;
 {restore the window; never larger than the work area (a bad saved size used to make the window huge)}
 if (WinPos.X>-1) and (WinPos.X<Screen.WorkAreaWidth-MinPanelSize) then
 begin
  Left:=WinPos.X;
  Position:=poDesigned; {use the saved position}
  if (WinPos.W>=400) and (WinPos.W<=Screen.WorkAreaWidth-(Width-ClientWidth)) then
   ClientWidth:=WinPos.W;
 end;
 if (WinPos.Y>-1) and (WinPos.Y<Screen.WorkAreaHeight-MinPanelSize) then
 begin
  Top:=WinPos.Y;
  Position:=poDesigned;
  if (WinPos.H>=300) and (WinPos.H<=Screen.WorkAreaHeight-(Height-ClientHeight)) then
   ClientHeight:=WinPos.H;
 end;
 if Left+Width>Screen.WorkAreaWidth then Left:=Max(0,Screen.WorkAreaWidth-Width);
 if Top+Height>Screen.WorkAreaHeight then Top:=Max(0,Screen.WorkAreaHeight-Height);
 if WinPos.Maxed=1 then WindowState:=wsMaximized;
 if (sizeBarPos>-1) and (SizeBarPos<ClientWidth-MinPanelSize) then
   TVDirs.Width:=sizeBarPos;


 DirControl:=TMaskedDirectoryControl.CreateFromLV(LVDir);
 DragAcceptFiles(Handle,true);
 FilesToDelete:=TStringList.Create;
 RefreshRecents;
 AddExtractAllItem(Extractfiles,0);
 AddExtractAllItem(ExtractFiles1,1);
// Application.OnException:=ExceptionHandler;
end;

Procedure TConManForm.ExceptionHandler(Sender: TObject; E: Exception);
begin
// ErrForm.ReportError(e,ExceptAddr);
end;

procedure TConManForm.IconArrage(Sender: TObject);
begin
 if Sender=SmallIcons then LVDir.ViewStyle:=vsSmallIcon
 else if Sender=LargeIcons then LVDir.ViewStyle:=vsIcon
 else if Sender=Details then LVDir.ViewStyle:=vsReport
 else if Sender=List then LVDir.ViewStyle:=vsList;
 TMenuItem(Sender).Checked:=true;
end;

procedure TConManForm.Close1Click(Sender: TObject);
begin
 Close;
end;

procedure TConManForm.Openanothercontainer1Click(Sender: TObject);
begin
if Pos('*.baf',OpenDialog.Filter)=0 then
 OpenDialog.Filter:=OpenDialog.Filter+'|Obi-Wan BAF models (*.baf)|*.baf|Indy CND levels (*.cnd)|*.cnd';
if OpenDialog.Execute then
begin
 OpenFile(OpenDialog.FileName);
end;
end;

procedure TConManForm.FormDestroy(Sender: TObject);
var i:integer;
begin
 DragAcceptFiles(Handle,false);
 DirControl.Free;
 for i:=0 to FilesToDelete.Count-1 do
  DeleteFile(FilesToDelete[i]);
end;

procedure TConManForm.AboutContainermanager1Click(Sender: TObject);
begin
 AboutContMan.ShowModal;
end;

procedure TConManForm.ByName1Click(Sender: TObject);
begin
 LvDir.AlphaSort;
end;

function CompareExts(Item1, Item2: TListItem; ParamSort: Integer): Integer; stdcall;
var ext1,ext2:String;
begin
 ext1:=UpperCase(ExtractFileExt(Item1.Caption));
 ext2:=UpperCase(ExtractFileExt(Item2.Caption));
 Result:=StrComp(Pchar(ext1),pchar(ext2));
end;

procedure TConManForm.ByType1Click(Sender: TObject);
begin
 LvDir.CustomSort(@CompareExts,0);
end;

function CompareSizes(Item1, Item2: TListItem; ParamSort: Integer): Integer; stdcall;
var size1,size2:Longint;
begin
 size1:=TFileInfo(Item1.Data).Size;
 size2:=TFileInfo(Item2.Data).Size;
 if size1>size2 then result:=1
 else if size1=size2 then result:=0
 else result:=-1;
end;


procedure TConManForm.BySize1Click(Sender: TObject);
begin
 LVDir.CustomSort(@CompareSizes,0);
end;

procedure TConManForm.ExtractfilesClick(Sender: TObject);
begin
 if LVDir.SelCount=0 then begin MsgBox('Select some files first','No, no, no!',mb_ok); exit; end;
 SaveDialog.FileName:=LVDir.Selected.Caption;
 if SaveDialog.Execute then
 begin
  if Dir is TBAFDirectory then AskConvertBAFMats(false);
  try
   ExtractSelectedFiles(ExtractFilePath(SaveDialog.FileName));
  finally
   if Dir is TBAFDirectory then TBAFDirectory(Dir).Convert16:=false;
  end;
 end;
end;

Procedure TConManForm.AskConvertBAFMats(all:boolean);
var i:integer;
    anyMat:boolean;
begin
 TBAFDirectory(Dir).Convert16:=false;
 anyMat:=false;
 if all then
 begin
  for i:=0 to Dir.Files.Count-1 do
   if CompareText(ExtractFileExt(Dir.Files[i]),'.mat')=0 then anyMat:=true;
 end else
  for i:=0 to LvDir.Items.Count-1 do
   if LVDir.Items[i].Selected and (CompareText(ExtractFileExt(LVDir.Items[i].Caption),'.mat')=0) then anyMat:=true;
 if not anyMat then exit;
 TBAFDirectory(Dir).Convert16:=
  MsgBox('Convert the MAT files to 16-bit (with the BAF palette baked in)?'#13#10+
         'Yes = 16-bit MATs (for Mat16 / NJED / OpenJKDF2)'#13#10+
         'No = original 8-bit MATs','Convert textures',MB_YESNO or MB_ICONQUESTION)=idYes;
end;

Procedure TConManForm.AddExtractAllItem(after:TMenuItem;idx:integer);
var mi:TMenuItem;
begin
 if (after=nil) or (after.Parent=nil) then exit;
 mi:=TMenuItem.Create(Self);
 mi.Caption:='Extract entire container (keep folders)...';
 mi.OnClick:=ExtractAllClick;
 mi.Enabled:=false; {stays grayed out until a container is opened}
 ExtractAllItems[idx]:=mi;
 after.Parent.Insert(after.Parent.IndexOf(after)+1,mi);
end;

procedure TConManForm.ExtractAllClick(Sender:TObject);
var dest,target:string;
    i,ov:integer;
begin
 if (Dir=nil) or (Dir.Files.Count=0) then
 begin
  MsgBox('There is nothing to extract.','Extract',MB_OK);
  exit;
 end;
 dest:='';
 if not SelectDirectory('Extract the whole container to:','',dest,[sdNewFolder,sdShowEdit,sdNewUI]) then exit;
 dest:=IncludeTrailingPathDelimiter(dest);
 if Dir is TBAFDirectory then AskConvertBAFMats(true);
 ov:=-1; {-1 = not asked yet, 0 = skip existing, 1 = overwrite existing}
 try
  Progress.Reset(Dir.Files.Count);
  Progress.Msg:='Extracting container...';
  try
   for i:=0 to Dir.Files.Count-1 do
   begin
    target:=dest+Dir.Files[i];
    Progress.Step;
    if FileExists(target) then
    begin
     if ov=-1 then
     begin
      case MsgBox('Some files already exist in the destination.'#13#10+
                  'Yes = overwrite them, No = skip existing files, Cancel = stop',
                  'Extract',MB_YESNOCANCEL or MB_ICONQUESTION) of
       idYes: ov:=1;
       idNo: ov:=0;
      else
       break;
      end;
     end;
     if ov=0 then continue;
     SysUtils.DeleteFile(target);
    end;
    ForceDirectories(ExtractFilePath(target));
    ExtractFile(Dir.OpenFileByFI(TFileInfo(Dir.Files.Objects[i])),target);
   end;
  finally
   Progress.Hide;
  end;
 finally
  if Dir is TBAFDirectory then TBAFDirectory(Dir).Convert16:=false;
 end;
end;

Procedure TConManForm.ExtractSelectedFiles(const destdir:string);
var i:integer;
    fname:string;
begin
 Progress.Reset(LVDir.SelCount);
 Progress.Msg:='Extracting files...';
 for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then
 begin
  fname:=DestDir+Caption;
  if (not FileExists(fname)) or (MsgBox('File '+fname+' already exists. Overwrite?','Warning',MB_YESNO)=idYES) then
   ExtractFile(Dir.OpenFileByFI(TFileInfo(Data)),fname);
  Progress.Step;
 end;
 Progress.Hide;
end;


Procedure TConManForm.ExtractFile(inFile:TFile;outFile:String);
var
    fout:TFile;
    bytes:longint;
    Buf:Array[0..$8000-1] of byte;
begin
 fout:=OpenFileWrite(outFile,fm_create+fm_letRewrite+fm_AskUser);
bytes:=inFile.Fsize;

Try
While bytes>sizeof(buf) do
begin
 inFile.Fread(buf,sizeof(buf));
 fout.FWrite(buf,sizeof(buf));
 dec(bytes,sizeof(buf));
end;
 inFile.Fread(buf,bytes);
 fout.FWrite(buf,bytes);
Finally
 inFile.Fclose;
 Fout.Fclose;
end;
end;

procedure TConManForm.Refresh1Click(Sender: TObject);
begin
 if Dir<>nil then OpenFile(Dir.GetFullName);
end;

procedure TConManForm.SelectAll1Click(Sender: TObject);
var i:Integer;
begin
With LVDir.Items do
begin
 BeginUpdate;
 For i:=0 to Count-1 do Item[i].Selected:=True;
 EndUpdate;
end;
end;

procedure TConManForm.InvertSelection1Click(Sender: TObject);
var i:Integer;
begin
With LVDir.Items do
begin
 BeginUpdate;
 For i:=0 to Count-1 do With Item[i] do Selected:=Not Selected;
 EndUpdate;
end;
end;

Procedure TConManForm.ProcessHDrop(Hdrop:Integer);
var s:array[0..255] of char;
    i:integer;
    files:TStringList;
begin
 files:=TStringList.Create;
 for i:=0 to DragQueryFile(Hdrop,Cardinal(-1),s,Length(s))-1 do
 begin
  DragQueryFile(HDrop,i,s,Length(s));
  files.Add(s);
 end;


Try
 if (Files.Count=1) and IsContainer(files[0]) then
 begin
  if (Dir=Nil) or (MsgBox('The file '+files[0]+' is a container. Would you like to open it rather then add it?','Question',MB_YESNO)=idYes) then
  begin
   OpenFile(files[0]);
   exit;
  end;
 end;

 DoAddFiles(files);
finally
 files.free;
end;
end;

Procedure TConManForm.WMDropFiles(var msg:TWMDropFiles);
begin
 ProcessHDrop(msg.drop);
 DragFinish(msg.drop);
end;

procedure TConManForm.LVDirColumnClick(Sender: TObject; Column: TListColumn);
begin
 Case Column.Index of
  0: LvDir.AlphaSort;
  1: LvDir.CustomSort(@CompareSizes,0);
 end;
end;

procedure TConManForm.HelpTopics1Click(Sender: TObject);
begin
 Application.HelpJump('Hlp_ConMan');
end;

procedure TConManForm.NewContainerClick(Sender: TObject);
var newCon,cdir:String;
    cc:TContainerCreator;
    files:TStringList;
    i:integer;
    f:TFile;
begin
 With NewConDialog do
 begin
  if Sender=LAB1 then
  begin
   DefaultExt:='lab';
   FileName:='Untitled.lab';
   Filter:='LAB files|*.lab';
  end;
  if Sender=GOB1 then
  begin
   DefaultExt:='gob';
   FileName:='Untitled.gob';
   Filter:='GOB files|*.gob';
  end;
  if Sender=LFD1 then
  begin
   DefaultExt:='lfd';
   FileName:='Untitled.lfd';
   Filter:='LFD files|*.lfd';
  end;
  if Sender=GOO1 then
  begin
   DefaultExt:='goo';
   FileName:='Untitled.goo';
   Filter:='GOO files|*.goo';
  end;
  if Sender=JKGOB1 then
  begin
   DefaultExt:='gob';
   FileName:='Untitled.gob';
   Filter:='JK GOB files|*.gob';
  end;
  if Sender=PAK1 then
  begin
   DefaultExt:='pak';
   FileName:='Untitled.pak';
   Filter:='Quake PAK files|*.pak';
  end;
  If not Execute then exit;
  newCon:=FileName;
 end;
 {if not AddDialog.Execute then exit;}

 if Sender=LAB1 then cc:=TLABCreator.Create(NewCon);
 if Sender=LFD1 then cc:=TLFDCreator.Create(NewCon);
 if Sender=GOB1 then cc:=TGOBCreator.Create(NewCon);
 if Sender=JKGOB1 then cc:=TGOB2Creator.Create(NewCon);
 if Sender=GOO1 then cc:=TGOB2Creator.Create(NewCon);
 if Sender=PAK1 then cc:=TPAKCreator.Create(NewCon);

{ cDir:=ExtractFilePath(AddDialog.FileName);}
 Files:=TStringList.Create;
{ Files.Assign(AddDialog.Files);}
try
 cc.prepareHeader(files);
{ Progress.Reset(files.count);
 for i:=0 to files.count-1 do
 begin
  Progress.Step;
  f:=OpenFileRead(Files[i],0);
  cc.AddFile(f);
  f.Fclose;
 end;}
finally
 Files.free;
 cc.Free;
 Progress.Hide;
end;
OpenFile(NewCon);
end;

Procedure TConManForm.DoAddFiles(newfiles:TStrings);
var oldCon,newCon,Fname:String;
    cc:TContainerCreator;
    files,flist,names:TStringList;
    i,nolds:integer;
    f:TFile;
begin
if Dir=nil then exit;
oldCon:=Dir.Name;
newCon:=Format('%s%x%s',['new',Integer(newFiles),ExtractFileExt(OldCon)]);
cc:=Dir.GetContainerCreator(NewCon);

flist:=TStringList.Create;
names:=TStringList.Create;

MakeLists(newFiles,flist,names);

Files:=TStringList.Create;
Files.Assign(Dir.Files);

For i:=0 to Names.Count-1 do
begin
 Fname:=Names[i];
 if not Dir.HasDirs then Fname:=ExtractFileName(fname);
 nolds:=files.IndexOf(fname);
 if nolds<>-1 then files.Delete(nolds);
end;

nolds:=files.Count;
Files.AddStrings(Names);
Try
try
 cc.prepareHeader(files);
 Progress.Reset(files.count);
 for i:=0 to nOlds-1 do
 begin
  Progress.Step;
  f:=Dir.OpenFile(Files[i],0);
  cc.AddFile(f);
  f.Fclose;
 end;

 for i:=nolds to files.count-1 do
 begin
  Progress.Step;
  f:=OpenFileRead(FList[i-nolds],0);
  cc.AddFile(f);
  f.Fclose;
 end;
finally
 cc.Free;
 Progress.Hide;
 Files.free;
 flist.free;
 names.free;
end;
except
 on Exception do begin DeleteFile(NewCon); raise; end;
end;

Dir.Free; Dir:=nil;
BackUpFile(OldCon);
RenameFile(NewCon,OldCon);
OpenFile(OldCon);
end;

procedure TConManForm.AddFilesClick(Sender: TObject);
begin
if not AddDialog.Execute then exit;
 DoAddFiles(AddDialog.Files);
end;

procedure TConManForm.DeleteFilesClick(Sender: TObject);
var oldCon,newCon:String;
    cc:TContainerCreator;
    tfiles,files:TStringList;
    i,n,nolds:integer;
    f:TFile;
    cpath:string;
Function GetCurDir:string;
begin
 Result:='';
 If not TVDirs.Visible then exit;
 if TVDirs.Selected=nil then exit;
 Result:=GetCurPath(TVDirs.Selected)+'\';
end;

begin
if LVDir.SelCount=0 then begin MsgBox('Select some files first','No, no, no!',mb_ok); exit; end;
oldCon:=Dir.Name;
newCon:=Format('%s%s%x%s',[ExtractFileName(OldCon),'new',Integer(sender),ExtractFileExt(OldCon)]);
cc:=Dir.GetContainerCreator(NewCon);
Files:=TStringList.Create;
Files.Assign(Dir.Files);


for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then
 begin
  n:=Files.IndexOfObject(TFileInfo(Data));
  if n<>-1 then Files.Delete(n);
 end;

try
 cc.prepareHeader(files);
 Progress.Reset(files.count);
 for i:=0 to Files.count-1 do
 begin
  Progress.Step;
  f:=Dir.OpenFileByFI(TFileInfo(Files.Objects[i]));
  cc.AddFile(f);
  f.Fclose;
 end;

finally
 Files.free;
 cc.Free;
 Progress.Hide;
end;
Dir.Free; Dir:=nil;
BackUpFile(OldCon);
RenameFile(NewCon,OldCon);
OpenFile(OldCon);
end;

procedure TConManForm.Paste1Click(Sender: TObject);
var clp:TClipboard;
    hdrop:integer;
begin
 clp:=Clipboard;
 if clp.HasFormat(CF_HDROP) then
 begin
  hdrop:=clp.GetAsHandle(CF_HDROP);
  ProcessHDrop(hdrop);
  clp.Close;
  {DragFinish(hdrop);}
 end;
end;

procedure TConManForm.Copy1Click(Sender: TObject);
var i:integer;
begin
 if Dir=nil then exit;
 FGiver:=TGiveFiles.Create(Dir);
 for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then FGiver.AddFile(Caption,TFileInfo(Data));
 FGiver.CopyIt;
end;

procedure TConManForm.FormHide(Sender: TObject);
var wp:TWindowPlacement;
begin
 if FGiver<>nil then begin Fgiver.Free; FGiver:=nil; end;
 {save the restored (normal) size so a maximized window does not store the full-screen size}
 wp.length:=SizeOf(wp);
 if GetWindowPlacement(Handle,@wp) then
 begin
  WinPos.X:=wp.rcNormalPosition.Left;
  WinPos.Y:=wp.rcNormalPosition.Top;
  WinPos.W:=wp.rcNormalPosition.Right-wp.rcNormalPosition.Left-(Width-ClientWidth);
  WinPos.H:=wp.rcNormalPosition.Bottom-wp.rcNormalPosition.Top-(Height-ClientHeight);
 end
 else
 begin
  WinPos.X:=Left;
  WinPos.Y:=Top;
  WinPos.W:=ClientWidth;
  WinPos.H:=ClientHeight;
 end;
 WinPos.Maxed:=integer(WindowState=wsMaximized);
 SizeBarPos:=TVDirs.Width;
end;

procedure TConManForm.LVDirMouseMove(Sender: TObject; Shift: TShiftState; X,
  Y: Integer);
var i:integer;
    li:TListItem;
begin
 if not (ssLeft in shift) then exit;
 li:=LVDir.GetItemAt(X,Y);
 if (li=nil) or (not li.selected) then exit;
 if Dir=nil then exit;
 if FGiver<>nil then begin Fgiver.Free; FGiver:=nil; end;
 FGiver:=TGiveFiles.Create(Dir);
 for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then FGiver.AddFile(Caption,TFileInfo(Data));
 DragAcceptFiles(Handle,false);
 FGiver.DragIt;
 DragAcceptFiles(Handle,true);
end;

procedure TConManForm.FormShow(Sender: TObject);
begin
  if Paramcount<>0 then OpenFile(ParamStr(1));
end;

Function TConManForm.GetCurPath(node:TTreeNode):String;
var root,cnode:TTreeNode;
begin
 Result:='';
 root:=TVDirs.Items.GetFirstNode;
 if node<>root then
 begin
  Result:=node.Text;
  cnode:=node.Parent;
  While cnode<>root do
  begin
   Result:=cnode.Text+'\'+Result;
   cnode:=cnode.parent;
  end;
 end;
end;

procedure TConManForm.TVDirsChange(Sender: TObject; Node: TTreeNode);
begin
 if dir=nil then exit;
 Dir.ChDir(GetCurPath(node));
 DirControl.SetMask('*');
 SetStatusBar;
end;

Function AddDefGOBDir(const fname:string):string;
var ext,newpath:string;
begin
 ext:=UpperCase(ExtractFileExt(fname));
 newpath:='';
 if ext='.JKL' then newpath:='jkl\'
 else if ext='.COG' then newpath:='cog\'
 else if ext='.3DO' then newpath:='3do\'
 else if ext='.MAT' then newpath:='mat\'
 else if ext='.DAT' then newpath:='misc\'
 else if ext='.UNI' then
 begin
   if (CompareText(ExtractFileName(fname),'cogstrings.uni')=0) or (CompareText(ExtractFileName(fname),'sithstrings.uni')=0)
     then newpath:='misc\' else newpath:='ui\';
 end
 else if ext='.KEY' then newpath:='3do\key\'
 else if (ext='.AI') or (ext='.AI0') or (ext='.AI2') then newpath:='misc\ai\'
 else if ext='.CMP' then newpath:='misc\cmp\'
 else if ext='.PAR' then newpath:='misc\par\'
 else if ext='.PER' then newpath:='misc\per\'
 else if ext='.PUP' then newpath:='misc\pup\'
 else if ext='.SND' then newpath:='misc\snd\'
 else if ext='.SPR' then newpath:='misc\spr\'
 else if ext='.WAV' then newpath:='sound\'
 else if ext='.BM' then newpath:='ui\bm\'
 else if ext='.SFT' then newpath:='ui\sft\'
 else if ext='.SMK' then newpath:='video\'
 else if ext='.SAN' then newpath:='video\';
 result:=newpath+fname;
end;

Function AddDefPAKDir(const fname:string):string;
var ext,newpath:string;
begin
 ext:=UpperCase(ExtractFileExt(fname));
 newpath:='';
 if ext='.WAV' then newpath:='sound\misc\'
 else if ext='.BSP' then newpath:='maps\'
 else if ext='.MDL' then newpath:='progs\'
 else if ext='.LMP' then newpath:='gfx\'
 else if ext='.PCX' then newpath:='env\'
 else if ext='.TGA' then newpath:='env\'
 else if ext='.WAL' then newpath:='textures\'
 else if ext='.DM2' then newpath:='demos\';
 result:=newpath+fname;
end;

Procedure TConManForm.MakeLists(files:TStrings;flist,names:TStringList);
{Makes list of files, putting files to directories by their
 extensions and resolving directories}
var i:integer;

procedure AddFile(const fname,name:string);
var n:integer;
begin
 n:=names.IndexOf(name);
 if n<>-1 then flist[n]:=fname else
 begin
  n:=names.add(name);
  flist.Insert(n,fname);
 end;
end;

Procedure AddDir(const dir,subdir:string);
var sr:TSearchRec;
    res:integer;
begin
 res:=FindFirst(dir+subdir+'\*.*',faAnyFile,sr);
 While res=0 do
 begin
  if ((sr.Attr and faVolumeID)=0) and (sr.name<>'.') and (sr.name<>'..') then
  if (sr.Attr and faDirectory)<>0 then AddDir(dir,subdir+'\'+sr.name)
  else AddFile(dir+subdir+'\'+sr.name,subdir+'\'+sr.name);
  res:=FindNext(sr);
 end;
 FindClose(sr);
end;

var fname:string;

begin
 flist.Clear;
 names.clear;
 names.sorted:=true;
 flist.sorted:=false;

 for i:=0 to files.count-1 do
 begin
  fname:=files[i];
  if DirectoryExists(fname) then
  begin
   AddDir(ExtractFilePath(fname),ExtractFileName(fname));
  end else
  begin
   if Dir is TGOB2Directory then AddFile(fname,AddDefGOBDir(ExtractFileName(fname)))
   else
   if Dir is TPAKDirectory then AddFile(fname,AddDefPAKDir(ExtractFileName(fname)))
   else AddFile(fname,ExtractFileName(fname));

  end;
 end;
end;

Procedure TConManForm.SetStatusBar;
begin
 if TVDirs.Visible then
 StatusBar.Panels[0].Text:=
 Format('%d File(s) in directory (%d in file)',[LVDir.Items.Count,Dir.Files.Count])
 else StatusBar.Panels[0].Text:=Format('%d File(s)',[Dir.Files.Count]);
end;


procedure TConManForm.AssociatecontainerswithConMan1Click(Sender: TObject);
var reg:TRegistry;

Procedure AssExt(const ext:string);
begin
 if not reg.OpenKey(ext,true) then exit;
 reg.WriteString('','Containers');
 reg.Closekey;
end;

begin
 reg:=TRegistry.Create;
Try
try
 reg.RootKey:=HKEY_CLASSES_ROOT;
 if not reg.OpenKey('\Containers',true) then Raise Exception.Create('Error accessing the registry');
 reg.WriteString('','Container File');
 reg.CloseKey;
 if not reg.OpenKey('\Containers\shell\open\command',true) then Raise Exception.Create('Error accessing the registry');
 reg.WriteString('',Paramstr(0)+' "%1"');
 reg.CloseKey;
 AssExt('.gob');
 AssExt('.goo');
 AssExt('.lab');
 AssExt('.lfd');
 AssExt('.wad');
 AssExt('.pak');
 ShowMessage('ConMan is now associated with .GOB, .GOO, .LAB, .LFD, .PAK and .WAD files');
finally
 reg.free;
end;

except
 On e:Exception do ShowMessage(e.message);
end;

end;

Function GetShellExecuteError(code:integer):string;
begin
case code of
 0: result:='';
 ERROR_FILE_NOT_FOUND:	result:='The specified file was not found.';
 ERROR_PATH_NOT_FOUND:	result:='The specified path was not found.';
 ERROR_BAD_FORMAT:      result:='The .EXE file is invalid (non-Win32 .EXE or error in .EXE image).';
 SE_ERR_ACCESSDENIED:   result:='The operating system denied access to the specified file.';
 SE_ERR_ASSOCINCOMPLETE: result:='The filename association is incomplete or invalid.';
 SE_ERR_DDEBUSY:        result:='The DDE transaction could not be completed because other DDE transactions were being processed.';
 SE_ERR_DDEFAIL:        result:='The DDE transaction failed.';
 SE_ERR_DDETIMEOUT:     result:='The DDE transaction could not be completed because the request timed out.';
 SE_ERR_DLLNOTFOUND:	result:='The specified dynamic-link library was not found.';
 SE_ERR_NOASSOC:        result:='There is no application associated with the given filename extension.';
 SE_ERR_OOM:	        result:='There was not enough memory to complete the operation.';
 SE_ERR_SHARE:          result:='A sharing violation occurred.';
else result:='Unknown error';
end;
end;

procedure TConManForm.LVDirDblClick(Sender: TObject);
var tempdir:array[0..255] of char;
    i,e:integer;
    fname:string;
begin
 GetTempPath(Length(tempdir),tempdir);
 Progress.Reset(LVDir.SelCount);
 Progress.Msg:='Extracting files...';
 for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then
 begin
  Progress.Step;
  fname:=tempdir+caption;
  ExtractFile(Dir.OpenFileByFI(TFileInfo(Data)),fname);
  FilesToDelete.Add(fname);
  e:=ShellExecute(Handle,NIL,pchar(fname),NIL,tempdir,SW_SHOWNORMAL);
  if e<32 then ShowMessage('Couldn''t open file '+fname+' '+GetShellExecuteError(e));
 end;
 Progress.Hide;
end;

Procedure TConManForm.RefreshRecents;
var mi:Tmenuitem; i:integer;
begin
 while ReopenContainer.Count>0 do ReopenContainer.Delete(0);
 for i:=0 to recents.count-1 do
 begin
  if Recents[i]='' then continue;
  mi:=TMenuItem.Create(Self);
  mi.Caption := StringReplace(Recents[i],'&','&&',[rfReplaceAll]); {'&' in a path would otherwise become an accelerator}
  mi.Tag := i;
  mi.OnClick:=ReopencontainerClick;
  ReopenContainer.Add(mi);
 end;
 ReopenContainer.Enabled:=ReopenContainer.Count>0;
end;

Procedure TConManForm.AddRecent(const recent:string);
var n:integer;
begin
 n:=Recents.IndexOf(recent);
 if n<>-1 then Recents.Delete(n);
 Recents.Insert(0,recent);
 if Recents.Count>4 then recents.Delete(4);
 RefreshRecents;
end;

procedure TConManForm.ReopencontainerClick(Sender: TObject);
var n:integer; path:string;
begin
 n:=(Sender as TMenuItem).Tag;
 if (n<0) or (n>=Recents.Count) then exit;
 path:=Recents[n];
 if not FileExists(path) then
 begin
  Recents.Delete(n); {drop entries whose file is gone}
  RefreshRecents;
  MessageDlg(path+' no longer exists and was removed from the recent files list.',mtWarning,[mbOK],0);
  exit;
 end;
 OpenFile(path);
end;

procedure TConManForm.MoveFilesClick(Sender: TObject);
var subdir:string;
    sl:TstringList;
    i:integer;
begin
 subdir:=Dir.CurDir;
 if not MoveForm.GetMoveToDir(Dir,subdir) then exit;
 if (subdir<>'') and (subdir[length(subdir)]<>'\') then subdir:=subdir+'\'; 

 sl:=TstringList.Create;
 for i:=0 to LvDir.Items.Count-1 do
 With LVDir.Items[i] do
 if Selected then
 begin
  sl.AddObject(subdir+Caption,TObject(Data));
 end;
try
 Dir.RenameFiles(sl);
finally
 sl.Free;
 OpenFile(Dir.Name);
end;
end;

procedure TConManForm.LVDirEdited(Sender: TObject; Item: TListItem;
  var S: string);
var sl:TStringList;
begin
 sl:=TStringList.Create;

 sl.AddObject(ConcPath(Dir.CurDir,s),TObject(Item.Data));
try
 if not Dir.RenameFiles(sl) then s:=Item.Caption;
finally
 sl.Free;
end;
end;

procedure TConManForm.PNResizeTVDirsMouseMove(Sender: TObject; Shift: TShiftState;
  X, Y: Integer);
var pt:TPoint;
begin
 if ssLeft in Shift then
 begin
  pt.x:=x; pt.y:=y;
  pt:=PNResizeTVDirs.ClientToScreen(pt);
  pt:=ScreenToClient(pt);
  if TVDirs.Width<>(pt.X-PNResizeTVDirs.Width div 2) then
  if ((pt.X-PNResizeTVDirs.Width div 2)<ClientWidth-MinPanelSize) and
     ((pt.X-PNResizeTVDirs.Width div 2)>MinPanelSize) then
  begin
   TVDirs.Width:=pt.X-PNResizeTVDirs.Width div 2;
  end;
 end;
end;

end.

