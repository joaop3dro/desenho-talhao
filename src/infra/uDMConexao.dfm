object DMConexao: TDMConexao
  OnCreate = DataModuleCreate
  Height = 480
  Width = 640
  object FDConnection: TFDConnection
    Params.Strings = (
      'LockingMode=Normal'
      'DriverID=SQLite')
    LoginPrompt = False
    Left = 80
    Top = 64
  end
end
