unit VoiceForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, StdCtrls, ShellAPI, Menus, ExtCtrls, ComCtrls,
  CommandProcessor, GoogleSpeechAPI;

type
  TfrmVoiceDictionary = class(TForm)
    eLog: TMemo;
    eInput: TEdit;
    HotkeyTimer: TTimer;
    sStatus: TStatusBar;
    procedure eInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
    procedure FormCreate(Sender: TObject);
    procedure HotkeyTimerTimer(Sender: TObject);
  private
    {Private declarations}
  public
    {Public declarations}
    procedure Log(s: String);
  end;

var
  frmVoiceDictionary: TfrmVoiceDictionary;

implementation

{$R *.dfm}

var
  hKeyState: Dword;

procedure TfrmVoiceDictionary.eInputKeyDown(Sender: TObject; var Key: Word; Shift: TShiftState);
begin
  if Key = 13 then
  begin
    Log('[User] ' + eInput.Text);
    CommandProcessor_Process(eInput.Text);
    eInput.Text:='';
    Key:=0;
  end;
end;

procedure TfrmVoiceDictionary.FormCreate(Sender: TObject);
begin
  CommandProcessor_Setup;
end;

procedure TfrmVoiceDictionary.HotkeyTimerTimer(Sender: TObject);
var
  InputText: String;
begin
  if GetAsyncKeyState(VK_CONTROL) <> 0 then
  begin
    if hKeyState = 0 then
    begin
      hKeyState:=1;
      sStatus.SimpleText:='Status: Recording...';
      FSpeech.StartRecording;
    end;
  end
  else
  begin
    if hKeyState = 1 then
    begin
      hKeyState:=0;
      FSpeech.StopRecording;
      sStatus.SimpleText:='Status: Processing...';
      Application.ProcessMessages;
      InputText:=FSpeech.RecognizeRecordedVoice;
      if FSpeech.GetError = SO_NOT_ACCURATE then
      begin
        Log('[Response] Sorry I don''t understand');
        FSpeech.TextToSpeech('Sorry I don''t understand');
        exit;
      end;
      if FSpeech.GetError = SO_CANNOT_RECOGNIZE then
      begin
        Log('[Response] Something wrong with Google Speech...');
        FSpeech.TextToSpeech('Something''s wrong with Google Speech');
        exit;
      end;
      Log('[Speech] ' + InputText);
      CommandProcessor_Process(InputText);
      sStatus.SimpleText:='Status: Ready';
    end;
  end;
end;

procedure TfrmVoiceDictionary.Log(s: String);
begin
  eLog.Text:=eLog.Text + s + #13#10;
  eLog.SelStart:=Length(eLog.Text);
  eLog.SelLength:=0;
  SendMessage(eLog.Handle, EM_SCROLLCARET, 0, 0);
end;

end.
