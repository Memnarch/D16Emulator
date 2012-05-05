unit CPUOperations;

interface

uses
  Classes, Types, Generics.Collections, EmuTypes, VirtualDevice;

type
  TCPUOperation = procedure(var ALeft, ARight: Word) of object;
  TCPUAction = procedure(var AVal: Word) of object;

  TCPUOperationItem = class
  private
    FOperation: TCPUOperation;
    FOpCode: Word;
    FCost: Byte;
    FReadOnly: Boolean;
  public
    constructor Create(ACode: Word; ACost: Byte; AOp: TCPUOperation; AReadOnly: Boolean); reintroduce;
    property Operation: TCPUOperation read FOperation;
    property OpCode: Word read FOpCode;
    property Cost: Byte read FCost;
    property ReadOnly: Boolean read FReadOnly;
  end;

  TCPUOperations = class
  private
    FOperations: TObjectList<TCPUOperationItem>;
    FSkipping: Boolean;
    FRegisters: PD16RegisterMem;
    FDevices: TObjectList<TVirtualDevice>;
    FPush: TCPUAction;
    FPop: TCPUAction;
    FUseInterruptQuery: Boolean;
    FSoftwareInterrupt: TInterruptEvent;
  public
    constructor Create(ARegisters: PD16RegisterMem; ADevices: TObjectList<TVirtualDevice>);
    destructor Destroy(); override;
    procedure RegisterOperation(AOpCode: word; ACost: Byte; AOperation: TCPUOperation; AReadOnly: Boolean = False);
    function GetOperation(AOpCode: Word): TCPUOperationItem;
    function IsBranchCode(ACode: Word): Boolean; virtual;
    property Operations: TObjectList<TCPUOperationItem> read FOperations;
    property Skipping: Boolean read FSkipping write FSkipping;
    property Registers: PD16RegisterMem read FRegisters write FRegisters;
    property Devices: TObjectList<TVirtualDevice> read FDevices;
    property Push: TCPUAction read FPush write FPush;
    property Pop: TCPUAction read FPop write FPop;
    property UseInterruptQuery: Boolean read FUseInterruptQuery write FUseInterruptQuery;
    property SoftwareInterrupt: TInterruptEvent read FSoftwareInterrupt write FSoftwareInterrupt;
  end;

implementation

{ TOperationItem }

constructor TCPUOperationItem.Create(ACode: Word; ACost: Byte; AOp: TCPUOperation; AReadOnly: Boolean);
begin
  inherited Create();
  FOpCode := ACode;
  FOperation := AOp;
  FCost := ACost;
  FReadOnly := AReadOnly;
end;

{ TOperations }

constructor TCPUOperations.Create;
begin
  FOperations := TObjectList<TCPUOperationItem>.Create();
  FSkipping := False;
  FRegisters := ARegisters;
  FDevices := ADevices;
  FUseInterruptQuery := True;
end;

destructor TCPUOperations.Destroy;
begin
  FOperations.Free;
  inherited;
end;

function TCPUOperations.GetOperation(AOpCode: Word): TCPUOperationItem;
var
  LItem: TCPUOperationItem;
begin
  Result := nil;
  for LItem in FOperations do
  begin
    if LItem.OpCode = AOpCode then
    begin
      Result := LItem;
      Break;
    end;
  end;
end;

function TCPUOperations.IsBranchCode(ACode: Word): Boolean;
begin
  Result := False;
end;

procedure TCPUOperations.RegisterOperation(AOpCode: Word; ACost: Byte; AOperation: TCPUOperation; AReadOnly: Boolean = False);
begin
  FOperations.Add(TCPUOperationItem.Create(AOpCode, ACost, AOperation, AReadOnly));
end;

end.
