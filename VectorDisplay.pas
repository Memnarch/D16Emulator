unit VectorDisplay;

interface

uses
  Classes, Types, Windows, Controls, SysUtils, EmuTypes, VirtualDevice, BasicScreenForm, Graphics, Math3D;

type
  TVertex = packed record
    X: Byte;
    Y: Byte;
    Z: Byte;
    Info: Byte;
  end;

  TVertices = array[0..127] of TVertex;
  PVertices = ^TVertices;

  TVectorDisplay = class(TVirtualDevice)
  private
    FMonitor: TBasicScreen;
    FBuffer: TBitmap;
    FVertices: PVertices;
    FState: Byte;
    FError: Byte;
    FVerticesToRender: Byte;
    F4DVertices: array[0..127] of TVectorClass4D;
    FProjectionMatrix: TMatrixClass4D;
    FRotateXMatrix: TMatrixClass4D;
    FRotateYMatrix: TMatrixClass4D;
    FRotateZMatrix: TMatrixClass4D;
    FWorldMatrix: TMatrixClass4D;
    FMoveMatrix: TMatrixClass4D;
    FViewMatrix: TMatrixClass4D;
    procedure RenderScreen(Sender: TObject);
    procedure DrawBuffer();
    procedure DrawVertices();
    procedure CopyVertices();
    procedure TransformVertices();
  public
    constructor Create(ARegisters:PD16RegisterMem; ARam: PD16Ram);
    destructor Destroy(); override;
    procedure Interrupt(); override;
  end;

const
  STATE_NO_DATA = 0;//    No vertices queued up, device is in stand-by
  STATE_RUNNING = 1;//    The device is projecting lines
  STATE_TURNING = 2;//   The device is projecting lines and turning

  ERROR_NONE = 0;//       There's been no error since the last poll.
  ERROR_BROKEN = $ffff;// There's been some major software or hardware problem,
                        // try turning off and turning on the device again.

implementation

uses
  Math;

{ TVectorDisplay }

procedure TVectorDisplay.CopyVertices;
var
  i: Integer;
begin
  for i := 0 to FVerticesToRender - 1 do
  begin
    F4DVertices[i].Element[0] := FVertices[i].X;
    F4DVertices[i].Element[1] := FVertices[i].Y;
    F4DVertices[i].Element[2] := FVertices[i].Z;
    F4DVertices[i].Element[3] := 1;//the W value
  end;
end;

constructor TVectorDisplay.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
var
  i: Integer;
begin
  inherited;
  FHardwareID := $42babf3c;
  FHardwareVerion := $0003;
  FManufactorID := $1eb37e91;
  FBuffer := TBitmap.Create();
  FBuffer.PixelFormat := pf32bit;
  FBuffer.SetSize(512, 512);
  FMonitor := TBasicScreen.Create(nil);
  FMonitor.ScreenTimer.Enabled := True;
  FMonitor.ClientWidth := FBuffer.Width;
  FMonitor.ClientHeight := FBuffer.Height;
  FMonitor.Screen.OnPaint := RenderScreen;
  FMonitor.Caption := '3D VectorDisplay';
  FMonitor.Show;
  FState := STATE_NO_DATA;
  FError := ERROR_NONE;

  FMoveMatrix := TMatrixClass4D.Create();
  FRotateXMatrix := TMatrixClass4D.Create();
  FRotateYMatrix := TMatrixClass4D.Create();
  FRotateZMatrix := TMatrixClass4D.Create();
  FWorldMatrix := TMatrixClass4D.Create();
  FViewMatrix := TMatrixClass4D.Create();

  FViewMatrix.SetAsMoveMatrix(0, 0, 1000);

  FMoveMatrix.SetAsMoveMatrix(0, 0, 0);
  FRotateXMatrix.SetAsRotationXMatrix(DegToRad(10));
  FRotateYMatrix.SetAsRotationYMatrix(DegToRad(0));
  FRotateZMatrix.SetAsRotationZMatrix(DegToRad(0));
  FWorldMatrix.CopyFromMatrix4D(FMoveMatrix);
  FWorldMatrix.MultiplyMatrix4D(FRotateXMatrix);
  FWorldMatrix.MultiplyMatrix4D(FRotateYMatrix);
  FWorldMatrix.MultiplyMatrix4D(FRotateZMatrix);
  FWorldMatrix.MultiplyMatrix4D(FViewMatrix);
  FProjectionMatrix := TMatrixClass4D.Create();
  FProjectionMatrix.SetAsPerspectiveProjectionMatrix(100, 200, 64, 64);
  FProjectionMatrix.MultiplyMatrix4D(FWorldMatrix);

  for i := 0 to High(F4DVertices) do
  begin
    F4DVertices[i] := TVectorClass4D.Create();
  end;
end;

destructor TVectorDisplay.Destroy;
var
  i: Integer;
begin
  FMonitor.Free;
  FBuffer.Free;
  FProjectionMatrix.Free;
  for i := 0 to High(F4DVertices) do
  begin
    F4DVertices[i].Free;
  end;
  inherited;
end;

procedure TVectorDisplay.DrawBuffer;
begin
  FBuffer.Canvas.Brush.Color := clNone;
  FBuffer.Canvas.FillRect(FBuffer.Canvas.ClipRect);
  if Assigned(FVertices) then
  begin
    DrawVertices();
  end;
end;

procedure TVectorDisplay.DrawVertices;
var
  i: Integer;

begin
  CopyVertices();
  TransformVertices();
  FBuffer.Canvas.Pen.Color := clWhite;
  if FVerticesToRender > 0 then
  begin
    FBuffer.Canvas.MoveTo(Round(F4DVertices[FVerticesToRender-1].X), Round(F4DVertices[FVerticesToRender-1].Y));
  end;
  for i := 0 to FVerticesToRender - 1 do
  begin
    FBuffer.Canvas.LineTo(Round(F4DVertices[i].X), Round(F4DVertices[i].Y));
    FBuffer.Canvas.MoveTo(Round(F4DVertices[i].X), Round(F4DVertices[i].Y));
  end;
end;

procedure TVectorDisplay.Interrupt;
begin
  case FRegisters[CRegA] of
    0:
    begin
      FRegisters[CRegB] := FState;
      FRegisters[CRegC] := FError;
      FError := ERROR_NONE;
    end;
    1:
    begin
      FVertices := Pointer(Integer(@FRam[0]) + FRegisters[CRegX]*2);
      FVerticesToRender := FRegisters[CRegY];
    end;
  end;
end;

procedure TVectorDisplay.RenderScreen(Sender: TObject);
begin
  DrawBuffer();
  FMonitor.Screen.Canvas.Draw(0, 0, FBuffer);
end;

procedure TVectorDisplay.TransformVertices;
var
  i: Integer;
begin
  for i := 0 to FVerticesToRender - 1 do
  begin
    F4DVertices[i].MultiplyWithMatrix4D(FProjectionMatrix);
    F4DVertices[i].Rescale(True);
    //denormalize to screenpos
    F4DVertices[i].X := (1-F4DVertices[i].X) * 256;
    F4DVertices[i].Y := (1-F4DVertices[i].Y) * 256;
  end;
end;

end.
