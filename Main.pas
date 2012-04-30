unit Main;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, Grids, ValEdit, Emulator, StdCtrls, SynEdit, SynEditHighlighter,
  SynHighlighterAsm;

type
  TForm1 = class(TForm)
    VEdit: TValueListEditor;
    Button1: TButton;
    Code: TSynEdit;
    Button2: TButton;
    Button3: TButton;
    SynAsmSyn1: TSynAsmSyn;
    procedure FormCreate(Sender: TObject);
    procedure Button1Click(Sender: TObject);
    procedure Button2Click(Sender: TObject);
    procedure Button3Click(Sender: TObject);
  private
    { Private declarations }
    FEmu: TD16Emulator;
    procedure UpdateRegs();
  public
    { Public declarations }
  end;

var
  Form1: TForm1;

implementation

uses
  D16Assembler;

{$R *.dfm}

procedure TForm1.Button1Click(Sender: TObject);
begin
  FEmu.Step();
end;

procedure TForm1.Button2Click(Sender: TObject);
begin
  FEmu.Reset();
end;

procedure TForm1.Button3Click(Sender: TObject);
var
  LAssembler: TD16Assembler;
begin
  LAssembler := TD16Assembler.Create();
  try
    try
      LAssembler.UseBigEdian := True;
      LAssembler.AssembleSource(Code.Lines.Text);
      LAssembler.SaveTo('test.d16');
      FEmu.LoadFromFile('test.d16', True);
    except
      on E: Exception do
      ShowMessage(E.Message);
    end;
  finally
    LAssembler.Free;
  end;
end;

procedure TForm1.FormCreate(Sender: TObject);
begin
  FEmu := TD16Emulator.Create();
  FEmu.OnStep := UpdateRegs;
end;

procedure TForm1.UpdateRegs;
begin
  VEdit.Values['A'] := IntToHex(FEmu.Registers[CRegA], 4);
  VEdit.Values['B'] := IntToHex(FEmu.Registers[CRegB], 4);
  VEdit.Values['C'] := IntToHex(FEmu.Registers[CRegC], 4);
  VEdit.Values['X'] := IntToHex(FEmu.Registers[CRegX], 4);
  VEdit.Values['Y'] := IntToHex(FEmu.Registers[CRegY], 4);
  VEdit.Values['Z'] := IntToHex(FEmu.Registers[CRegZ], 4);
  VEdit.Values['I'] := IntToHex(FEmu.Registers[CRegI], 4);
  VEdit.Values['J'] := IntToHex(FEmu.Registers[CRegJ], 4);
  VEdit.Values['PC'] := IntToHex(FEmu.Registers[CRegPC], 4);
  VEdit.Values['SP'] := IntToHex(FEmu.Registers[CRegSP], 4);
  VEdit.Values['EX'] := IntToHex(FEmu.Registers[CRegEX], 4);
  VEdit.Values['IA'] := IntToHex(FEmu.Registers[CRegIA], 4);
end;

end.
