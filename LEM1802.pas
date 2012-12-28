unit LEM1802;

interface

uses
  Classes, Types, Windows, Controls, SysUtils, EmuTypes, VirtualDevice, BasicScreenForm, Graphics;

type
  TByteFont = array[0..127] of DWord;
  PByteFont = ^TByteFont;

  TColorPalet = array[0..15] of Word;
  PColorPalet = ^TColorPalet;

  TSmallByteFont = array[0..255] of Word;
  PSMallByteFont = ^TSmallByteFont;

  TSplitWord = packed record
    Low: Word;
    High: Word;
  end;

  TLEM1802 = class(TVirtualDevice)
  private
    FScreenAddr: Integer;
    FMonitor: TBasicScreen;
    FBuffer: TBitmap;
    FFont: TBitmap;
    FChar: TBitmap;
    FRectMap: TBitMap;
    FDefaultColors: TColorPalet;
    FCurrentColors: PColorPalet;
    FDefaultFont: TByteFont;
    FCurrentFont: PByteFont;
    FTestChar: DWord;
    FBorderColorIndex: Byte;
    FBlinkOn: Boolean;
    FBlinkTimer: Byte;
    procedure RenderScreen(Sender: TObject);
    procedure RenderText();
    procedure DrawChar(AScreenX, AScreenY, ACharIndex: Integer; ACanBlink: Boolean; AFGColor, ABGColor: Byte);
    procedure InitDefaultColors();
    procedure DrawByteChar(ACanvas: TCanvas; AChar: DWord; AX, AY: Integer);
    procedure ConvertFontToChars();
    procedure CharsToFont();
    function GraphicToChar(ACanvas: TCanvas; AX, AY: Integer): DWord;
    function RGBToPaletColor(R, G, B: Byte): Word;
    function PaletToTColor(AColor: Word): TColor;
  public
    constructor Create(ARegisters:PD16RegisterMem; ARam: PD16Ram);
    destructor Destroy(); override;
    procedure Interrupt(); override;
    procedure UpdateDevice(); override;
  end;

implementation

const
  DSTCOPY = $00AA0029;


{ TLEM1802 }

procedure TLEM1802.CharsToFont;
var
  LTest: TBitmap;
  i: Integer;
begin
  //this function was used to test if the dump from grafik to Bytefont worked
  LTest := TBitmap.Create();
  try
    LTest.SetSize(4, 8*128);
    for i := 0 to 127 do
    begin
      DrawByteChar(LTest.Canvas, FDefaultFont[i], 0, 8*i);
    end;
    LTest.SaveToFile('Dump.bmp');
  finally
    LTest.Free;
  end;
end;

procedure TLEM1802.ConvertFontToChars;
var
  LX, LY: Integer;
begin
  for LY := 0 to 3 do
  begin
    for LX := 0 to 31 do
    begin
      FDefaultFont[LY*32+LX] := GraphicToChar(FFont.Canvas, LX*4, LY*8);
    end;
  end;
end;

constructor TLEM1802.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  inherited;
  FHardwareID := $7349f615;
  FHardwareVerion := $1802;
  FManufactorID := $1c6c8b36;//NYA_ELEKTRISKA
  FNeedsUpdate := True;
  FScreenAddr := 0;
  InitDefaultColors();
  FBuffer := TBitmap.Create();
  FBuffer.PixelFormat := pf24bit;
  FBuffer.SetSize(128 + 8, 96 + 8);
  FBuffer.Canvas.Brush.Color := clBlack;
  FBuffer.Canvas.FillRect(FBuffer.Canvas.ClipRect);
  FRectMap := TBitmap.Create();
  FRectMap.SetSize(4, 8);

  FChar := TBitmap.Create();
  FChar.SetSize(4, 8);
  FChar.PixelFormat := pf1bit;
  FChar.Monochrome := True;

  FFont := TBitmap.Create();
  FFont.Monochrome := True;
  FFont.LoadFromFile('Font.bmp');
  ConvertFontToChars();
  FCurrentFont := @FDefaultFont;

  FMonitor := TBasicScreen.Create(nil);
  FMonitor.ScreenTimer.Enabled := True;
  FMonitor.ClientWidth := FBuffer.Width*4;
  FMonitor.ClientHeight := FBuffer.Height*4;
  FMonitor.Screen.OnPaint := RenderScreen;
  FMonitor.Caption := 'LEM1802';
  //testchar "F"
  FTestChar := 4278782208;
