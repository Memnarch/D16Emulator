unit EmuTypes;

interface

type
  TD16Ram = array[0..$FFFF] of Word;
  PD16Ram = ^TD16Ram;
  TD16RegisterMem = array[0..11] of Word;
  PD16RegisterMem = ^TD16RegisterMem;

  TD16AlertPoints = array[0..$FFFF] of Boolean;

  TAlertPointModification = record
    Address: Word;
    Enabled: Boolean;
  end;

  TEvent = procedure() of object;
  TMessageEvent = procedure(AMessage: string) of object;
  TInterruptEvent = procedure(AMessage: Word) of object;
  TAlertEvent = procedure(var APauseExecution: Boolean) of object;

const
  CRegA = 0;
  CRegB = 1;
  CRegC = 2;
  CRegX = 3;
  CRegY = 4;
  CRegZ = 5;
  CRegI = 6;
  CRegJ = 7;
  CRegPC = 8;
  CRegSP = 9;
  CRegEX = 10;
  CRegIA = 11;

implementation

end.
