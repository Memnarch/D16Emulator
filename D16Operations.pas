unit D16Operations;

interface

uses
  Generics.Collections, Operations, EmuTypes, VirtualDevice;

type
  TD16Operation = class(TOperations)
  private
    procedure SetValue(var ALeft, ARight: Word);
    procedure AddValue(var ALeft, ARight: Word);
    procedure SubValue(var ALeft, ARight: Word);
    procedure MulValue(var ALeft, ARight: Word);
    procedure MliValue(var ALeft, ARight: Word);
    procedure DivValue(var ALeft, ARight: Word);
    procedure DviValue(var ALeft, ARight: Word);
    procedure ModValue(var ALeft, ARight: Word);
    procedure MdiValue(var ALeft, ARight: Word);
    procedure AndValue(var ALeft, ARight: Word);
    procedure BorValue(var ALeft, ARight: Word);
    procedure XorValue(var ALeft, ARight: Word);
    procedure ShrValue(var ALeft, ARight: Word);
    procedure AsrValue(var ALeft, ARight: Word);
    procedure ShlValue(var ALeft, ARight: Word);
    procedure IfbValue(var ALeft, ARight: Word);
    procedure IfcValue(var ALeft, ARight: Word);
    procedure IfeValue(var ALeft, ARight: Word);
    procedure IfnValue(var ALeft, ARight: Word);
    procedure IfgValue(var ALeft, ARight: Word);
    procedure IfaValue(var ALeft, ARight: Word);
    procedure IflValue(var ALeft, ARight: Word);
    procedure IfuValue(var ALeft, ARight: Word);
    procedure AdxValue(var ALeft, ARight: Word);
    procedure SbxValue(var ALeft, ARight: Word);
    procedure StiValue(var ALeft, ARight: Word);
    procedure StdValue(var ALeft, ARight: Word);
    procedure JSR(var ALeft, ARight: Word);
    procedure GetIA(var ALeft, ARight: Word);
    procedure SetIA(var ALeft, ARight: Word);
    procedure RFI(var ALeft, ARight: Word);
    procedure IAQ(var ALeft, ARight: Word);
    procedure HWN(var ALeft, ARight: Word);
    procedure HWQ(var ALeft, ARight: Word);
    procedure HWI(var ALeft, ARight: Word);
    procedure Init();
  public
    constructor Create(ARegisters: PD16RegisterMem; ADevices: TObjectList<TVirtualDevice>);
    function IsBranchCode(ACode: Word): Boolean; override;
  end;

implementation

uses
  Classes, Types, SysUtils;

{ TD16Operation }

procedure TD16Operation.AddValue(var ALeft, ARight: Word);
begin
  if (ALeft + ARight) > High(Word) then
  begin
    Registers[CRegEX] := 1;
  end
  else
  begin
    Registers[CRegEX] := 0;
  end;
  ALeft := ALeft + ARight;
end;

procedure TD16Operation.AdxValue(var ALeft, ARight: Word);
var
  LHasOverflow: Boolean;
begin
  LHasOverflow := (ALeft + ARight + Registers[CRegEX]) > High(Word);
  ALeft := ALeft + ARight + Registers[CRegEX];
  if LHasOverflow then
  begin
    Registers[CRegEX] := 1;
  end
  else
  begin
    Registers[CRegEX] := 0;
  end;
end;

procedure TD16Operation.AndValue(var ALeft, ARight: Word);
begin
  ALeft := ALeft and ARight;
end;

procedure TD16Operation.AsrValue(var ALeft, ARight: Word);
var
  LShift: Byte;
  LLeft: Word;
begin
  Registers[CRegEX] := ((ALeft shl 16) shr ARight) and $FFFF;
  LShift := ARight;
  LLeft := ALeft;
  asm
    mov cl, LShift;
    sar LLeft, cl;
  end;
  ALeft := LLeft;
end;

procedure TD16Operation.BorValue(var ALeft, ARight: Word);
begin
  ALeft := ALeft or ARight;
end;

constructor TD16Operation.Create;
begin
  inherited Create(ARegisters, ADevices);
  Init();
end;

procedure TD16Operation.DivValue(var ALeft, ARight: Word);
begin
  if ARight <> 0 then
  begin
    Registers[CRegEX] := ((ALeft shl 16) div ARight) and $FFFF;
    ALeft := ALeft div ARight;
  end
  else
  begin
    ALeft := 0;
    Registers[CRegEX] := 0;
  end;
