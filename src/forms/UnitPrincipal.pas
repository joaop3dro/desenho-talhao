unit UnitPrincipal;

interface

uses
  System.SysUtils, System.Types, System.UITypes, System.Classes, System.Variants,
  System.Rtti,
  FMX.Types, FMX.Controls, FMX.Forms, FMX.Graphics, FMX.Dialogs, FMX.Maps,
  FMX.Controls.Presentation, FMX.StdCtrls, FMX.Objects, FMX.Layouts,
  FMX.ListBox, FMX.Edit, System.IOUtils, FMX.TabControl, FireDAC.Comp.Client,
  uDb, uGeoUtils, uMapService, uPolygonDrawService, uTalhaoRepository, system.Generics.Collections,
  System.Math, uDMConexao;

type
  TFrmPrincipal = class(TForm)
    imgMoto: TImage;
    TimerJoystick: TTimer;
    InitTimer: TTimer;
    MapView1: TMapView;
    CirclePin: TCircle;
    LayoutBottom: TLayout;
    LblInfo: TLabel;
    LblArea: TLabel;
    BtnStart: TButton;
    BtnAddPoint: TButton;
    BtnFinish: TButton;
    BtnSave: TButton;
    BtnLoadLast: TButton;
    BtnClear: TButton;
    LayoutPad: TLayout;
    BtnUp: TButton;
    BtnLeft: TButton;
    BtnRight: TButton;
    BtnDown: TButton;
    BtnUpLeft: TButton;
    BtnUpRight: TButton;
    BtnDownLeft: TButton;
    BtnDownRight: TButton;
    Layout2: TLayout;
    Layout3: TLayout;
    CmbTalhoes2: TComboBox;
    Layout1: TLayout;
    pnlPin: TPanel;
    LayoutMapOverlay: TLayout;
    procedure FormCreate(Sender: TObject);
    procedure FormDestroy(Sender: TObject);
    procedure MapViewMarkerDragEnd(Marker: TMapMarker);
    procedure MapViewMarkerClick(Marker: TMapMarker);
    procedure TimerJoystickTimer(Sender: TObject);
    procedure BtnStartClick(Sender: TObject);
    procedure BtnAddPointClick(Sender: TObject);
    procedure BtnFinishClick(Sender: TObject);
    procedure BtnClearClick(Sender: TObject);
    procedure BtnSaveClick(Sender: TObject);
    procedure BtnLoadLastClick(Sender: TObject);
    procedure BtnUpClick(Sender: TObject);
    procedure PadBtnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PadBtnMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PadMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure PadMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
    procedure PadMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
    procedure InitTimerTimer(Sender: TObject);
  private
    { Private declarations }
    FJoyDX: Single;
    FJoyDY: Single;

    FConn: TFDConnection;
    FRepo1: TTalhaoRepository;
    FMapSvc: TMapService;
    FDrawSvc: TPolygonDrawService;

    FMarkerCurrent: TMapMarker;
    FPolygon: TMapPolygon;
    FLinePreview: TMapPolyline;

    FStepMeters: Double;
    FLastSavedTalhaoId: Int64;
    FLastAreaM2: Double;

    FPadTimer: TTimer;
    FPadNorthMeters: Double;
    FPadEastMeters: Double;
    FAutoAddAccumMeters: Double;

    procedure UpdateOverlay;
    procedure UpdateInfo;

    procedure MoveCurrent(const ANorthMeters, AEastMeters: Double);
    function GetLastTalhaoId: Int64;
    procedure AppendLog(const AText: string);
    function Ready: Boolean;
    procedure SetDemo2Enabled(const AEnabled: Boolean);
    procedure Toast(const S: string);
    procedure PadTimerTick(Sender: TObject);
    procedure UpdateTalhoes;
    function GetSelectedTalhaoId2: Int64;
    function DistanceMeters(const A, B: TMapCoordinate): Double;
    function FormatDistance(const AMeters: Double): string;
    procedure UpdatePadVector(const X, Y: Single);

    procedure RecreateMapView;
  public
    { Public declarations }
  end;

