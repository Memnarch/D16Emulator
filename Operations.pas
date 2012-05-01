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
  public
    constructor Create(ACode, ACost: Byte; AOp: TOperation); reintroduce;
    property Operation: TOperation read FOperation;
    property OpCode: Word read FOpCode;
    property Cost: Byte read FCost;
  end;

  TOperations = class
  private
    FOperations: TObjectList<TOperationItem>;
    FSkipping: Boolean;
    FRegisters: PD16RegisterMem;
    FDevices: TObjectList<TVirtualDevice>;
    FPush: TCPUAction;
    FPop: TCPUAction;
  public
    constructor Create(ARegisters: PD16RegisterMem; ADevices: TObjectList<TVirtualDevice>);
    destructor Destroy(); override;
    procedure RegisterOperation(AOpCode: word; ACost: Byte; AOperation: TOperation);
    function GetOperation(AOpCode: Word): TOperationItem;
    function IsBranchCode(ACode: Word): Boolean; virtual;
    property Operations: TObjectList<TOperationItem> read FOperations;
    property Skipping: Boolean read FSkipping write FSkipping;
    property Registers: PD16RegisterMem read FRegisters write FRegisters;
    property Devices: TObjectList<TVirtualDevice> read FDevices;
    property Push: TCPUAction read FPush write FPush;
    property Pop: TCPUAction read FPop write FPop;
  end;

implementation

{ TOperationItem }

constructor TOperationItem.Create(ACode, ACost: Byte; AOp: TOperation);
begin
  inherited Create();
  FOpCode := ACode;
  FOperation := AOp;
  FCost := ACost;
end;

{ TOperations }

constructor TOperations.Create;
begin
  FOperations := TObjectList<TOperationItem>.Create();
  FSkipping := False;
  FRegisters := ARegisters;
  FDevices := ADevices;
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

procedure TOperations.RegisterOperation(AOpCode: Word; ACost: Byte; AOperation: TOperation);
begin
  FOperations.Add(TOperationItem.Create(AOpCode, ACost, AOperation));
end;

end.
