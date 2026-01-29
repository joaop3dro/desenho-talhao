unit uMapService;

interface

uses
  System.SysUtils,
  System.Rtti,
  System.UITypes,
  FMX.Maps;

type
  TMapService = class
  private
    FMap: TMapView;
  public
    constructor Create(const AMap: TMapView);

    procedure SetCenter(const ALat, ALon: Double; const AZoom: Single = 15);
    function GetCenter: TMapCoordinate;

    function CreateOrMoveMarker(var AMarker: TMapMarker; const APos: TMapCoordinate; const ATitle: string): TMapMarker;
    procedure ClearMapObjects;

    function CreateOrUpdatePolygon(var APoly: TMapPolygon; const APoints: TArray<TMapCoordinate>): TMapPolygon;
    function CreateOrUpdatePolyline(var ALine: TMapPolyline; const APoints: TArray<TMapCoordinate>): TMapPolyline;
  end;

implementation

constructor TMapService.Create(const AMap: TMapView);
begin
  inherited Create;
  FMap := AMap;
end;

procedure TMapService.SetCenter(const ALat, ALon: Double; const AZoom: Single);
begin
  FMap.Location := TMapCoordinate.Create(ALat, ALon);
  FMap.Zoom := AZoom;
end;

function TMapService.GetCenter: TMapCoordinate;
begin
  Result := FMap.Location;
end;

procedure TMapService.ClearMapObjects;
  procedure ClearListByRtti(const AListObj: TObject);
  var
    Ctx: TRttiContext;
    T: TRttiType;
    CountProp: TRttiProperty;
    ClearMeth: TRttiMethod;
    DeleteMeth: TRttiMethod;
    RemoveAtMeth: TRttiMethod;
    Count: Integer;
  begin
    if AListObj = nil then
      Exit;

    Ctx := TRttiContext.Create;
    T := Ctx.GetType(AListObj.ClassType);
    CountProp := T.GetProperty('Count');
    ClearMeth := T.GetMethod('Clear');
    DeleteMeth := T.GetMethod('Delete');
    RemoveAtMeth := T.GetMethod('RemoveAt');

    // Preferência: Clear() (mais eficiente e comum)
    if ClearMeth <> nil then
    begin
      try
        ClearMeth.Invoke(AListObj, []);
        Exit;
      except
        // fallback abaixo
      end;
    end;

    if (CountProp = nil) then
      Exit;

    if (DeleteMeth = nil) and (RemoveAtMeth = nil) then
      Exit;

    while True do
    begin
      Count := CountProp.GetValue(AListObj).AsInteger;
      if Count <= 0 then
        Break;

      if DeleteMeth <> nil then
        DeleteMeth.Invoke(AListObj, [0])
      else
        RemoveAtMeth.Invoke(AListObj, [0]);
    end;
  end;

var
  Ctx: TRttiContext;
  MapType: TRttiType;
  Prop: TRttiProperty;
  ListObj: TObject;
begin
  // Algumas versões do Delphi não expõem FMap.Markers/FMap.Polygons publicamente.
  // Para manter compatibilidade, tenta limpar via RTTI quando as propriedades existirem.
  Ctx := TRttiContext.Create;
  MapType := Ctx.GetType(FMap.ClassType);

  Prop := MapType.GetProperty('Markers');
  if Prop <> nil then
  begin
    ListObj := Prop.GetValue(FMap).AsObject;
    ClearListByRtti(ListObj);
  end;

  Prop := MapType.GetProperty('Polygons');
  if Prop <> nil then
  begin
    ListObj := Prop.GetValue(FMap).AsObject;
    ClearListByRtti(ListObj);
  end;

  Prop := MapType.GetProperty('Polylines');
  if Prop <> nil then
  begin
    ListObj := Prop.GetValue(FMap).AsObject;
    ClearListByRtti(ListObj);
  end;
end;

function TMapService.CreateOrMoveMarker(var AMarker: TMapMarker; const APos: TMapCoordinate; const ATitle: string): TMapMarker;
var
  Desc: TMapMarkerDescriptor;
begin
  // Algumas versões não suportam atualizar marker (sem Location/Title ou Descriptor writeable).
  // Para manter compatibilidade de compilação, este método sempre cria um novo marker.
  Desc := TMapMarkerDescriptor.Create(APos, ATitle);
  AMarker := FMap.AddMarker(Desc);
  Result := AMarker;
end;

function TMapService.CreateOrUpdatePolygon(var APoly: TMapPolygon; const APoints: TArray<TMapCoordinate>): TMapPolygon;
var
  Desc: TMapPolygonDescriptor;
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;
begin
  // Algumas versões utilizam TMapPolygonDescriptor e não expõem Points.
  // Para manter compatibilidade, cria um novo polígono via descriptor.
  Desc := TMapPolygonDescriptor.Create(APoints);

  // Estilo (nem todas as versões possuem essas props; por isso RTTI)
  Ctx := TRttiContext.Create;
  T := Ctx.GetType(TypeInfo(TMapPolygonDescriptor));

  P := T.GetProperty('StrokeColor');
  if P <> nil then
    P.SetValue(@Desc, TValue.From<TAlphaColor>($FF1E88E5));

  P := T.GetProperty('StrokeWidth');
  if P <> nil then
    P.SetValue(@Desc, TValue.From<Single>(3));

  P := T.GetProperty('FillColor');
  if P <> nil then
    P.SetValue(@Desc, TValue.From<TAlphaColor>($401E88E5));

  APoly := FMap.AddPolygon(Desc);

  Result := APoly;
end;

function TMapService.CreateOrUpdatePolyline(var ALine: TMapPolyline; const APoints: TArray<TMapCoordinate>): TMapPolyline;
var
  Desc: TMapPolylineDescriptor;
  Ctx: TRttiContext;
  T: TRttiType;
  P: TRttiProperty;
begin
  Desc := TMapPolylineDescriptor.Create(APoints);

  // Estilo (nem todas as versões possuem essas props; por isso RTTI)
  Ctx := TRttiContext.Create;
  T := Ctx.GetType(TypeInfo(TMapPolylineDescriptor));

  P := T.GetProperty('StrokeColor');
  if P <> nil then
    P.SetValue(@Desc, TValue.From<TAlphaColor>($FF1E88E5));

  P := T.GetProperty('StrokeWidth');
  if P <> nil then
    P.SetValue(@Desc, TValue.From<Single>(2));

  ALine := FMap.AddPolyline(Desc);
  Result := ALine;
end;

end.
