unit Floppy;

interface

uses
  Classes, Types, EmuTypes, VirtualDevice, ExtCtrls;

type

  TFloppy = class(TVirtualDevice)
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
  end;

implementation

{ TFloppy }

constructor TFloppy.Create;
begin
  inherited;
  FHardwareID := $74fa4cae;
  FHardwareVerion := $07c2;
  FManufactorID := $21544948;
end;

end.
