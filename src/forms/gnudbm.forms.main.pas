unit gnudbm.Forms.Main;

{$mode objfpc}{$H+}

interface

uses
  Classes
, SysUtils
, Forms
, Controls
, Graphics
, Dialogs
, ExtCtrls
, StdCtrls
, Menus
, ActnList
, StdActns
, gdbm
;

type

  { TfrmMain }

  TfrmMain = class(TForm)
    actGDBMCreateDB: TAction;
    actGDBMInsert: TAction;
    actGDBMList: TAction;
    alMain: TActionList;
    btnGDBMCreateDB: TButton;
    btnGDBMInsert: TButton;
    btnGDBMList: TButton;
    edtDBFilename: TEdit;
    actFileExit: TFileExit;
    lblDBFilename: TLabel;
    memLog: TMemo;
    mnuGDBMList: TMenuItem;
    mnuGDBMCreateDB: TMenuItem;
    mnuFile: TMenuItem;
    mnuFileSep1: TMenuItem;
    mnuFileExit: TMenuItem;
    mnuGDBM: TMenuItem;
    mnuGDBMInsert: TMenuItem;
    mmMain: TMainMenu;
    panEdits: TPanel;
    panButtons: TPanel;
    procedure alMainUpdate(AAction: TBasicAction; var Handled: Boolean);
    procedure actGDBMCreateDBExecute(Sender: TObject);
    procedure actGDBMInsertExecute(Sender: TObject);
    procedure actGDBMListExecute(Sender: TObject);
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
  private
    FDB: PGDBM_FILE;

    FInsertInProgress: Boolean;
    FInsertDone: Boolean;

    procedure InitShortcuts;
    function RandomString(AWidth: Integer): String;
  public

  end;

var
  frmMain: TfrmMain;

implementation

uses
  LCLType
;

const
  cChars = 'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWZYX0123456789';
  cEntryCount = 100;

{$R *.lfm}

{ TfrmMain }

function TfrmMain.RandomString(AWidth: Integer): String;
var
  index: Integer;
begin
  Result:= '';
  for index := 1 to AWidth do
  begin
    Result := Result + cChars[random(Length(cChars))+1];
  end;
end;

procedure TfrmMain.alMainUpdate(AAction: TBasicAction; var Handled: Boolean);
begin
  if AAction = actGDBMCreateDB then
  begin
    actGDBMCreateDB.Enabled:= FDB = nil;
    edtDBFilename.Enabled:= actGDBMCreateDB.Enabled;
    Handled:= True;
  end;
  if AAction = actGDBMInsert then
  begin
    actGDBMInsert.Enabled:= (not (FDB = nil)) and (not FInsertInProgress) and (not FInsertDone);
    Handled:= True;
  end;
  if AAction = actGDBMList then
  begin
    actGDBMList.Enabled:= (not (FDB = nil)) and (FInsertDone);
    Handled:= True;
  end;
end;

procedure TfrmMain.actGDBMCreateDBExecute(Sender: TObject);
begin
  actGDBMCreateDB.Enabled:= False;
  Application.ProcessMessages;
  if edtDBFilename.Text <> '' then
  begin
    if FileExists(edtDBFilename.Text) then
    begin
      DeleteFile(edtDBFilename.Text);
    end;
    FDB:= gdbm_open(edtDBFilename.Text,512,GDBM_NEWDB,432,nil);
    if FDB <> nil then
    begin
      memLog.Append(Format('Database created: %s', [edtDBFilename.Text]));
    end
    else
    begin
      memLog.Append(Format('ERROR creating database: %s', [edtDBFilename.Text]));
    end;
  end;
  Application.ProcessMessages;
end;

procedure TfrmMain.actGDBMInsertExecute(Sender: TObject);
var
  index: Integer;
  key, value: String;
  keys: TStringList;
  keysFilename: String;
begin
  actGDBMInsert.Enabled:= False;
  memLog.Append(Format('Putting %d entries.',[cEntryCount]));
  Application.ProcessMessages;
  FInsertInProgress:= True;
  keys:= TStringList.Create;
  try
    for index:=1 to cEntryCount do
    begin
      if (index = 1) or (index mod 1000 = 0) then
      begin
        memLog.Append(Format('Putting entry %s.',[FormatFloat(',0',index)]));
        Application.ProcessMessages;
      end;
      key:= RandomString(16);
      keys.Append(key);
      value:= Format('{"index":%d,"hash":"%s"}', [index, RandomString(64)]);
      gdbm_store(FDB,key, value, GDBM_INSERT);
    end;
    FInsertInProgress:= False;
    FInsertDone:= True;
    keysFilename:= ChangeFileExt(edtDBFilename.Text, '.txt');
    memLog.Append(Format('Dumping %s keys to %s',[FormatFloat(',0',index), keysFilename]));
    keys.SaveToFile(keysFilename);
  finally
    keys.Free;
  end;
  memLog.Append(Format('Completed putting %s entries.', [FormatFloat(',0',cEntryCount)]));
  Application.ProcessMessages;
end;

procedure TfrmMain.actGDBMListExecute(Sender: TObject);
var
  key, value: String;
  index: Integer;
begin
  actGDBMList.Enabled:= False;
  memLog.Append('Listing entries.');
  Application.ProcessMessages;
  if Assigned(FDB) then
  begin
    gdbm_firstkey(FDB, key);
    index:= 0;
    while key <> '' do
    begin
      Inc(index);
      value:= gdbm_fetch(FDB, key);
      if (index = 1) or (index mod 1000 = 0) then
      begin
        memLog.Append(Format('%s - %s: %s', [FormatFloat(',0',index), key, value]));
        Application.ProcessMessages;
      end;
      try
        key:= gdbm_nextkey(FDB, key);
      except
        on E: Exception do
        begin
          memLog.Append(Format('ERROR: %s', [E.Message]));
          key:= '';
        end;
      end;
    end;
    memLog.Append(Format('Listed %s entries.',[FormatFloat(',0',index)]));
  end;
  Application.ProcessMessages;
  actGDBMList.Enabled:= True;
end;

procedure TfrmMain.InitShortcuts;
begin
{$IFDEF LINUX}
  actFileExit.ShortCut := KeyToShortCut(VK_Q, [ssCtrl]);
{$ENDIF}
{$IFDEF WINDOWS}
  actFileExit.ShortCut := KeyToShortCut(VK_X, [ssAlt]);
{$ENDIF}
end;

procedure TfrmMain.FormCreate(Sender: TObject);
begin
  Randomize;

  FDB:= nil;
  FInsertInProgress:= False;
  FInsertDone:= False;

  InitShortcuts;
end;

procedure TfrmMain.FormDestroy(Sender: TObject);
begin
  if FDB <> nil then
  begin
    gdbm_close(FDB);
  end;
end;

end.

