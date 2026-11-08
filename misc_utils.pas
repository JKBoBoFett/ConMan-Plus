unit misc_utils;

interface
uses Classes, SysUtils{, GlobalVars}, Forms;

{Miscellaneous help routines}

Type
TStringParser=class(TStringList)
 Procedure ParseString(var s:STring);
end;

TMsgType=(mt_info,mt_warning,mt_error);  {Message Types for PanMessage() }

Function MsgBox(Txt, Caption:String;flags:Integer):Integer;
Function GetWord(const s:string;p:integer;var w:string):integer;
Function GetWordN(const s:String;n:integer):String;
Function PGetWord(ps:Pchar;pw:Pchar):Pchar; {Same thing, but for PChar strings}
Function AStr(const a:array of AnsiChar):String; {zero-terminated AnsiChar array -> String}
Function StrToDouble(const s:String):Double;
Function StrToLongInt(const s:String):Longint;
Function HexToDword(const s:String):Longint;
Function StrToDword(const s:String):Longint;
Function DwordToStr(d:Longint):String;
Function PScanf(ps:pchar;const format:String;const Vals:array of pointer):boolean;
Function SScanf(const s:string;const format:String;const Vals:array of pointer):boolean;
Function Real_Min(a,b:Double):Double;
Function Real_Max(a,b:Double):Double;
Function RoundTo2Dec(d:Double):Double; {Rounds to 2 decimal points}
{handles the number -2147483648 ($80000000) properly.
 for some reason, StrToInt gets confused by it}

Function ValInt(const s:String;var i:Integer):Boolean;
Function ValHex(const s:String;var h:LongInt):Boolean;
Function ValDword(const s:String; var d:LongInt):Boolean;
Function ValDouble(const s:String; var d:Double):Boolean;

Procedure RemoveComment(var s:String);

Function ScanForSpace(const s:string;p:integer):integer; {if p is negative - scan backwards}
Function ScanForNonSpace(const s:string;p:integer):integer; {if p is negative - scan backwards}

Function ConcPath(const dir,subdir:string):string;

implementation
uses Windows;

Function ConcPath(const dir,subdir:string):string;
begin
 if dir='' then begin result:=subdir; exit; end;
 if dir[length(dir)]<>'\' then result:=dir+'\'+subdir
 else result:=dir+subdir;
end;