end;

destructor TLEM1802.Destroy;
begin
  FMonitor.Free;
  FBuffer.Free;
  FFont.Free;
  inherited;
end;

procedure TLEM1802.DrawByteChar(ACanvas: TCanvas; AChar: DWord; AX, AY: Integer);
var
  x, y: Integer;
  LColor: TColor;
  LShift: Byte;
  LChar: DWord;
begin
  TSplitWord(LChar).Low := TSplitWord(AChar).High;
  TSplitWord(LChar).High := TSplitWord(AChar).Low;
  for y := 0 to 7 do
  begin
    for x := 0 to 3 do
    begin
      LShift := (31-(x*8+y));
      if((LChar shr LShift) and 1) = 1 then
      begin
        LColor := clWhite;// clWhite;
      end
      else
      begin
        LColor := 0;// clNone;
      end;
      ACanvas.Pixels[x + AX, 7-y + AY] := LColor;
    end;
  end;
end;

procedure TLEM1802.DrawChar(AScreenX, AScreenY, ACharIndex: Integer; ACanBlink: Boolean; AFGColor, ABGColor: Byte);
begin
  if (not ACanBlink) or FBlinkOn then
  begin
    FRectMap.Canvas.Brush.Color := PaletToTColor(FCurrentColors[AFGColor]);
    FRectMap.Canvas.FillRect(FRectMap.Canvas.ClipRect);
    DrawByteChar(FChar.Canvas, FCurrentFont[ACharIndex], 0, 0);
    FBuffer.Canvas.Brush.Color := PaletToTColor(FCurrentColors[ABGColor]);
    FBuffer.Canvas.FillRect(Rect(AScreenX, AScreenY, AScreenX+4, AScreenY+8));
    MaskBlt(FBuffer.Canvas.Handle, AScreenX, AScreenY, 4, 8, FRectMap.Canvas.Handle, 0,0, FChar.Handle, 0, 0, MakeROP4(SRCCOPY, DSTCOPY));
  end
  else
  begin
    FBuffer.Canvas.Brush.Color := PaletToTColor(FCurrentColors[ABGColor]);
    FBuffer.Canvas.FillRect(Rect(AScreenX, AScreenY, AScreenX+4, AScreenY+8));
  end;
end;

function TLEM1802.GraphicToChar(ACanvas: TCanvas; AX, AY: Integer): DWord;
var
  LX, LY: Integer;
  LShift: Byte;
  LChar: DWord;
begin
  Result := 0;
  LChar := 0;
  for LY := 0 to 7 do
  begin
    for LX := 0 to 3 do
    begin
      LShift := (31-(LX*8+LY));
      if ACanvas.Pixels[LX + AX, AY+7-LY] <> 0 then
      begin
        LChar := LChar or (1 shl LShift);
      end;
    end;
  end;
  TSplitWord(Result).Low := TSplitWord(LChar).High;
  TSplitWord(Result).High := TSplitWord(LChar).Low;
end;

procedure TLEM1802.InitDefaultColors;
begin
  FDefaultColors[0] := 0;
  FDefaultColors[1] := RGBToPaletColor(0,0, $aa);
  FDefaultColors[2] := RGBToPaletColor(0, $aa, 0);
  FDefaultColors[3] := RGBToPaletColor(0, $aa, $aa);
  FDefaultColors[4] := RGBToPaletColor($aa, 0, 0);
  FDefaultColors[5] := RGBToPaletColor($aa,0, $aa);
  FDefaultColors[6] := RGBToPaletColor($aa,$55, 0);
  FDefaultColors[7] := RGBToPaletColor($aa,$aa, $aa);

  FDefaultColors[8] := RGBToPaletColor($55,$55, $55);
  FDefaultColors[9] := RGBToPaletColor($55,$55, $ff);
  FDefaultColors[$a] := RGBToPaletColor($55, $ff, $55);
  FDefaultColors[$b] := RGBToPaletColor($55, $ff, $ff);
  FDefaultColors[$c] := RGBToPaletColor($ff,$55, $55);
  FDefaultColors[$d] := RGBToPaletColor($ff,$55, $ff);
  FDefaultColors[$e] := RGBToPaletColor($ff,$ff, $55);
  FDefaultColors[$f] := RGBToPaletColor($ff,$ff, $ff);

  FCurrentColors := @FDefaultColors;
  FBorderColorIndex := 0;
