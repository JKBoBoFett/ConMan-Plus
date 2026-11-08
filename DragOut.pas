unit DragOut;

interface
uses files, ActiveX, classes, clipbrd, fileoperations;

Type
 TGiveFiles=class
  data:IDataObject;
  copied:boolean;
  FContainer:TContainerFile;
  Files:TStringList;
  extracted:boolean;
  Constructor Create(Container:TContainerFile);
  Destructor Destroy;override;
  Procedure Clear;
  Procedure AddFile(Name:String;fi:TFileInfo);
  Procedure CopyIt; {Copies to clipboard}
  Procedure DragIt; {Drag&drops}
  Procedure ExtractFiles;
 end;

implementation

uses Windows, ComObj {for OleCheck}, SysUtils, ShlObj;

var TempDir:String;

type
  TMyDataObject = class(TObject, IDataObject)
  private
    RefCount: integer;
    Data: TStringList;
  public
    function QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
    function _AddRef: Longint; stdcall;
    function _Release: Longint; stdcall;
    function GetData(const formatetcIn: TFormatEtc; out medium: TStgMedium):
      HResult; stdcall;
    function GetDataHere(const formatetc: TFormatEtc; out medium: TStgMedium):
      HResult; stdcall;
    function QueryGetData(const formatetc: TFormatEtc): HResult;
      stdcall;
    function GetCanonicalFormatEtc(const formatetc: TFormatEtc;
      out formatetcOut: TFormatEtc): HResult; stdcall;
    function SetData(const formatetc: TFormatEtc; var medium: TStgMedium;
      fRelease: BOOL): HResult; stdcall;
    function EnumFormatEtc(dwDirection: Longint; out enumFormatEtc:
      IEnumFormatEtc): HResult; stdcall;
    function DAdvise(const formatetc: TFormatEtc; advf: Longint;
      const advSink: IAdviseSink; out dwConnection: Longint): HResult; stdcall;
    function DUnadvise(dwConnection: Longint): HResult; stdcall;
    function EnumDAdvise(out enumAdvise: IEnumStatData): HResult;
      stdcall;
    constructor Create(sl: TStringList);
  end;

  TMyEnum = class(TObject, IEnumFormatEtc)
  private
    RefCount: integer;
    Index: integer;

  public
    function QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
    function _AddRef: Longint; stdcall;
    function _Release: Longint; stdcall;
    function Next(celt: Longint; out elt;
      pceltFetched: PLongint): HResult; stdcall;
    function Skip(celt: Longint): HResult; stdcall;
    function Reset: HResult; stdcall;
    function Clone(out enum: IEnumFormatEtc): HResult; stdcall;
  end;

  TMyDropSource = class(TObject, IDropSource)
  private
    RefCount: integer;
    dobj:TMyDataObject;
    giver:TGiveFiles;
  public
    Constructor Create(obj:TMyDataObject;agiver:TGiveFiles);
    function QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
    function _AddRef: Longint; stdcall;
    function _Release: Longint; stdcall;
    function QueryContinueDrag(fEscapePressed: BOOL;
      grfKeyState: Longint): HResult; stdcall;
    function GiveFeedback(dwEffect: Longint): HResult; stdcall;
  end;


Function Slist2Hdrop(sl:TStringList):HGlobal;
var
  pdf: PDropFiles;
  ps, ps1: PChar;
  lentdir,len:Integer;
  i:integer;
begin
  len:=0;
  lentdir:=Length(TempDir);
  For i:=0 to sl.Count-1 do
   inc(len,Length(sl[i])+1+Lentdir);
  Result := GlobalAlloc(GMEM_SHARE, Sizeof(pdf^)+(len+2)*SizeOf(Char));
    if Result = 0 then exit;

 pdf:=GlobalLock(Result);
 with pdf^ do
 begin
  pFiles:=sizeof(pdf^);
  pt.X:=0;
  pt.Y:=0;
  fNC:=true;
  fWide:=true; {PChar is UTF-16}
 end;
 ps:=pchar(pdf)+sizeof(pdf^);
 ps1:=ps;
 ps^:=#0;
 for i:=0 to sl.Count-1 do
 begin
  ps:=StrEcopy(ps,pchar(TempDir));
  ps:=StrECopy(ps,Pchar(sl[i]))+1;
 end;
 ps^:=#0;
 if ps1=nil then;
 GlobalUnlock(Result);
