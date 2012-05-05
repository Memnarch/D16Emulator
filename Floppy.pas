unit Floppy;

interface

uses
  Classes, Types, EmuTypes, VirtualDevice, ExtCtrls;

type

  TFloppy = class(TVirtualDevice)
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    procedure Interrupt(); override;
  end;

implementation

{ TFloppy }

constructor TFloppy.Create;
begin
  inherited;
  FHardwareID := 0;//$74fa4cae;
  FHardwareVerion := 0;//$07c2;
  FManufactorID := 0;//$21544948;
end;

procedure TFloppy.Interrupt;
begin
  inherited;
  case FRegisters[CRegA] of
    0:
    begin
      FRegisters[CRegB] := 0; //no media
    end;
    1:
    begin

    end;
  end;
  FRegisters[CRegA] := 1;//error_no_media
end;

end.