end;

procedure TLEM1802.Interrupt;
var
  LLastScreenAddr: Integer;
  i: Integer;
begin
  inherited;
  case FRegisters[CRegA] of
    0:
    begin
      LLastScreenAddr := FScreenAddr;
      FScreenAddr := FRegisters[CRegB];
      if (FScreenAddr > 0) and (LLastScreenAddr = 0) then
      begin
        FMonitor.Show();
      end
      else
      begin
        if FScreenAddr = 0 then
        begin
          FMonitor.Hide;
        end;
      end;
    end;

    1:
    begin
      if FRegisters[CRegB] = 0 then
      begin
        FCurrentFont := @FDefaultFont;
      end
      else
      begin
        if FRegisters[CRegB] <= SizeOf(TD16Ram) - SizeOf(TByteFont) then
        begin
          FCurrentFont := Pointer(Integer(@FRam[0]) + FRegisters[CRegB]*2);
        end
        else
        begin
          raise EAbort.Create('Could not Map font to 0x' + IntToHex(FRegisters[CRegB], 4) + ' as writting/reading the font will exceed Ram boundaries!');
        end;
      end;
    end;

    2:
    begin
      if FRegisters[CRegB] = 0 then
      begin
        FCurrentColors := @FDefaultColors;
      end
      else
      begin
        if FRegisters[CRegB] <= SizeOf(TD16Ram) - SizeOf(TColorPalet) then
        begin
          FCurrentColors := Pointer(Integer(@FRam[0]) + FRegisters[CRegB]*2);
        end
        else
        begin
          raise EAbort.Create('Could not Map ColorPalet to 0x' + IntToHex(FRegisters[CRegB], 4) + ' as writting/reading the Palet will exceed Ram boundaries!');
        end;
      end;
    end;

    3:
    begin
      FBorderColorIndex := FRegisters[CRegB] and $F;
    end;

    4:
    begin
      for i := 0 to 255 do
      begin
        FRam[FRegisters[CRegB] + i] := PSMallByteFont((@TSmallByteFont(FDefaultFont)))[i];
      end;
    end;

    5:
    begin
      for i := 0 to 15 do
      begin
        FRam[FRegisters[CRegB] + i] := FDefaultColors[i];
      end;
    end;

  end;
end;

function TLEM1802.PaletToTColor(AColor: Word): TColor;
begin
  Result := RGB((AColor shr 8) and $F * 16, (AColor shr 4) and $F * 16, AColor and $F * 16);
end;

procedure TLEM1802.RenderScreen(Sender: TObject);
begin
  if FScreenAddr > 0 then
  begin
    RenderText();
  end;
  FMonitor.Screen.Canvas.CopyRect(FMonitor.Screen.Canvas.ClipRect, FBuffer.Canvas, FBuffer.Canvas.ClipRect);
end;

procedure TLEM1802.RenderText;
var
  LLeter: Byte;
  i, k: Cardinal;
  LAddr: Integer;
begin
  LAddr := FScreenAddr;
  FBuffer.Canvas.Brush.Color := PaletToTColor(FCurrentColors[FBorderColorIndex]);
  FBuffer.Canvas.FillRect(FBuffer.Canvas.ClipRect);
  for i := 0 to 11 do
  begin
    for k := 0 to 31 do
    begin
      LLeter := FRam[LAddr] and $7f; // get the lower 7 bits
      DrawChar(k*4 + 4, i*8 + 4, LLeter, (FRam[LAddr] and $80) = $80,
        (FRam[LAddr] shr 12) and $f, (FRam[LAddr] shr 8) and $f);
      Inc(LAddr);
    end;
  end;
end;

function TLEM1802.RGBToPaletColor(R, G, B: Byte): Word;
begin
  Result := 0;
  Result := Result or ((R and $F) shl 8);
  Result := Result or ((G and $F) shl 4);
  Result := Result or (B and $F);
end;

procedure TLEM1802.UpdateDevice;
begin
  Inc(FBlinkTimer);
  if FBlinkTimer = 30 then
  begin
    FBlinkOn := not FBlinkOn;
    FBlinkTimer := 0;
  end;
end;

end.
