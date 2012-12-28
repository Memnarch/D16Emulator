unit Emulator;

interface

uses
  Classes, Types, Windows, Messages, SysUtils, SyncObjs, Generics.Collections, EmuTypes, CPUOperations, VirtualDevice;// SiAuto, SmartInspect;

type
  TEmulationState = (esStopped, esRunning, esPaused);

  TD16Emulator = class(TThread)
  private
    FRam: TD16Ram;
    FAlertPoints: TD16AlertPoints;
    FRegisters: TD16RegisterMem;
    FRefreshCycles: Integer;
    FLastSleep: TDateTime;
    FLastUpdate: TDateTime;
    FState: TEmulationState;
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
    FOnPause: TEvent;
    FAlertChangeQueue: TQueue<TAlertPointModification>;
    FAlertAccessLock: TCriticalSection;
    FCallStack: TStack<Word>;
    FOnAlert: TAlertEvent;
    FOnRun: TEvent;
    FLastAlertAddress: Integer;
    FOnReturn: TEvent;
    FOnCall: TEvent;
    procedure ResetRam();
    procedure ResetRegisters();
    procedure ResetAlertPoints();
    procedure AddCycles(ACycles: Integer);
    function ReadValue(AFromCode: Byte; var AUsedAddress: Integer; AModifySP: Boolean = False): Word;
    procedure WriteValue(AToCode: Byte; AToAdress: Integer; AVal: Word; AModOnlySP: Boolean = False);
    procedure DecodeWord(AInput: Word; var AOpcode: Word; var ALeft, ARight: byte);
    function GetAdressForOperand(AOperand: Byte): Integer;
    procedure ExecuteOperation(AOpCode: Word; var ALeft, ARight: Word; var AIsReadOnly: Boolean);
    procedure DoOnStep();
    procedure DoOnIdle();
    procedure DoOnMessage();
    procedure DoOnPause();
    procedure DoOnAlert();
    procedure DoOnRun();
    procedure DoOnCall();
    procedure DoOnReturn();
    procedure Push(var AVal: Word);
    procedure Pop(var AVal: Word);
    procedure InitBaseDevices();
    procedure ProcessDeviceUpdates();
    procedure ProcessInterruptQueue();
    procedure QueueInterrupt(AMessage: Word);
    procedure CallSWInterrupt(AMessage: Word);
    procedure JumpOverCondition();
    procedure Init();
    procedure InternalPause();
    procedure InternalOnAlert();
    procedure ProcessMessages();
    procedure UpdateAlertPoints();
    procedure CheckAlertPoints();
    procedure HandleMessages(AMSG: TMsg);
  protected
    procedure Execute(); override;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure LoadFromFile(AFile: string; AUseBigEndian: Boolean = False);
    procedure Reset();
    procedure Run();
    procedure Stop();
    procedure Pause();
    procedure Step();
    procedure RegisterDevice(ADevice: TVirtualDevice);
    procedure SetAlertPoint(AAddress: Word; AEnabled: Boolean);
    property Ram: TD16Ram read FRam write FRam;
    property Registers: TD16RegisterMem read FRegisters write FRegisters;
    property OnStep: TEvent read FOnStep write FOnStep;
    property OnIdle: TEvent read FOnIdle write FOnIdle;
    property OnMessage: TMessageEvent read FOnMessage write FOnMessage;
    property OnPause: TEvent read FOnPause write FOnPause;
    property OnAlert: TAlertEvent read FOnAlert write FOnAlert;
    property OnRun: TEvent read FOnRun write FOnRun;
    property OnCall: TEvent read FOnCall write FOnCall;
    property OnReturn: TEvent read FOnReturn write FOnReturn;
    property Operations: TCPUOperations read FOperations;
    property Cycles: Cardinal read FCycles write FCycles;
    property Devices: TObjectList<TVirtualDevice> read FDevices;
    property InterruptQueue: TQueue<Word> read FInterruptQueue;
    property UseLogging: Boolean read FUseLogging write FUseLogging;
  end;

const
    WM_PAUSE = WM_USER + 1;
    WM_STOP = WM_USER + 2;

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

procedure TD16Emulator.CheckAlertPoints;
begin
  if (Self.FState = esRunning) and FAlertPoints[FRegisters[CRegPC]]
    and (FRegisters[CRegPC] <> FLastAlertAddress)
  then
  begin
    FLastAlertAddress := FRegisters[CRegPC];
    DoOnAlert();
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
  FAlertChangeQueue.Free;
  FAlertAccessLock.Free;
  inherited;
end;

procedure TD16Emulator.DoOnAlert;
begin
  if Assigned(FOnAlert) then
  begin
    Synchronize(InternalOnAlert);
  end;
end;

procedure TD16Emulator.DoOnCall;
begin
  FCallStack.Push(FRam[FRegisters[CRegSP]]);//we read the return adress which has been pushed by JSR
  if Assigned(FOnCall) then
  begin
    Synchronize(FOnCall);
  end;
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

procedure TD16Emulator.DoOnPause;
begin
  if Assigned(FOnPause) then
  begin
    Synchronize(FOnPause);
  end;
end;

procedure TD16Emulator.DoOnReturn;
begin
  if (FCallStack.Count > 0) and (FCallStack.Peek = FRegisters[CRegPC]) then
  begin
    FCallStack.Pop;
    if Assigned(FOnReturn) then
    begin
      Synchronize(FOnReturn);
    end;
  end;
end;

