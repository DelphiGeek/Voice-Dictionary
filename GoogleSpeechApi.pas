unit GoogleSpeechApi;

interface

uses
  Windows, Sysutils, Classes, MMSystem, ShellApi, IdHTTP, SuperObject, Forms, Math;

type
  TStringArray = array of String;

  TSpeechResult = (SO_SUCCESS, SO_CANNOT_RECOGNIZE, SO_NOT_ACCURATE);

  TSpeechObject = class(TThread)
  private
    FTempDirectory: String;
    {* Audio Objects *}
    op: TMCI_Open_Parms;
    rp: TMCI_Record_Parms;
    sp: TMCI_SaveParms;
    {* Random Header *}
    RandomQ: String;
    {* Last Error Code *}
    LastErrorCode: TSpeechResult;
    {* Messages *}
    p_Status: Dword; {* 0 - Ready 1 - Speaking *}
    p_Message: Dword; {* 0 - No message 1 - Stop current speech *}
    p_TextToSpeech: String;

    procedure SpeechToWav(TextIn, Filename: String);
    function GetTempDirectory: String;
    function SplitInto100LetterWordSegments(TextIn: String): TStringArray;
  public
    Accuracy: Byte;
    procedure SyncSpeechText(TextIn: String);
    constructor Create;
    procedure Execute; override;
    procedure StartRecording;
    procedure StopRecording;
    function RecognizeRecordedVoice: String;
    function GetError: TSpeechResult;
    procedure TextToSpeech(TextIn: String);
    function DefineWord(WordIn: String): String;
  end;

implementation

constructor TSpeechObject.Create;
begin
  {* Initialize Anti-Conflict *}
  Randomize;
  RandomQ:=IntToStr(Random($7FFFFFF)) + '_';
  {* Initialize Default Accuracy *}
  Accuracy:=50;
  {* Initialize Other *}
  FTempDirectory:='';
  inherited Create(False);
end;

function TSpeechObject.DefineWord(WordIn: String): String;
var
  HttpObject: TIdHttp;
  s: TStringStream;
begin
  Result:='';
  {* Get Dictionary Definition *}
  HttpObject:=TIdHttp.Create(nil);
  s:=TStringStream.Create;
  try
    HttpObject.Request.Pragma:='no-cache';
    HttpObject.Request.UserAgent:='Chrome';
    HttpObject.ConnectTimeout:=5000;
    HttpObject.ReadTimeout:=8000;
    HttpObject.Get('http://www.google.com/dictionary/json?callback=dict_api.callbacks.id100&sl=en&tl=en&restrict=pr%2Cde&client=te&q=' + WordIn, s);
    s.Position:=0;
    Result:=s.ReadString(s.Size);
  except
    Result:='';
  end;
  s.Free;
  HttpObject.Free;
  if Result = '' then
    Exit;
  {* No Response *}
  if Pos('{"type":"meaning","terms":[{"type":"text","text":"', Result) = 0 then
    Exit;
  {* Screw SuperObject, Doing it the Old Fashion Way *}
  Result:=Copy(Result, Pos('{"type":"meaning","terms":[{"type":"text","text":"', Result) + Length('{"type":"meaning","terms":[{"type":"text","text":"'), Length(Result) - Pos('{"type":"meaning","terms":[{"type":"text","text":"', Result) - Length('{"type":"meaning","terms":[{"type":"text","text":"'));
  Result:=Copy(Result, 0, Pos('"', Result) - 1);
end;

procedure TSpeechObject.Execute;
begin
  while not(Terminated) do
  begin
    {* Speech Request *}
    if p_Status = 1 then
    begin
      p_Status:=0;
      SyncSpeechText(p_TextToSpeech);
    end;
    Sleep(1);
  end;
end;

function TSpeechObject.GetError: TSpeechResult;
begin
  Result:=LastErrorCode;
end;

function TSpeechObject.GetTempDirectory: String;
var
  TempFolder: array [0 .. MAX_PATH] of Char;
begin
  if FTempDirectory <> '' then
  begin
    Result:=FTempDirectory;
    Exit;
  end;
  GetTempPath(MAX_PATH, @TempFolder[0]);
  FTempDirectory:=TempFolder;
  Result:=FTempDirectory;
end;

function TSpeechObject.RecognizeRecordedVoice: String;
var
  SEFFMPEG: ShellExecuteInfoW;
  SendStream: TFileStream;
  sResponse: TStringStream;
  IdHTTP: TIdHttp;
  dwStatus: Dword;
  szResponse: String;
  sObj: ISuperObject;
