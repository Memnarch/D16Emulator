object Form1: TForm1
  Left = 0
  Top = 0
  Caption = 'Form1'
  ClientHeight = 366
  ClientWidth = 786
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  OnCreate = FormCreate
  PixelsPerInch = 96
  TextHeight = 13
  object VEdit: TValueListEditor
    Left = 0
    Top = 0
    Width = 297
    Height = 366
    Align = alLeft
    Strings.Strings = (
      'A=0'
      'B='
      'C='
      'X='
      'Y='
      'Z='
      'I='
      'J='
      'PC='
      'SP='
      'EX='
      'IA=')
    TabOrder = 0
    TitleCaptions.Strings = (
      'Register'
      'Value')
    ColWidths = (
      150
      141)
  end
  object Button1: TButton
    Left = 303
    Top = 8
    Width = 75
    Height = 25
    Caption = 'Step'
    TabOrder = 1
    OnClick = Button1Click
  end
  object Code: TSynEdit
    Left = 512
    Top = 0
    Width = 274
    Height = 366
    Align = alRight
    Font.Charset = DEFAULT_CHARSET
    Font.Color = clWindowText
    Font.Height = -13
    Font.Name = 'Courier New'
    Font.Style = []
    TabOrder = 2
    Gutter.Font.Charset = DEFAULT_CHARSET
    Gutter.Font.Color = clWindowText
    Gutter.Font.Height = -11
    Gutter.Font.Name = 'Courier New'
    Gutter.Font.Style = []
    Highlighter = SynAsmSyn1
    Lines.Strings = (
      'set [0xFF], 0x43'
      'set c, 0xFE'
      'set push, [c+1]'
      'set push, 0'
      'set b, [sp+1]'
      'set a,[b]')
  end
  object Button2: TButton
    Left = 303
    Top = 39
    Width = 75
    Height = 25
    Caption = 'Reset'
    TabOrder = 3
    OnClick = Button2Click
  end
  object Button3: TButton
    Left = 303
    Top = 70
    Width = 75
    Height = 25
    Caption = 'Assmble&&Load'
    TabOrder = 4
    OnClick = Button3Click
  end
  object SynAsmSyn1: TSynAsmSyn
    Left = 384
    Top = 192
  end
end
