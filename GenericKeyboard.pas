unit GenericKeyboard;

interface

uses
  Classes, Types, Windows, SysUtils, EmuTypes, VirtualDevice, Generics.Collections, SiAuto;

type
  TGenericKeyboard = class(TVirtualDevice)
  private
    FKeyBuffer: TList;
    FInterruptAddress: Word;
    FKeyStates: TKeyboardState;
    FOldKeyStates: TKeyboardState;
    function IsKeyDown(ACode: Word): Word;
  public
    constructor Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
    destructor Destroy(); override;
    procedure Interrupt(); override;
    procedure UpdateDevice(); override;
  end;

implementation

{ TGenericKeyboard }

constructor TGenericKeyboard.Create(ARegisters: PD16RegisterMem; ARam: PD16Ram);
begin
  inherited;
  FHardwareID := $30cf7406;
  FHardwareVerion := $1;
  FManufactorID := 0;
  FNeedsUpdate := True;
  FKeyBuffer := TList.Create();
end;

destructor TGenericKeyboard.Destroy;
begin
  FKeyBuffer.Free;
  inherited;
end;

procedure TGenericKeyboard.Interrupt;
begin
  inherited;
  case FRegisters[CRegA] of
    0:   //clear keybuffer
    begin
      FKeyBuffer.Clear();
    end;
    1:      //get the first key in the buffer or 0 if no key is inside
    begin
      if FKeyBuffer.Count > 0 then
      begin
        FRegisters[CRegC] := Word(FKeyBuffer.Items[0]);
        FKeyBuffer.Delete(0);
      end
      else
      begin
        FRegisters[CRegC] := 0;
      end;
    end;
    2:
    begin
      FRegisters[CRegC] := IsKeyDown(FRegisters[CRegB]);
    end;
    3:
    begin
      FInterruptAddress := FRegisters[CRegB];
    end;
  end;
end;

function TGenericKeyboard.IsKeyDown(ACode: Word): Word;
begin
  Result := 0;
  if (ACode >= $20) and (ACode <= $7F) then
  begin
    if FKeyStates[Byte(ACode)] > 1 then
    begin
      Result := 1;
    end;
  end
  else
  begin
    case ACode of
      $11:
      begin
        if FKeyStates[VK_RETURN] > 1 then
        begin
          Result := 1;
        end;
      end;
    end;
  end;
end;

procedure TGenericKeyboard.UpdateDevice;
var
  i: Integer;
begin
  inherited;
  FOldKeyStates := FKeyStates;
  GetKeyState(0);//triger windows internal keyboardstate update
  if GetKeyboardState(FKeyStates) then
  begin
    for i := $20 to $7F do
    begin
      if (FKeyStates[i] <> FOldKeyStates[i]) and (FKeyStates[i] > 1) then
      begin
        FKeyBuffer.Add(Pointer(i));
        SiMain.LogMessage('Added ' + IntToHex(i, 4));
      end;
    end;
  end;
end;

end.
