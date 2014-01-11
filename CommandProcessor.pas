unit CommandProcessor;

interface

uses
  Windows, Sysutils, Classes, StdCtrls, GoogleSpeechApi, Messages;

procedure CommandProcessor_Setup;
procedure CommandProcessor_Process(szInput: String);

var
  FSpeech: TSpeechObject;

implementation

uses VoiceForm;

{* I've Been Using These Functions For So Long I Don't Remember Where They Came From *}
function Occurs(const str, separator: String): Integer;
var
  i, nSep: Integer;
begin
  nSep:=0;
  for i:=1 to Length(str) do
    if str[i] = separator then
      inc(nSep);
  Result:=nSep;
end;

function SplitW(const str: String; const separator: String; count: Integer = -1): TStringArray;
var
  i, n: Integer;
  p, q, s: PChar;
begin
  SetLength(Result, Occurs(str, separator) + 1);
  p:=PChar(str);
  s:=PChar(separator);
  n:=Length(separator);
  i:=0;
  repeat
    q:=StrPos(p, s);
    if q = nil then
      q:=StrScan(p, #0);
    begin
      if (i) = (count - 1) then
        SetString(Result[i], p, StrLen(p))
      else
        SetString(Result[i], p, q - p);
    end;
    p:=q + n;
    inc(i);
    if i = count then
    begin
      SetLength(Result, i);
      exit;
    end;
  until q^ = #0;
end;

procedure CommandProcessor_Setup;
begin
  FSpeech:=TSpeechObject.Create;
end;

procedure AddToResponse(szResp: String);
begin
  frmVoiceDictionary.Log('[Response] ' + szResp);
end;

procedure SpeakResponse(szResp: String);
begin
  FSpeech.TextToSpeech(szResp);
end;

{* Really Really Ghetto AI *}
procedure HandleWhat(szInput: String);
var
  p: Integer;
  tr: String;
begin
  {* What time is it? *}
  p:=Pos('time', szInput);
  if p > 0 then
  begin
    if Pos('is it', szInput) > p then
    begin
      tr:='The time is ' + FormatDateTime('hh:nn ampm', Time);
      SpeakResponse(tr);
      AddToResponse(tr);
    end;
  end;
  {* What day is it? *}
  p:=Pos('day', szInput);
  if p > 0 then
  begin
    if Pos('is it', szInput) > p then
    begin
      tr:='The date is ' + FormatDateTime('mmmm dd, yyyy', Now);
      SpeakResponse(tr);
      AddToResponse(tr);
    end;
  end;
  p:=Pos('date', szInput);
  if p > 0 then
  begin
    if Pos('is it', szInput) > p then
    begin
      tr:='The date is ' + FormatDateTime('mmmm dd, yyyy', Now);
      SpeakResponse(tr);
      AddToResponse(tr);
    end;
  end;
end;

function DeleteInBetweenData(szInput, szStartMarker, szEndMarker: String): String;
var
  dwStart, dwEnd: Integer;
begin
  dwStart:=Pos(szStartMarker, szInput);
  dwEnd:=Pos(szEndMarker, szInput);
  if dwEnd <= dwStart then
  begin
    Result:=szInput;
    exit;
  end;
  Delete(szInput, dwStart, (dwEnd - dwStart) + Length(szStartMarker) + Length(szEndMarker) - 3);
  Result:=szInput;
end;

procedure HandleDefine(szWord: String);
var
  szDefinition: String;
begin
  szWord:=LowerCase(szWord);
  szDefinition:=FSpeech.DefineWord(szWord);
  if szDefinition = '' then
  begin
    SpeakResponse('I cannot find the definition of ' + szWord);
    AddToResponse('I cannot find the definition of ' + szWord);
  end
  else
  begin
    szDefinition:=DeleteInBetweenData(szDefinition, '<i>', '</i>');
    szDefinition:='The definition of ' + szWord + ' is ' + LowerCase(szDefinition);
    SpeakResponse(szDefinition);
    AddToResponse(szDefinition);
  end;
end;

procedure CommandProcessor_Process(szInput: String);
var
  WordArray: TStringArray;
begin
  WordArray:=SplitW(szInput, ' ');
  if LowerCase(WordArray[0]) = 'what' then
    HandleWhat(szInput);
  if LowerCase(WordArray[0]) = 'define' then
    if High(WordArray) > 0 then
      HandleDefine(WordArray[1]);
end;

end.