Function ScanForSpace(const s:string;p:integer):integer; {if p is negative - scan backwards}
begin
 if p<0 then {backwards}
 begin
  p:=-p;
  while (p>1) and not (s[p] in [' ',#9]) do dec(p);
  Result:=p;
 end else
 begin
  While (p<=length(s)) and not (s[p] in [' ',#9]) do inc(p);
  Result:=p;
 end;
end;

Function ScanForNonSpace(const s:string;p:integer):integer; {if p is negative - scan backwards}
begin
 if p<0 then {backwards}
 begin
  p:=-p;
  while (p>1) and (s[p] in [' ',#9]) do dec(p);
  Result:=p;
 end else
 begin
  While (p<=length(s)) and (s[p] in [' ',#9]) do inc(p);
  Result:=p;
 end;
end;

Function GetWordN(const s:String;n:integer):String;
var i,p:Integer;
begin
 p:=1;
 for i:=1 to n do
 begin
  p:=ScanForNonSpace(s,p);
  if i<>n then p:=ScanForSpace(s,p);
 end;
 i:=ScanForSpace(s,p);
 Result:=UpperCase(Copy(s,p,i-p));
end;

Procedure RemoveComment(var s:String);
var p:integer;
begin
 p:=Pos('#',s);
 if p<>0 then SetLength(s,p-1);
end;

Function Real_Min(a,b:Double):Double;
begin
 if a>b then result:=b else result:=a;
end;

Function Real_Max(a,b:Double):Double;
begin
 if a>b then result:=a else result:=b;
end;

Function RoundTo2Dec(d:Double):Double;
begin
 Result:=Round(d*100)/100;
end;

Function StrToDouble(const s:String):Double;
var a:Integer;
begin
 if s='' then begin result:=0; exit; end;
 Val(s,Result,a);
 if a<>0 then raise EConvertError.Create('Invalid number: '+s);
end;

Function StrToLongInt(const s:String):Longint;
var a:Integer;
begin
 Val(s,Result,a);
end;

Function HexToDword(const s:String):Longint;
var a:Integer;
begin
 if s='' then begin result:=0; exit; end;
 Val('$'+s,Result,a);
end;

Function ValInt(const s:String;var i:Integer):Boolean;
var a:Integer;
begin
 Result:=true;
 if s='' then begin i:=0; exit; end;
 Val(s,i,a);
 Result:=a=0;
end;

Function ValHex(const s:String;var h:LongInt):Boolean;
var a:Integer;
begin
 Result:=true;
 if s='' then begin h:=0; exit; end;
 Val('$'+s,h,a);
 Result:=a=0;
end;

Function ValDword(const s:String; var d:LongInt):Boolean;
var a:Integer;
begin
 Result:=true;
 if s='' then begin d:=0; exit; end;
 Val(s,d,a);
 if a=10 then
 if s[10] in ['0'..'9'] then
 begin
  d:=d*10+(ord(s[10])-ord('0'));
  a:=0;
 end;
 Result:=not ((a<>0) and (s[a]<>#0));
end;

Function ValDouble(const s:String; var d:Double):Boolean;
var a:Integer;
begin
 Result:=true;
 if s='' then begin d:=0; exit; end;
 Val(s,d,a);
 Result:=a=0;
end;


Function StrToDword(const s:String):Longint;
var a:Integer;
begin
 if s='' then begin result:=0; exit; end;
 Val(s,Result,a);
 if a=10 then
 if s[10] in ['0'..'9'] then
 begin
  Result:=Result*10+(ord(s[10])-ord('0'));
  a:=0;
 end;
 if (a<>0) and (s[a]<>#0)
  then Raise EConvertError.Create(s+' is not a valid number');
end;

Function DwordToStr(d:Longint):String;
begin
 Result:=UIntToStr(Cardinal(d)); {unsigned conversion; replaces old asm that assumed 1-byte Char}
end;


Function AStr(const a:array of AnsiChar):String;
var n,i:Integer;
begin
 n:=0;
 while (n<=High(a)) and (a[n]<>#0) do inc(n);
 SetLength(Result,n);
 for i:=0 to n-1 do Result[i+1]:=Char(Ord(a[i]));
end;

Function MsgBox(Txt, Caption:String;flags:Integer):Integer;
begin
 Result:=Application.MessageBox(Pchar(Txt),Pchar(Caption),flags);
end;

Function GetWord(const s:string;p:integer;var w:string):integer;
var b,e:integer;
begin
 if s='' then begin w:=''; result:=1; exit; end;
 b:=p;
 While (s[b] in [' ',#9]) and (b<=length(s)) do inc(b);
 e:=b;
 While (not (s[e] in [' ',#9])) and (e<=length(s)) do inc(e);
 w:=Copy(s,b,e-b);
 GetWord:=e;
end;

Function PGetWord(ps:Pchar;pw:Pchar):Pchar;
var pb,pe:PChar;
begin
 if ps^=#0 then begin pw^:=#0; result:=ps; exit; end;
 pb:=ps;
 while pb^ in [' ',#9] do inc(pb);
 pe:=pb;
 while not (pe^ in [' ',#9,#0]) do inc(pe);
 StrLCopy(pw,pb,pe-pb);
 Result:=pe;
end;

Function PScanf(ps:pchar;const format:String;const Vals:array of pointer):boolean;
var pp, {position of % in format string}
    pb, {beginning of the prefix}
    pv, {position of the value}
    pe, {end of the prefix}
    pf:Pchar;
    tmp:array[0..99] of char;
    ptmp:Pchar;
    Len:Integer; {Lenth of prefix string}
    a, {Dummy variable for Val()}
    nval:Integer; {Index in vals[] array}
    lastdigit,dw:Dword;
    c:Char;
begin
 Result:=true;
 nval:=0;
 pf:=PChar(format);
 Repeat
  pp:=StrScan(pf,'%'); if pp=nil then break;
  pb:=pf;
  while (pb^ in [' ',#9]) and (pb<pp) do inc(pb);

  if pp=pb then
  begin
   Len:=0; pv:=ps;
  end
  else
  begin
   pe:=pp-1;
   while (pe^ in [' ',#9]) and (pe>pb) do dec(pe);
   len:=pe-pb+1;
   StrLCopy(tmp,pb,len);
   pv:=StrPos(ps,tmp);
   if pv=nil then begin pf:=pp+1; if pf^<>#0 then inc(pf); inc(nval); continue;  end;
   pv:=pv+len;
  end;

  ptmp:=@tmp[1];
  ps:=PGetWord(pv,ptmp);
  inc(pp); a:=0;
  case pp^ of {format specifier}
   'd','D': Val(Ptmp,Integer(Vals[nval]^),a);
   'u','U': begin
             Val(PTmp,dw,a);
             if a<>0 then
             begin
              c:=(Ptmp+a-1)^;
              if c in ['0'..'9'] then
              begin
               lastdigit:=Ord(c)-Ord('0');
               dw:=dw*10+lastdigit;
               a:=0;
              end;
             end;
             Dword(Vals[nval]^):=dw;
            end;
   'f','F': Val(Ptmp,Double(Vals[nval]^),a);
   'b','B': Val(Ptmp,byte(Vals[nval]^),a);
   'c','C': Char(Vals[nval]^):=Ptmp^;
   's','S': String(Vals[nval]^):=ptmp;
   'x','X': begin
             tmp[0]:='$';
             Val(tmp,Integer(Vals[nval]^),a);
            end;
  else a:=1;
  end;
  if a<>0 then result:=false;
  pf:=pp; if pf^<>#0 then inc(pf);
  inc(nval);
 until false;

end;

Function SScanf(const s:string;const format:String;const Vals:array of pointer):boolean;
begin
 Result:=pScanf(PChar(s),format,vals);
end;

Procedure TStringParser.ParseString(var s:STring);
var cpos:Word;w:String;
begin
 Clear;
 cpos:=1;
 While Cpos<Length(s) do
 begin
  cPos:=GetWord(s,cpos,w);
  Add(UpperCase(w));
 end;
end;

Function StrToDoubleDef(const s:String;def:Double):Double;
var a:Integer;
begin
 Val(s,result,a);
 if a<>0 then Result:=def;
end;

end.
