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
      'IA='
      'Cycles=')
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
      'set b, 5'
      'jsr subrut'
      'set a, b'
      ''
      ':subrut'
      'set a, 3'
      'set pc, pop')
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
  object ed1: TEdit
    Left = 320
    Top = 280
    Width = 121
    Height = 21
    TabOrder = 5
  end
  object ed2: TEdit
    Left = 320
    Top = 307
    Width = 121
    Height = 21
    TabOrder = 6
  end
  object btnDezToHex: TButton
    Left = 320
    Top = 240
    Width = 75
    Height = 25
    Caption = 'btnDezToHex'
    TabOrder = 7
    OnClick = btnDezToHexClick
  end
  object Button4: TButton
    Left = 303
    Top = 101
    Width = 75
    Height = 25
    Caption = 'Run'
    TabOrder = 8
    OnClick = Button4Click
  end
  object SynAsmSyn1: TSynAsmSyn
    Left = 384
    Top = 192
  end
end
