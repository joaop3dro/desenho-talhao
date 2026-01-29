unit uGeoUtils;

interface

uses
  System.Math,
  System.Generics.Collections,
  FMX.Maps;

type
  TGeoUtils = record
  public
    class function DegToRad(const ADeg: Double): Double; static;
    class function RadToDeg(const ARad: Double): Double; static;

    class procedure MoveLatLonMeters(
      var ALat, ALon: Double;
      const ANorthMeters, AEastMeters: Double); static;

    class function PolygonAreaMeters2_Equirect(
      const APoints: TList<TMapCoordinate>): Double; static;
  end;

implementation

class function TGeoUtils.DegToRad(const ADeg: Double): Double;
begin
  Result := ADeg * (Pi / 180.0);
end;

class function TGeoUtils.RadToDeg(const ARad: Double): Double;
begin
  Result := ARad * (180.0 / Pi);
end;

class procedure TGeoUtils.MoveLatLonMeters(
  var ALat, ALon: Double;
  const ANorthMeters, AEastMeters: Double);
var
  LatRad: Double;
  MetersPerDegLat: Double;
  MetersPerDegLon: Double;
  DLatDeg: Double;
  DLonDeg: Double;
begin
  // Aproximação suficiente para pequenos deslocamentos (ajuste fino via botões)
  LatRad := DegToRad(ALat);
  MetersPerDegLat := 111320.0;
  MetersPerDegLon := 111320.0 * Cos(LatRad);

  if SameValue(MetersPerDegLon, 0.0) then
    MetersPerDegLon := 0.00001;

  DLatDeg := ANorthMeters / MetersPerDegLat;
  DLonDeg := AEastMeters / MetersPerDegLon;

  ALat := ALat + DLatDeg;
  ALon := ALon + DLonDeg;
end;

class function TGeoUtils.PolygonAreaMeters2_Equirect(
  const APoints: TList<TMapCoordinate>): Double;
var
  i: Integer;
  Lat0, Lon0: Double;
  LatRad: Double;
  MPerDegLat, MPerDegLon: Double;
  x1, y1, x2, y2: Double;
  Sum: Double;
begin
  Result := 0;
  if (APoints = nil) or (APoints.Count < 3) then
    Exit;

  // Usa o 1o ponto como origem de projeção local
  Lat0 := APoints[0].Latitude;
  Lon0 := APoints[0].Longitude;
  LatRad := DegToRad(Lat0);

  MPerDegLat := 111320.0;
  MPerDegLon := 111320.0 * Cos(LatRad);
  if SameValue(MPerDegLon, 0.0) then
    MPerDegLon := 0.00001;

  Sum := 0;
  for i := 0 to APoints.Count - 1 do
  begin
    x1 := (APoints[i].Longitude - Lon0) * MPerDegLon;
    y1 := (APoints[i].Latitude - Lat0) * MPerDegLat;

    if i = APoints.Count - 1 then
    begin
      x2 := (APoints[0].Longitude - Lon0) * MPerDegLon;
      y2 := (APoints[0].Latitude - Lat0) * MPerDegLat;
    end
    else
    begin
      x2 := (APoints[i + 1].Longitude - Lon0) * MPerDegLon;
      y2 := (APoints[i + 1].Latitude - Lat0) * MPerDegLat;
    end;

    Sum := Sum + (x1 * y2 - x2 * y1);
  end;

  Result := Abs(Sum) * 0.5;
end;

end.
