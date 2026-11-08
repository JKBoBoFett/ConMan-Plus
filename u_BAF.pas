unit u_BAF;

{Read-only container for Obi-Wan (Saber / "BAF") model files.
 A BAF is a memory image of the engine's rdModel3 structures plus embedded
 8-bit MATs and embedded keyframes.  This unit presents it like an archive:

   <model>.3do        JK text 3DO built from the model data
   mat\<name> .mat    the embedded 8-bit MATs (extracted untouched, or converted to
                      16-bit with the BAF palette baked in when Convert16 is set)
   key\<name>.key    every embedded animation as a JK text KEY file }

interface
uses Classes, SysUtils, Files;

type
  TBAFFileInfo = class(TFileInfo)
    Data: TBytes;   {original bytes}
    Data16: TBytes; {16-bit conversion (MATs only; empty if conversion failed)}
  end;

  TMemFile = class(TFile)
    FName: String;
    Data: TBytes;
    FPosn: Integer;
    Constructor CreateRead(const aName: String; const aData: TBytes);
    Function GetFullName: String; override;
    Function GetShortName: String; override;
    Function Fread(var buf; size: integer): integer; override;
    Function Fwrite(const buf; size: integer): integer; override;
    Function Fsize: Longint; override;
    Function Fpos: Longint; override;
    Procedure Fseek(Pos: longint); override;
    Destructor FClose; override;
  end;

  TBAFDirectory = class(TContainerFile)
    Convert16: Boolean; {when set, .mat files are opened as converted 16-bit MATs}
    Procedure Refresh; override;
    Function DataFor(fi: TBAFFileInfo): TBytes;
    Function OpenFile(Fname: TFileName; mode: Integer): TFile; override;
    Function OpenFilebyFI(fi: TFileInfo): TFile; override;
    Procedure RenameFile(Fname, newname: TFileName); override;
    Function DeleteFiles(DelList: TStringList): boolean; override;
    Function AddFiles(AddList: TStringList): boolean; override;
    Function GetContainerCreator(name: String): TContainerCreator; override;
    Function RenameFiles(newnames: TStringList): boolean; override;
  end;

implementation

uses Math;

var
  FS: TFormatSettings;

{ ---------- TMemFile ---------- }

Constructor TMemFile.CreateRead(const aName: String; const aData: TBytes);
begin
  inherited Create;
  FName := aName;
  Data := aData;
  FPosn := 0;
end;

Function TMemFile.GetFullName: String;
begin
  Result := FName;
end;

