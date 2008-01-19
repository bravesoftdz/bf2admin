unit Main;

interface

uses
  SysUtils, Windows, Messages, Classes, Graphics, Controls,
  Forms, Dialogs, StdCtrls, Buttons, ExtCtrls, Menus, ComCtrls, XPMan,
  Sockets, WinSock, UMD5, Mask, ScktComp, IdBaseComponent, IdComponent,
  IdTCPConnection, IdTCPClient, IdTelnet, CheckLst;

type
  TMainForm = class(TForm)
    XPManifest1: TXPManifest;
    CopyrightPanel: TPanel;
    ButtonBox: TGroupBox;
    LogBox: TGroupBox;
    PlayersListBox: TGroupBox;
    PlayersList: TListBox;
    LoginButton: TButton;
    LogWindow: TMemo;
    AuthBox: TGroupBox;
    LoginLabel: TLabel;
    PasswordLabel: TLabel;
    EnteredLogin: TEdit;
    EnteredPassword: TMaskEdit;
    Socket: TTcpClient;
    Tnt: TIdTelnet;
    Debug: TMemo;
    CheckAuthStart: TButton;
    SafetyExitButton: TButton;
    BitBtn1: TBitBtn;
    RefreshPlayersListBtn: TButton;
    KickPlayerBtn: TButton;
    BanPlayerBtn: TButton;
    AddBadNameBtn: TButton;

    procedure Starting(Sender: TObject);
    procedure CheckAuth(Sender: TObject);
    procedure TestConnection;
    procedure Connecting;
    procedure OnTelnetDataAvailable(Sender: TIdTelnet; Buffer: String);
    procedure DataSorter(Data: String);
    procedure TelnetAuth(DataSeed: String);
    procedure AutoGetPlayersList;
    procedure TempProcedure(Sender: TObject);
    procedure SafetyExit(Sender: TObject);
    procedure RefreshPlayersList(Sender: TObject);
    procedure KickPlayer(Sender: TObject);
    procedure AddBadName(Sender: TObject);
    procedure BanPlayer(Sender: TObject);

  end;

var
  MainForm: TMainForm;

  {Program Auth}
  Login: String;
  Password: String;
  AuthSuccess: Boolean;

  {Connection}
  TestConnectionSuccess: Boolean;
  Err: Boolean;

  {Socket}
  Buffer: String;
  BufferLen: Integer;
  ReceivedText: String;

  {Telnet}
  TntStringNumber: Integer;
  Data: String;
  DataSeed: String;
  TmpPassword: String;
  TmpData: String;
  Temp: String;

  {Data}
  CurPos: Integer;
  CurData: String;
  Player: array[1..100] of String;
  PlayerName: array[1..100] of String;
  PlayerId: array[1..100] of String;
  PlayerIp: array[1..100] of String;
  PlayerCDKey: array[1..100] of String;
  SelectedPlayerNumber: Integer;
  SelectedI: Integer;

  {Other}
  MustExit: Boolean;
  NoVar: Integer;
  i: Integer;


implementation

{$r *.dfm}

procedure TMainForm.Starting(Sender: TObject);
    begin
        TestConnection;
        if ( TestConnectionSuccess = false ) then exit;
        Connecting;
        if ( Err = true ) then exit;
    end;

