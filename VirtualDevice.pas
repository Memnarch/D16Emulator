unit VirtualDevice;

interface

uses
  Classes, Types, EmuTypes;//, SiAuto, SmartInspect;

type
  TVirtualDevice = class
  private
    FSoftwareInterrupt: TInterruptEvent;
  protected
    FRegisters: PD16RegisterMem;
    FHardwareID: Cardinal;
    FManufactorID: Cardinal;
    FHardwareVerion: Word;
    FRam: PD16Ram;
    FNeedsUpdate: Boolean;
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    procedure Interrupt(); virtual; abstract;
    procedure UpdateDevice(); virtual;
    property HardwareID: Cardinal read FHardwareID;
    property HardwareVersion: Word read FHardwareVerion;
    property ManufactorID: Cardinal read FManufactorID;
    property NeedsUpdate: Boolean read FNeedsUpdate;
    property SoftwareInterrupt: TInterruptEvent read FSoftwareInterrupt write FSoftwareInterrupt;
  end;

implementation

{ TVirtualDevice }


constructor TVirtualDevice.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  FRegisters := ARegisters;
  FRam := ARam;
  FNeedsUpdate := False;
end;

procedure TVirtualDevice.UpdateDevice;
begin

end;

end.