var
  FrmPrincipal: TFrmPrincipal;

implementation

{$R *.fmx}

type
  TTalhaoIdObj = class(TObject)
  public
    Id: Int64;
    constructor Create(const AId: Int64);
  end;

constructor TTalhaoIdObj.Create(const AId: Int64);
begin
  inherited Create;
  Id := AId;
end;

procedure TFrmPrincipal.PadTimerTick(Sender: TObject);
const
  AUTO_ADD_EVERY_METERS = 5.0;
var
  StepMoved: Double;
begin
  if not Ready then
    Exit;
  if not FDrawSvc.IsActive then
    Exit;
  if (FPadNorthMeters = 0) and (FPadEastMeters = 0) then
    Exit;

  MoveCurrent(FPadNorthMeters, FPadEastMeters);

  StepMoved := Sqrt(Sqr(FPadNorthMeters) + Sqr(FPadEastMeters));
  FAutoAddAccumMeters := FAutoAddAccumMeters + StepMoved;

  if FAutoAddAccumMeters >= AUTO_ADD_EVERY_METERS then
  begin
    FAutoAddAccumMeters := 0;
    FDrawSvc.AddPoint;
    UpdateInfo;
    UpdateOverlay;
  end;
end;

procedure TFrmPrincipal.UpdateTalhoes;
var
  Items: TArray<TTalhaoListItem>;
  I: Integer;
  S: string;
begin
  if not Ready then
    Exit;
  if not Assigned(CmbTalhoes2) then
    Exit;

  for I := 0 to CmbTalhoes2.Items.Count - 1 do
    CmbTalhoes2.Items.Objects[I].Free;
  CmbTalhoes2.Clear;

  Items := FRepo1.ListTalhoes;
  for I := 0 to High(Items) do
  begin
    S := Format('%d - %s', [Items[I].Id, FormatDateTime('dd/mm/yyyy hh:nn', Items[I].CreatedAt)]);
    CmbTalhoes2.Items.AddObject(S, TTalhaoIdObj.Create(Items[I].Id));
  end;

  if CmbTalhoes2.Items.Count > 0 then
    CmbTalhoes2.ItemIndex := 0;
end;

function TFrmPrincipal.GetSelectedTalhaoId2: Int64;
var
  Obj: TObject;
begin
  Result := 0;
  if not Assigned(CmbTalhoes2) then
    Exit;
  if CmbTalhoes2.ItemIndex < 0 then
    Exit;
  Obj := CmbTalhoes2.Items.Objects[CmbTalhoes2.ItemIndex];
  if Obj is TTalhaoIdObj then
    Result := TTalhaoIdObj(Obj).Id;
end;

function TFrmPrincipal.DistanceMeters(const A, B: TMapCoordinate): Double;
const
  R = 6371000.0;
var
  Lat1, Lat2, DLat, DLon: Double;
begin
  Lat1 := DegToRad(A.Latitude);
  Lat2 := DegToRad(B.Latitude);
  DLat := DegToRad(B.Latitude - A.Latitude);
  DLon := DegToRad(B.Longitude - A.Longitude);
  Result := 2 * R * ArcSin(Sqrt(Sqr(Sin(DLat / 2)) + Cos(Lat1) * Cos(Lat2) * Sqr(Sin(DLon / 2))));
end;

function TFrmPrincipal.FormatDistance(const AMeters: Double): string;
begin
  if AMeters >= 1000 then
    Result := Format('%.2f km', [AMeters / 1000.0])
  else
    Result := Format('%.1f m', [AMeters]);
end;

function TFrmPrincipal.Ready: Boolean;
begin
  Result := Assigned(FMapSvc) and Assigned(FDrawSvc) and Assigned(FRepo1) and Assigned(FConn) and FConn.Connected;
end;

