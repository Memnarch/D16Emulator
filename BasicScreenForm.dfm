object BasicScreen: TBasicScreen
  Left = 0
  Top = 0
  Caption = 'BasicScreen'
  ClientHeight = 290
  ClientWidth = 554
  Color = clBtnFace
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  PixelsPerInch = 96
  TextHeight = 13
  object Screen: TPaintBox
    Left = 0
    Top = 0
    Width = 554
    Height = 290
    Align = alClient
    ExplicitLeft = 232
    ExplicitTop = 112
    ExplicitWidth = 105
    ExplicitHeight = 105
  end
  object ScreenTimer: TTimer
    Interval = 16
    OnTimer = ScreenTimerTimer
    Left = 272
    Top = 152
  end
end
