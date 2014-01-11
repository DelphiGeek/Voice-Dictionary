object frmVoiceDictionary: TfrmVoiceDictionary
  Left = 0
  Top = 0
  BorderIcons = [biSystemMenu, biMinimize]
  BorderStyle = bsSingle
  Caption = 'Voice Dictionary - Press and Hold Ctrl to Speak'
  ClientHeight = 407
  ClientWidth = 585
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
  object eLog: TMemo
    Left = 8
    Top = 8
    Width = 569
    Height = 345
    ReadOnly = True
    ScrollBars = ssVertical
    TabOrder = 0
  end
  object eInput: TEdit
    Left = 8
    Top = 360
    Width = 569
    Height = 21
    TabOrder = 1
    OnKeyDown = eInputKeyDown
  end
  object sStatus: TStatusBar
    Left = 0
    Top = 388
    Width = 585
    Height = 19
    Panels = <>
    SimplePanel = True
    SimpleText = 'Status: Ready'
  end
  object HotkeyTimer: TTimer
    Interval = 50
    OnTimer = HotkeyTimerTimer
    Left = 16
    Top = 16
  end
end