procedure TFrmPrincipal.SetDemo2Enabled(const AEnabled: Boolean);
begin
  if Assigned(BtnStart) then
    BtnStart.Enabled := AEnabled;

  if Assigned(BtnAddPoint) then
    BtnAddPoint.Enabled := AEnabled;

  if Assigned(BtnFinish) then
    BtnFinish.Enabled := AEnabled;

  if Assigned(BtnSave) then
    BtnSave.Enabled := AEnabled;

  if Assigned(BtnLoadLast) then
    BtnLoadLast.Enabled := AEnabled;

  if Assigned(LayoutPad) then
    LayoutPad.Enabled := AEnabled;
end;

procedure TFrmPrincipal.AppendLog(const AText: string);
var
  FN: string;
begin
  try
    FN := TPath.Combine(TPath.GetDocumentsPath, 'demo_log.txt');
    TFile.AppendAllText(FN, FormatDateTime('yyyy-mm-dd hh:nn:ss.zzz', Now) + ' - ' + AText + sLineBreak);
  except
    // ignore
  end;
end;

procedure TFrmPrincipal.BtnAddPointClick(Sender: TObject);
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  if not FDrawSvc.IsActive then
    Exit;
  FDrawSvc.AddPoint;
  UpdateInfo;
  UpdateOverlay;
end;

procedure TFrmPrincipal.BtnClearClick(Sender: TObject);
const
  DEFAULT_LAT = -23.55052;
  DEFAULT_LON = -46.633308;
var
  HasSomethingToClear: Boolean;
  Z: Single;
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;

  HasSomethingToClear := (FDrawSvc <> nil) and (FDrawSvc.IsActive or (FDrawSvc.PointCount > 0))
    or (FPolygon <> nil) or (FLinePreview <> nil) or (FMarkerCurrent <> nil);

  if not HasSomethingToClear then
    Exit;

  MessageDlg('Deseja remover o desenho?', TMsgDlgType.mtConfirmation, [TMsgDlgBtn.mbYes, TMsgDlgBtn.mbNo], 0,
    procedure(const AResult: TModalResult)
    begin
      if AResult <> mrYes then
        Exit;

      if (FDrawSvc <> nil) and FDrawSvc.IsActive then
        FDrawSvc.Stop;

      // Stop não limpa a lista de pontos; então reinicia/zera para evitar redraw posterior
      if (FDrawSvc <> nil) then
      begin
        FDrawSvc.Start(TMapCoordinate.Create(0, 0));
        FDrawSvc.Stop;
      end;

      FMapSvc.ClearMapObjects;
      FMarkerCurrent := nil;
      FPolygon := nil;
      FLinePreview := nil;

      // Força refresh visual do mapa (alguns providers podem deixar overlay "fantasma")
      MapView1.Location := TMapCoordinate.Create(DEFAULT_LAT, DEFAULT_LON);
      MapView1.Repaint;
      Z := MapView1.Zoom;
      MapView1.Zoom := Z + 0.01;
      MapView1.Zoom := Z;

      // Fallback definitivo: recria o componente do mapa para zerar cache do provider (Android/iOS)
      RecreateMapView;

//      // Recarrega o componente (workaround para overlays que não somem no provider)
//      MapView1.Visible := False;
//      MapView1.Visible := True;
//
//      // Alguns providers só limpam de vez ao alternar MapType; faz via RTTI para compatibilidade
//      try
//        var Ctx: TRttiContext := TRttiContext.Create;
//        var T: TRttiType := Ctx.GetType(MapView1.ClassType);
//        var P: TRttiProperty := T.GetProperty('MapType');
//        if (P <> nil) and P.IsWritable then
//        begin
//          var Cur: TValue := P.GetValue(MapView1);
//          // tenta alternar entre Normal e Satellite (se existir no enum) e volta
//          P.SetValue(MapView1, TValue.From<TMapType>(TMapType.Satellite));
//          P.SetValue(MapView1, Cur);
//        end;
//      except
//        // ignore
//      end;

      FAutoAddAccumMeters := 0;
      FLastAreaM2 := 0;

      MapView1.HitTest := True;

      if Assigned(LayoutMapOverlay) then
      begin
        pnlPin.Visible := True;
        LayoutMapOverlay.Visible := True;
      end;

      if Assigned(CirclePin) then
        CirclePin.Visible := True;

      UpdateInfo;
    end);
end;

