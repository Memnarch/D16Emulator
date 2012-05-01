unit Emulator;

interface

uses
  Classes, Types, SysUtils, Generics.Collections, EmuTypes, Operations, VirtualDevice;

type

  TD16Emulator = class
  private
    FRam: TD16Ram;
    FRegisters: TD16RegisterMem;
    FRefreshCycles: Integer;
    FLastSleep: TDateTime;
    FRunning: Boolean;
    FOnStep: TEvent;
    FOperations: TOperations;
    FCycles: Cardinal;
    FDevices: TObjectList<TVirtualDevice>;
    procedure ResetRam();
    procedure ResetRegisters();
    procedure AddCycles(ACycles: Integer);
    function ReadValue(AFromCode: Byte; var AUsedAddress: Integer; AModifySP: Boolean = False): Word;
    procedure WriteValue(AToCode: Byte; AToAdress: Integer; AVal: Word);
    procedure DecodeWord(AInput: Word; var AOpcode: Word; var ALeft, ARight: byte);
    function GetAdressForOperand(AOperand: Byte): Integer;
    procedure ExecuteOperation(AOpCode: Byte; var ALeft, ARight: Word);
    procedure DoOnStep();
    procedure Push(var AVal: Word);
    procedure Pop(var AVal: Word);
  public
    constructor Create();
    destructor Destroy(); override;
    procedure LoadFromFile(AFile: string; AUseBigEndian: Boolean = False);
    procedure Reset();
    procedure Run();
    procedure Stop();
    procedure Step();
    property Ram: TD16Ram read FRam write FRam;
    property Registers: TD16RegisterMem read FRegisters write FRegisters;
    property OnStep: TEvent read FOnStep write FOnStep;
    property Operations: TOperations read FOperations;
    property Cycles: Cardinal read FCycles write FCycles;
    property Devices: TObjectList<TVirtualDevice> read FDevices;
  end;

implementation

uses
  DateUtils, D16Operations;

{ TD16Emulator }

procedure TD16Emulator.AddCycles(ACycles: Integer);
var
  LSpend: Cardinal;
begin
  Inc(FRefreshCycles, ACycles);
  Inc(FCycles, ACycles);
  if FRefreshCycles >= 2000 then
  begin
    Dec(FRefreshCycles, 2000);
    LSpend := MilliSecondsBetween(FLastSleep, Now());
    if LSpend < 20 then
    begin
      Sleep(20-LSpend);
    end;
    FLastSleep := Now();
  end;
end;

constructor TD16Emulator.Create;
begin
  FDevices := TObjectList<TVirtualDevice>.Create();
  FOperations := TD16Operation.Create(@FRegisters, FDevices);
  FOperations.Push := Push;
  FOperations.Pop := Pop;
end;

procedure TD16Emulator.DecodeWord(AInput: Word; var AOpcode: Word; var ALeft,
  ARight: Byte);
var
  LBaseOp: Byte;
begin
  LBaseOp := AInput and $1f;//11111
  ALeft := 0;
  ARight := 0;
  if LBaseOp > 0 then
  begin
    AOpcode := LBaseOp;
    ALeft := (AInput shr 5) and $1f;
    ARight := (AInput shr 10);
  end
  else
  begin
    AOpCode := AInput and $3E0; //asking for the second 5 bits. Mas is 1111100000 //(AInput shr 5) and $1f;
    ARight := (AInput shr 10) and $3f;
  end;
end;

destructor TD16Emulator.Destroy;
begin
  FOperations.Free;
  inherited;
end;

procedure TD16Emulator.DoOnStep;
begin
  if Assigned(FOnStep) then
  begin
    FOnStep();
  end;
end;

procedure TD16Emulator.Step;
var
  LCode, LOpCode: Word;
  LLeft, LRight: Byte;
  LLeftVal, LRightVal: Word;
  LLeftAddr, LRightAddr: Integer;
begin
  LCode := FRam[FRegisters[CRegPC]];
  Inc(FRegisters[CRegPC]);
  DecodeWord(LCode, LOpCode, LLeft, LRight);
  LRightVal := ReadValue(LRight, LRightAddr, not FOperations.Skipping);
  LLeftVal := ReadValue(LLeft, LLeftAddr);
  if not FOperations.Skipping then
  begin
    ExecuteOperation(LOpCode, LLeftVal, LRightVal);
    WriteValue(LLeft, LLeftAddr, LLeftVal);
  end
  else
  begin
    AddCycles(1);
  end;
  if (not FOperations.IsBranchCode(LOpCode)) and (FOperations.Skipping) then
  begin
    FOperations.Skipping := False;
  end;
  DoOnStep();
end;

procedure TD16Emulator.ExecuteOperation(AOpCode: Byte; var ALeft, ARight: Word);
var
  LItem: TOperationItem;
