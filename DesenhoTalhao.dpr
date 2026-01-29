program DesenhoTalhao;

uses
  System.StartUpCopy,
  FMX.Forms,
  uDMConexao in 'src\infra\uDMConexao.pas' {DMConexao: TDataModule},
  UnitPrincipal in 'src\forms\UnitPrincipal.pas' {FrmPrincipal},
  uGeoUtils in 'src\services\uGeoUtils.pas',
  uMapService in 'src\services\uMapService.pas',
  uPolygonDrawService in 'src\services\uPolygonDrawService.pas',
  uTalhaoRepository in 'src\services\uTalhaoRepository.pas',
  uDb in 'src\repositories\uDb.pas';

{$R *.res}

begin
  Application.Initialize;
  Application.CreateForm(TDMConexao, DMConexao);
  Application.CreateForm(TFrmPrincipal, FrmPrincipal);
  Application.Run;
end.
