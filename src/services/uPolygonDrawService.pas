unit uPolygonDrawService;

interface

uses
  System.SysUtils,
  System.Generics.Collections,
  FMX.Maps;

type
  TPolygonDrawService = class
  private
    FPoints: TList<TMapCoordinate>;
    FCurrent: TMapCoordinate;
    FActive: Boolean;
  public
    constructor Create;
    destructor Destroy; override;

    procedure Start(const AInitialCurrent: TMapCoordinate);
    procedure Stop;

    function IsActive: Boolean;
    function PointCount: Integer;

    procedure SetCurrent(const APos: TMapCoordinate);
    function GetCurrent: TMapCoordinate;

    procedure AddPoint;

    function BuildPreviewPoints: TArray<TMapCoordinate>;
    function BuildClosedPoints: TArray<TMapCoordinate>;

    function GetCommittedPoints: TList<TMapCoordinate>;
  end;

implementation

constructor TPolygonDrawService.Create;
begin
  inherited Create;
  FPoints := TList<TMapCoordinate>.Create;
  FCurrent := TMapCoordinate.Create(0, 0);
  FActive := False;
end;

destructor TPolygonDrawService.Destroy;
begin
  FPoints.Free;
  inherited;
end;

procedure TPolygonDrawService.Start(const AInitialCurrent: TMapCoordinate);
begin
  FPoints.Clear;
  FCurrent := AInitialCurrent;
  FActive := True;
end;

procedure TPolygonDrawService.Stop;
begin
  FActive := False;
end;

function TPolygonDrawService.IsActive: Boolean;
begin
  Result := FActive;
end;

function TPolygonDrawService.PointCount: Integer;
begin
  Result := FPoints.Count;
end;

procedure TPolygonDrawService.SetCurrent(const APos: TMapCoordinate);
begin
  FCurrent := APos;
end;

function TPolygonDrawService.GetCurrent: TMapCoordinate;
begin
  Result := FCurrent;
end;

procedure TPolygonDrawService.AddPoint;
begin
  if not FActive then
    Exit;
  FPoints.Add(FCurrent);
end;

function TPolygonDrawService.BuildPreviewPoints: TArray<TMapCoordinate>;
var
  i: Integer;
begin
  // Preview: pontos já confirmados + ponto atual
  SetLength(Result, FPoints.Count + 1);
  for i := 0 to FPoints.Count - 1 do
    Result[i] := FPoints[i];
  Result[High(Result)] := FCurrent;
end;

function TPolygonDrawService.BuildClosedPoints: TArray<TMapCoordinate>;
var
  i: Integer;
begin
  // Fecha automaticamente: inclui o primeiro ponto no final
  if FPoints.Count < 3 then
  begin
    SetLength(Result, 0);
    Exit;
  end;

  SetLength(Result, FPoints.Count + 1);
  for i := 0 to FPoints.Count - 1 do
    Result[i] := FPoints[i];
  Result[High(Result)] := FPoints[0];
end;

function TPolygonDrawService.GetCommittedPoints: TList<TMapCoordinate>;
begin
  Result := FPoints;
end;

end.