begin
  LItem := FOperations.GetOperation(AOpCode);
  if Assigned(LItem) then
  begin
    LItem.Operation(ALeft, ARight);
    AddCycles(LItem.Cost);
    if FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end
  else
  begin
    Stop();
    raise EAbort.Create('Unknown Opcode 0x' + IntToHex(AOpCode, 4));
  end;
end;

function TD16Emulator.GetAdressForOperand(AOperand: Byte): Integer;
begin
  Result := 0;
  if AOperand <= 7 then//register
  begin
    Result := -AOperand - 1;
  end;
  if (AOperand >= 8) and (AOperand <= $f) then//[register]
  begin
    Result := FRegisters[AOperand-8];
  end;
  if (AOperand >= $10) and (AOperand <= $17) then
  begin
    Result := FRegisters[AOperand-$10] + FRam[FRegisters[CRegPC]];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;
  if (AOperand  = $18) or (AOperand = $19) then //[sp], push/pop behaviour handled before this function call by read/write method
  begin
    Result := FRegisters[CRegSP];
  end;
  if AOperand = $1a then
  begin
    Result := FRegisters[CRegSP] + FRam[FRegisters[CRegPC]];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;
  if AOperand = $1b then
  begin
    Result := -CRegSP -1;
  end;
  if AOperand = $1c then
  begin
    Result := -CRegPC-1;
  end;
  if AOperand = $1d then
  begin
    Result := -CRegEX-1;
  end;
  if AOperand = $1e then
  begin
    Result := FRam[FRegisters[CRegPC]];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;
  if AOperand = $1f then
  begin
    Result := FRegisters[CRegPC];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;
  if (AOperand >= $20) and (AOperand <= $3f)then
  begin
    Result := -AOperand-1;
  end;
end;

procedure TD16Emulator.LoadFromFile(AFile: string; AUseBigEndian: Boolean = False);
var
  LStream: TMemoryStream;
  i: Integer;
begin
  Reset();
  LStream := TMemoryStream.Create();
  LStream.LoadFromFile(AFile);
  LStream.Read(FRam[0], LStream.Size);
  LStream.Free;
  if AUseBigEndian then
  begin
    for i := 0 to High(FRam) do
    begin
      FRam[i] := (FRam[i] shl 8) + (FRam[i] shr 8);
    end;
  end;
end;

procedure TD16Emulator.Pop(var AVal: Word);
begin
  AVal := Ram[FRegisters[CRegSP]];
  FRegisters[CRegSP] := FRegisters[CRegSP] + 1;
end;

procedure TD16Emulator.Push(var AVal: Word);
begin
  Dec(FRegisters[CRegSP]);
  FRam[FRegisters[CRegSP]] := AVal;
end;

function TD16Emulator.ReadValue(AFromCode: Byte; var AUsedAddress: Integer; AModifySP: Boolean): Word;
var
  LFrom: Integer;
begin
  LFrom := GetAdressForOperand(AFromCode);
  AUsedAddress := LFrom;
  if LFrom >= 0 then
  begin
    Result := FRam[LFrom];
  end
  else
  begin
    LFrom := Abs(LFrom) - 1;
    if (LFrom >= $20) and (LFrom <= $3f) then
    begin
      Result := LFrom-$21;
    end
    else
    begin
      Result := FRegisters[LFrom];
    end;
  end;
  if AModifySP and (AFromCode = $18) then
  begin
    Inc(FRegisters[CRegSP], 1);
  end;
  if ((AFromCode >= $10) and (AFromCode <= $17)) or (AFromCode = $1a) or (AFromCode = $1e) or (AFromCode = $1f) then
  begin
    Inc(FRegisters[CRegPC]);
  end;
end;

procedure TD16Emulator.Reset;
begin
  ResetRegisters();
  ResetRam();
  FRefreshCycles := 0;
  FCycles := 0;
  FLastSleep := Now();
  DoOnStep();
end;

procedure TD16Emulator.ResetRam;
var
  i: Integer;
begin
  for i := 0 to High(FRam) do
  begin
    FRam[i] := 0;
  end;
end;

procedure TD16Emulator.ResetRegisters;
var
  i: Integer;
begin
  for i := 0 to High(FRegisters) do
  begin
    FRegisters[i] := 0;
  end;
end;

procedure TD16Emulator.Run;
begin
  ResetRegisters();
  FRunning := True;
  FLastSleep := Now();
  while FRunning do
  begin
    Step();
  end;
end;

procedure TD16Emulator.Stop;
begin
  FRunning := False;
end;

procedure TD16Emulator.WriteValue(AToCode: Byte; AToAdress: Integer; AVal: Word);
var
  LTo: Integer;
begin
  if AToCode = $18 then
  begin
    Dec(FRegisters[CRegSP]);
    LTo := GetAdressForOperand(AToCode);
  end
  else
  begin
    LTo := AToAdress;;
  end;

  if LTo >= 0 then
  begin
    FRam[LTo] := AVal;
  end
  else
  begin
    LTo := Abs(LTo) - 1;
    FRegisters[LTo] := AVal;
  end;
end;

end.
