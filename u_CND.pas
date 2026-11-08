unit u_CND;

{Read-only container view of an "Indiana Jones and the Infernal Machine" .CND level file.
 A CND is a compiled level; it embeds the level's textures, animations and sounds.
 Presented as:

   mat\<name>    textures, rebuilt as standalone MAT files (RGB565/555/RGBA etc. as stored)
   key\<name>    animations, as text KEY files
   sound\<name>  sounds as WAV files (a .wv "IndyWV" file when the compressed data
                 uses a mode that cannot be inflated)

 Layout reference: smlu/Urgon (libim) CND serialization.}

interface
uses Classes, SysUtils, Files, u_BAF;

type
  TCNDDirectory = class(TContainerFile)
    Procedure Refresh; override;
    Function OpenFile(Fname: TFileName; mode: Integer): TFile; override;
    Function OpenFilebyFI(fi: TFileInfo): TFile; override;
    Procedure RenameFile(Fname, newname: TFileName); override;
    Function DeleteFiles(DelList: TStringList): boolean; override;
    Function AddFiles(AddList: TStringList): boolean; override;
    Function GetContainerCreator(name: String): TContainerCreator; override;
    Function RenameFiles(newnames: TStringList): boolean; override;
  end;

{Quick check used when sniffing files: True if D (at least the first 1568 bytes) looks like an Indy CND}
Function LooksLikeIndyCND(const D: TBytes): Boolean;

implementation

uses Math;

const
  HeaderSize = 1568;
  OfsVersion = 1288;
  OfsNumMaterials = 1368;
  OfsNumVertices = 1384;
  OfsNumTexVertices = 1400;
  OfsNumAdjoins = 1416;
  OfsNumSurfaces = 1424;
  OfsNumSectors = 1432;
  OfsNumAIClasses = 1440;
  OfsNumModels = 1452;
  OfsNumSprites = 1464;
  OfsNumKeyframes = 1476;
  NameLen = 64;
  SoundInfoSize = 48;
  MatHeaderSize = 136;
  SurfaceHeaderSize = 56;
  SurfaceVertsSize = 24;
  SectorHeaderSize = 244;
  KeyHeaderSize = 92;
  KeyNodeSize = 72;
  KeyMarkerSize = 8;
  KeyEntrySize = 56;

var
  FS: TFormatSettings;

Function RdI(const D: TBytes; o: Integer): Integer;
begin
  if (o < 0) or (o + 4 > Length(D)) then raise Exception.Create('CND: read past end of file');
  Move(D[o], Result, 4);
end;

Function RdF(const D: TBytes; o: Integer): Single;
begin
  if (o < 0) or (o + 4 > Length(D)) then raise Exception.Create('CND: read past end of file');
  Move(D[o], Result, 4);
end;

Function RdW(const D: TBytes; o: Integer): Word;
begin
  if (o < 0) or (o + 2 > Length(D)) then raise Exception.Create('CND: read past end of file');
  Move(D[o], Result, 2);
end;

Function RdZ(const D: TBytes; o, n: Integer): String;
var i: Integer;
begin
  Result := '';
  for i := 0 to n - 1 do
  begin
    if o + i >= Length(D) then break;
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

Function TextToBytes(const s: String): TBytes;
begin
  Result := TEncoding.ANSI.GetBytes(s);
end;

Function LooksLikeIndyCND(const D: TBytes): Boolean;
begin
  Result := false;
  if Length(D) < HeaderSize then exit;
  try
    Result := (RdI(D, OfsVersion) = 3) and (RdI(D, 0) = Length(D));
  except
    Result := false;
  end;
end;

{ ---------- sections ---------- }

type
  TSections = record
    soundsOff, nSounds, soundDataSize: Integer;
    matOff, numMat, pixSize: Integer;
    geoOff, sectorsOff, aiOff, modelsOff, spritesOff, keysOff: Integer;
  end;

Function LocateSections(const D: TBytes; out S: TSections): Boolean;
var
  numSurfVerts, numSectors, vecBuff: Integer;
