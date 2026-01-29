unit uTalhaoRepository;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FireDAC.Comp.Client,
  FMX.Maps;

type
  TTalhao = record
    Id: Int64;
    CreatedAt: TDateTime;
    Points: TList<TMapCoordinate>;
    procedure Init;
    procedure Done;
  end;

  TTalhaoListItem = record
    Id: Int64;
    CreatedAt: TDateTime;
  end;

  TTalhaoRepository = class
  private
    FConn: TFDConnection;
  public
    constructor Create(const AConn: TFDConnection);
    function InsertTalhao(const APoints: TList<TMapCoordinate>): Int64;
    function LoadTalhao(const ATalhaoId: Int64; out ATalhao: TTalhao): Boolean;
    function ListTalhoes: TArray<TTalhaoListItem>;
  end;

implementation

uses
  System.DateUtils,
  FireDAC.Comp.DataSet,
  FireDAC.Stan.Param;

procedure TTalhao.Init;
begin
  Id := 0;
  CreatedAt := 0;
  Points := TList<TMapCoordinate>.Create;
end;

procedure TTalhao.Done;
begin
  Points.Free;
  Points := nil;
end;

constructor TTalhaoRepository.Create(const AConn: TFDConnection);
begin
  inherited Create;
  FConn := AConn;
end;

function TTalhaoRepository.InsertTalhao(const APoints: TList<TMapCoordinate>): Int64;
var
  Q: TFDQuery;
  i: Integer;
  TalhaoId: Int64;
begin
  if (APoints = nil) or (APoints.Count < 3) then
    raise Exception.Create('Talhão precisa de ao menos 3 pontos.');

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    FConn.StartTransaction;
    try
      Q.SQL.Text := 'INSERT INTO talhao(created_at) VALUES(:created_at)';
      Q.ParamByName('created_at').AsString := FormatDateTime('yyyy-mm-dd"T"hh:nn:ss', Now);
      Q.ExecSQL;

      TalhaoId := FConn.ExecSQLScalar('SELECT last_insert_rowid()');

      Q.SQL.Text :=
        'INSERT INTO talhao_ponto(talhao_id, ord, lat, lon) ' +
        'VALUES(:talhao_id, :ord, :lat, :lon)';

      for i := 0 to APoints.Count - 1 do
      begin
        Q.ParamByName('talhao_id').AsLargeInt := TalhaoId;
        Q.ParamByName('ord').AsInteger := i;
        Q.ParamByName('lat').AsFloat := APoints[i].Latitude;
        Q.ParamByName('lon').AsFloat := APoints[i].Longitude;
        Q.ExecSQL;
      end;

      FConn.Commit;
      Result := TalhaoId;
    except
      FConn.Rollback;
      raise;
    end;
  finally
    Q.Free;
  end;
end;

function TTalhaoRepository.LoadTalhao(const ATalhaoId: Int64; out ATalhao: TTalhao): Boolean;
var
  Q: TFDQuery;
  P: TMapCoordinate;
begin
  ATalhao.Init;
  Result := False;

  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;

    Q.SQL.Text := 'SELECT id, created_at FROM talhao WHERE id = :id';
    Q.ParamByName('id').AsLargeInt := ATalhaoId;
    Q.Open;
    if Q.Eof then
      Exit;

    ATalhao.Id := Q.FieldByName('id').AsLargeInt;
    ATalhao.CreatedAt := ISO8601ToDate(Q.FieldByName('created_at').AsString, False);
    Q.Close;

    Q.SQL.Text := 'SELECT lat, lon FROM talhao_ponto WHERE talhao_id = :id ORDER BY ord';
    Q.ParamByName('id').AsLargeInt := ATalhaoId;
    Q.Open;

    while not Q.Eof do
    begin
      P := TMapCoordinate.Create(Q.FieldByName('lat').AsFloat, Q.FieldByName('lon').AsFloat);
      ATalhao.Points.Add(P);
      Q.Next;
    end;

    Result := ATalhao.Points.Count >= 3;
  finally
    Q.Free;
    if not Result then
      ATalhao.Done;
  end;
end;

function TTalhaoRepository.ListTalhoes: TArray<TTalhaoListItem>;
var
  Q: TFDQuery;
  L: TList<TTalhaoListItem>;
  It: TTalhaoListItem;
begin
  L := TList<TTalhaoListItem>.Create;
  try
    Q := TFDQuery.Create(nil);
    try
      Q.Connection := FConn;
      Q.SQL.Text := 'SELECT id, created_at FROM talhao ORDER BY id DESC';
      Q.Open;
      while not Q.Eof do
      begin
        It.Id := Q.FieldByName('id').AsLargeInt;
        It.CreatedAt := ISO8601ToDate(Q.FieldByName('created_at').AsString, False);
        L.Add(It);
        Q.Next;
      end;
    finally
      Q.Free;
    end;
    Result := L.ToArray;
  finally
    L.Free;
  end;
end;

end.
