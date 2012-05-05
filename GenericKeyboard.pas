unit GenericKeyboard;

interface

uses
  Classes, Types, EmuTypes, VirtualDevice;

type
  TGenericKeyboard = class(TVirtualDevice)
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    procedure Interrupt(); override;
  end;

implementation

{ TGenericKeyboard }

constructor TGenericKeyboard.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  inherited;
  FHardwareID := $30cf7406;
  FHardwareVerion := $1;
  FManufactorID := 0;
end;

procedure TGenericKeyboard.Interrupt;
begin
  inherited;
  case FRegisters[CRegA] of
    0:
    begin

    end;
    1:
    begin
      FRegisters[CRegC] := 0;
    end;
    2:
    begin
      FRegisters[CRegC] := 0;
    end;
    3:
    begin

    end;
  end;
end;

end.