end;

procedure TD16Operation.DviValue(var ALeft, ARight: Word);
begin
  if ARight <> 0 then
  begin
    Registers[CRegEX] := Word(((SmallInt(ALeft) shl 16) div SmallInt(ARight)) and $FFFF);
    ALeft := Word(SmallInt(ALeft) div SmallInt(ARight));
  end
  else
  begin
    ALeft := 0;
    Registers[CRegEX] := 0;
  end;
end;

procedure TD16Operation.GetIA(var ALeft, ARight: Word);
begin
  ALeft := Registers[CRegIA];
end;

procedure TD16Operation.HWI(var ALeft, ARight: Word);
var
  LDevice: TVirtualDevice;
begin
  LDevice := Devices.Items[ALeft-1];
  if Assigned(LDevice) then
  begin
    LDevice.Interrupt();
  end
  else
  begin
    raise Exception.Create('HWI Error: No existing hardware with id ' + IntToStr(ALeft));
  end;
end;

procedure TD16Operation.HWN(var ALeft, ARight: Word);
begin
  ALeft := Devices.Count;
end;

procedure TD16Operation.HWQ(var ALeft, ARight: Word);
var
  LDevice: TVirtualDevice;
begin
  LDevice := Devices.Items[ALeft-1];
  if Assigned(LDevice) then
  begin
    Registers[CRegA] := LDevice.HardwareID;
    Registers[CRegB] := LDevice.HardwareID shr 16;
    Registers[CRegC] := LDevice.HardwareVersion;
    Registers[CRegX] := LDevice.ManufactorID;
    Registers[CRegY] := LDevice.ManufactorID shr 16;
  end
  else
  begin
    raise Exception.Create('No existing device with ID ' + IntToStr(ALeft));
  end;
end;

procedure TD16Operation.IAQ(var ALeft, ARight: Word);
begin
  UseInterruptQuery := ALeft <> 0;
end;

procedure TD16Operation.IfaValue(var ALeft, ARight: Word);
begin
  Skipping := not (SMallInt(ALeft) > SmallInt(ARight));
end;

procedure TD16Operation.IfbValue(var ALeft, ARight: Word);
begin
  Skipping := not ((ALeft and ARight) <> 0);
end;

procedure TD16Operation.IfcValue(var ALeft, ARight: Word);
begin
  Skipping := not ((ALeft and ARight) = 0);
end;

procedure TD16Operation.IfeValue(var ALeft, ARight: Word);
begin
  Skipping := not (ALeft = ARight);
end;

procedure TD16Operation.IfgValue(var ALeft, ARight: Word);
begin
  Skipping := not (ALeft > ARight);
end;

procedure TD16Operation.IflValue(var ALeft, ARight: Word);
begin
  Skipping := not (ALeft < ARight);
end;

procedure TD16Operation.IfnValue(var ALeft, ARight: Word);
begin
  Skipping := not (ALeft <> ARight);
end;

procedure TD16Operation.IfuValue(var ALeft, ARight: Word);
begin
  Skipping := not (SmallInt(ALeft) < SmallInt(ARight));
end;

procedure TD16Operation.Init;
begin
  RegisterOperation($1, 1, SetValue);
  RegisterOperation($2, 2, AddValue);
  RegisterOperation($3, 2, SubValue);
  RegisterOperation($4, 2, MulValue);
  RegisterOperation($5, 2, MliValue);
  RegisterOperation($6, 3, DivValue);
  RegisterOperation($7, 3, DviValue);
  RegisterOperation($8, 3, ModValue);
  RegisterOperation($9, 3, MdiValue);
  RegisterOperation($a, 1, AndValue);
  RegisterOperation($b, 1, BorValue);
  RegisterOperation($c, 1, XorValue);
  RegisterOperation($d, 1, ShrValue);
  RegisterOperation($e, 1, AsrValue);
  RegisterOperation($f, 1, ShlValue);
  RegisterOperation($10, 2, IfbValue);
  RegisterOperation($11, 2, IfcValue);
  RegisterOperation($12, 2, IfeValue);
  RegisterOperation($13, 2, IfnValue);
  RegisterOperation($14, 2, IfgValue);
  RegisterOperation($15, 2, IfaValue);
  RegisterOperation($16, 2, IflValue);
  RegisterOperation($17, 2, IfuValue);

  RegisterOperation($1a, 3, AdxValue);
  RegisterOperation($1b, 3, sbxValue);

  RegisterOperation($1e, 2, StiValue);
  RegisterOperation($1f, 2, StdValue);

  //non basic operations. Lower 5 bits are always 0
  RegisterOperation($1 shl 5, 3, JSR);

  RegisterOperation($9 shl 5, 1, GetIA);
  RegisterOperation($a shl 5, 1, SetIA);
  RegisterOperation($b shl 5, 3, RFI);
  RegisterOperation($c shl 5, 2, IAQ);

  RegisterOperation($10 shl 5, 2, HWN);
  RegisterOperation($11 shl 5, 4, HWQ, True);
  RegisterOperation($12 shl 5, 4, HWI);
