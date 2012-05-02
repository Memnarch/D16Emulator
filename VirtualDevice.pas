unit VirtualDevice;

interface

uses
  Classes, Types, EmuTypes;

type
  TVirtualDevice = class
  protected
    FRegisters: PD16RegisterMem;
    FHardwareID: Cardinal;
    FManufactorID: Cardinal;
    FHardwareVerion: Word;
    FRam: PD16Ram;
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    procedure Interrupt(); virtual; abstract;
    property HardwareID: Cardinal read FHardwareID;
    property HardwareVersion: Word read FHardwareVerion;
    property ManufactorID: Cardinal read FManufactorID;
  end;

implementation

{ TVirtualDevice }

constructor TVirtualDevice.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  FRegisters := ARegisters;
  FRam := ARam;
end;

end.
