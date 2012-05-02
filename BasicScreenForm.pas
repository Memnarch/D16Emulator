unit BasicScreenForm;

interface

uses
  Windows, Messages, SysUtils, Variants, Classes, Graphics, Controls, Forms,
  Dialogs, ExtCtrls;

type
  TBasicScreen = class(TForm)
    Screen: TPaintBox;
    ScreenTimer: TTimer;
    procedure ScreenTimerTimer(Sender: TObject);
  private
    { Private declarations }
    procedure NoEraseBKGN(var message: TMessage); message WM_ERASEBKGND;
  public
    { Public declarations }
  end;

var
  BasicScreen: TBasicScreen;

implementation

{$R *.dfm}

procedure TBasicScreen.NoEraseBKGN(var Message: TMessage);
begin
  Message.Result := 1;
end;

procedure TBasicScreen.ScreenTimerTimer(Sender: TObject);
begin
  Screen.Repaint;
end;

end.
