unit uDMConexao;

interface

uses
  System.SysUtils, System.Classes, System.IOUtils,
  FireDAC.Comp.Client, FireDAC.Stan.Def, FireDAC.Stan.Async, FireDAC.Stan.Intf,
  FireDAC.UI.Intf, FireDAC.FMXUI.Wait, FireDAC.Phys, FireDAC.Phys.SQLite,
  FireDAC.Phys.SQLiteDef, FireDAC.Stan.Option, FireDAC.Comp.UI,
  FireDAC.Comp.DataSet, FireDAC.DApt, FireDAC.Stan.Error, FireDAC.Phys.Intf,
  FireDAC.Stan.Pool, Data.DB, FireDAC.Stan.ExprFuncs,
  FireDAC.Phys.SQLiteWrapper.Stat;

type
  TDMConexao = class(TDataModule)
    FDConnection: TFDConnection;
    procedure DataModuleCreate(Sender: TObject);
  public
    function DBPath: string;
    procedure GarantirEstrutura;
  end;

var
  DMConexao: TDMConexao;

implementation

{%CLASSGROUP 'FMX.Controls.TControl'}

{$R *.dfm}

procedure TDMConexao.DataModuleCreate(Sender: TObject);
begin
   with FDConnection do
  begin
    Params.Values['DriverID'] := 'SQLite';

{$IFDEF IOS}
    Params.Values['Database'] := TPath.Combine(TPath.GetDocumentsPath,'talhao_agro.db');
{$ENDIF}
{$IFDEF ANDROID}
    Params.Values['Database'] := TPath.Combine(TPath.GetDocumentsPath,'talhao_agro.db');
{$ENDIF}
{$IFDEF MSWINDOWS}
    Params.Values['Database'] := '..\..\db\talhao_agro.db';
{$ENDIF}
  end;

  GarantirEstrutura;
end;

function TDMConexao.DBPath: string;
begin
  Result := TPath.Combine(TPath.GetDocumentsPath, 'talhao_agro.db');
end;

procedure TDMConexao.GarantirEstrutura;
const
  SQL_TALHAO =
    'CREATE TABLE IF NOT EXISTS TALHAO (' +
    '  ID INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  NOME TEXT,' +
    '  DATA_CRIACAO_UTC TEXT, created_at TEXT NOT NULL ' +
    ');';

  SQL_PONTO =
    'CREATE TABLE IF NOT EXISTS TALHAO_PONTO (' +
    '  ID INTEGER PRIMARY KEY AUTOINCREMENT,' +
    '  TALHAO_ID INTEGER,' +
    '  ORDEM INTEGER,' +
    '  LATITUDE REAL,' +
    '  LONGITUDE REAL,' +
    '  ord INTEGER NOT NULL,' +
    '  lat REAL NOT NULL,' +
    '  lon REAL NOT NULL' +
    ');';

  SQL_IDX1 = 'CREATE INDEX IF NOT EXISTS IDX_TALHAO_PONTO_1 ON TALHAO_PONTO (TALHAO_ID, ORDEM);';
begin
  FDConnection.ExecSQL(SQL_TALHAO);
  FDConnection.ExecSQL(SQL_PONTO);
  FDConnection.ExecSQL(SQL_IDX1);
end;

end.