procedure TFrmPrincipal.RecreateMapView;
var
  OldMap: TMapView;
  NewMap: TMapView;
  OldLoc: TMapCoordinate;
  OldZoom: Single;
begin
  if not Assigned(MapView1) then
    Exit;

  OldMap := MapView1;
  OldLoc := OldMap.Location;
  OldZoom := OldMap.Zoom;

  // Evita conflito de Name ao criar um novo MapView
  try
    OldMap.Name := 'MapViewOld';
  except
    // ignore
  end;

  // Cria novo mapa
  NewMap := TMapView.Create(Self);
  NewMap.Name := 'MapView1';
  NewMap.Align := TAlignLayout.Client;
  NewMap.Parent := Self;
  NewMap.Zoom := OldZoom;
  NewMap.Location := OldLoc;

  // Coloca o pin de volta em cima do novo mapa
  if Assigned(pnlPin) then
  begin
    pnlPin.Parent := NewMap;
    pnlPin.Align := TAlignLayout.Center;
  end;

  // Mantém o painel inferior por cima do mapa
  if Assigned(LayoutBottom) then
    LayoutBottom.BringToFront;

  // Troca referência do form
  MapView1 := NewMap;

  // Recria serviço do mapa para apontar para o novo componente
  FreeAndNil(FMapSvc);
  FMapSvc := TMapService.Create(MapView1);

  // Destrói o mapa antigo por último
  try
    OldMap.Parent := nil;
  except
    // ignore
  end;
  OldMap.Free;
end;

procedure TFrmPrincipal.BtnFinishClick(Sender: TObject);
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  if not FDrawSvc.IsActive then
    Exit;

  if FDrawSvc.PointCount < 3 then
  begin
    ShowMessage('Adicione ao menos 3 pontos antes de finalizar.');
    Exit;
  end;

  // Fecha e desenha o polígono final
  FMapSvc.ClearMapObjects;
  FPolygon := nil;
  FLinePreview := nil;
  FMapSvc.CreateOrUpdatePolygon(FPolygon, FDrawSvc.BuildClosedPoints);

  FDrawSvc.Stop;
  MapView1.HitTest := True;
  if Assigned(LayoutMapOverlay) then
  begin
    pnlPin.Visible := False;
    LayoutMapOverlay.Visible := True;
  end;

  if Assigned(CirclePin) then
    CirclePin.Visible := True;
  UpdateInfo;
end;

procedure TFrmPrincipal.BtnLoadLastClick(Sender: TObject);
var
  Id: Int64;
  T: TTalhao;
  i: Integer;
  LatMin, LatMax, LonMin, LonMax: Double;
  CenterLat, CenterLon: Double;
  Pts: TArray<TMapCoordinate>;
  AreaM2: Double;
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  Id := GetSelectedTalhaoId2;
  if Id <= 0 then
    Id := GetLastTalhaoId;
  if Id <= 0 then
  begin
    ShowMessage('Nenhum talhão salvo ainda.');
    Exit;
  end;

  if not FRepo1.LoadTalhao(Id, T) then
  begin
    ShowMessage('Falha ao carregar talhão.');
    Exit;
  end;
  try
    FMapSvc.ClearMapObjects;
    FMarkerCurrent := nil;
    FPolygon := nil;
    FLinePreview := nil;

    LatMin := T.Points[0].Latitude;
    LatMax := LatMin;
    LonMin := T.Points[0].Longitude;
    LonMax := LonMin;

    for i := 1 to T.Points.Count - 1 do
    begin
      LatMin := Min(LatMin, T.Points[i].Latitude);
      LatMax := Max(LatMax, T.Points[i].Latitude);
      LonMin := Min(LonMin, T.Points[i].Longitude);
      LonMax := Max(LonMax, T.Points[i].Longitude);
    end;

    CenterLat := (LatMin + LatMax) / 2;
    CenterLon := (LonMin + LonMax) / 2;
    FMapSvc.SetCenter(CenterLat, CenterLon, 17);

    SetLength(Pts, T.Points.Count + 1);
    for i := 0 to T.Points.Count - 1 do
      Pts[i] := T.Points[i];
    Pts[High(Pts)] := T.Points[0];

    FMapSvc.CreateOrUpdatePolygon(FPolygon, Pts);

    AreaM2 := TGeoUtils.PolygonAreaMeters2_Equirect(T.Points);
    FLastAreaM2 := AreaM2;
    FLastSavedTalhaoId := T.Id;
    UpdateInfo;
  finally
    T.Done;
  end;
