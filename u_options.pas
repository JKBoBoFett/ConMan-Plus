unit u_options;

{Settings (recent files, window position) are stored in ConMan.ini next to the program.
 If that folder is not writable the file goes to %APPDATA%\ConMan instead.}

interface
uses Classes, SysUtils, IniFiles;

type

    TWinPos=record
     X,Y,W,H:integer;
     maxed:integer;
    end;

const
 MaxRecents=4;

var
 Recents:TStringList;
 WinPos:TWinPos=(X:-1;Y:-1;W:-1;H:-1;Maxed:0);
 sizeBarPos:integer=-1;

implementation

Function IniFileName:string;
var dir,appdata:string; f:TextFile; test:string;
begin
 dir:=ExtractFilePath(ParamStr(0));
 Result:=dir+'ConMan.ini';
 if FileExists(Result) then exit;
 {can we create a file next to the exe?}
 test:=dir+'ConMan.tmp';
 AssignFile(f,test);
 {$I-}
 Rewrite(f);
 {$I+}
 if IOResult=0 then
 begin
  CloseFile(f);
  DeleteFile(test);
  exit;
 end;
 appdata:=GetEnvironmentVariable('APPDATA');
 if appdata='' then exit;
 appdata:=IncludeTrailingPathDelimiter(appdata)+'ConMan\';
 ForceDirectories(appdata);
 Result:=appdata+'ConMan.ini';
end;

Procedure LoadSettings;
var ini:TIniFile; i:integer; s:string;
begin
 Recents:=TStringList.Create;
 ini:=TIniFile.Create(IniFileName);
 try
  for i:=1 to MaxRecents do
  begin
   s:=ini.ReadString('Recent','File'+IntToStr(i),'');
   if s<>'' then Recents.Add(s);
  end;
  WinPos.X:=ini.ReadInteger('Window','X',WinPos.X);
  WinPos.Y:=ini.ReadInteger('Window','Y',WinPos.Y);
  WinPos.W:=ini.ReadInteger('Window','W',WinPos.W);
  WinPos.H:=ini.ReadInteger('Window','H',WinPos.H);
  WinPos.Maxed:=ini.ReadInteger('Window','Maximized',WinPos.Maxed);
  sizeBarPos:=ini.ReadInteger('Window','SizeBarPos',sizeBarPos);
 finally
  ini.Free;
 end;
end;

Procedure SaveSettings;
var ini:TIniFile; i:integer;
begin
 try
  ini:=TIniFile.Create(IniFileName);
  try
   for i:=1 to MaxRecents do
    if i<=Recents.Count then ini.WriteString('Recent','File'+IntToStr(i),Recents[i-1])
    else ini.DeleteKey('Recent','File'+IntToStr(i));
   ini.WriteInteger('Window','X',WinPos.X);
   ini.WriteInteger('Window','Y',WinPos.Y);
   ini.WriteInteger('Window','W',WinPos.W);
   ini.WriteInteger('Window','H',WinPos.H);
   ini.WriteInteger('Window','Maximized',WinPos.Maxed);
   ini.WriteInteger('Window','SizeBarPos',sizeBarPos);
  finally
   ini.Free;
  end;
 except
  on Exception do; {settings are best effort}
 end;
 Recents.Free;
end;

initialization
 LoadSettings;

finalization
 SaveSettings;

end.
