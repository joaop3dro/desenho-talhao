unit uDb;

interface

uses
  System.SysUtils,
  System.IOUtils,
  FireDAC.Comp.Client;

type
  TDb = class
  public
    class function CreateConnection: TFDConnection; static;
    class function GetDbFileName: string; static;
    class procedure EnsureSchema(const AConn: TFDConnection); static;
  end;

implementation

uses
  FireDAC.Stan.Intf,
  FireDAC.Stan.Def,
  FireDAC.Stan.Async,
  FireDAC.Stan.Pool,
  FireDAC.Phys,
  FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteWrapper,
  FireDAC.Phys.SQLiteDef,
  FireDAC.UI.Intf,
  FireDAC.FMXUI.Wait, FireDAC.DApt;

class function TDb.GetDbFileName: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'talhao_demo.db');
end;

class function TDb.CreateConnection: TFDConnection;
begin
  Result := TFDConnection.Create(nil);
  Result.LoginPrompt := False;

  Result.Params.Clear;
  Result.Params.DriverID := 'SQLite';
  Result.Params.Database := GetDbFileName;
  Result.Params.Add('OpenMode=CreateUTF8');
end;

class procedure TDb.EnsureSchema(const AConn: TFDConnection);
const
  SQL_TALHAO =
    'CREATE TABLE IF NOT EXISTS talhao (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  created_at TEXT NOT NULL' +
    ');';

  SQL_PONTOS =
    'CREATE TABLE IF NOT EXISTS talhao_ponto (' +
    '  id INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  talhao_id INTEGER NOT NULL,' +
    '  ord INTEGER NOT NULL,' +
    '  lat REAL NOT NULL,' +
    '  lon REAL NOT NULL,' +
    '  FOREIGN KEY(talhao_id) REFERENCES talhao(id)' +
    ');';

  SQL_IDX =
    'CREATE INDEX IF NOT EXISTS idx_talhao_ponto_talhao_ord ON talhao_ponto(talhao_id, ord);';
var
  Q: TFDQuery;
begin
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := AConn;
    Q.ExecSQL(SQL_TALHAO);
    Q.ExecSQL(SQL_PONTOS);
    Q.ExecSQL(SQL_IDX);
  finally
    Q.Free;
  end;
end;

end.