procedure TMainForm.CheckAuth(Sender: TObject);
    begin
        {Login := EnteredLogin.Text; }
        Login := LowerCase(MD5DigestToStr(MD5String(EnteredLogin.Text)));
        ShowMessage ( Login );
        {Password := EnteredPassword.Text;  }
        Password := LowerCase(MD5DigestToStr(MD5String(EnteredPassword.Text)));
        ShowMessage ( Password );
        AuthSuccess := false;
        if {(( Login = '16d931518c10461131e748e3b84d4546' ) and ( Password = '327a15cb2d7852697f880ba28b15033d' ) or
            ( Login = 'd914e3ecf6cc481114a3f534a5faf90b' ) and ( Password = 'ddb2f1c1e74c0ec2aadb050e4b531f22' ) or
            ( Login = '1fe538d226cf8f5200895c1962a85861' ) and ( Password = '9645ca120158d9d5097ead8044a24235' ))
           }true   then AuthSuccess := true;
        if ( AuthSuccess = false ) then
            begin
                ShowMessage('Неправильный логин или пароль.');
                halt;
            end;
        if ( AuthSuccess = true ) then
            begin
                CheckAuthStart.Enabled := false;
                EnteredLogin.Enabled := false;
                EnteredPassword.Enabled := false;
                LoginButton.Enabled := true;
            end;
    end;

procedure TMainForm.TestConnection;
    begin
        LogWindow.Lines.Add('Устанавливаем IP-адрес');
        LogWindow.Lines.Add('Проверяем соединение');
        Socket.RemoteHost := '10.10.0.19';
        Socket.RemotePort := '4711';
        Socket.Active := true;
        if ( Socket.Connected = true ) then
            begin
                LogWindow.Lines.Add('Есть возможность соединения');
                TestConnectionSuccess := true;
            end
            else
            begin
                LogWindow.Lines.Add('Нет возможности соединения');
                TestConnectionSuccess := false;
            end;
        Socket.Active := false;
    end;

procedure TMainForm.Connecting;
    begin
        LogWindow.Lines.Add('Инициализируем подключение');
        DataSeed := EmptyStr;
        TntStringNumber := 0;
        try
            Tnt.Connect;
            Err := false;
        except
            LogWindow.Lines.Add('Отключено.');
            exit;
        end;
        LoginButton.Enabled := false;
        RefreshPlayersListBtn.Enabled := true;
        KickPlayerBtn.Enabled := true;
        BanPlayerBtn.Enabled := true;
        AddBadNameBtn.Enabled := true;
    end;

procedure TMainForm.OnTelnetDataAvailable(Sender: TIdTelnet; Buffer: String);
    begin
        ReceivedText := Buffer;
        TntStringNumber := TntStringNumber + 1;
        DataSorter(ReceivedText);
    end;