end;

function TD16Operation.IsBranchCode(ACode: Word): Boolean;
begin
  Result := (ACode >= $10) and (ACode <= $17);
end;

procedure TD16Operation.JSR(var ALeft, ARight: Word);
begin
  Push(Registers[CRegPC]);
  Registers[CRegPC] := ALeft;
end;

procedure TD16Operation.MdiValue(var ALeft, ARight: Word);
begin
  if ARight <> 0 then
  begin
    ALeft := Word(SmallInt(ALeft) mod SmallInt(ARight));
  end
  else
  begin
    ALeft := 0;
  end;
end;

procedure TD16Operation.MliValue(var ALeft, ARight: Word);
begin
  Registers[CRegEX] := Word(((SmallInt(ALeft)*SmallInt(ARight)) shr 16) and $FFFF);
  ALeft := Word(SmallInt(ALeft) * SmallInt(ARight));
end;

procedure TD16Operation.ModValue(var ALeft, ARight: Word);
begin
  if ARight <> 0 then
  begin
    ALeft := ALeft mod ARight;
  end
  else
  begin
    ALeft := 0;
  end;
end;

procedure TD16Operation.MulValue(var ALeft, ARight: Word);
begin
  Registers[CRegEX] := ((ALeft*ARight) shr 16) and $FFFF;
  ALeft := ALeft * ARight;
end;

procedure TD16Operation.RFI(var ALeft, ARight: Word);
begin
  UseInterruptQuery := False;
  Pop(Registers[CRegA]);
  Pop(Registers[CRegPC]);
end;

procedure TD16Operation.SbxValue(var ALeft, ARight: Word);
var
  LHasUnderflow: Boolean;
begin
  LHasUnderflow := (ALeft - ARight + Registers[CRegEX]) < Low(Word);
  ALeft := ALeft - ARight + Registers[CRegEX];
  if LHasUnderflow then
  begin
    Registers[CRegEX] := $FFFF;
  end
  else
  begin
    Registers[CRegEX] := 0;
  end;
end;

procedure TD16Operation.SetIA(var ALeft, ARight: Word);
begin
  Registers[CRegIA] := ALeft;
end;

procedure TD16Operation.SetValue(var ALeft, ARight: Word);
begin
  ALeft := ARight;
end;

procedure TD16Operation.ShlValue(var ALeft, ARight: Word);
var
  LEX: Cardinal;
begin
  LEX := ALeft shl ARight;
  asm
    sar LEX, 16;
  end;
  Registers[CRegEX] := LEX and $FFFF;
  ALeft := ALeft shl ARight;
end;

procedure TD16Operation.ShrValue(var ALeft, ARight: Word);
var
  LRight: Byte;
  LEX: Cardinal;
begin
  LEX := ALeft shl 16;
  LRight := ARight;
  asm
    mov cl, LRight;
    sar LEX, cl;
  end;
  Registers[CRegEX] := LEX and $FFFF;
  ALeft := ALeft shr ARight;
end;

procedure TD16Operation.StdValue(var ALeft, ARight: Word);
begin
  ALeft := ARight;
  Dec(Registers[CRegI]);
  Dec(Registers[CRegJ])
end;

procedure TD16Operation.StiValue(var ALeft, ARight: Word);
begin
  ALeft := ARight;
  Inc(Registers[CRegI]);
  Inc(Registers[CRegJ])
end;

procedure TD16Operation.SubValue(var ALeft, ARight: Word);
begin
  if (ALeft - ARight) < Low(Word) then
  begin
    Registers[CRegEX] := $FFFF;
  end
  else
  begin
    Registers[CRegEX] := 0;
  end;
  ALeft := ALeft - ARight;
end;

procedure TD16Operation.XorValue(var ALeft, ARight: Word);
begin
  ALeft := ALeft xor ARight;
end;

end.
