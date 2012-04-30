unit Operations;

interface

uses
  Classes, Types, Generics.Collections;

type
  TOperation = procedure(var ALeft, ARight: Word) of object;

  TOperationItem = class
  private
    FOperation: TOperation;
    FOpCode: Byte;
    FCost: Byte;
  public
    constructor Create(ACode, ACost: Byte; AOp: TOperation); reintroduce;
    property Operation: TOperation read FOperation;
    property OpCode: Byte read FOpCode;
    property Cost: Byte read FCost;
  end;

  TOperations = class
  private
    FOperations: TObjectList<TOperationItem>;
  public
    constructor Create();
    destructor Destroy(); override;
    procedure RegisterOperation(AOpCode, ACost: Byte; AOperation: TOperation);
    function GetOperation(AOpCode: Byte): TOperationItem;
    property Operations: TObjectList<TOperationItem> read FOperations;
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
end;

destructor TOperations.Destroy;
begin
  FOperations.Free;
  inherited;
end;

function TOperations.GetOperation(AOpCode: Byte): TOperationItem;
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

procedure TOperations.RegisterOperation(AOpCode, ACost: Byte; AOperation: TOperation);
begin
  FOperations.Add(TOperationItem.Create(AOpCode, ACost, AOperation));
end;

end.