end;

procedure TFrmPrincipal.BtnSaveClick(Sender: TObject);
var
  Id: Int64;
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  if FDrawSvc.IsActive then
  begin
    ShowMessage('Finalize o desenho antes de salvar.');
    Exit;
  end;

  if (FPolygon = nil) or (FDrawSvc.GetCommittedPoints.Count < 3) then
  begin
    ShowMessage('Nenhum talhão válido para salvar.');
    Exit;
  end;

  Id := FRepo1.InsertTalhao(FDrawSvc.GetCommittedPoints);
  FLastSavedTalhaoId := Id;
  UpdateInfo;
  UpdateTalhoes;
  if Assigned(CmbTalhoes2) then
    CmbTalhoes2.ItemIndex := 0;
  ShowMessage(Format('Talhão salvo. ID=%d', [Id]));
end;

procedure TFrmPrincipal.BtnStartClick(Sender: TObject);
var
  C: TMapCoordinate;
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  C := FMapSvc.GetCenter;
  FDrawSvc.Start(C);
  FDrawSvc.AddPoint;
  MapView1.HitTest := False;

  if Assigned(LayoutMapOverlay) then
  begin
    pnlPin.Visible := False;
    LayoutMapOverlay.Visible := False;
  end;

  if Assigned(CirclePin) then
    CirclePin.Visible := False;

  FAutoAddAccumMeters := 0;
  FLastAreaM2 := 0;
  UpdateInfo;
  UpdateOverlay;
end;

procedure TFrmPrincipal.BtnUpClick(Sender: TObject);
begin
  if not Ready then
  begin
    Toast('Ainda inicializando...');
    Exit;
  end;
  if Sender = BtnUp then
    MoveCurrent(FStepMeters, 0)
  else if Sender = BtnDown then
    MoveCurrent(-FStepMeters, 0)
  else if Sender = BtnLeft then
    MoveCurrent(0, -FStepMeters)
  else if Sender = BtnRight then
    MoveCurrent(0, FStepMeters);

  if Sender = BtnUpLeft then
    MoveCurrent(FStepMeters, -FStepMeters)
  else if Sender = BtnUpRight then
    MoveCurrent(FStepMeters, FStepMeters)
  else if Sender = BtnDownLeft then
    MoveCurrent(-FStepMeters, -FStepMeters)
  else if Sender = BtnDownRight then
    MoveCurrent(-FStepMeters, FStepMeters);
end;

procedure TFrmPrincipal.PadBtnMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if not Ready then
    Exit;
  if not Assigned(FPadTimer) then
    Exit;
  if not FDrawSvc.IsActive then
    Exit;

  FPadNorthMeters := 0;
  FPadEastMeters := 0;

  if Sender = BtnUp then
    FPadNorthMeters := FStepMeters
  else if Sender = BtnDown then
    FPadNorthMeters := -FStepMeters
  else if Sender = BtnLeft then
    FPadEastMeters := -FStepMeters
  else if Sender = BtnRight then
    FPadEastMeters := FStepMeters;

  if Sender = BtnUpLeft then
  begin
    FPadNorthMeters := FStepMeters;
    FPadEastMeters := -FStepMeters;
  end
  else if Sender = BtnUpRight then
  begin
    FPadNorthMeters := FStepMeters;
    FPadEastMeters := FStepMeters;
  end
  else if Sender = BtnDownLeft then
  begin
    FPadNorthMeters := -FStepMeters;
    FPadEastMeters := -FStepMeters;
  end
  else if Sender = BtnDownRight then
  begin
    FPadNorthMeters := -FStepMeters;
    FPadEastMeters := FStepMeters;
  end;

  if (FPadNorthMeters <> 0) or (FPadEastMeters <> 0) then
    FPadTimer.Enabled := True;
