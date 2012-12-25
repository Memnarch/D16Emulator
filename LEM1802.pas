unit LEM1802;

interface

uses
  Classes, Types, Windows, Controls, SysUtils, EmuTypes, VirtualDevice, BasicScreenForm, Graphics;

type

  TLEM1802 = class(TVirtualDevice)
  private
    FScreenAddr: Integer;
    FMonitor: TBasicScreen;
    FBuffer: TBitmap;
    FFont: TBitmap;
    FChar: TBitmap;
    FRectMap: TBitMap;
    FColors: array[0..16] of TColor;
    FBitFont: array[0..127] of DWord;
    FTestChar: DWord;
    procedure RenderScreen(Sender: TObject);
    procedure RenderText();
    procedure DrawChar(AScreenX, AScreenY, ACharIndex: Integer; AFGColor, ABGColor: Byte);
    procedure InitDefaultColors();
    procedure DrawByteChar(ACanvas: TCanvas; AChar: DWord; AX, AY: Integer);
    procedure ConvertFontToChars();
    procedure CharsToFont();
    function GraphicToChar(ACanvas: TCanvas; AX, AY: Integer): DWord;
  public
    constructor Create(ARegisters:PD16RegisterMem; ARam: PD16Ram);
    destructor Destroy(); override;
    procedure Interrupt(); override;
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
      DrawByteChar(LTest.Canvas, FBitFont[i], 0, 8*i);
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
      FBitFont[LY*32+LX] := GraphicToChar(FFont.Canvas, LX*4, LY*8);
    end;
  end;
end;

constructor TLEM1802.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  inherited;
  FHardwareID := $7349f615;
  FHardwareVerion := $1802;
  FManufactorID := $1c6c8b36;//NYA_ELEKTRISKA
  FScreenAddr := 0;
  InitDefaultColors();
  FBuffer := TBitmap.Create();
  FBuffer.PixelFormat := pf24bit;
  FBuffer.SetSize(128, 96);
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
begin
  for y := 0 to 7 do
  begin
    for x := 0 to 3 do
    begin
      LShift := (31-(x*8+y));
      if((AChar shr LShift) and 1) = 1 then
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

procedure TLEM1802.DrawChar(AScreenX, AScreenY, ACharIndex: Integer; AFGColor, ABGColor: Byte);
begin
  FRectMap.Canvas.Brush.Color := FColors[AFGColor];
  FRectMap.Canvas.FillRect(FRectMap.Canvas.ClipRect);
  DrawByteChar(FChar.Canvas, FBitFont[ACharIndex], 0, 0);
  FBuffer.Canvas.Brush.Color := FColors[ABGColor];
  FBuffer.Canvas.FillRect(Rect(AScreenX, AScreenY, AScreenX+4, AScreenY+8));
  MaskBlt(FBuffer.Canvas.Handle, AScreenX, AScreenY, 4, 8, FRectMap.Canvas.Handle, 0,0, FChar.Handle, 0, 0, MakeROP4(SRCCOPY, DSTCOPY));
end;

function TLEM1802.GraphicToChar(ACanvas: TCanvas; AX, AY: Integer): DWord;
var
  LX, LY: Integer;
  LShift: Byte;
begin
  Result := 0;
  for LY := 0 to 7 do
  begin
    for LX := 0 to 3 do
    begin
      LShift := (31-(LX*8+LY));
      if ACanvas.Pixels[LX + AX, AY+7-LY] <> 0 then
      begin
        Result := Result or (1 shl LShift);
      end;
    end;
  end;
end;

procedure TLEM1802.InitDefaultColors;
begin
  FColors[1] := RGB(0,0, $aa);
  FColors[2] := RGB(0, $aa, 0);
  FColors[3] := RGB(0, $aa, $aa);
  FColors[4] := RGB($aa, 0, 0);
  FColors[5] := RGB($aa,0, $aa);
  FColors[6] := RGB($aa,$55, 0);
  FColors[7] := RGB($aa,$aa, $aa);

  FColors[8] := RGB($55,$55, $55);
  FColors[9] := RGB($55,$55, $ff);
  FColors[$a] := RGB($55, $ff, $55);
  FColors[$b] := RGB($55, $ff, $ff);
  FColors[$c] := RGB($ff,$55, $55);
  FColors[$d] := RGB($ff,$55, $ff);
  FColors[$e] := RGB($ff,$ff, $55);
  FColors[$f] := RGB($ff,$ff, $ff);
end;

procedure TLEM1802.Interrupt;
var
  LLastScreenAddr: Integer;
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

    end;

    2:
    begin

    end;

    3:
    begin

    end;

    4:
    begin

    end;

    5:
    begin

    end;

  end;
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
  for i := 0 to 11 do
  begin
    for k := 0 to 31 do
    begin
      LLeter := FRam[LAddr] and $7f; // get the lower 7 bits
      DrawChar(k*4, i*8, LLeter, (FRam[LAddr] shr 12) and $f, (FRam[LAddr] shr 8) and $f);
      Inc(LAddr);
    end;
  end;
end;

end.