procedure TD16Emulator.DoOnRun;
begin
  if Assigned(FOnRun) then
  begin
    Synchronize(FOnRun);
  end;
end;

procedure TD16Emulator.DoOnStep;
begin
  if Assigned(FOnStep) then
  begin
    Synchronize(FOnStep);
  end;
end;

procedure TD16Emulator.SetAlertPoint(AAddress: Word; AEnabled: Boolean);
var
  LAlert: TAlertPointModification;
begin
  FAlertAccessLock.Enter();
  try
    LAlert.Address := AAddress;
    LAlert.Enabled := AEnabled;
    FAlertChangeQueue.Enqueue(LAlert);
  finally
    FAlertAccessLock.Leave;
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

  if LOpCode = $1 shl 5 then//opcode = JSR
  begin
    DoOnCall();
  end
  else
  begin
    if (LOpCode = $1) and (LLeft = $1c) and (LRight = $18) then
    begin
      //triggered by set pc, pop
      DoOnReturn();
    end;
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
    ProcessMessages();//this call can trigger pausing the emulator
    UpdateAlertPoints();
    CheckAlertPoints(); // this call can trigger pausing the emulation, too
    if FState = esRunning then
    begin
      try
        Step();
      except
        on E: Exception do
        begin
          FState := esStopped;
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
    FLog.SaveToFile('RunLog.txt');
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

  if (AOperand >= $10) and (AOperand <= $17) then //[register + next word]
  begin
    Result := (FRegisters[AOperand-$10] + FRam[FRegisters[CRegPC]]) mod $10000;
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;

  if (AOperand  = $18) or (AOperand = $19) then //[sp], push/pop behaviour handled before this function call by read/write method
  begin
    Result := FRegisters[CRegSP];
  end;

  if AOperand = $1a then //[SP + next word]
  begin
    Result := (FRegisters[CRegSP] + FRam[FRegisters[CRegPC]]) mod $10000;
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;

  if AOperand = $1b then //SP
  begin
    Result := -CRegSP -1;
  end;

  if AOperand = $1c then //PC
  begin
    Result := -CRegPC-1;
  end;

  if AOperand = $1d then //EX
  begin
    Result := -CRegEX-1;
  end;

  if AOperand = $1e then //[Next Word]
  begin
    Result := FRam[FRegisters[CRegPC]];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;

  if AOperand = $1f then //next word (literal)
  begin
    Result := FRegisters[CRegPC];
    if not FOperations.Skipping then
    begin
      AddCycles(1);
    end;
  end;

  if (AOperand >= $20) and (AOperand <= $3f)then //literal value -1 to 30
  begin
    Result := -AOperand-1;
  end;
end;

procedure TD16Emulator.HandleMessages(AMSG: TMsg);
begin
  case AMSG.message of
    WM_PAUSE:
    begin
      InternalPause();
    end;

    WM_STOP:
    begin
      FState := esStopped;
      Self.Terminate();
    end;
  end;
end;

procedure TD16Emulator.Init;
begin
  FAlertChangeQueue := TQueue<TAlertPointModification>.Create();
  FAlertAccessLock := TCriticalSection.Create();
  FCallStack := TStack<Word>.Create();
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
  RegisterDevice(TFloppy.Create(@FRegisters, @FRam));
end;

procedure TD16Emulator.InternalOnAlert;
var
  LPause: Boolean;
begin
  //this emthod is already executed synchronized!
  LPause := False;
  FOnAlert(LPause);
  if LPause then
  begin
    InternalPause();
  end;
end;

procedure TD16Emulator.InternalPause;
begin
  FState := esPaused;
  DoOnPause();
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
  if FState = esStopped then
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

procedure TD16Emulator.Pause;
begin
  PostThreadMessage(Self.ThreadID, WM_PAUSE, 0, 0);
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

procedure TD16Emulator.ProcessMessages;
var
  LMSG: TMsg;
begin
  if PeekMessage(LMSG, 0,  0, 0, PM_REMOVE) then
  begin
    TranslateMessage(LMSG);
    DispatchMessage(LMSG);
    HandleMessages(LMSG);
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
  if FState = esStopped then
  begin
    ResetRegisters();
    ResetRam();
    ResetAlertPoints();
    FRefreshCycles := 0;
    FCycles := 0;
    FLastSleep := Now();
    FLastUpdate := Now();
    FLog.Clear;
    DoOnStep();
  end;
end;

procedure TD16Emulator.ResetAlertPoints;
var
  i: Integer;
begin
  for i := Low(FAlertPoints) to High(FAlertPoints) do
  begin
    FAlertPoints[i] := False;
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
  if not (FState = esRunning) then
  begin
    if FState = esStopped then //otherwhise we resume from paused state, no resetting required
    begin
      ResetRegisters();
      FLastAlertAddress := -1;
    end;
    FLastSleep := Now();
    DoOnRun();
    FState := esRunning;
  end;
end;

procedure TD16Emulator.Stop;
begin
  PostThreadMessage(Self.ThreadID, WM_STOP, 0, 0);
end;

procedure TD16Emulator.UpdateAlertPoints;
var
  LAlert: TAlertPointModification;
begin
  if not (FState = esRunning) then Exit;

  FAlertAccessLock.Enter();
  try
    while FAlertChangeQueue.Count > 0 do
    begin
      LAlert := FAlertChangeQueue.Dequeue();
      FAlertPoints[LAlert.Address] := LAlert.Enabled;
    end;
  finally
    FAlertAccessLock.Leave;
  end;
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