end;

procedure TFrmPrincipal.PadBtnMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Assigned(FPadTimer) then
    FPadTimer.Enabled := False;
  FPadNorthMeters := 0;
  FPadEastMeters := 0;
end;

procedure TFrmPrincipal.UpdatePadVector(const X, Y: Single);
var
  CX, CY: Single;
  DX, DY: Single;
  NX, NY: Single;
  Dead: Single;
begin
  if not Ready then
    Exit;
  if not Assigned(LayoutPad) then
    Exit;
  if not Assigned(FPadTimer) then
    Exit;
  if not FDrawSvc.IsActive then
    Exit;

  CX := LayoutPad.Width / 2;
  CY := LayoutPad.Height / 2;

  DX := X - CX;
  DY := Y - CY;

  if CX <= 0 then
    Exit;
  if CY <= 0 then
    Exit;

  NX := DX / CX;
  NY := DY / CY;

  if NX > 1 then NX := 1;
  if NX < -1 then NX := -1;
  if NY > 1 then NY := 1;
  if NY < -1 then NY := -1;

  Dead := 0.25;
  if Abs(NX) < Dead then NX := 0;
  if Abs(NY) < Dead then NY := 0;

  // Y cresce para baixo, então norte é -NY
  if NX > 0 then
    FPadEastMeters := FStepMeters
  else if NX < 0 then
    FPadEastMeters := -FStepMeters
  else
    FPadEastMeters := 0;

  if NY < 0 then
    FPadNorthMeters := FStepMeters
  else if NY > 0 then
    FPadNorthMeters := -FStepMeters
  else
    FPadNorthMeters := 0;

  if (FPadNorthMeters = 0) and (FPadEastMeters = 0) then
    FPadTimer.Enabled := False
  else
    FPadTimer.Enabled := True;
end;

