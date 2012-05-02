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
    FRectMap: TBitMap;
    FColors: array[0..16] of TColor;
    procedure RenderScreen(Sender: TObject);
    procedure RenderText();
    procedure DrawChar(AScreenX, AScreenY, ACharX, ACharY: Integer; AFGColor, ABGColor: Byte);
    procedure InitDefaultColors();
  public
    constructor Create(ARegisters:PD16RegisterMem; ARam: PD16Ram);
    destructor Destroy(); override;
    procedure Interrupt(); override;
  end;

implementation

const
  DSTCOPY = $00AA0029;


{ TLEM1802 }

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

  FFont := TBitmap.Create();
  FFont.Monochrome := True;
  FFont.LoadFromFile('Font.bmp');

  FMonitor := TBasicScreen.Create(nil);
  FMonitor.ClientWidth := FBuffer.Width*4;
  FMonitor.ClientHeight := FBuffer.Height*4;
  FMonitor.Screen.OnPaint := RenderScreen;
  FMonitor.Caption := 'LEM1802';
end;

destructor TLEM1802.Destroy;
begin
  FMonitor.Free;
  FBuffer.Free;
  FFont.Free;
  inherited;
end;

procedure TLEM1802.DrawChar(AScreenX, AScreenY, ACharX, ACharY: Integer; AFGColor, ABGColor: Byte);
begin
  FRectMap.Canvas.Brush.Color := FColors[AFGColor];
  FRectMap.Canvas.FillRect(FRectMap.Canvas.ClipRect);
  FBuffer.Canvas.Brush.Color := FColors[ABGColor];
  FBuffer.Canvas.FillRect(Rect(AScreenX, AScreenY, AScreenX+4, AScreenY+8));
  MaskBlt(FBuffer.Canvas.Handle, AScreenX, AScreenY, 4, 8, FRectMap.Canvas.Handle, 0,0, FFont.Handle, ACharX, ACharY, MakeROP4(SRCCOPY, DSTCOPY));
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
  LX, LY: Cardinal;
  i, k: Cardinal;
  LAddr: Integer;
begin
  LAddr := FScreenAddr;
  for i := 0 to 11 do
  begin
    for k := 0 to 31 do
    begin
      LLeter := FRam[LAddr] and $7f; // get the lower 7 bits
      LY := LLeter div 32 * 8;
      LX := LLeter mod 32 * 4;
      //FBuffer.Canvas.CopyRect(Rect(k*4,i*8, k*4+3, i*8+7), FFont.Canvas, Rect(LX, LY, LX+3, LY+7));
      DrawChar(k*4, i*8, LX, LY, (FRam[LAddr] shr 12) and $f, (FRam[LAddr] shr 8) and $f);
      Inc(LAddr);
    end;
  end;
end;

end.