begin
  Result := false;
  if Length(D) < HeaderSize then exit;
  if RdI(D, OfsVersion) <> 3 then exit;

  S.soundsOff := HeaderSize;
  S.nSounds := RdI(D, S.soundsOff);
  S.soundDataSize := RdI(D, S.soundsOff + 4);
  if (S.nSounds < 0) or (S.soundDataSize < 0) then exit;
  S.matOff := S.soundsOff + 8 + SoundInfoSize * S.nSounds + S.soundDataSize + 4;

  S.numMat := RdI(D, OfsNumMaterials);
  S.pixSize := RdI(D, S.matOff);
  if (S.numMat < 0) or (S.pixSize < 0) then exit;
  S.geoOff := S.matOff + 4 + S.pixSize + MatHeaderSize * S.numMat;

  numSurfVerts := RdI(D, S.geoOff + 12 * RdI(D, OfsNumVertices) + 8 * RdI(D, OfsNumTexVertices) +
                         12 * RdI(D, OfsNumAdjoins) + SurfaceHeaderSize * RdI(D, OfsNumSurfaces));
  S.sectorsOff := S.geoOff + 12 * RdI(D, OfsNumVertices) + 8 * RdI(D, OfsNumTexVertices) +
                  12 * RdI(D, OfsNumAdjoins) + SurfaceHeaderSize * RdI(D, OfsNumSurfaces) +
                  4 + SurfaceVertsSize * numSurfVerts;

  numSectors := RdI(D, OfsNumSectors);
  vecBuff := RdI(D, S.sectorsOff + SectorHeaderSize * numSectors);
  S.aiOff := S.sectorsOff + SectorHeaderSize * numSectors + 4 + 4 * vecBuff;
  S.modelsOff := S.aiOff + NameLen * RdI(D, OfsNumAIClasses);
  S.spritesOff := S.modelsOff + NameLen * RdI(D, OfsNumModels);
  S.keysOff := S.spritesOff + NameLen * RdI(D, OfsNumSprites);
  Result := (S.keysOff > 0) and (S.keysOff <= Length(D));
end;

{ ---------- materials -> MAT ---------- }

Function BuildMat(const D: TBytes; hdr, pix: Integer; out used: Integer): TBytes;
var
  w, h, cel, mip, bpp, c, m, cw, ch, cellSize, k: Integer;
  ms: TMemoryStream;
  u: Cardinal;
  magic: Cardinal;
begin
  w := RdI(D, hdr + NameLen);
  h := RdI(D, hdr + NameLen + 4);
  cel := RdI(D, hdr + NameLen + 8);
  mip := RdI(D, hdr + NameLen + 12);
  bpp := RdI(D, hdr + NameLen + 16 + 4); {ColorFormat.bpp follows ColorFormat.mode}
  used := 0;
  if (cel < 1) or (mip < 1) then raise Exception.Create('material without pixel data');
  if (bpp mod 8 <> 0) or (bpp < 8) then raise Exception.Create('unsupported colour depth');
  cellSize := 0;
  cw := w; ch := h;
  m := mip;
  while (m > 0) and (cw > 0) and (ch > 0) do
  begin
    Inc(cellSize, cw * ch * (bpp div 8));
    cw := cw shr 1; ch := ch shr 1;
    Dec(m);
  end;
  used := cellSize * cel;
  if pix + used > Length(D) then raise Exception.Create('pixel data out of range');

  ms := TMemoryStream.Create;
  try
    magic := $2054414D; ms.WriteBuffer(magic, 4);
    u := $32; ms.WriteBuffer(u, 4);
    u := 2; ms.WriteBuffer(u, 4);
    u := cel; ms.WriteBuffer(u, 4);
    ms.WriteBuffer(u, 4);
    ms.WriteBuffer(D[hdr + NameLen + 16], 56); {ColorFormat}
    for c := 0 to cel - 1 do
    begin
      u := 8; ms.WriteBuffer(u, 4);
      u := 0;
      for k := 1 to 8 do ms.WriteBuffer(u, 4);
      u := c; ms.WriteBuffer(u, 4);
    end;
    for c := 0 to cel - 1 do
    begin
      u := w; ms.WriteBuffer(u, 4);
      u := h; ms.WriteBuffer(u, 4);
      u := 0; ms.WriteBuffer(u, 4); ms.WriteBuffer(u, 4); ms.WriteBuffer(u, 4);
      u := mip; ms.WriteBuffer(u, 4);
      ms.WriteBuffer(D[pix + c * cellSize], cellSize);
    end;
    SetLength(Result, ms.Size);
    Move(ms.Memory^, Result[0], ms.Size);
  finally
    ms.Free;
  end;
end;

{ ---------- keyframes -> text KEY ---------- }

Function BuildKeyText(const D: TBytes; keyIdx, hdrBase, markBase, nodeBase, entryBase: Integer;
  firstMarker, firstNode, firstEntry: Integer; out nMarkers, nNodes, nEntries: Integer): TBytes;
