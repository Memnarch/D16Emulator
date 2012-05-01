unit VirtualDevice;

interface

uses
  Classes, Types, EmuTypes;

type
  TVirtualDevice = class
  private
    FRegisters: PD16RegisterMem;
  protected
    FHardwareID: Cardinal;
    FManufactorID: Cardinal;
    FHardwareVerion: Word;
  public
    constructor Create(ARegisters: PD16RegisterMem);
    procedure Interrupt(); virtual; abstract;
    property Registers: PD16RegisterMem read FRegisters;
    property HardwareID: Cardinal read FHardwareID;
    property HardwareVersion: Word read FHardwareVerion;
    property ManufactorID: Cardinal read FManufactorID;
  end;

implementation

{ TVirtualDevice }

constructor TVirtualDevice.Create(ARegisters: PD16RegisterMem);
begin
  FRegisters := ARegisters;
end;

end.
