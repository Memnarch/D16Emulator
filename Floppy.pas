unit Floppy;

interface

uses
  Classes, Types, EmuTypes, VirtualDevice, ExtCtrls;

const
  STATE_NO_MEDIA = 0;//   There's no floppy in the drive.
  STATE_READY = 1;//     The drive is ready to accept commands.
  STATE_READY_WP = 2;//  Same as ready, except the floppy is write protected.
  STATE_BUSY = 3;//      The drive is busy either reading or writing a sector.

  ERROR_NONE = 0;//       There's been no error since the last poll.
  ERROR_BUSY = 1;//       Drive is busy performing an action
  ERROR_NO_MEDIA = 2;//   Attempted to read or write with no floppy inserted.
  ERROR_PROTECTED = 3;//  Attempted to write to write protected floppy.
  ERROR_EJECT = 4;//      The floppy was removed while reading or writing.
  ERROR_BAD_SECTOR = 5;// The requested sector is broken, the data on it is lost.
  ERROR_BROKEN = $ffff;//There's been some major software or hardware problem,
                        //try turning off and turning on the device again.

type
  TFloppySector = array[0..511] of Word;
  TFloppyTrack = array[0..17] of TFloppySector;
  TFloppyTask = (ftNone, ftRead, ftWrite);

  TFloppy = class(TVirtualDevice)
  private
    FOldState: Byte;
    FState: Byte;
    FError: Byte;
    FMemory: array[0..79] of TFloppyTrack;
    FInterruptMessage: Word;
    FTask: TFloppyTask;
    FRamAddress: Word;
    FSector: Word;
    FTrack: Word;
    FSeekTime: Word;
    FWordsProcessed: Word;
    procedure SetError(const Value: Byte);
    procedure SetState(const Value: Byte);
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    procedure Interrupt(); override;
    procedure UpdateDevice(); override;
    property State: Byte read FState write SetState;
    property Error: Byte read FError write SetError;
  end;

implementation

const
  CTrackSeekTime = 2.4;

{ TFloppy }

constructor TFloppy.Create;
begin
  inherited;
  FHardwareID := $4fd524c5;
  FHardwareVerion := $000b;;
  FManufactorID := $1eb37e91;
  FNeedsUpdate := True;
  FState := STATE_NO_MEDIA;
  FError := ERROR_NONE;
  FInterruptMessage := 0;
end;

procedure TFloppy.Interrupt;
begin
  inherited;
  case FRegisters[CRegA] of
    0:
    begin
      FRegisters[CRegB] := FState; //no media
      FRegisters[CRegC] := FError;//error_no_media
    end;
    1:
    begin
      FInterruptMessage := FRegisters[CRegX];
    end;
    2:
    begin
      if (FState = STATE_READY) or (FState = STATE_READY_WP) then
      begin
        FTrack := FRegisters[CRegX] div 18;
        FSector := FRegisters[CRegX] mod 18;
        FRamAddress := FRegisters[CRegY];
        if (FTrack < 80) and (FSector < 18) then
        begin
          FRegisters[CRegB] := 1;
          FWordsProcessed := 0;
          FTask := ftRead;
          FSeekTime := Round(FTrack*CTrackSeekTime);
          FOldState := State;
          State := STATE_BUSY;
        end
        else
        begin
          Error := ERROR_BAD_SECTOR;
        end;
      end
      else
      begin
        case State of
          STATE_NO_MEDIA: Error := ERROR_NO_MEDIA;
          STATE_BUSY: Error := ERROR_BUSY;
        end;
      end;
    end;
    3:
    begin
      if (FState = STATE_READY) then
      begin
        FTrack := FRegisters[CRegX] div 18;
        FSector := FRegisters[CRegX] mod 18;
        FRamAddress := FRegisters[CRegY];
        if (FTrack < 80) and (FSector < 18) then
        begin
          FRegisters[CRegB] := 1;
          FWordsProcessed := 0;
          FTask := ftWrite;
          FSeekTime := Round(FTrack*CTrackSeekTime);
          FOldState := State;
          State := STATE_BUSY;
        end
        else
        begin
          Error := ERROR_BAD_SECTOR;
        end;
      end
      else
      begin
        case State of
          STATE_NO_MEDIA: Error := ERROR_NO_MEDIA;
          STATE_BUSY: Error := ERROR_BUSY;
          STATE_READY_WP: Error := ERROR_PROTECTED;
        end;
      end;
    end;
  end;
end;

procedure TFloppy.SetError(const Value: Byte);
begin
  FError := Value;
  if FInterruptMessage <> 0 then
  begin
    SoftwareInterrupt(FInterruptMessage);
  end;
end;

procedure TFloppy.SetState(const Value: Byte);
begin
  FState := Value;
  if FInterruptMessage <> 0 then
  begin
    SoftwareInterrupt(FInterruptMessage);
  end;
end;

procedure TFloppy.UpdateDevice;
var
  i: Integer;
begin
  if FTask <> ftNone then
  begin
    if FSeekTime >= 10 then
    begin
      Dec(FSeekTime, 10);
    end
    else
    begin
      FSeekTime := 0;
      for i := 0 to 255 do //only 256 words per update
      begin
        case FTask of
          ftRead:
          begin
            FRam[(FRamAddress + i + FWordsProcessed) mod $10000] := FMemory[FTrack][FSector][i + FWordsProcessed];
          end;
          ftWrite:
          begin
            FMemory[FTrack][FSector][i + FWordsProcessed] := FRam[(FRamAddress + i + FWordsProcessed) mod $10000];
          end;
        end;
      end;
      Inc(FWordsProcessed, 256);
      if FWordsProcessed = 512 then
      begin
        FTask := ftNone;
        if State = STATE_BUSY then
        begin
          State := FOldState;
        end;
      end;
    end;
  end;
end;

end.
