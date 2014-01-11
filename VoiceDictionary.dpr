program VoiceDictionary;

uses
  Forms,
  GoogleSpeechApi in 'GoogleSpeechApi.pas',
  CommandProcessor in 'CommandProcessor.pas',
  VoiceForm in 'VoiceForm.pas' {frmVoiceDictionary},
  SuperObject in 'SuperObject.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.MainFormOnTaskbar := True;
  Application.CreateForm(TfrmVoiceDictionary, frmVoiceDictionary);
  Application.Run;
end.