Function TMemFile.GetShortName: String;
begin
  Result := ExtractFileName(StringReplace(FName, '\', PathDelim, [rfReplaceAll]));
end;

Function TMemFile.Fread(var buf; size: integer): integer;
begin
  Result := Length(Data) - FPosn;
  if Result > size then Result := size;
  if Result < 0 then Result := 0;
  if Result > 0 then Move(Data[FPosn], buf, Result);
  Inc(FPosn, Result);
end;

Function TMemFile.Fwrite(const buf; size: integer): integer;
begin
  raise Exception.Create('BAF contents are read-only');
end;

Function TMemFile.Fsize: Longint;
begin
  Result := Length(Data);
end;

Function TMemFile.Fpos: Longint;
begin
  Result := FPosn;
end;

Procedure TMemFile.Fseek(Pos: longint);
begin
  FPosn := Pos;
end;

Destructor TMemFile.FClose;
begin
  Data := nil;
end;

{ ---------- helpers ---------- }

Function RdI(const D: TBytes; o: Integer): Integer;
begin
  if (o < 0) or (o + 4 > Length(D)) then raise Exception.Create('BAF: read past end of file');
  Move(D[o], Result, 4);
end;

Function RdF(const D: TBytes; o: Integer): Single;
begin
  if (o < 0) or (o + 4 > Length(D)) then raise Exception.Create('BAF: read past end of file');
  Move(D[o], Result, 4);
end;

Function RdZ(const D: TBytes; o, n: Integer): String;
var i: Integer;
begin
  Result := '';
  for i := 0 to n - 1 do
  begin
    if D[o + i] = 0 then break;
    Result := Result + Char(D[o + i]);
  end;
end;

Function FmtF(x: Single; w, p: Integer): String;
var d: Double;
begin
  d := x;
  Result := Format('%*.*f', [w, p, d], FS);
end;

Function IsNameChar(b: Byte; allowDash: Boolean): Boolean;
begin
  Result := ((b >= Ord('0')) and (b <= Ord('9'))) or ((b >= Ord('A')) and (b <= Ord('Z'))) or
            ((b >= Ord('a')) and (b <= Ord('z'))) or (b = Ord('_')) or (b = Ord('.')) or
            (allowDash and (b = Ord('-')));
end;

Function TextToBytes(const s: String): TBytes;
begin
  Result := TEncoding.ANSI.GetBytes(s);
end;

{ ---------- 8-bit MAT helpers ---------- }

{Offset just past the pixel data of the 8-bit MAT starting at raw (where an embedded palette would begin)}
Function MatPixelEnd(const D: TBytes; raw: Integer): Integer;
var rc, cc, c, m, n, sx, sy, nm, q: Integer;
begin
  rc := RdI(D, raw + 12);
  cc := RdI(D, raw + 16);
  q := raw + 76 + rc * 40;
  for c := 0 to cc - 1 do
  begin
    sx := RdI(D, q);
    sy := RdI(D, q + 4);
    nm := RdI(D, q + 20);
    Inc(q, 24);
    n := 0;
    for m := 0 to Max(nm, 1) - 1 do
      Inc(n, Max(sx shr m, 1) * Max(sy shr m, 1));
    Inc(q, n);
  end;
  Result := q;
end;

{ ---------- 8-bit MAT -> 16-bit MAT ---------- }

Function Mat8to16(const D: TBytes; raw, rawEnd: Integer): TBytes;
type
  TCell = record sx, sy, tb, nm, po, n: Integer; end;
var
  rc, cc, q, c, m, n, k, palOff, i, r, g, b, v: Integer;
  cells: array of TCell;
  alpha: Boolean;
  hdr: array[0..18] of Cardinal;
  ms: TMemoryStream;
  w: Word;
  u: Cardinal;
begin
  rc := RdI(D, raw + 12);
  cc := RdI(D, raw + 16);
  q := raw + 76 + rc * 40;
  SetLength(cells, cc);
  alpha := false;
  for c := 0 to cc - 1 do
  begin
    cells[c].sx := RdI(D, q);
    cells[c].sy := RdI(D, q + 4);
    cells[c].tb := RdI(D, q + 8);
    cells[c].nm := RdI(D, q + 20);
    Inc(q, 24);
    n := 0;
    for m := 0 to Max(cells[c].nm, 1) - 1 do
      Inc(n, Max(cells[c].sx shr m, 1) * Max(cells[c].sy shr m, 1));
    cells[c].po := q;
    cells[c].n := n;
    Inc(q, n);
    if cells[c].tb <> 0 then alpha := true;
  end;
  palOff := 336; {BAF palette}
  if rawEnd - q >= 768 then palOff := q; {the MAT carries its own palette}

  hdr[0] := $2054414D; hdr[1] := 50; hdr[2] := 2; hdr[3] := rc; hdr[4] := cc;
  hdr[5] := 1; hdr[6] := 16; hdr[7] := 5;
  if alpha then hdr[8] := 5 else hdr[8] := 6;
  hdr[9] := 5;
  if alpha then hdr[10] := 10 else hdr[10] := 11;
  hdr[11] := 5; hdr[12] := 0; hdr[13] := 3;
  if alpha then hdr[14] := 3 else hdr[14] := 2;
  hdr[15] := 3;
  if alpha then hdr[16] := 1 else hdr[16] := 0;
  if alpha then hdr[17] := 15 else hdr[17] := 0;
  if alpha then hdr[18] := 7 else hdr[18] := 0;

  ms := TMemoryStream.Create;
  try
    ms.WriteBuffer(hdr[0], SizeOf(hdr));
    if rc > 0 then ms.WriteBuffer(D[raw + 76], rc * 40);
    for c := 0 to cc - 1 do
    begin
      u := cells[c].sx; ms.WriteBuffer(u, 4);
      u := cells[c].sy; ms.WriteBuffer(u, 4);
      u := cells[c].tb; ms.WriteBuffer(u, 4);
      u := 0; ms.WriteBuffer(u, 4);
      ms.WriteBuffer(u, 4);
      u := cells[c].nm; ms.WriteBuffer(u, 4);
      for k := 0 to cells[c].n - 1 do
      begin
        i := D[cells[c].po + k];
        r := D[palOff + i * 3];
        g := D[palOff + i * 3 + 1];
        b := D[palOff + i * 3 + 2];
        if alpha then
        begin
          if (i = 0) and (cells[c].tb <> 0) then v := 0 else v := $8000;
          v := v or ((r shr 3) shl 10) or ((g shr 3) shl 5) or (b shr 3);
        end
        else
          v := ((r shr 3) shl 11) or ((g shr 2) shl 5) or (b shr 3);
        w := v;
        ms.WriteBuffer(w, 2);
      end;
    end;
    SetLength(Result, ms.Size);
    Move(ms.Memory^, Result[0], ms.Size);
  finally
    ms.Free;
  end;
end;

{ ---------- model -> JK .3do text ---------- }

Function BuildModel3DO(const D: TBytes; mo: Integer; const modelName, srcName: String;
  matNames: TStringList): TBytes;
var
  SB: TStringBuilder;
  nmesh, numH, k, i, j, o, ro, cur, vs, uvs, fs, p, n, u, f, nv, base, geo, lit, tex: Integer;
  radius, mrad, xl: Single;
  name, s: String;
  fnx, fny, fnz: array of Single;
  ps, uvi: Integer;
  fl, typ, mi, par, nch, ch, sib: Integer;

  procedure Ln(const t: String);
  begin
    SB.Append(t);
    SB.Append(#13#10);
  end;

begin
  SB := TStringBuilder.Create;
  try
    nmesh := RdI(D, mo + 36);
    numH := RdI(D, mo + 84);
    radius := RdF(D, mo + 92);
    ro := mo + 132;
    cur := ro + 112 * nmesh;

    Ln('# MODEL ''' + modelName + ''' converted from ''' + srcName + ''' by ConMan');
    Ln(''); Ln('###############'); Ln('SECTION: HEADER'); Ln(''); Ln('3DO 2.1'); Ln('');
    Ln('###############'); Ln('SECTION: MODELRESOURCE'); Ln(''); Ln('# Materials list');
    Ln('MATERIALS ' + IntToStr(matNames.Count)); Ln('');
    for i := 0 to matNames.Count - 1 do
      Ln(Format('%10d:%15s', [i, matNames[i]]));
    Ln(''); Ln(''); Ln('###############'); Ln('SECTION: GEOMETRYDEF'); Ln('');
    Ln('# Object radius'); Ln('RADIUS ' + FmtF(radius, 10, 6)); Ln('');
    Ln('# Insertion offset');
    Ln('INSERT OFFSET ' + FmtF(RdF(D, mo + 120), 10, 6) + ' ' + FmtF(RdF(D, mo + 124), 10, 6) + ' ' + FmtF(RdF(D, mo + 128), 10, 6));
    Ln(''); Ln('# Number of Geometry Sets'); Ln('GEOSETS 1'); Ln('');
    Ln('# Geometry Set definition'); Ln('GEOSET 0'); Ln('');
    Ln('# Number of Meshes'); Ln('MESHES ' + IntToStr(nmesh)); Ln(''); Ln('');

    for k := 0 to nmesh - 1 do
    begin
      o := ro + 112 * k;
      name := RdZ(D, o, 32);
      geo := RdI(D, o + 36);
      lit := RdI(D, o + 40);
      tex := RdI(D, o + 44);
      n := RdI(D, o + 72);
      u := RdI(D, o + 76);
      f := RdI(D, o + 80);
      mrad := RdF(D, o + 84);
      vs := cur;
      Ln('# Mesh definition'); Ln('MESH ' + IntToStr(k)); Ln('');
      Ln('NAME ' + name); Ln('');
      Ln('RADIUS ' + FmtF(mrad, 10, 6)); Ln('');
      Ln('GEOMETRYMODE'#9 + IntToStr(geo));
      Ln('LIGHTINGMODE'#9 + IntToStr(lit));
      Ln('TEXTUREMODE'#9 + IntToStr(tex));
      Ln(''); Ln('');
      Ln('VERTICES ' + IntToStr(n)); Ln('');
      Ln('# num:     x:         y:         z:         i: ');
      for i := 0 to n - 1 do
        Ln(Format('  %3d: %s %s %s %s', [i, FmtF(RdF(D, vs + 12 * i), 10, 6), FmtF(RdF(D, vs + 12 * i + 4), 10, 6),
           FmtF(RdF(D, vs + 12 * i + 8), 10, 6), FmtF(RdF(D, vs + 24 * n + 4 * i), 10, 6)]));
      uvs := vs + 32 * n;
      Ln(''); Ln(''); Ln('TEXTURE VERTICES ' + IntToStr(u)); Ln('');
      for i := 0 to u - 1 do
        Ln(Format('  %3d: %s %s', [i, FmtF(RdF(D, uvs + 8 * i), 10, 6), FmtF(RdF(D, uvs + 8 * i + 4), 10, 6)]));
      Ln(''); Ln(''); Ln('VERTEX NORMALS'); Ln(''); Ln('# num:     x:         y:         z:');
      for i := 0 to n - 1 do
        Ln(Format('  %3d: %s %s %s', [i, FmtF(RdF(D, vs + 12 * n + 12 * i), 10, 6), FmtF(RdF(D, vs + 12 * n + 12 * i + 4), 10, 6),
           FmtF(RdF(D, vs + 12 * n + 12 * i + 8), 10, 6)]));
      fs := uvs + 8 * u;
      p := fs + 76 * f;
      Ln(''); Ln(''); Ln('FACES ' + IntToStr(f)); Ln('');
      Ln('#  num:  material:   type:  geo:  light:   tex:  extralight:  verts:');
      SetLength(fnx, f); SetLength(fny, f); SetLength(fnz, f);
      for i := 0 to f - 1 do
      begin
        base := fs + 76 * i;
        nv := RdI(D, base + 20);
        xl := RdF(D, base + 48);
        fnx[i] := RdF(D, base + 56); fny[i] := RdF(D, base + 60); fnz[i] := RdF(D, base + 64);
        s := Format('   %3d: %9d  0x%.4x  %4d %7d %6d %s %7d  ',
          [i, RdI(D, base), RdI(D, base + 4), RdI(D, base + 8), RdI(D, base + 12), RdI(D, base + 16),
           FmtF(xl, 12, 4), nv]);
        ps := p;
        uvi := p + 4 * nv;
        for j := 0 to nv - 1 do
          s := s + Format('%3d,%3d ', [RdI(D, ps + 4 * j), RdI(D, uvi + 4 * j)]);
        Inc(p, 8 * nv);
        Ln(s);
      end;
      Ln(''); Ln(''); Ln('FACE NORMALS'); Ln(''); Ln('# num:     x:         y:         z:');
      for i := 0 to f - 1 do
        Ln(Format('  %3d: %s %s %s', [i, FmtF(fnx[i], 10, 6), FmtF(fny[i], 10, 6), FmtF(fnz[i], 10, 6)]));
      Ln(''); Ln('');
      cur := p;
    end;

    Ln('###############'); Ln('SECTION: HIERARCHYDEF'); Ln(''); Ln('# Hierarchy node list');
    Ln('HIERARCHY NODES ' + IntToStr(numH)); Ln('');
    Ln('#  num:   flags:   type:    mesh:  parent:  child:  sibling:  numChildren:        x:         y:         z:     pitch:       yaw:      roll:    pivotx:    pivoty:    pivotz:  hnodename:');
    for i := 0 to numH - 1 do
    begin
      o := cur + 180 * i;
      name := RdZ(D, o, 32);
      fl := RdI(D, o + 64); typ := RdI(D, o + 72); mi := RdI(D, o + 76); par := RdI(D, o + 80);
      nch := RdI(D, o + 84); ch := RdI(D, o + 88); sib := RdI(D, o + 92);
      Ln(Format('   %3d:  0x%.4x 0x%.5X %8d %8d %7d %9d %13d %s %s %s %s %s %s %s %s %s  %s',
        [i, fl, typ, mi, par, ch, sib, nch,
         FmtF(RdF(D, o + 108), 10, 6), FmtF(RdF(D, o + 112), 10, 6), FmtF(RdF(D, o + 116), 10, 6),
         FmtF(RdF(D, o + 120), 10, 6), FmtF(RdF(D, o + 124), 10, 6), FmtF(RdF(D, o + 128), 10, 6),
         FmtF(RdF(D, o + 96), 10, 6), FmtF(RdF(D, o + 100), 10, 6), FmtF(RdF(D, o + 104), 10, 6),
         name]));
    end;
    Result := TextToBytes(SB.ToString);
  finally
    SB.Free;
  end;
end;

{ ---------- embedded keyframe -> JK text .key ---------- }

{Parses the key record starting at p (32-byte name + rdKeyframe + joints + entries).
 Returns False if it does not look like a valid record.}
Function BuildKey(const D: TBytes; p: Integer; const keyName: String; out Text: TBytes): Boolean;
type
  TJ = record nodeNum, numEntries: Integer; name: String; end;
var
  SB: TStringBuilder;
  flags, typ, nj, nf, nj2, nmk, jp, ep, j, k, nonEmpty: Integer;
  fps: Single;
  joints: array of TJ;
  tot: Integer;

  procedure Ln(const t: String);
  begin
    SB.Append(t);
    SB.Append(#13#10);
  end;

begin
  Result := false;
  flags := RdI(D, p + 36);
  nj := RdI(D, p + 40);
  typ := RdI(D, p + 44);
  fps := RdF(D, p + 48);
  nf := RdI(D, p + 52);
  nj2 := RdI(D, p + 56);
  nmk := RdI(D, p + 64);
  if (nj <> nj2) or (nj <= 0) or (nj > 200) or (nf < 0) or (nf > 5000) or (nmk < 0) or (nmk > 8) then exit;
  jp := p + 32 + 100;
  SetLength(joints, nj);
  tot := 0;
  nonEmpty := 0;
  for j := 0 to nj - 1 do
  begin
    joints[j].name := RdZ(D, jp + 44 * j, 32);
    joints[j].nodeNum := RdI(D, jp + 44 * j + 32);
    joints[j].numEntries := RdI(D, jp + 44 * j + 36);
    if (joints[j].numEntries < 0) or (joints[j].numEntries > 100000) then exit;
    Inc(tot, joints[j].numEntries);
    if joints[j].numEntries > 0 then Inc(nonEmpty);
  end;
  ep := jp + 44 * nj;
  if ep + 56 * tot > Length(D) then exit;

  SB := TStringBuilder.Create;
  try
    Ln('# KEYFRAME ''' + keyName + ''' created from ''ConMan BAF extract''');
    Ln(''); Ln('###############'); Ln('SECTION: HEADER'); Ln('');
    Ln(Format('FLAGS  0x%.4x', [flags]));
    Ln(Format('TYPE   0x%X', [typ]));
    Ln('FRAMES ' + IntToStr(nf));
    Ln('FPS    ' + FmtF(fps, 0, 3));
    Ln('JOINTS ' + IntToStr(nj));
    if nmk > 0 then
    begin
      Ln(''); Ln(''); Ln('###############'); Ln('SECTION: MARKERS'); Ln('');
      Ln('MARKERS ' + IntToStr(nmk)); Ln('');
      for k := 0 to nmk - 1 do
        Ln(FmtF(RdF(D, p + 68 + 4 * k), 0, 6) + ' ' + IntToStr(RdI(D, p + 68 + 32 + 4 * k)));
    end;
    Ln(''); Ln(''); Ln('###############'); Ln('SECTION: KEYFRAME NODES'); Ln('');
    Ln('NODES ' + IntToStr(nonEmpty)); Ln('');
    for j := 0 to nj - 1 do
    begin
      if joints[j].numEntries = 0 then continue;
      Ln('NODE    ' + IntToStr(j));
      Ln('MESH NAME ' + joints[j].name);
      Ln('ENTRIES ' + IntToStr(joints[j].numEntries));
      Ln('');
      Ln('# num:   frame:   flags:           x:           y:           z:           p:           y:           r:');
      Ln('#                                 dx:          dy:          dz:          dp:          dy:          dr:');
      for k := 0 to joints[j].numEntries - 1 do
      begin
        Ln(Format(' %3d:  %7d   0x%.4x %s %s %s %s %s %s',
          [k, Round(RdF(D, ep)), RdI(D, ep + 4),
           FmtF(RdF(D, ep + 8), 12, 8), FmtF(RdF(D, ep + 12), 12, 8), FmtF(RdF(D, ep + 16), 12, 8),
           FmtF(RdF(D, ep + 20), 12, 8), FmtF(RdF(D, ep + 24), 12, 8), FmtF(RdF(D, ep + 28), 12, 8)]));
        Ln(Format(' %s %s %s %s %s %s',
          [FmtF(RdF(D, ep + 32), 35, 8), FmtF(RdF(D, ep + 36), 12, 8), FmtF(RdF(D, ep + 40), 12, 8),
           FmtF(RdF(D, ep + 44), 12, 8), FmtF(RdF(D, ep + 48), 12, 8), FmtF(RdF(D, ep + 52), 12, 8)]));
        Inc(ep, 56);
      end;
      Ln('');
    end;
    Text := TextToBytes(SB.ToString);
    Result := true;
  finally
    SB.Free;
  end;
end;

{ ---------- TBAFDirectory ---------- }

Procedure TBAFDirectory.Refresh;
var
  D: TBytes;
  fsr: TFileStream;
  i, p, q, e, mo, runStart, nameStart: Integer;
  matPos: array of Integer;
  matNames: TStringList;
  names: TStringList;
  modelName, nm, fn: String;
  fi: TBAFFileInfo;
  keyBytes: TBytes;
  seen: Integer;
  haveKeys, haveMats: Boolean;

  procedure AddItem(const path: String; const data: TBytes);
  begin
    fi := TBAFFileInfo.Create;
    fi.Data := data;
    fi.size := Length(data);
    fi.offs := 0;
    Files.AddObject(path, fi);
  end;

begin
  ClearIndex;
  HasDirs := true;
  CanRename := false;

  fsr := TFileStream.Create(name, fmOpenRead or fmShareDenyNone);
  try
    SetLength(D, fsr.Size);
    if fsr.Size > 0 then fsr.ReadBuffer(D[0], fsr.Size);
  finally
    fsr.Free;
  end;
  if Length(D) < 336 + 768 then raise Exception.Create(name + ' is not a BAF file');

  matNames := TStringList.Create;
  names := TStringList.Create;
  try
    {1. embedded MATs: 32-byte name followed by 'MAT ' + version 50}
    SetLength(matPos, 0);
    for p := 32 to Length(D) - 8 do
      if (D[p] = $4D) and (D[p + 1] = $41) and (D[p + 2] = $54) and (D[p + 3] = $20) and
         (D[p + 4] = $32) and (D[p + 5] = 0) and (D[p + 6] = 0) and (D[p + 7] = 0) then
      begin
        SetLength(matPos, Length(matPos) + 1);
        matPos[High(matPos)] := p - 32;
      end;
    if Length(matPos) = 0 then raise Exception.Create(name + ' is not a BAF file (no embedded materials)');

    {2. model name: first "<name>.3do" after the last material}
    mo := -1;
    q := matPos[High(matPos)] + 32;
    for p := q to Length(D) - 5 do
      if (D[p] = Ord('.')) and (D[p + 1] = Ord('3')) and (D[p + 2] = Ord('d')) and (D[p + 3] = Ord('o')) and (D[p + 4] = 0) then
      begin
        runStart := p;
        while (runStart > q) and (p - runStart < 31) and IsNameChar(D[runStart - 1], false) do Dec(runStart);
        if p - runStart >= 3 then begin mo := runStart; break; end;
      end;
    if mo < 0 then raise Exception.Create(name + ' is not a BAF file (no model found)');
    modelName := RdZ(D, mo, 32);

    for i := 0 to High(matPos) do
      matNames.Add(RdZ(D, matPos[i], 32));

    haveMats := false; haveKeys := false;

    {3. model}
    try
      AddItem(modelName, BuildModel3DO(D, mo, modelName, ExtractFileName(name), matNames));
    except
      on Exception do ; {model failed to parse - the rest is still extractable}
    end;

    {4. materials}
    for i := 0 to High(matPos) do
    begin
      if i < High(matPos) then e := matPos[i + 1] else e := mo;
      p := matPos[i] + 32;
      SetLength(keyBytes, e - p);
      Move(D[p], keyBytes[0], e - p);
      AddItem('mat\' + matNames[i], keyBytes);
      haveMats := true;
      try
        TBAFFileInfo(Files.Objects[Files.Count - 1]).Data16 := Mat8to16(D, p, e);
      except
        on Exception do ;
      end;
    end;

    {5. keyframes: "<name>.key" + #0 starts a record (32-byte name field)}
    p := 0;
    while p <= Length(D) - 5 do
    begin
      if (D[p] = Ord('.')) and (D[p + 1] = Ord('k')) and (D[p + 2] = Ord('e')) and (D[p + 3] = Ord('y')) and (D[p + 4] = 0) then
      begin
        runStart := p;
        while (runStart > 0) and (p - runStart < 27) and IsNameChar(D[runStart - 1], true) do Dec(runStart);
        if p - runStart >= 1 then
        begin
          nameStart := runStart;
          nm := RdZ(D, nameStart, 32);
          try
            if BuildKey(D, nameStart, nm, keyBytes) then
            begin
              fn := nm;
              seen := 1;
              while Files.IndexOf('key\' + fn) <> -1 do
              begin
                Inc(seen);
                fn := ChangeFileExt(nm, '') + '_' + IntToStr(seen) + '.key';
              end;
              AddItem('key\' + fn, keyBytes);
              haveKeys := true;
              p := nameStart + 32 + 100;
              continue;
            end;
          except
            on Exception do ;
          end;
        end;
      end;
      Inc(p);
    end;

    if haveMats then Dirs.Add('mat');
    if haveKeys then Dirs.Add('key');
  finally
    matNames.Free;
    names.Free;
  end;
end;

Function TBAFDirectory.DataFor(fi: TBAFFileInfo): TBytes;
begin
  if Convert16 and (Length(fi.Data16) > 0) then Result := fi.Data16 else Result := fi.Data;
end;

Function TBAFDirectory.OpenFile(Fname: TFileName; mode: Integer): TFile;
var i: Integer;
begin
  if fc.Changed then Refresh;
  if mode <> 0 then raise Exception.Create('Cannot write file inside BAF: ' + Fname);
  i := Files.IndexOf(Fname);
  if i = -1 then raise Exception.Create('File not found: ' + Fname);
  Result := TMemFile.CreateRead(Fname, DataFor(TBAFFileInfo(Files.Objects[i])));
end;

Function TBAFDirectory.OpenFilebyFI(fi: TFileInfo): TFile;
var i: Integer;
begin
  if fc.Changed then raise Exception.Create('File has been changed! reload.');
  i := Files.IndexOfObject(fi);
  if i = -1 then raise Exception.Create('OpenFileByFI: Cannot find file');
  Result := TMemFile.CreateRead(Files[i], DataFor(TBAFFileInfo(fi)));
end;

Procedure TBAFDirectory.RenameFile(Fname, newname: TFileName);
begin
  raise Exception.Create('BAF files are read-only');
end;

Function TBAFDirectory.DeleteFiles(DelList: TStringList): boolean;
begin
  raise Exception.Create('BAF files are read-only');
end;

Function TBAFDirectory.AddFiles(AddList: TStringList): boolean;
begin
  raise Exception.Create('BAF files are read-only');
end;

Function TBAFDirectory.GetContainerCreator(name: String): TContainerCreator;
begin
  raise Exception.Create('BAF files are read-only');
end;

Function TBAFDirectory.RenameFiles(newnames: TStringList): boolean;
begin
  raise Exception.Create('BAF files are read-only');
end;

initialization
  {$IFDEF FPC}
  FS := DefaultFormatSettings;
  {$ELSE}
  FS := TFormatSettings.Create;
  {$ENDIF}
  FS.DecimalSeparator := '.';
end.