procedure TMainForm.DataSorter(Data: String);
    begin
        TmpData := Data;

        if (( length(Data) = 35 ) and ( TntStringNumber = 2 )) then
            begin
                DataSeed := Data;
                delete(DataSeed, 1, 17);
                delete(DataSeed, 17, 2);
                Debug.Lines.Add(DataSeed);
                TelnetAuth(DataSeed);
            end;

        if ( Data = '### Battlefield 2 ModManager Rcon v3.5.' + #10 ) then LogWindow.Lines.Add('Подключение к консоли установлено.');

        if ( Data = 'Authentication successful, rcon ready.' + #10 ) then AutoGetPlayersList;

        if (( pos('Id: ', Data) <> 0 ) and
            ( pos('CD-key hash: ', Data) <> 0 ) and
            ( pos(' is remote ip: ', Data) <> 0 ) and
            ( pos(' ->', Data) <> 0 )) then
                begin
                    CurData := Data;
                    TmpData := EmptyStr;
                    CurPos := 0;
                    i := 1;
                    while ( length(CurData) > 0 ) do
                        begin
                            CurPos := pos('CD-key hash: ', CurData) + 46;
                            TmpData := copy(CurData, 1, CurPos);
                            delete(CurData, 1, CurPos);
                            while ( pos(#10, TmpData) <> 0 ) do
                                delete(TmpData, pos(#10, TmpData), 1);
                            {Получаем полную строку}
                            Player[i] := TmpData;
                            {Получаем Name}
                            Temp := TmpData;
                            delete(Temp, 1, 9);
                            delete(Temp, pos(' is remote ip', Temp), 1000);
                            PlayerName[i] := Temp;
                            {Получаем ID}
                            Temp := TmpData;
                            delete(Temp, 1, 4);
                            delete(Temp, 3, 1000);
                            if ( pos(' ', Temp) = 1 ) then delete(Temp, 1, 1);
                            PlayerID[i] := Temp;
                            {Получаем IP}
                            Temp := TmpData;
                            delete(Temp, 1, pos('is remote ip: ', Temp) + 13);
                            delete(Temp, pos('->', Temp) - 6, 1000);
                            PlayerIP[i] := Temp;
                            {Получаем CDKey}
                            Temp := TmpData;
                            delete(Temp, 1, pos('CD-key hash: ', Temp) + 12);
                            PlayerCDKey[i] := Temp;

                            PlayersList.AddItem(Player[i], PlayersList);

                            i := i + 1;
                        end;
                end;

        Debug.Lines.Add(Data);
    end;

procedure TMainForm.TelnetAuth(DataSeed: String);
    begin
        TmpPassword := EmptyStr;
        TmpPassword := DataSeed + 'iamgameadminofbf2server';
        Debug.Lines.Add(TmpPassword);
        TmpPassword := LowerCase(MD5DigestToStr(MD5String(TmpPassword)));
        Debug.Lines.Add(TmpPassword);
        try
            LogWindow.Lines.Add('Авторизицация...');
            Tnt.Socket.WriteLn ('login ' + TmpPassword);
        except
            LogWindow.Lines.Add('Авторизация не удалась');
        end;
    end;

procedure TMainForm.AutoGetPlayersList;
    begin
        LogWindow.Lines.Add('Авторизация прошла успешно.');
        Tnt.Socket.WriteLn ('list');
    end;

procedure TMainForm.RefreshPlayersList(Sender: TObject);
    begin
        PlayersList.Clear;
        Tnt.Socket.WriteLn('list');
    end;

procedure TMainForm.KickPlayer(Sender: TObject);
    begin
        try
            SelectedI := PlayersList.ItemIndex + 1;
            Tnt.Socket.WriteLn('kick ' + PlayerID[SelectedI] + ' "HeBbInoJIHeHue npaBuJI CepBepa"');
            RefreshPlayersList ( Nil );
        finally
            LogWindow.Lines.Add('Игрок кикнут:' + PlayerID[SelectedI] + ' ' + PlayerName[SelectedI]);
        end;
    end;

procedure TMainForm.BanPlayer(Sender: TObject);
    begin
        try
            SelectedI := PlayersList.ItemIndex + 1;
            Tnt.Socket.WriteLn('bm addBan Address "" "Perm" "' + PlayerIP[SelectedI] + '"');
            RefreshPlayersList ( Nil );
        finally
            LogWindow.Lines.Add('Маска бана по IP ' + PlayerIP[SelectedI] + ' добавлена');
        end;
    end;

procedure TMainForm.AddBadName(Sender: TObject);
    begin
        try
            SelectedI := PlayersList.ItemIndex + 1;
            Tnt.Socket.WriteLn('exec PB_SV_BadName 30 ' + PlayerName[SelectedI]);
            RefreshPlayersList ( Nil );
        finally
            LogWindow.Lines.Add('Запрещен к использованию ник ' + PlayerName[SelectedI]);
        end;
    end;

procedure TMainForm.TempProcedure(Sender: TObject);
    begin
        ShowMessage(Player[PlayersList.ItemIndex] {+ #13 +
                    PlayerID[PlayersList.ItemIndex + 1] + #13 +
                    PlayerIP[PlayersList.ItemIndex + 1] + #13 +
                    PlayerCDKey[PlayersList.ItemIndex + 1]});
        //Tnt.Socket.WriteLn('banlist');
    end;

procedure TMainForm.SafetyExit(Sender: TObject);
    begin
        try
            if ( Tnt.Connected = true ) then Tnt.Disconnect;
        finally
            Close;
        end;
    end;

begin

ReceivedText := '';

end.