begin
  Result:='';
  {* Use ffmpeg to Convert Wav to Flac *}
  FillChar(SEFFMPEG, SizeOf(SEFFMPEG), 0);
  with SEFFMPEG do
  begin
    cbSize:=SizeOf(SEFFMPEG);
    fMask:=SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_DDEWAIT;
    Wnd:=GetActiveWindow();
    SEFFMPEG.lpVerb:='open';
    SEFFMPEG.lpParameters:=PChar('-y -i "' + GetTempDirectory + RandomQ + 'Record.wav' + '" -vn -ac 1 -ar 16000 -acodec flac "' + GetTempDirectory + RandomQ + 'Record.flac' + '"');
    lpFile:=PChar(ExtractFilePath(Application.ExeName) + 'ffmpeg.exe');
    nShow:=SW_HIDE;
  end;
  ShellExecuteEx(@SEFFMPEG);
  WaitForSingleObject(SEFFMPEG.hProcess, INFINITE);
  CloseHandle(SEFFMPEG.hProcess);
  DeleteFile(GetTempDirectory + RandomQ + 'Record.wav');
  {* Request Using Google's API *}
  SendStream:=TFileStream.Create(GetTempDirectory + RandomQ + 'Record.flac', fmOpenRead);
  SendStream.Position:=0;
  sResponse:=TStringStream.Create;
  IdHTTP:=TIdHttp.Create(nil);
  try
    IdHTTP.Request.accept:='*/*';
    IdHTTP.Request.ContentType:='audio/x-flac; rate=16000';
    IdHTTP.Request.Connection:='Keep-Alive';
    IdHTTP.Request.ContentLength:=SendStream.Size;
    IdHTTP.Post('http://www.google.com/speech-api/v1/recognize?xjerr=1&client=chromium&lang=en-US', SendStream, sResponse);
    sResponse.Position:=0;
    szResponse:=sResponse.ReadString(sResponse.Size);
  except
  end;
  IdHTTP.Free;
  SendStream.Free;
  sResponse.Free;
  {* Use SuperObject to Parse Response *}
  try
    sObj:=TSuperObject.ParseString(PChar(szResponse), true);
    dwStatus:=sObj.AsObject.i['status'];
    if dwStatus = 0 then
    begin
      Result:=Copy(sObj.AsObject.s['hypotheses'], 2, Length(sObj.AsObject.s['hypotheses']) - 2);
      if round(TSuperObject.ParseString(PChar(Result), true).AsObject.D['confidence'] * 100) >= Accuracy then
      begin
        Result:=TSuperObject.ParseString(PChar(Result), true).AsObject.s['utterance'];
        LastErrorCode:=SO_SUCCESS;
      end
      else
      begin
        LastErrorCode:=SO_NOT_ACCURATE;
        Result:='';
      end;
    end
    else
      LastErrorCode:=SO_CANNOT_RECOGNIZE;
  except
    Result:='';
  end;
  DeleteFile(GetTempDirectory + RandomQ + 'Record.flac');
end;

function Url_Encode(const Url: string): string;
var
  i: Integer;
begin
  Result:='';
  for i:=1 to Length(Url) do
  begin
    case Url[i] of
      'a' .. 'z', 'A' .. 'Z', '0' .. '9', '/', '.', '&', '-':
        Result:=Result + Url[i];
    else
      Result:=Result + '%' + UpperCase(IntToHex(Ord(Url[i]), 2));
    end;
  end;
end;

Procedure TSpeechObject.SpeechToWav(TextIn, Filename: String);
var
  HttpObject: TIdHttp;
  FSpeechMp3: TFileStream;
  SEFFMPEG: ShellExecuteInfoW;
begin
  TextIn:=LowerCase(TextIn);
  {* Accept 100 Characters *}
  if Length(TextIn) > 100 then
    TextIn:=Copy(TextIn, 1, 100);
  {* Create Mp3 File *}
  DeleteFile(GetTempDirectory + RandomQ + 'TTS.mp3');
  HttpObject:=TIdHttp.Create(nil);
  FSpeechMp3:=TFileStream.Create(GetTempDirectory + RandomQ + 'TTS.mp3', fmCreate);
  FSpeechMp3.Position:=0;
  try
    HttpObject.Request.Pragma:='no-cache';
    HttpObject.Request.UserAgent:='Chrome';
    HttpObject.Get('http://translate.google.com/translate_tts?tl=en&q=' + Url_Encode(TextIn), FSpeechMp3);
  except
  end;
  FSpeechMp3.Free;
  HttpObject.Free;
  {* Convert to Wav so Windows can Play it *}
  FillChar(SEFFMPEG, SizeOf(SEFFMPEG), 0);
  with SEFFMPEG do
  begin
    cbSize:=SizeOf(SEFFMPEG);
    fMask:=SEE_MASK_NOCLOSEPROCESS or SEE_MASK_FLAG_DDEWAIT;
    Wnd:=GetActiveWindow();
    SEFFMPEG.lpVerb:='open';
    SEFFMPEG.lpParameters:=PChar('-y -i "' + GetTempDirectory + RandomQ + 'TTS.mp3' + '" "' + Filename + '"');
    lpFile:=PChar(ExtractFilePath(Application.ExeName) + 'ffmpeg.exe');
    nShow:=SW_HIDE;
  end;
  ShellExecuteEx(@SEFFMPEG);
  WaitForSingleObject(SEFFMPEG.hProcess, INFINITE);
  CloseHandle(SEFFMPEG.hProcess);
  {* Delete Mp3 *}
  DeleteFile(GetTempDirectory + RandomQ + 'TTS.mp3');
end;

function TSpeechObject.SplitInto100LetterWordSegments(TextIn: String): TStringArray;
var
  i, lasti: Integer;
begin
  {* Splits String Into 80-100 Word Segments (Assuming Words are Under 20 Characters) *}
  SetLength(Result, 1);
  lasti:=1;
  i:=1;
  while i <= Length(TextIn) do
  begin
    if ((i - lasti) > 80) or (i >= Length(TextIn)) then
    begin
      while true do
      begin
        if i > Length(TextIn) then
          break;
        if TextIn[i] = ' ' then
          break;
        inc(i);
      end;
      Result[ High(Result)]:=Copy(TextIn, lasti, i - lasti);
      SetLength(Result, High(Result) + 2);
      lasti:=i;
    end;
    inc(i);
  end;
  if High(Result) = 0 then
    Result[0]:=TextIn
  else
    SetLength(Result, High(Result));
end;

procedure TSpeechObject.StartRecording;
begin
  op.lpstrDeviceType:='waveaudio';
  op.lpstrElementName:='';
  mciSendCommand(0, MCI_OPEN, MCI_OPEN_ELEMENT or MCI_OPEN_TYPE, cardinal(@op));
  rp.dwFrom:=0;
  rp.dwTo:=0;
  rp.dwCallback:=0;
  mciSendCommand(op.wDeviceID, MCI_RECORD, 0, cardinal(@rp));
end;

procedure TSpeechObject.StopRecording;
begin
  sp.lpfilename:=PChar(GetTempDirectory + RandomQ + 'Record.wav');
  mciSendCommand(op.wDeviceID, MCI_SAVE, MCI_SAVE_FILE or MCI_WAIT, cardinal(@sp));
  mciSendCommand(op.wDeviceID, MCI_CLOSE, 0, 0);
end;

procedure TSpeechObject.SyncSpeechText(TextIn: String);
var
  TextSplit: TStringArray;
  tc: Dword;
  i, songlength: Dword;
  sFile: String;
  rStr: PChar;
begin
  {* Reset Flags *}
  p_Message:=0;
  TextSplit:=SplitInto100LetterWordSegments(TextIn);
  {* Convert Into Wav Files *}
  sFile:=GetTempDirectory + RandomQ;
  for i:=0 to High(TextSplit) do
    SpeechToWav(TextSplit[i], sFile + IntToStr(i) + '_Speech.wav');
  {* Play Each Wav File *}
  for i:=0 to High(TextSplit) do
  begin
    mciSendString(PChar('Open "' + sFile + IntToStr(i) + '_Speech.wav' + '" alias tmpsndfile'), nil, 0, 0);
    mciSendString('Set tmpsndfile time format milliseconds', nil, 0, 0);
    GetMem(rStr, 1024);
    mciSendString('Status tmpsndfile length', rStr, 1024, 0);
    try
      songlength:=StrToInt(rStr);
    except
      songlength:=0;
    end;
    FreeMem(rStr);
    mciSendString('Close tmpsndfile', nil, 0, 0);
    Sleep(5);
    sndPlaySound(PChar(sFile + IntToStr(i) + '_Speech.wav'), SND_NODEFAULT Or SND_ASYNC);
    tc:=GetTickCount + songlength;
    while GetTickCount < tc do
    begin
      if p_Message = 1 then
        break;
      Sleep(5);
    end;
    if p_Message = 1 then
      break;
  end;
  {* Delete Wav Files *}
  for i:=0 to High(TextSplit) do
    DeleteFile(sFile + IntToStr(i) + '_Speech.wav');
end;

procedure TSpeechObject.TextToSpeech(TextIn: String);
begin
  p_TextToSpeech:=TextIn;
  p_Message:=1;
  p_Status:=1;
end;

end.