end;

{ TMyDataObject }
constructor TMyDataObject.Create(sl: TStringList);
begin
  inherited Create;
  Data := sl;
end;

function TMyDataObject.QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
begin
  if GetInterface(iid, obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TMyDataObject._AddRef: Longint; stdcall;
begin
  Inc(RefCount);
  Result := RefCount;
end;

function TMyDataObject._Release: Longint; stdcall;
begin
  Dec(RefCount);
  Result := RefCount;
  if RefCount = 0 then
    Free;
end;

function TMyDataObject.GetData(const formatetcIn: TFormatEtc; out medium: TStgMedium):
      HResult; stdcall;
var
  hdf: HGlobal;
begin
  if Failed(QueryGetData(formatetcIn)) then
    Result := DV_E_FORMATETC
  else begin
  hdf:=sList2HDrop(data);
   if hdf=0 then
   begin
    Result := E_OUTOFMEMORY;
    Exit;
   end;

    with medium do begin
      tymed := TYMED_HGLOBAL;
      hGlobal:=hdf;
      unkForRelease := nil;
    end;

    Result := S_OK;
  end;
end;

function TMyDataObject.GetDataHere(const formatetc: TFormatEtc; out medium: TStgMedium):
      HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TMyDataObject.QueryGetData(const formatetc: TFormatEtc): HResult; stdcall;
begin
  with formatetc do begin
    if cfFormat <> CF_HDROP then
      Result := DV_E_FORMATETC
    else if (tymed and TYMED_HGLOBAL) = 0 then
      Result := DV_E_TYMED
    else
      Result := S_OK;
  end;
end;

function TMyDataObject.GetCanonicalFormatEtc(const formatetc: TFormatEtc;
      out formatetcOut: TFormatEtc): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TMyDataObject.SetData(const formatetc: TFormatEtc; var medium: TStgMedium;
      fRelease: BOOL): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TMyDataObject.EnumFormatEtc(dwDirection: Longint; out enumFormatEtc:
      IEnumFormatEtc): HResult; stdcall;
begin
  if dwDirection = DATADIR_GET then begin
    enumFormatEtc := TMyEnum.Create;
    Result := S_OK;
  end else begin
    enumFormatEtc := nil;
    Result := E_NOTIMPL;
  end;
end;

function TMyDataObject.DAdvise(const formatetc: TFormatEtc; advf: Longint;
      const advSink: IAdviseSink; out dwConnection: Longint): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TMyDataObject.DUnadvise(dwConnection: Longint): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;

function TMyDataObject.EnumDAdvise(out enumAdvise: IEnumStatData): HResult; stdcall;
begin
  Result := E_NOTIMPL;
end;


{ TMyEnum }

function TMyEnum.QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
begin
  if GetInterface(iid, obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TMyEnum._AddRef: Longint; stdcall;
begin
  Inc(RefCount);
  Result := RefCount;
end;

function TMyEnum._Release: Longint; stdcall;
begin
  Dec(RefCount);
  Result := RefCount;
  if RefCount = 0 then
    Free;
end;

function TMyEnum.Next(celt: Longint; out elt;
      pceltFetched: PLongint): HResult; stdcall;
begin
  Result := S_FALSE;
  if (Index = 0) and (celt > 0) then begin
    Inc(Index);
    with TFormatEtc(elt) do begin
      cfFormat := CF_HDROP;
      ptd := nil; // not sure I should do this!
      dwAspect := DVASPECT_ICON;
      lindex := -1;
      tymed := TYMED_HGLOBAL;
    end;

    if pceltFetched <> nil then pceltFetched^ := 1;
    if celt = 1 then Result := S_OK;
  end else begin
    if pceltFetched <> nil then pceltFetched^ := 0;
  end;
end;

function TMyEnum.Skip(celt: Longint): HResult; stdcall;
begin
  Inc(Index, celt);
  if Index > 1 then Result := S_FALSE else Result := S_OK;
end;

function TMyEnum.Reset: HResult; stdcall;
begin
  Index := 0;
  Result := S_OK;
end;

function TMyEnum.Clone(out enum: IEnumFormatEtc): HResult; stdcall;
var e: TMyEnum;
begin
  e := TMyEnum.Create;
  e.Index := Index;
  enum := e;
  Result := S_OK;
end;


{ TMyDropDSource }

Constructor TMyDropSource.Create(obj:TMyDataObject;agiver:TGiveFiles);
begin
 dobj:=obj;
 giver:=agiver;
end;

function TMyDropSource.QueryInterface(const iid: TGUID; out obj): HResult; stdcall;
begin
  if GetInterface(iid, obj) then Result := S_OK else Result := E_NOINTERFACE;
end;

function TMyDropSource._AddRef: Longint; stdcall;
begin
  Inc(RefCount);
  Result := RefCount;
end;

function TMyDropSource._Release: Longint; stdcall;
begin
  Dec(RefCount);
  Result := RefCount;
  if RefCount = 0 then
    Free;
end;

function TMyDropSource.QueryContinueDrag(fEscapePressed: BOOL;
      grfKeyState: Longint): HResult; stdcall;
begin
  if fEscapePressed then
    Result := DRAGDROP_S_CANCEL
  else if (grfKeyState and MK_LBUTTON) = 0 then
  begin  Result := DRAGDROP_S_DROP; giver.ExtractFiles; end
  else
    Result := NOERROR;
end;

function TMyDropSource.GiveFeedback(dwEffect: Longint): HResult; stdcall;
begin
  Result := DRAGDROP_S_USEDEFAULTCURSORS;
end;


{ Global Function }

Constructor TGiveFiles.Create(Container:TContainerFile);
begin
 FContainer:=Container;
 files:=TStringList.Create;
end;

Destructor TGiveFiles.Destroy;
begin
 Clear;
 files.free;
 inherited;
end;

Procedure TGiveFiles.AddFile(Name:String;fi:TFileInfo);
begin
 Files.AddObject(Name,Fi);
end;

Procedure TGiveFiles.Clear;
var clp:TClipBoard;
    i:integer;
begin
 clp:=Clipboard;
 if clp.HasFormat(CF_HDROP) then Clp.Clear;
 if extracted then
 for i:=0 to files.count-1 do
   DeleteFile(TempDir+files[i]);
 extracted:=false;
 Files.Clear;
end;

Procedure TGiveFiles.CopyIt; {Copies to clipboard}
var  hdf:Hglobal;
     clp:TClipBoard;
begin
 ExtractFiles;
 hdf:=sList2HDrop(files);
 clp:=Clipboard;
 clp.SetAsHandle(CF_HDROP,hdf);
end;

Procedure TGiveFiles.ExtractFiles;
var i:integer;
    f,fout:TFile;
begin
 if extracted then exit;
 for i:=0 to Files.Count-1 do
 begin
  f:=FContainer.OpenFileByFI(TFileInfo(Files.Objects[i]));
  fout:=OpenFileWrite(TempDir+files[i],0);
  CopyFileData(f,fout,f.fsize);
  f.Fclose;
  fout.Fclose;
 end;
 extracted:=true;
end;


Procedure TGiveFiles.DragIt; {Drag&drops}
var
  MyData: TMyDataObject;
  MyDrop: TMyDropSource;
  Effect: LongInt;
begin
 {ExtractFiles;}
  try
    MyData := TMyDataObject.Create(files);
    MyData._AddRef;
{    OleSetClipBoard(MyData);
    exit;}
    try
      MyDrop := TMyDropSource.Create(MyData,self);
      MyDrop._AddRef;
      try
        DoDragDrop(MyData, MyDrop,
                       DROPEFFECT_COPY, Effect);

      finally
        MyData._Release;
      end;
    finally
      MyDrop._Release;
    end;
  except
  end;
end;



{ Startup/Shutdown }
var s:array[0..255] of char;

initialization
begin
  OleCheck(OleInitialize(nil));
  GetTempPath(256,s);
  TempDir:=s;
end;

finalization
  OleUninitialize;
end.