procedure TFrmPrincipal.PadMouseDown(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  UpdatePadVector(X, Y);
end;

procedure TFrmPrincipal.PadMouseMove(Sender: TObject; Shift: TShiftState; X, Y: Single);
begin
  // enquanto arrasta o dedo, atualiza direção (inclui diagonais)
  UpdatePadVector(X, Y);
end;

procedure TFrmPrincipal.PadMouseUp(Sender: TObject; Button: TMouseButton; Shift: TShiftState; X, Y: Single);
begin
  if Assigned(FPadTimer) then
    FPadTimer.Enabled := False;
  FPadNorthMeters := 0;
  FPadEastMeters := 0;
end;

procedure TFrmPrincipal.FormCreate(Sender: TObject);
const
  DEFAULT_LAT = -23.55052;
  DEFAULT_LON = -46.633308;
begin
  FStepMeters := 1.0;
  FLastSavedTalhaoId := 0;
  FLastAreaM2 := 0;

  SetDemo2Enabled(False);

  // Deixa o mapa aparecer primeiro (evita "travar no splash" por trabalho pesado no OnCreate)
  MapView1.Zoom := 17;
  MapView1.Location := TMapCoordinate.Create(DEFAULT_LAT, DEFAULT_LON);
  UpdateInfo;

  // Inicialização post-create
  InitTimer.Interval := 10;
  InitTimer.Enabled := True;
end;

procedure TFrmPrincipal.FormDestroy(Sender: TObject);
var
  I: Integer;
begin
  if Assigned(FPadTimer) then
    FPadTimer.Enabled := False;

  FPadTimer.Free;

  if Assigned(CmbTalhoes2) then
  begin
    for I := 0 to CmbTalhoes2.Items.Count - 1 do
      CmbTalhoes2.Items.Objects[I].Free;
    CmbTalhoes2.Clear;
  end;

  FDrawSvc.Free;
  FMapSvc.Free;
  FRepo1.Free;
  FConn.Free;
end;

procedure TFrmPrincipal.InitTimerTimer(Sender: TObject);
begin
  InitTimer.Enabled := False;
  try
    // Inicializa (SQLite + serviços de mapa/desenho)
    if not Assigned(FConn) then
      FConn := TDb.CreateConnection;

    FConn.Connected := True;
    TDb.EnsureSchema(FConn);

    if not Assigned(FRepo1) then
      FRepo1 := TTalhaoRepository.Create(FConn);
    if not Assigned(FMapSvc) then
      FMapSvc := TMapService.Create(MapView1);
    if not Assigned(FDrawSvc) then
      FDrawSvc := TPolygonDrawService.Create;

    if not Assigned(FPadTimer) then
    begin
      FPadTimer := TTimer.Create(Self);
      FPadTimer.Enabled := False;
      FPadTimer.Interval := 120;
      FPadTimer.OnTimer := PadTimerTick;
    end;

    if Assigned(BtnUp) then
    begin
      BtnUp.OnMouseDown := PadBtnMouseDown;
      BtnUp.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnDown) then
    begin
      BtnDown.OnMouseDown := PadBtnMouseDown;
      BtnDown.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnLeft) then
    begin
      BtnLeft.OnMouseDown := PadBtnMouseDown;
      BtnLeft.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnRight) then
    begin
      BtnRight.OnMouseDown := PadBtnMouseDown;
      BtnRight.OnMouseUp := PadBtnMouseUp;
    end;

    if Assigned(BtnUpLeft) then
    begin
      BtnUpLeft.OnMouseDown := PadBtnMouseDown;
      BtnUpLeft.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnUpRight) then
    begin
      BtnUpRight.OnMouseDown := PadBtnMouseDown;
      BtnUpRight.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnDownLeft) then
    begin
      BtnDownLeft.OnMouseDown := PadBtnMouseDown;
      BtnDownLeft.OnMouseUp := PadBtnMouseUp;
    end;
    if Assigned(BtnDownRight) then
    begin
      BtnDownRight.OnMouseDown := PadBtnMouseDown;
      BtnDownRight.OnMouseUp := PadBtnMouseUp;
    end;

    if Assigned(LayoutPad) then
    begin
      LayoutPad.OnMouseDown := PadMouseDown;
      LayoutPad.OnMouseMove := PadMouseMove;
      LayoutPad.OnMouseUp := PadMouseUp;
    end;

    UpdateTalhoes;

    SetDemo2Enabled(True);
    UpdateInfo;
  except
    on E: Exception do
    begin
      AppendLog('InitTimerTimer: ' + E.ClassName + ' - ' + E.Message);
      SetDemo2Enabled(False);
      Toast('Falha init demo 2: ' + E.Message);
    end;
  end;
end;

function TFrmPrincipal.GetLastTalhaoId: Int64;
var
  Q: TFDQuery;
begin
  Result := 0;
  if not Ready then
    Exit;
  Q := TFDQuery.Create(nil);
  try
    Q.Connection := FConn;
    Q.SQL.Text := 'SELECT id FROM talhao ORDER BY id DESC LIMIT 1';
    Q.Open;
    if not Q.Eof then
      Result := Q.Fields[0].AsLargeInt;
  finally
    Q.Free;
  end;
end;

procedure TFrmPrincipal.MapViewMarkerClick(Marker: TMapMarker);
begin
    showmessage('Mostrar detalhes do técnico: ' + Marker.Descriptor.Title);
end;

procedure TFrmPrincipal.MapViewMarkerDragEnd(Marker: TMapMarker);
begin
    showmessage(Marker.Descriptor.Position.Latitude.ToString + ' - ' +
                Marker.Descriptor.Position.Longitude.ToString);
end;

procedure TFrmPrincipal.MoveCurrent(const ANorthMeters, AEastMeters: Double);
var
  Lat, Lon: Double;
  C: TMapCoordinate;
begin
  if not Ready then
    Exit;
  if not FDrawSvc.IsActive then
    Exit;

  C := FDrawSvc.GetCurrent;
  Lat := C.Latitude;
  Lon := C.Longitude;
  TGeoUtils.MoveLatLonMeters(Lat, Lon, ANorthMeters, AEastMeters);
  FDrawSvc.SetCurrent(TMapCoordinate.Create(Lat, Lon));

  UpdateInfo;
  UpdateOverlay;
