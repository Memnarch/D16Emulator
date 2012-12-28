unit GenericKeyboard;

interface

uses
  Classes, Types, Windows, SysUtils, EmuTypes, VirtualDevice, Generics.Collections, SiAuto;

type
  TDynByteArray = array of Byte;

  TGenericKeyboard = class(TVirtualDevice)
  private
    FKeyBuffer: TList;
    FKeyList: TDynByteArray;
    FInterruptAddress: Word;
    FKeyStates: TKeyboardState;
    FOldKeyStates: TKeyboardState;
    function IsVKPressed(AVK: Byte): Boolean;
    function IsKeyDown(ACode: Word): Word;
    procedure InitKeys();
    function ListToArray(AList: array of Byte): TDynByteArray;
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
  InitKeys();
end;

destructor TGenericKeyboard.Destroy;
begin
  FKeyBuffer.Free;
  inherited;
end;

procedure TGenericKeyboard.InitKeys;
begin
  FKeyList := ListToArray([$31, $32, $33, $34, $35, $36, $37, $38, $39, $30, $DB, $51, $57, $45, $52, $54, $5A, $55, $49, $4F,
    $50, $BA, $BB, $41, $53, $44, $46, $47, $48, $4A, $4B, $4C, $C0, $DE, $BF, $E2, $59, $58, $43, $56, $42,
    $4E, $4D, $BC, $BE, $BD, $20]);
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
      $10:
      begin
        if FKeyStates[VK_BACK] > 1 then
        begin
          Result := 1;
        end;
      end;
      $11:
      begin
        if FKeyStates[VK_RETURN] > 1 then
        begin
          Result := 1;
        end;
      end;
      $12:
      begin
        if FKeyStates[VK_INSERT] > 1 then
        begin
          Result := 1;
        end;
      end;

      $13:
      begin
        if FKeyStates[VK_DELETE] > 1 then
        begin
          Result := 1;
        end;
      end;
      $80:
      begin
        if FKeyStates[VK_UP] > 1 then
        begin
          Result := 1;
        end;
      end;
      $81:
      begin
        if FKeyStates[VK_DOWN] > 1 then
        begin
          Result := 1;
        end;
      end;
      $82:
      begin
        if FKeyStates[VK_LEFT] > 1 then
        begin
          Result := 1;
        end;
      end;
      $83:
      begin
        if FKeyStates[VK_RIGHT] > 1 then
        begin
          Result := 1;
        end;
      end;
      $90:
      begin
        if FKeyStates[VK_SHIFT] > 1 then
        begin
          Result := 1;
        end;
      end;
      $91:
      begin
        if FKeyStates[VK_CONTROL] > 1 then
        begin
          Result := 1;
        end;
      end;
    end;
  end;
end;

function TGenericKeyboard.IsVKPressed(AVK: Byte): Boolean;
begin
  Result := (FKeyStates[AVK] <> FOldKeyStates[AVK]) and (FKeyStates[AVK] > 1)
end;

function TGenericKeyboard.ListToArray(AList: array of Byte): TDynByteArray;
var
  i: Integer;
begin
  SetLength(Result, Length(AList));
  for i := 0 to High(AList) do
  begin
    Result[i] := AList[i];
  end;
end;

procedure TGenericKeyboard.UpdateDevice;
var
  i: Integer;
  LChars: string;
begin
  inherited;
  FOldKeyStates := FKeyStates;
  GetKeyState(0);//triger windows internal keyboardstate update
  LChars := '  ';
  if GetKeyboardState(FKeyStates) then
  begin
    for i := 0 to High(FKeyList) do //$30 to $DD do //$20 to $7F do
    begin
      if (FKeyStates[FKeyList[i]] <> FOldKeyStates[FKeyList[i]]) and (FKeyStates[FKeyList[i]] > 1) then
      begin
//        SiMain.LogString('VK', IntToHex(FKeyList[i], 4));
        if (ToAscii(FKeyList[i], MapVirtualKey(FKeyList[i], 0), FKeyStates, @LChars[1], 0) = 1)
          and (Byte(AnsiChar(LChars[1])) >= $20) and (Byte(AnsiChar(LChars[1])) <= $7F) then
        begin
          FKeyBuffer.Add(Pointer(AnsiChar(LChars[1])));
        end;
      end;
    end;
    if IsVKPressed(VK_BACK) then
    begin
      FKeyBuffer.Add(Pointer($10));
    end;

    if IsVKPressed(VK_RETURN) then
    begin
      FKeyBuffer.Add(Pointer($11));
    end;

    if IsVKPressed(VK_INSERT) then
    begin
      FKeyBuffer.Add(Pointer($12));
    end;

    if IsVKPressed(VK_DELETE) then
    begin
      FKeyBuffer.Add(Pointer($13));
    end;

    if IsVKPressed(VK_UP) then
    begin
      FKeyBuffer.Add(Pointer($80));
    end;

    if IsVKPressed(VK_DOWN) then
    begin
      FKeyBuffer.Add(Pointer($81));
    end;

    if IsVKPressed(VK_LEFT) then
    begin
      FKeyBuffer.Add(Pointer($82));
    end;

    if IsVKPressed(VK_RIGHT) then
    begin
      FKeyBuffer.Add(Pointer($83));
    end;

    if IsVKPressed(VK_SHIFT) then
    begin
      FKeyBuffer.Add(Pointer($90));
    end;

    if IsVKPressed(VK_CONTROL) then
    begin
      FKeyBuffer.Add(Pointer($91));
    end;
  end;
end;

end.
