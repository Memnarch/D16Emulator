unit D16Operations;

interface

uses
  Operations;

type
  TD16Operation = class(TOperations)
  private
    procedure SetValue(var ALeft, ARight: Word);
    procedure Init();
  public
    constructor Create();
  end;

implementation

{ TD16Operation }

constructor TD16Operation.Create;
begin
  inherited;
  Init();
end;

procedure TD16Operation.Init;
begin
  RegisterOperation($1, 1, SetValue);
end;

procedure TD16Operation.SetValue(var ALeft, ARight: Word);
begin
  ALeft := ARight;
end;

end.