end;

procedure TFrmPrincipal.TimerJoystickTimer(Sender: TObject);
begin
  // Ajusta o último ponto desenhado (precisão em campo)
  if (Abs(FJoyDX) < 0.001) and (Abs(FJoyDY) < 0.001) then Exit;
end;

procedure TFrmPrincipal.Toast(const S: string);
begin
//
end;

procedure TFrmPrincipal.UpdateInfo;
var
  C: TMapCoordinate;
  Preview: TArray<TMapCoordinate>;
  I, StartIdx: Integer;
  D: Double;
begin
  C := MapView1.Location;
  LblInfo.Text := Format('Centro: %.6f, %.6f | Zoom: %.1f | Step: %.1f m', [C.Latitude, C.Longitude, MapView1.Zoom, FStepMeters]);
  if FDrawSvc <> nil then
  begin
    if FDrawSvc.IsActive then
      LblInfo.Text := LblInfo.Text + sLineBreak + Format('Desenho ativo | Pontos: %d', [FDrawSvc.PointCount])
    else
      LblInfo.Text := LblInfo.Text + sLineBreak + 'Desenho inativo';
  end;

  if Assigned(LayoutMapOverlay) then
  begin
    pnlPin.Visible := (FDrawSvc <> nil) and (not FDrawSvc.IsActive);
    LayoutMapOverlay.Visible := (FDrawSvc <> nil) and (not FDrawSvc.IsActive);
  end;

  if Assigned(CirclePin) then
    CirclePin.Visible := (FDrawSvc <> nil) and (not FDrawSvc.IsActive);

  if (FDrawSvc <> nil) and FDrawSvc.IsActive then
  begin
    Preview := FDrawSvc.BuildPreviewPoints;
    if Length(Preview) >= 2 then
    begin
      StartIdx := Length(Preview) - 6;
      if StartIdx < 1 then StartIdx := 1;
      for I := StartIdx to Length(Preview) - 1 do
      begin
        D := DistanceMeters(Preview[I - 1], Preview[I]);
        LblInfo.Text := LblInfo.Text + sLineBreak + Format('P%d -> P%d: %s', [I, I + 1, FormatDistance(D)]);
      end;
    end;
  end;

  if FLastSavedTalhaoId > 0 then
    LblInfo.Text := LblInfo.Text + sLineBreak + Format('Último talhão salvo: %d', [FLastSavedTalhaoId]);

  if FLastAreaM2 > 0 then
    LblArea.Text := Format('Área aprox: %.2f m² (%.4f ha)', [FLastAreaM2, FLastAreaM2 / 10000.0])
  else
    LblArea.Text := 'Área aprox: -';
end;

procedure TFrmPrincipal.UpdateOverlay;
var
  Preview: TArray<TMapCoordinate>;
  Closed: TArray<TMapCoordinate>;
  AreaM2: Double;
  TmpList: TList<TMapCoordinate>;
  i: Integer;
begin
  if not Ready then
    Exit;
  if not FDrawSvc.IsActive then
    Exit;

  // Preview sem pins: desenha linha (polyline) e evita acúmulo limpando overlays
  FMapSvc.ClearMapObjects;
  FMarkerCurrent := nil;
  FPolygon := nil;
  FLinePreview := nil;

  Preview := FDrawSvc.BuildPreviewPoints;
  if Length(Preview) >= 2 then
  begin
    FMapSvc.CreateOrUpdatePolyline(FLinePreview, Preview);

    if FDrawSvc.PointCount >= 3 then
    begin
      TmpList := TList<TMapCoordinate>.Create;
      try
        Closed := FDrawSvc.BuildClosedPoints;
        for i := 0 to Length(Closed) - 2 do
          TmpList.Add(Closed[i]);
        AreaM2 := TGeoUtils.PolygonAreaMeters2_Equirect(TmpList);
        FLastAreaM2 := AreaM2;
        UpdateInfo;
      finally
        TmpList.Free;
      end;
    end;
  end;
end;

end.
