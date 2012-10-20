unit Emulator;

interface

uses
  Classes, Types, Windows, Messages, SysUtils, SyncObjs, Generics.Collections, EmuTypes, CPUOperations, VirtualDevice, SiAuto, SmartInspect;

type

  TD16Emulator = class(TThread)
  private
    FRam: TD16Ram;
    FRegisters: TD16RegisterMem;
    FRefreshCycles: Integer;
    FLastSleep: TDateTime;
    FLastUpdate: TDateTime;
    FRunning: Boolean;
    FOnStep: TEvent;
    FOperations: TCPUOperations;
    FCycles: Cardinal;
    FDevices: TObjectList<TVirtualDevice>;
    FOnIdle: TEvent;
    FMessage: string;
    FOnMessage: TMessageEvent;
    FUpdateQuery: TObjectList<TVirtualDevice>;
    FInterruptQueue: TQueue<Word>;
    FLog: TStringList;
    FUseLogging: Boolean;
    procedure ResetRam();
    procedure ResetRegisters();
    procedure AddCycles(ACycles: Integer);
    function ReadValue(AFromCode: Byte; var AUsedAddress: Integer; AModifySP: Boolean = False): Word;
    procedure WriteValue(AToCode: Byte; AToAdress: Integer; AVal: Word; AModOnlySP: Boolean = False);
    procedure DecodeWord(AInput: Word; var AOpcode: Word; var ALeft, ARight: byte);
    function GetAdressForOperand(AOperand: Byte): Integer;
    procedure ExecuteOperation(AOpCode: Word; var ALeft, ARight: Word; var AIsReadOnly: Boolean);
    procedure DoOnStep();
    procedure DoOnIdle();
    procedure DoOnMessage();
    procedure Push(var AVal: Word);
    procedure Pop(var AVal: Word);
    procedure InitBaseDevices();
    procedure ProcessDeviceUpdates();
    procedure ProcessInterruptQueue();
    procedure QueueInterrupt(AMessage: Word);
    procedure CallSWInterrupt(AMessage: Word);
    procedure JumpOverCondition();
    procedure Init();
  protected
    procedure Execute(); override;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure LoadFromFile(AFile: string; AUseBigEndian: Boolean = False);
    procedure Reset();
    procedure Run();
    procedure Stop();
    procedure Step();
    procedure RegisterDevice(ADevice: TVirtualDevice);
    property Ram: TD16Ram read FRam write FRam;
    property Registers: TD16RegisterMem read FRegisters write FRegisters;
    property OnStep: TEvent read FOnStep write FOnStep;
    property OnIdle: TEvent read FOnIdle write FOnIdle;
    property OnMessage: TMessageEvent read FOnMessage write FOnMessage;
    property Operations: TCPUOperations read FOperations;
    property Cycles: Cardinal read FCycles write FCycles;
    property Devices: TObjectList<TVirtualDevice> read FDevices;
    property InterruptQueue: TQueue<Word> read FInterruptQueue;
    property UseLogging: Boolean read FUseLogging write FUseLogging;
  end;

implementation

uses
  DateUtils, D16Operations, LEM1802, GenericKeyboard, GenericClock, Floppy;

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
    DoOnIdle();
    LSpend := MilliSecondsBetween(FLastSleep, Now());
    if LSpend < 20 then
    begin
      Sleep(20-LSpend);
    end;
    FLastSleep := Now();
  end;
end;

procedure TD16Emulator.CallSWInterrupt(AMessage: Word);
begin
  if FRegisters[CRegIA] <> 0 then
  begin
    FOperations.UseInterruptQuery := False;
    Push(FRegisters[CRegPC]);
    Push(FRegisters[CRegA]);
    FRegisters[CRegA] := AMessage;
    FRegisters[CRegPC] := FRegisters[CRegIA];
  end;
end;

constructor TD16Emulator.Create;
begin
  inherited;
  Init();
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
    ALeft := (AInput shr 10) and $3f;
  end;
end;

destructor TD16Emulator.Destroy;
begin
  FOperations.Free;
  FDevices.Free;
  FUpdateQuery.Free;
  FInterruptQueue.Free;
  FLog.Free;
  inherited;
end;

procedure TD16Emulator.DoOnIdle;
begin
  if Assigned(FOnIdle) then
  begin
    Synchronize(FOnIdle);
  end;
end;

procedure TD16Emulator.DoOnMessage;
begin
  if Assigned(FOnMessage) then
  begin
    FOnMessage(FMessage);
  end;
end;

procedure TD16Emulator.DoOnStep;
begin
  if Assigned(FOnStep) then
  begin
    Synchronize(FOnStep);
  end;
end;

procedure TD16Emulator.Step;
var
  LCode, LOpCode: Word;
  LLeft, LRight: Byte;
  LLeftVal, LRightVal: Word;
  LLeftAddr, LRightAddr: Integer;
  LIsReadOnly: Boolean;
begin
  LCode := FRam[FRegisters[CRegPC]];
  Inc(FRegisters[CRegPC]);
  DecodeWord(LCode, LOpCode, LLeft, LRight);
  LRightVal := ReadValue(LRight, LRightAddr, not FOperations.Skipping);
  LLeftVal := ReadValue(LLeft, LLeftAddr);

  ExecuteOperation(LOpCode, LLeftVal, LRightVal, LIsReadOnly);
  WriteValue(LLeft, LLeftAddr, LLeftVal, LIsReadOnly);
  if FOperations.Skipping then
  begin
    JumpOverCondition();
  end;
  ProcessDeviceUpdates();
  ProcessInterruptQueue();

  DoOnStep();
