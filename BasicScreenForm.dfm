object BasicScreen: TBasicScreen
  Left = 0
  Top = 0
  BorderIcons = []
  BorderStyle = bsDialog
  Caption = 'BasicScreen'
  ClientHeight = 300
  ClientWidth = 564
  Color = clBtnFace
  DoubleBuffered = True
  Font.Charset = DEFAULT_CHARSET
  Font.Color = clWindowText
  Font.Height = -11
  Font.Name = 'Tahoma'
  Font.Style = []
  OldCreateOrder = False
  Position = poMainFormCenter
  PixelsPerInch = 96
  TextHeight = 13
  object Screen: TPaintBox
    Left = 0
    Top = 0
    Width = 564
    Height = 300
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
