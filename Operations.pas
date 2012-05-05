unit Operations;

interface

uses
  Classes, Types, Generics.Collections, EmuTypes, VirtualDevice;

type
  TOperation = procedure(var ALeft, ARight: Word) of object;
  TCPUAction = procedure(var AVal: Word) of object;

  TOperationItem = class
  private
    FOperation: TOperation;
    FOpCode: Word;
    FCost: Byte;
    FReadOnly: Boolean;
  public
    constructor Create(ACode: Word; ACost: Byte; AOp: TOperation; AReadOnly: Boolean); reintroduce;
    property Operation: TOperation read FOperation;
    property OpCode: Word read FOpCode;
    property Cost: Byte read FCost;
    property ReadOnly: Boolean read FReadOnly;
  end;

  TOperations = class
  private
    FOperations: TObjectList<TOperationItem>;
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
    procedure RegisterOperation(AOpCode: word; ACost: Byte; AOperation: TOperation; AReadOnly: Boolean = False);
    function GetOperation(AOpCode: Word): TOperationItem;
    function IsBranchCode(ACode: Word): Boolean; virtual;
    property Operations: TObjectList<TOperationItem> read FOperations;
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

constructor TOperationItem.Create(ACode: Word; ACost: Byte; AOp: TOperation; AReadOnly: Boolean);
begin
  inherited Create();
  FOpCode := ACode;
  FOperation := AOp;
  FCost := ACost;
  FReadOnly := AReadOnly;
end;

{ TOperations }

constructor TOperations.Create;
begin
  FOperations := TObjectList<TOperationItem>.Create();
  FSkipping := False;
  FRegisters := ARegisters;
  FDevices := ADevices;
  FUseInterruptQuery := True;
end;

destructor TOperations.Destroy;
begin
  FOperations.Free;
  inherited;
end;

function TOperations.GetOperation(AOpCode: Word): TOperationItem;
var
  LItem: TOperationItem;
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

function TOperations.IsBranchCode(ACode: Word): Boolean;
begin
  Result := False;
end;

procedure TOperations.RegisterOperation(AOpCode: Word; ACost: Byte; AOperation: TOperation; AReadOnly: Boolean = False);
begin
  FOperations.Add(TOperationItem.Create(AOpCode, ACost, AOperation, AReadOnly));
end;

end.