end;

procedure TD16Emulator.Execute;
begin
  inherited;
  while not Terminated do
  begin
    if FRunning then
    begin
      try
        Step();
      except
        on E: Exception do
        begin
          FRunning := False;
          FMessage := E.Message;
          Synchronize(DoOnMessage);
        end;
      end;
    end
    else
    begin
      Sleep(20);
    end;
  end;
  if FUseLogging then
  begin
    FLog.SaveToFile('D:\RunLog.txt');
  end;
end;

procedure TD16Emulator.ExecuteOperation(AOpCode: Word; var ALeft, ARight: Word; var AIsReadOnly: Boolean);
var
  LItem: TCPUOperationItem;
begin
  LItem := FOperations.GetOperation(AOpCode);
  if Assigned(LItem) then
  begin
    if FUseLogging then
    begin
      FLog.Add(LItem.OperationName);
    end;
    LItem.Operation(ALeft, ARight);
    AddCycles(LItem.Cost);
    AIsReadOnly := LItem.ReadOnly;
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

procedure TD16Emulator.Init;
begin
  FLog := TStringList.Create();
  FLog.Sorted := True;
  FLog.Duplicates := dupIgnore;
  FDevices := TObjectList<TVirtualDevice>.Create();
  FUpdateQuery := TObjectList<TVirtualDevice>.Create(False);
  FInterruptQueue := TQueue<Word>.Create();
  FOperations := TD16Operation.Create(@FRegisters, FDevices);
  FOperations.Push := Push;
  FOperations.Pop := Pop;
  FOperations.SoftwareInterrupt := QueueInterrupt;
  InitBaseDevices();
end;

procedure TD16Emulator.InitBaseDevices;
begin
  RegisterDevice(TLEM1802.Create(@FRegisters, @FRam));
  RegisterDevice(TGenericKeyboard.Create(@FRegisters, @FRam));
  RegisterDevice(TGenericClock.Create(@FRegisters, @FRam));
//  RegisterDevice(TFloppy.Create(@FRegisters, @FRam));
end;

procedure TD16Emulator.JumpOverCondition;
var
  LLeftAddr, LRightAddr: Integer;
  LCode, LOpCode: Word;
  LLeft, LRight: Byte;
begin
  while FOperations.Skipping do
  begin
    AddCycles(1);
    LCode := FRam[FRegisters[CRegPC]];
    Inc(FRegisters[CRegPC]);
    DecodeWord(LCode, LOpCode, LLeft, LRight);
    ReadValue(LRight, LRightAddr, False);
    ReadValue(LLeft, LLeftAddr);
    if not FOperations.IsBranchCode(LOpCode) then
    begin
      FOperations.Skipping := False;
    end;
  end;
end;

procedure TD16Emulator.LoadFromFile(AFile: string; AUseBigEndian: Boolean = False);
var
  LStream: TMemoryStream;
  i: Integer;
begin
  if not FRunning then
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
end;

procedure TD16Emulator.Pop(var AVal: Word);
begin
  AVal := Ram[FRegisters[CRegSP]];
  FRegisters[CRegSP] := FRegisters[CRegSP] + 1;
end;

procedure TD16Emulator.ProcessDeviceUpdates;
var
  LDevice: TVirtualDevice;
begin
  if MilliSecondsBetween(FLastUpdate, Now()) >= 10 then
  begin
    for LDevice in FUpdateQuery do
    begin
      LDevice.UpdateDevice();
    end;
    FLastUpdate := Now();
  end;
end;

procedure TD16Emulator.ProcessInterruptQueue;
begin
  if FRegisters[CRegIA] = 0 then
  begin
    FInterruptQueue.Clear;
  end;
  if (FOperations.UseInterruptQuery) and (FInterruptQueue.Count > 0) then
  begin
    CallSWInterrupt(FInterruptQueue.Dequeue);
  end;
end;

procedure TD16Emulator.Push(var AVal: Word);
begin
  Dec(FRegisters[CRegSP]);
  FRam[FRegisters[CRegSP]] := AVal;
end;

procedure TD16Emulator.QueueInterrupt(AMessage: Word);
begin
  AddCycles(4);
  if FRegisters[CRegIA] = 0 then exit;

  FInterruptQueue.Enqueue(AMessage);
  if FInterruptQueue.Count > 256 then
  begin
    raise EAbort.Create('Interruptqueue overflow');
  end;
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

procedure TD16Emulator.RegisterDevice(ADevice: TVirtualDevice);
begin
  FDevices.Add(ADevice);
  ADevice.SoftwareInterrupt := QueueInterrupt;
  if ADevice.NeedsUpdate then
  begin
    FUpdateQuery.Add(ADevice);
  end;
end;

procedure TD16Emulator.Reset;
begin
  if not FRunning then
  begin
    ResetRegisters();
    ResetRam();
    FRefreshCycles := 0;
    FCycles := 0;
    FLastSleep := Now();
    FLastUpdate := Now();
    FLog.Clear;
    DoOnStep();
  end;
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
  if not FRunning then
  begin
    ResetRegisters();
    FLastSleep := Now();
    FRunning := True;
  end;
end;

procedure TD16Emulator.Stop;
begin
  FRunning := False;
end;

procedure TD16Emulator.WriteValue(AToCode: Byte; AToAdress: Integer; AVal: Word; AModOnlySP: Boolean = False);
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

  if not AModOnlySP then
  begin
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
end;

end.