var
  SB: TStringBuilder;
  h, k, j, ep, np, mp, n: Integer;
  keyName: String;

  procedure Ln(const t: String);
  begin
    SB.Append(t);
    SB.Append(#13#10);
  end;

begin
  h := hdrBase + KeyHeaderSize * keyIdx;
  keyName := RdZ(D, h, NameLen);
  nMarkers := RdI(D, h + NameLen + 16);
  nNodes := RdI(D, h + NameLen + 24);
  nEntries := 0;
  mp := markBase + KeyMarkerSize * firstMarker;
  np := nodeBase + KeyNodeSize * firstNode;
  ep := entryBase + KeyEntrySize * firstEntry;
  SB := TStringBuilder.Create;
  try
    Ln('# KEYFRAME ''' + keyName + ''' created from ''ConMan CND extract''');
    Ln(''); Ln('###############'); Ln('SECTION: HEADER'); Ln('');
    Ln(Format('FLAGS  0x%.4x', [RdI(D, h + NameLen)]));
    Ln(Format('TYPE   0x%X', [RdI(D, h + NameLen + 4)]));
    Ln('FRAMES ' + IntToStr(RdI(D, h + NameLen + 8)));
    Ln('FPS    ' + FmtF(RdF(D, h + NameLen + 12), 0, 3));
    Ln('JOINTS ' + IntToStr(RdI(D, h + NameLen + 20)));
    if nMarkers > 0 then
    begin
      Ln(''); Ln(''); Ln('###############'); Ln('SECTION: MARKERS'); Ln('');
      Ln('MARKERS ' + IntToStr(nMarkers)); Ln('');
      for k := 0 to nMarkers - 1 do
        Ln(FmtF(RdF(D, mp + 8 * k), 0, 6) + ' ' + IntToStr(RdI(D, mp + 8 * k + 4)));
    end;
    Ln(''); Ln(''); Ln('###############'); Ln('SECTION: KEYFRAME NODES'); Ln('');
    Ln('NODES ' + IntToStr(nNodes)); Ln('');
    for j := 0 to nNodes - 1 do
    begin
      Ln('NODE    ' + IntToStr(RdI(D, np + NameLen)));
      Ln('MESH NAME ' + RdZ(D, np, NameLen));
      k := RdI(D, np + NameLen + 4);
      Ln('ENTRIES ' + IntToStr(k));
      Ln('');
      Ln('# num:   frame:   flags:           x:           y:           z:           p:           y:           r:');
      Ln('#                                 dx:          dy:          dz:          dp:          dy:          dr:');
      Inc(np, KeyNodeSize);
      Inc(nEntries, k);
      n := 0;
      while k > 0 do
      begin
        Dec(k);
        Inc(n);
        Ln(Format(' %3d:  %7d   0x%.4x %s %s %s %s %s %s',
          [n, Round(RdF(D, ep)), RdI(D, ep + 4),
           FmtF(RdF(D, ep + 8), 12, 8), FmtF(RdF(D, ep + 12), 12, 8), FmtF(RdF(D, ep + 16), 12, 8),
           FmtF(RdF(D, ep + 20), 12, 8), FmtF(RdF(D, ep + 24), 12, 8), FmtF(RdF(D, ep + 28), 12, 8)]));
        Ln(Format(' %s %s %s %s %s %s',
          [FmtF(RdF(D, ep + 32), 35, 8), FmtF(RdF(D, ep + 36), 12, 8), FmtF(RdF(D, ep + 40), 12, 8),
           FmtF(RdF(D, ep + 44), 12, 8), FmtF(RdF(D, ep + 48), 12, 8), FmtF(RdF(D, ep + 52), 12, 8)]));
        Inc(ep, KeyEntrySize);
      end;
      Ln('');
    end;
    Result := TextToBytes(SB.ToString);
  finally
    SB.Free;
  end;
end;

{ ---------- sounds -> WAV ---------- }

Function Swap16(w: Word): Word;
begin
  Result := Word((w shr 8) or ((w and $FF) shl 8));
end;

{IndyVW "WVSM" inflate.  Returns False when the compression mode is not supported.}
Function InflateIndyVW(const D: TBytes; p0, size: Integer; out Data: TBytes): Boolean;
var
  p, pe, infSize, channels, i, blk, nBlocks: Integer;
  u1: ShortInt;
  u2, u4: Word;
  u3: Byte;
  outPos: Integer;

  function RB: Byte;
  begin
    if p >= pe then raise Exception.Create('sound data truncated');
    Result := D[p];
    Inc(p);
  end;

  function RW: Word;
  begin
    Result := RB;
    Result := Result or (Word(RB) shl 8);
  end;

  procedure PutW(v: Word);
  begin
    if outPos + 2 > Length(Data) then raise Exception.Create('sound data overflow');
    Data[outPos] := v and $FF;
    Data[outPos + 1] := v shr 8;
    Inc(outPos, 2);
  end;

  function ChSample(expander: Integer): Word;
  var b: Byte; s: Word;
  begin
    b := RB;
    if b = $80 then
    begin
      s := RW;
      Result := Swap16(s);
    end
    else
      Result := Word((ShortInt(b) * (1 shl expander)) and $FFFF);
  end;

  procedure InflateBlock(blockSize: Integer);
  var nSamples, se, sel, ser, k: Integer;
  begin
    nSamples := blockSize div 2;
    if nSamples = 0 then exit;
    RW; {compressed size, big endian - unused}
    se := RB;
    sel := se shr 4;
    ser := se and $F;
    k := 0;
    while k < nSamples do
    begin
      PutW(ChSample(sel));
      if k + 1 >= nSamples then exit;
      PutW(ChSample(ser));
      Inc(k, 2);
    end;
  end;

begin
  Result := false;
  p := p0;
  pe := p0 + size;
  infSize := 0;
  for i := 0 to 3 do infSize := infSize or (Integer(RB) shl (8 * i));
  u1 := ShortInt(RB);
  u2 := RW;
  channels := 1;
  u3 := 0; u4 := 0;
  if u1 < 0 then channels := 2;
  u2 := Swap16(u2);
  if channels > 1 then
  begin
    u3 := RB;
    u4 := Swap16(RW);
  end;
  if not ((channels = 2) and (u2 = $1111) and (u3 = $64) and (u4 = $2222) and
          (p + 4 <= pe) and (D[p] = Ord('W')) and (D[p + 1] = Ord('V')) and (D[p + 2] = Ord('S')) and (D[p + 3] = Ord('M'))) then
    exit;
  Inc(p, 4);
  if (infSize < 0) or (infSize > 256 * 1024 * 1024) then exit;
  SetLength(Data, infSize + 2);
  outPos := 0;
  nBlocks := infSize div 4096;
  for blk := 1 to nBlocks do InflateBlock(4096);
  InflateBlock(infSize mod 4096);
  SetLength(Data, outPos);
  Result := true;
end;

Function MakeWav(const pcm: TBytes; channels, rate, bits: Integer): TBytes;
var
  ms: TMemoryStream;
  u: Cardinal;
  w: Word;
  blockAlign: Integer;
begin
  blockAlign := channels * bits div 8;
  ms := TMemoryStream.Create;
  try
    u := $46464952; ms.WriteBuffer(u, 4); {RIFF}
    u := 36 + Length(pcm); ms.WriteBuffer(u, 4);
    u := $45564157; ms.WriteBuffer(u, 4); {WAVE}
    u := $20746D66; ms.WriteBuffer(u, 4); {fmt }
    u := 16; ms.WriteBuffer(u, 4);
    w := 1; ms.WriteBuffer(w, 2);
    w := channels; ms.WriteBuffer(w, 2);
    u := rate; ms.WriteBuffer(u, 4);
    u := rate * blockAlign; ms.WriteBuffer(u, 4);
    w := blockAlign; ms.WriteBuffer(w, 2);
    w := bits; ms.WriteBuffer(w, 2);
    u := $61746164; ms.WriteBuffer(u, 4); {data}
    u := Length(pcm); ms.WriteBuffer(u, 4);
    if Length(pcm) > 0 then ms.WriteBuffer(pcm[0], Length(pcm));
    SetLength(Result, ms.Size);
    Move(ms.Memory^, Result[0], ms.Size);
  finally
    ms.Free;
  end;
end;

Function MakeIndyWV(const D: TBytes; p, size, channels, rate, bits: Integer): TBytes;
var
  ms: TMemoryStream;
  u: Cardinal;
  tag: array[0..5] of Byte;
begin
  tag[0] := Ord('I'); tag[1] := Ord('N'); tag[2] := Ord('D'); tag[3] := Ord('Y'); tag[4] := Ord('W'); tag[5] := Ord('V');
  ms := TMemoryStream.Create;
  try
    ms.WriteBuffer(tag[0], 6);
    u := rate; ms.WriteBuffer(u, 4);
    u := bits; ms.WriteBuffer(u, 4);
    u := channels; ms.WriteBuffer(u, 4);
    u := size; ms.WriteBuffer(u, 4);
    u := 0; ms.WriteBuffer(u, 4);
    if size > 0 then ms.WriteBuffer(D[p], size);
    SetLength(Result, ms.Size);
    Move(ms.Memory^, Result[0], ms.Size);
  finally
    ms.Free;
  end;
end;

{ ---------- level -> NDY (Infernal Machine text level) ---------- }

const
  NdyCopyright: array[0..37] of String = (
    '................................',
    '................@...@...@...@...',
    '.............@...@..@..@...@....',
    '................@.@.@.@.@.@.....',
    '@@@@@@@@......@...........@.....',
    '@@@@@@@@....@@......@@@....@....',
    '@@.....@.....@......@@@.....@@..',
    '@@.@@@@@......@.....@@@......@@.',
    '@@@@@@@@.......@....@@.....@@...',
    '@@@@@@@@.........@@@@@@@@@@.....',
    '@@@@@@@@..........@@@@@@........',
    '@@.....@..........@@@@@.........',
    '@@.@@@@@.........@@@@@@.........',
    '@@.....@.........@@@@@@.........',
    '@@@@@@@@.........@@@@@@.........',
    '@@@@@@@@.........@@@@@@@........',
    '@@@...@@.........@@@@@@@........',
    '@@.@@@.@.........@.....@........',
    '@@..@..@........@.......@.......',
    '@@@@@@@@........@.......@.......',
    '@@@@@@@@.......@........@.......',
    '@@..@@@@.......@........@.......',
    '@@@@..@@......@.........@.......',
    '@@@@.@.@......@.........@.......',
    '@@....@@........................',
    '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
    '@@@@@@@@@@@@@.@@@@@@@@@@@@@@@@@@',
    '@@.@@..@@@@@..@@@@@@@@@@.@@@@@@@',
    '@@.@.@.@@@@.@.@@@.@..@@...@@@..@',
    '@@..@@@@@@....@@@..@@@@@.@@@@.@@',
    '@@@@@@@@...@@.@@@.@@@@@..@@...@@',
    '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@',
    '@.(c).lucasarts.entertainment..@',
    '@.........company.llc..........@',
    '@....(c).lucasfilm.ltd.&.tm....@',
    '@.....all.rights.reserved......@',
    '@...used.under.authorization...@',
    '@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@@');

Function BuildNDY(const D: TBytes; const S: TSections): TBytes;
var
  nv, ntv, nadj, nsurf, nsec, vo, to_, ao, so, svo, secO, vecO, i, j, k, p, n, q, nn, base: Integer;
  SB: TStringBuilder;
  starts, secVertStart: array of Integer;
  line, nm: String;
  poolOff: Integer;

  procedure Ln(const t: String);
  begin
    SB.Append(t);
    SB.Append(#13#10);
  end;

  function F8(o: Integer): String;
  begin
    Result := FmtF(RdF(D, o), 0, 8);
  end;

  function V3(o: Integer): String;
  begin
    Result := F8(o) + ' ' + F8(o + 4) + ' ' + F8(o + 8);
  end;

  procedure NameList(const title, countName: String; off, count, bufMin: Integer);
  var m: Integer;
  begin
    Ln(title);
    if count > bufMin then m := count else m := bufMin;
    Ln(countName + ' ' + IntToStr(m));
    for m := 0 to count - 1 do Ln(IntToStr(m) + ': ' + RdZ(D, off + NameLen * m, NameLen));
    Ln('end'); Ln('');
  end;

  procedure EmptyList(const title, countName: String; bufMin: Integer);
  begin
    Ln(title); Ln(countName + ' ' + IntToStr(bufMin)); Ln('end'); Ln('');
  end;

begin
  nv := RdI(D, OfsNumVertices);
  ntv := RdI(D, OfsNumTexVertices);
  nadj := RdI(D, OfsNumAdjoins);
  nsurf := RdI(D, OfsNumSurfaces);
  nsec := RdI(D, OfsNumSectors);
  vo := S.geoOff;
  to_ := vo + 12 * nv;
  ao := to_ + 8 * ntv;
  so := ao + 12 * nadj;
  svo := so + SurfaceHeaderSize * nsurf + 4;
  secO := svo + SurfaceVertsSize * RdI(D, so + SurfaceHeaderSize * nsurf);
  vecO := secO + SectorHeaderSize * nsec + 4;

  SetLength(starts, nsurf + 1);
  starts[0] := 0;
  for i := 0 to nsurf - 1 do starts[i + 1] := starts[i] + RdI(D, so + SurfaceHeaderSize * i + 52);

  SB := TStringBuilder.Create;
  try
    Ln('SECTION: COPYRIGHT');
    for i := 0 to High(NdyCopyright) do Ln(NdyCopyright[i]);
    Ln('');
    Ln('SECTION: HEADER');
    Ln('Version 3');
    Ln('World Gravity ' + F8(1292));
    Ln('Ceiling Sky Z ' + F8(1296));
    Ln('Horizon Distance ' + F8(1300));
    Ln('Horizon Pixels per Rev 768.000000');
    Ln('Horizon Sky Offset ' + F8(1304) + ' ' + F8(1308));
    Ln('Ceiling Sky Offset ' + F8(1312) + ' ' + F8(1316));
    Ln('LOD Distances ' + FmtF(RdF(D, 1320), 0, 6) + ' ' + FmtF(RdF(D, 1324), 0, 6) + ' ' +
       FmtF(RdF(D, 1328), 0, 6) + ' ' + FmtF(RdF(D, 1332), 0, 6));
    Ln('Fog ' + IntToStr(RdI(D, 1336)) + ' ' + F8(1340) + ' ' + F8(1344) + ' ' + F8(1348) + ' ' + F8(1352) + ' ' +
       F8(1356) + ' ' + F8(1360));
    Ln('');

    poolOff := S.soundsOff + 8 + SoundInfoSize * S.nSounds;
    Ln('SECTION: SOUNDS');
    Ln('World sounds ' + IntToStr(S.nSounds));
    for i := 0 to S.nSounds - 1 do
      Ln(RdZ(D, poolOff + RdI(D, S.soundsOff + 8 + SoundInfoSize * i + 12), 128));
    Ln('end'); Ln('');

    Ln('SECTION: MATERIALS');
    Ln('World materials ' + IntToStr(S.numMat + 64));
    for i := 0 to S.numMat - 1 do
      Ln(IntToStr(i) + ': ' + RdZ(D, S.matOff + 4 + MatHeaderSize * i, NameLen));
    Ln('end'); Ln('');

    Ln('SECTION: GEORESOURCE');
    Ln('World vertices ' + IntToStr(nv));
    Ln('#num:'#9'vertex:');
    for i := 0 to nv - 1 do Ln(IntToStr(i) + ': ' + V3(vo + 12 * i));
    Ln('');
    Ln('World texture vertices ' + IntToStr(ntv));
    Ln('#num:'#9'u:'#9'v:');
    for i := 0 to ntv - 1 do Ln(IntToStr(i) + ': ' + F8(to_ + 8 * i) + ' ' + F8(to_ + 8 * i + 4));
    Ln('');
    Ln('World adjoins ' + IntToStr(nadj));
    Ln('#num:'#9'flags:'#9'mirror:'#9'dist:');
    for i := 0 to nadj - 1 do
    begin
      q := RdI(D, ao + 12 * i + 4);
      if q < 0 then q := 0;
      Ln(IntToStr(i) + ': 0x' + IntToHex(RdI(D, ao + 12 * i), 1) + ' ' + IntToStr(q) + ' ' + F8(ao + 12 * i + 8));
    end;
    Ln('');
    Ln('World surfaces ' + IntToStr(nsurf));
    Ln('#num:   mat:'#9'surfflags:'#9'faceflags:'#9'geo:'#9'light:'#9'tex:'#9'adjoin:'#9'extralight:'#9'nverts:'#9'vertices:'#9#9#9'intensities:');
    for i := 0 to nsurf - 1 do
    begin
      p := so + SurfaceHeaderSize * i;
      n := RdI(D, p + 52);
      line := IntToStr(i) + ':'#9 + IntToStr(RdI(D, p)) + #9'0x' + IntToHex(RdI(D, p + 4), 1) +
              #9'0x' + IntToHex(RdI(D, p + 8), 1) + #9 + IntToStr(RdI(D, p + 12)) + #9 + IntToStr(RdI(D, p + 16)) +
              #9'3'#9 + IntToStr(RdI(D, p + 20)) + #9 + F8(p + 24) + ' ' + F8(p + 28) + ' ' + F8(p + 32) + ' ' + F8(p + 36) +
              #9 + IntToStr(n);
      for k := 0 to n - 1 do
        line := line + #9 + IntToStr(RdI(D, svo + SurfaceVertsSize * (starts[i] + k))) + ',' +
                IntToStr(RdI(D, svo + SurfaceVertsSize * (starts[i] + k) + 4));
      for k := 0 to n - 1 do
      begin
        q := svo + SurfaceVertsSize * (starts[i] + k) + 8;
        line := line + #9 + F8(q) + #9 + F8(q + 4) + #9 + F8(q + 8);
      end;
      Ln(line);
    end;
    Ln('');
    Ln('#--- Surface normals ---');
    for i := 0 to nsurf - 1 do
      Ln(IntToStr(i) + ':'#9 + F8(so + SurfaceHeaderSize * i + 40) + #9 + F8(so + SurfaceHeaderSize * i + 44) + #9 +
         F8(so + SurfaceHeaderSize * i + 48));
    Ln('');

    Ln('Section: SECTORS');
    Ln('World sectors ' + IntToStr(nsec));
    Ln('');
    SetLength(secVertStart, nsec + 1);
    secVertStart[0] := 0;
    for j := 0 to nsec - 1 do secVertStart[j + 1] := secVertStart[j] + RdI(D, secO + SectorHeaderSize * j + 224);
    for j := 0 to nsec - 1 do
    begin
      p := secO + SectorHeaderSize * j;
      Ln('SECTOR'#9 + IntToStr(j));
      Ln('FLAGS'#9'0x' + IntToHex(RdI(D, p), 1));
      Ln('AMBIENT LIGHT'#9 + V3(p + 4));
      Ln('EXTRA LIGHT'#9 + V3(p + 20));
      if (RdF(D, p + 36) <> 0) or (RdF(D, p + 40) <> 0) or (RdF(D, p + 44) <> 0) then Ln('TINT'#9 + V3(p + 36));
      if (RdF(D, p + 48) <> 0) or (RdF(D, p + 52) <> 0) or (RdF(D, p + 56) <> 0) then Ln('AVERAGE LIGHT INTENSITY'#9 + V3(p + 48));
      if (RdF(D, p + 64) <> 0) or (RdF(D, p + 68) <> 0) or (RdF(D, p + 72) <> 0) then Ln('AVERAGE LIGHT POSITION'#9 + V3(p + 64));
      if (RdF(D, p + 76) <> 0) or (RdF(D, p + 80) <> 0) then Ln('AVERAGE LIGHT FALLOFF'#9 + F8(p + 76) + ' ' + F8(p + 80));
      Ln('BOUNDBOX'#9 + V3(p + 108) + ' ' + V3(p + 120));
      nn := 0;
      for k := 0 to 5 do if RdF(D, p + 84 + 4 * k) <> 0 then nn := 1;
      if nn <> 0 then Ln('COLLIDEBOX'#9 + V3(p + 84) + ' ' + V3(p + 96));
      nm := RdZ(D, p + 132, NameLen);
      if nm <> '' then Ln('SOUND'#9 + nm + ' ' + FmtF(RdF(D, p + 196), 0, 6));
      if (RdF(D, p + 232) <> 0) or (RdF(D, p + 236) <> 0) or (RdF(D, p + 240) <> 0) then Ln('THRUST'#9 + V3(p + 232));
      Ln('CENTER'#9 + V3(p + 200));
      Ln('RADIUS'#9 + F8(p + 212));
      n := RdI(D, p + 224);
      Ln('VERTICES'#9 + IntToStr(n));
      for k := 0 to n - 1 do
        Ln(IntToStr(k) + ': ' + IntToStr(RdI(D, vecO + 4 * (secVertStart[j] + k))));
      Ln('SURFACES'#9 + IntToStr(RdI(D, p + 216)) + #9 + IntToStr(RdI(D, p + 220)));
      Ln('');
    end;

    NameList('Section: AICLASS', 'World AIClasses', S.aiOff, RdI(D, OfsNumAIClasses), 64);
    NameList('Section: MODELS', 'World models', S.modelsOff, RdI(D, OfsNumModels), 1024);
    NameList('Section: SPRITES', 'World sprites', S.spritesOff, RdI(D, OfsNumSprites), 128);

    nn := RdI(D, OfsNumKeyframes);
    Ln('Section: KEYFRAMES');
    if nn > 512 then q := nn else q := 512;
    Ln('World keyframes ' + IntToStr(q));
    base := S.keysOff + 12;
    for i := 0 to nn - 1 do Ln(IntToStr(i) + ': ' + RdZ(D, base + KeyHeaderSize * i, NameLen));
    Ln('end'); Ln('');

    EmptyList('Section: ANIMCLASS', 'World puppets', 64);
    EmptyList('Section: Soundclass', 'World soundclasses', 128);
    EmptyList('Section: cogscripts', 'World scripts', 128);
    Ln('Section: cogs'); Ln('World cogs'#9'0'); Ln('#Num'#9'Script          Symbol values'); Ln('end'); Ln('');
    Ln('Section: TEMPLATES'); Ln('World templates 0'); Ln('#Name:           Based On:        Params:'); Ln('end'); Ln('');
    Ln('Section: Things'); Ln('World things 0'); Ln('end'); Ln('');
    Result := TextToBytes(SB.ToString);
  finally
    SB.Free;
  end;
end;

{ ---------- TCNDDirectory ---------- }

Procedure TCNDDirectory.Refresh;
var
  D: TBytes;
  fsr: TFileStream;
  S: TSections;
  i, j, p, hdr, pixPos, used, nm, ne, nk: Integer;
  fi: TBAFFileInfo;
  nameS, base: String;
  haveMat, haveKey, haveSnd, haveGeo: Boolean;
  bytes, pcm: TBytes;
  cMark, cNode, cEntry, tm, tn, te: Integer;
  numKeys: Integer;
  dataPool, sInfo, dOff, dSize, nOff, ch, rate, bits, comp: Integer;

  procedure AddItem(const path: String; const data: TBytes);
  var seen: Integer; pth: String;
  begin
    pth := path;
    seen := 1;
    while Files.IndexOf(pth) <> -1 do
    begin
      Inc(seen);
      pth := ChangeFileExt(path, '') + '_' + IntToStr(seen) + ExtractFileExt(path);
    end;
    fi := TBAFFileInfo.Create;
    fi.Data := data;
    fi.size := Length(data);
    fi.offs := 0;
    Files.AddObject(pth, fi);
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
  if not LocateSections(D, S) then
    raise Exception.Create(name + ' is not an Indiana Jones and the Infernal Machine CND file');

  haveMat := false; haveKey := false; haveSnd := false; haveGeo := false;

  {materials}
  try
    pixPos := S.matOff + 4 + MatHeaderSize * S.numMat;
    for i := 0 to S.numMat - 1 do
    begin
      hdr := S.matOff + 4 + MatHeaderSize * i;
      nameS := RdZ(D, hdr, NameLen);
      try
        bytes := BuildMat(D, hdr, pixPos, used);
        Inc(pixPos, used);
        AddItem('mat\' + nameS, bytes);
        haveMat := true;
      except
        on Exception do
        begin
          {materials without pixel data consume nothing; real errors stop the section}
          if (RdI(D, hdr + NameLen + 8) >= 1) and (RdI(D, hdr + NameLen + 12) >= 1) then break;
        end;
      end;
    end;
  except
    on Exception do ;
  end;

  {keyframes}
  try
    numKeys := RdI(D, OfsNumKeyframes);
    if numKeys > 0 then
    begin
      tm := RdI(D, S.keysOff);
      tn := RdI(D, S.keysOff + 4);
      te := RdI(D, S.keysOff + 8);
      hdr := S.keysOff + 12;
      cMark := 0; cNode := 0; cEntry := 0;
      for i := 0 to numKeys - 1 do
      begin
        nameS := RdZ(D, hdr + KeyHeaderSize * i, NameLen);
        bytes := BuildKeyText(D, i, hdr, hdr + KeyHeaderSize * numKeys,
                              hdr + KeyHeaderSize * numKeys + KeyMarkerSize * tm,
                              hdr + KeyHeaderSize * numKeys + KeyMarkerSize * tm + KeyNodeSize * tn,
                              cMark, cNode, cEntry, nm, nk, ne);
        Inc(cMark, nm); Inc(cNode, nk); Inc(cEntry, ne);
        AddItem('key\' + nameS, bytes);
        haveKey := true;
      end;
      if te < 0 then ;
    end;
  except
    on Exception do ;
  end;

  {sounds}
  try
    dataPool := S.soundsOff + 8 + SoundInfoSize * S.nSounds;
    for i := 0 to S.nSounds - 1 do
    begin
      sInfo := S.soundsOff + 8 + SoundInfoSize * i;
      nOff := RdI(D, sInfo + 12);
      dOff := RdI(D, sInfo + 16);
      rate := RdI(D, sInfo + 24);
      bits := RdI(D, sInfo + 28);
      ch := RdI(D, sInfo + 32);
      dSize := RdI(D, sInfo + 36);
      comp := RdI(D, sInfo + 40);
      nameS := RdZ(D, dataPool + nOff, 128);
      if nameS = '' then nameS := 'sound' + IntToStr(i);
      base := ChangeFileExt(nameS, '');
      if (dOff < 0) or (dSize < 0) or (dataPool + dOff + dSize > Length(D)) then continue;
      try
        if comp = 0 then
        begin
          SetLength(pcm, dSize);
          if dSize > 0 then Move(D[dataPool + dOff], pcm[0], dSize);
          AddItem('sound\' + base + '.wav', MakeWav(pcm, ch, rate, bits));
          haveSnd := true;
        end
        else if InflateIndyVW(D, dataPool + dOff, dSize, pcm) then
        begin
          AddItem('sound\' + base + '.wav', MakeWav(pcm, ch, rate, bits));
          haveSnd := true;
        end
        else
        begin
          AddItem('sound\' + base + '.wv', MakeIndyWV(D, dataPool + dOff, dSize, ch, rate, bits));
          haveSnd := true;
        end;
      except
        on Exception do ;
      end;
    end;
  except
    on Exception do ;
  end;

  {world geometry}
  try
    base := ChangeFileExt(ExtractFileName(name), '');
    AddItem('geo\' + base + '.ndy', BuildNDY(D, S));
    haveGeo := true;
  except
    on Exception do ;
  end;

  if haveGeo then Dirs.Add('geo');
  if haveMat then Dirs.Add('mat');
  if haveKey then Dirs.Add('key');
  if haveSnd then Dirs.Add('sound');
  if Files.Count = 0 then
    raise Exception.Create('No geometry, textures, animations or sounds could be read from ' + name);
end;

Function TCNDDirectory.OpenFile(Fname: TFileName; mode: Integer): TFile;
var i: Integer;
begin
  if fc.Changed then Refresh;
  if mode <> 0 then raise Exception.Create('Cannot write file inside CND: ' + Fname);
  i := Files.IndexOf(Fname);
  if i = -1 then raise Exception.Create('File not found: ' + Fname);
  Result := TMemFile.CreateRead(Fname, TBAFFileInfo(Files.Objects[i]).Data);
end;

Function TCNDDirectory.OpenFilebyFI(fi: TFileInfo): TFile;
var i: Integer;
begin
  if fc.Changed then raise Exception.Create('File has been changed! reload.');
  i := Files.IndexOfObject(fi);
  if i = -1 then raise Exception.Create('OpenFileByFI: Cannot find file');
  Result := TMemFile.CreateRead(Files[i], TBAFFileInfo(fi).Data);
end;

Procedure TCNDDirectory.RenameFile(Fname, newname: TFileName);
begin
  raise Exception.Create('CND files are read-only');
end;

Function TCNDDirectory.DeleteFiles(DelList: TStringList): boolean;
begin
  raise Exception.Create('CND files are read-only');
end;

Function TCNDDirectory.AddFiles(AddList: TStringList): boolean;
begin
  raise Exception.Create('CND files are read-only');
end;

Function TCNDDirectory.GetContainerCreator(name: String): TContainerCreator;
begin
  raise Exception.Create('CND files are read-only');
end;

Function TCNDDirectory.RenameFiles(newnames: TStringList): boolean;
begin
  raise Exception.Create('CND files are read-only');
end;

initialization
  {$IFDEF FPC}
  FS := DefaultFormatSettings;
  {$ELSE}
  FS := TFormatSettings.Create;
  {$ENDIF}
  FS.DecimalSeparator := '.';
end.
