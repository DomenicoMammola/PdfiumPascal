unit PdfiumPascalThumbnailsPanelCtrl;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Classes,  Controls, ExtCtrls, Forms, Graphics, StdCtrls,
  Contnrs,
  PdfiumCore, PdfiumPascalViewPageCtrl;

type

  { TPdfPageThumbnailPanel }

(*  TPdfPageThumbnailPanel = class(TCustomPanel)
  strict private
    const MARGIN_WIDTH : integer = 20;
  strict private
    FPage : TPdfPage;
    FCachedBitmap : TBitmap;
    FViewportX, FViewportY : integer;
    procedure SetPage(AValue: TPdfPage);
    procedure AdjustGeometry(out aPageWidth, aPageHeight, aViewportX, aViewportY : integer);
  protected
    procedure Paint; override;
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    property Page : TPdfPage read FPage write SetPage;
  end;*)

  { TPdfThumbnailsPanel }

  { TPdfThumbnailsPanelMouseMoveData }

  TPdfThumbnailsPanelMouseMoveData = record
    MouseOnPage : boolean;
    IdxCurrentPage : integer;

    procedure Clear;
  end;

  TPdfThumbnailsPanelClickOnThumbnailEvent = procedure (aPageIdx : integer) of object;

  TPdfThumbnailsPanel = class(TCustomControl)
  strict private
    const TEXT_HEIGHT : integer = 10;
  strict private
    FCurrentPageIdx : integer;
    FDocument : TPdfDocument;
    FScrollbar : TScrollBar;
    FPages : TObjectList;
    FTextColor : TColor;
    FMarginWidth : integer;
    FMouseMoveData : TPdfThumbnailsPanelMouseMoveData;
    FOnClickOnThumbnail : TPdfThumbnailsPanelClickOnThumbnailEvent;

    procedure Rebuild;
    procedure SetDocument(aValue : TPdfDocument);
    procedure PaintPage(const aPage : TPdfPage; const aPageIndex : integer; const aDrawingRect : TRect);
    procedure CalculateGeometryOfPage(const aDrawingRect : TRect; const aPage : TPdfPage; out aPageWidth, aPageHeight, aViewportX, aViewportY : integer);
    procedure UpdateMouseMoveData(X, Y: integer);
    function GetSquareSize : integer;
  protected
    procedure Paint; override;
    procedure MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer); override;
    procedure MouseMove(Shift: TShiftState; X, Y: integer); override;
    procedure Click; override;
    procedure DblClick; override;

  public
    constructor Create(AOwner: TComponent); override;
    destructor Destroy; override;

    property Document : TPdfDocument read FDocument write SetDocument;
    property Scrollbar : TScrollBar read FScrollbar write FScrollbar;
    property TextColor : TColor read FTextColor write FTextColor;
    property MarginWidth : integer read FMarginWidth write FMarginWidth;

    property OnClickOnThumbnail : TPdfThumbnailsPanelClickOnThumbnailEvent read FOnClickOnThumbnail write FOnClickOnThumbnail;
  end;

  { TPdfThumbnailsControl }

  TPdfThumbnailsControl = class(TCustomPanel)
  strict private
    FDocument : TPdfDocument;
    FScrollbar : TScrollBar;
    FPanel : TPdfThumbnailsPanel;
    FViewControl : TPdfPageViewControl;
    procedure SetDocument(AValue: TPdfDocument);
    procedure OnChangeScrollbar(aSender: TObject);
    procedure OnClickOnThumbnail(aPageIdx : integer);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property Document : TPdfDocument read FDocument write SetDocument;
    property ViewControl : TPdfPageViewControl read FViewControl write FViewControl;
  end;


  { TPdfThumbsControl }
(*
  TPdfThumbsControl = class(TCustomPanel)
  strict private
    FDocument: TPdfDocument;
    FScrollBox : TScrollBox;
    FPanels : TList;
    procedure SetDocument(AValue: TPdfDocument);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;

    property Document: TPdfDocument read FDocument write SetDocument;
  end;*)

implementation

uses
  SysUtils, Math, LCLIntf, LCLType;

type

  { TPageThumbData }

  TPageThumbData = class
  strict private
    FCachedBitmap : TBitmap;
    FViewportX : integer;
    FViewportY : integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RebuildCachedBitmap(aPage : TPdfPage; const aWidth, aHeight : integer);

    property CachedBitmap : TBitmap read FCachedBitmap;
    property viewportX : integer read FViewportX write FViewportX;
    property viewportY : integer read FViewportY write FViewportY;
  end;

{ TPageThumbData }

constructor TPageThumbData.Create;
begin
  FCachedBitmap := nil;
  FViewportX := 0;
  FViewportY := 0;
end;

destructor TPageThumbData.Destroy;
begin
  FreeAndNil(FCachedBitmap);
  inherited Destroy;
end;

procedure TPageThumbData.RebuildCachedBitmap(aPage: TPdfPage; const aWidth, aHeight: integer);
begin
  FreeAndNil(FCachedBitmap);
  FCachedBitmap:= TBitmap.Create;
  FCachedBitmap.Width:= aWidth;
  FCachedBitmap.Height:= aHeight;
  FCachedBitmap.Canvas.Brush.Style:= bsSolid;
  //FCachedBitmap.Canvas.Brush.Color:= clWhite;
  //FCachedBitmap.Canvas.FillRect(0, 0, FCachedBitmap.Width, FCachedBitmap.Height);

  if Assigned(GraphicsBackend_DrawPageToCanvas) then
    GraphicsBackend_DrawPageToCanvas(aPage, FCachedBitmap.Canvas, 0, 0, aWidth, aHeight, prNormal, [], clWhite);
end;

{ TPdfThumbnailsPanelMouseMoveData }

procedure TPdfThumbnailsPanelMouseMoveData.Clear;
begin
  MouseOnPage := false;
  IdxCurrentPage := -1;
end;

{ TPdfPageThumbnailPanel }
(*
procedure TPdfPageThumbnailPanel.SetPage(AValue: TPdfPage);
begin
  if FPage=AValue then Exit;
  FPage:=AValue;
  FreeAndNil(FCachedBitmap);
end;

procedure TPdfPageThumbnailPanel.AdjustGeometry (out aPageWidth, aPageHeight, aViewportX, aViewportY : integer);
var
  relPage, relViewport : double;
  ch, cw : integer;
  scroolbarSize : integer;
begin
//  LCLIntf.GetSystemMetrics(SM_CXVSCROLL);
  scroolbarSize := LCLIntf.GetSystemMetrics(SM_CYHSCROLL);
  ch := ClientRect.Height - (2 * MARGIN_WIDTH) - scroolbarSize;
  cw := ClientRect.Width - (2 * MARGIN_WIDTH);
  relPage:= FPage.Height / FPage.Width;
  relViewport:= ch / cw;

  if (relViewport > relPage) then
  begin
    aPageWidth := cw;
    aPageHeight := min(ch, round(aPageWidth * FPage.Height / FPage.Width));
    aViewportX := MARGIN_WIDTH;
    aViewportY := MARGIN_WIDTH + ((ch - aPageHeight) div 2);
  end
  else
  begin
    aPageHeight := ch;
    aPageWidth := min(cw, round(aPageHeight * FPage.Width / FPage.Height));
    aViewportX := MARGIN_WIDTH + ((cw - aPageWidth) div 2);
    aViewportY := MARGIN_WIDTH;
  end;
end;

procedure TPdfPageThumbnailPanel.Paint;
var
  pageWidth, pageHeight : Integer;
begin
  inherited Paint;
  Canvas.Brush.Style:= bsSolid;
  Canvas.Brush.Color:= Self.Color;
  Canvas.FillRect(ClientRect);

  if Assigned(FPage) then
  begin
    if not Assigned(FCachedBitmap) then
    begin
      AdjustGeometry(pageWidth, pageHeight, FViewportX, FViewportY);

      FCachedBitmap:= TBitmap.Create;
      FCachedBitmap.Width:= pageWidth;
      FCachedBitmap.Height:= pageHeight;
      FCachedBitmap.Canvas.Brush.Style:= bsSolid;
      FCachedBitmap.Canvas.Brush.Color:= clWhite;
      FCachedBitmap.Canvas.FillRect(0, 0, FCachedBitmap.Width, FCachedBitmap.Height);

      if Assigned(GraphicsBackend_DrawPageToCanvas) then
        GraphicsBackend_DrawPageToCanvas(FPage, FCachedBitmap.Canvas, 0, 0, pageWidth, pageHeight, prNormal, [], clWhite);
    end;

    Self.Canvas.Draw(FViewportX, FViewportY, FCachedBitmap);
  end;
end;

constructor TPdfPageThumbnailPanel.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FPage := nil;
  FCachedBitmap := nil;
  Color:= clDkGray;
end;

destructor TPdfPageThumbnailPanel.Destroy;
begin
  FreeAndNil(FCachedBitmap);
  inherited Destroy;
end;
*)

{ TPdfThumbnailsPanel }

procedure TPdfThumbnailsPanel.Rebuild;
var
  i : integer;
begin
  FPages.Clear;
  if not Assigned(FDocument) then
    exit;
  for i := 0 to FDocument.PageCount - 1 do
    FPages.Add(TPageThumbData.Create);
end;

procedure TPdfThumbnailsPanel.SetDocument(aValue: TPdfDocument);
begin
  FDocument:=AValue;
  Rebuild;
  Invalidate;
end;

procedure TPdfThumbnailsPanel.PaintPage(const aPage : TPdfPage; const aPageIndex : integer; const aDrawingRect : TRect);
var
  curData : TPageThumbData;
  pw, ph, vx, vy : integer;
  nbp : String;
begin
  Canvas.Brush.Color:= Self.Color;
  nbp := IntToStr(aPageIndex + 1);

  curData := FPages.Items[aPageIndex] as TPageThumbData;
  if not Assigned(curData.CachedBitmap) then
  begin
    CalculateGeometryOfPage(aDrawingRect, aPage, pw, ph, vx, vy);
    curData.RebuildCachedBitmap(aPage, pw, ph);
    curData.viewPortX:= vx;
    curData.viewPortY:= vy;
  end;

  Canvas.Draw(curData.viewportX + aDrawingRect.Left, curData.viewportY, curData.CachedBitmap);
  Canvas.Pen.Color:= Self.TextColor;
  pw := Canvas.TextExtent(nbp).Width;
  Canvas.TextOut(aDrawingRect.Left + ((aDrawingRect.Width - pw) div 2), aDrawingRect.Bottom - FMarginWidth, nbp);
end;

procedure TPdfThumbnailsPanel.CalculateGeometryOfPage(const aDrawingRect: TRect; const aPage : TPdfPage; out aPageWidth, aPageHeight, aViewportX, aViewportY: integer);
var
  relPage, relViewport : double;
  ch, cw : integer;
begin
  ch := aDrawingRect.Height - (2 * FMarginWidth) - TEXT_HEIGHT;
  cw := aDrawingRect.Width - (2 * FMarginWidth);
  relPage:= aPage.Height / aPage.Width;
  relViewport:= ch / cw;

  if (relViewport > relPage) then
  begin
    aPageWidth := cw;
    aPageHeight := min(ch, round(aPageWidth * aPage.Height / aPage.Width));
    aViewportX := FMarginWidth;
    aViewportY := FMarginWidth + ((ch - aPageHeight) div 2);
  end
  else
  begin
    aPageHeight := ch;
    aPageWidth := min(cw, round(aPageHeight * aPage.Width / aPage.Height));
    aViewportX := FMarginWidth + ((cw - aPageWidth) div 2);
    aViewportY := FMarginWidth;
  end;
end;

procedure TPdfThumbnailsPanel.UpdateMouseMoveData(X, Y: integer);
var
  idx, i : integer;
  curData : TPageThumbData;
  l, t : integer;
begin
  FMouseMoveData.Clear;

  if not PtInRect(ClientRect, Classes.Point(X, Y)) then
    exit;

  if not Assigned(FDocument) then
    exit;

  idx := (X div GetSquareSize) + FScrollbar.Position - 1;

  if (idx >= FDocument.PageCount) then
    exit;

  curData := FPages.Items[idx] as TPageThumbData;
  l := ClientRect.Left + ((idx - FScrollbar.Position + 1) * GetSquareSize) + curData.viewportX;
  t := ClientRect.Top + curData.viewportY;
  if PtInRect(Classes.Rect(l, t, l + curData.CachedBitmap.Width, t + curData.CachedBitmap.Height), Classes.Point(X, Y)) then
  begin
    FMouseMoveData.MouseOnPage := true;
    FMouseMoveData.IdxCurrentPage := idx;
  end;
end;

function TPdfThumbnailsPanel.GetSquareSize: integer;
begin
  Result := Self.Height
end;

procedure TPdfThumbnailsPanel.Paint;
var
  i : integer;
  squareSize : integer;
  curDrawingRect : TRect;
begin
  Canvas.Lock;
  try
    Canvas.Pen.Mode := pmCopy;
    Canvas.Brush.Color := Self.Color;
    Canvas.Brush.Style := bsSolid;
    Canvas.FillRect(ClientRect);

    if (not Assigned(FScrollbar)) or (not Assigned(FDocument)) then
      exit;

    squareSize := GetSquareSize;

    for i := FScrollbar.Position to FDocument.PageCount do
    begin
      curDrawingRect.Left := 0 + (i-FScrollbar.Position) * squareSize;
      curDrawingRect.Right := curDrawingRect.Left + squareSize;
      curDrawingRect.Top := 0;
      curDrawingRect.Bottom := squareSize;
      if curDrawingRect.Left > Self.ClientRect.Width then
        break;
      PaintPage(FDocument.Pages[i - 1], i - 1, curDrawingRect);
    end;

  finally
    Canvas.Unlock;
  end;
end;

procedure TPdfThumbnailsPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TPdfThumbnailsPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if (Button = mbLeft) then
  begin
    UpdateMouseMoveData(X, Y);
  end;

  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TPdfThumbnailsPanel.MouseMove(Shift: TShiftState; X, Y: integer);
begin
  UpdateMouseMoveData(X, Y);
  inherited MouseMove(Shift, X, Y);
end;

procedure TPdfThumbnailsPanel.Click;
begin
  if Assigned(FOnClickOnThumbnail) and (FMouseMoveData.MouseOnPage) and (FMouseMoveData.IdxCurrentPage >= 0) then
    FOnClickOnThumbnail(FMouseMoveData.IdxCurrentPage);
  inherited Click;
end;

procedure TPdfThumbnailsPanel.DblClick;
begin
  inherited DblClick;
end;

constructor TPdfThumbnailsPanel.Create(AOwner: TComponent);
begin
  inherited Create(AOwner);
  FCurrentPageIdx := 0;
  FDocument := nil;
  FScrollbar := nil;
  FPages := TObjectList.Create(true);
  Color := clDkGray;
  FTextColor := clBlack;
  FMarginWidth := 20;
  FOnClickOnThumbnail := nil;
end;

destructor TPdfThumbnailsPanel.Destroy;
begin
  FPages.Free;
  inherited Destroy;
end;

{ TPdfThumbnailsControl }

procedure TPdfThumbnailsControl.SetDocument(AValue: TPdfDocument);
begin
  FDocument := AValue;
  FScrollbar.Min := 1;
  FScrollbar.Max := FDocument.PageCount;
  FPanel.Document := FDocument;
end;

procedure TPdfThumbnailsControl.OnChangeScrollbar(aSender: TObject);
begin
  FPanel.Invalidate;
end;

procedure TPdfThumbnailsControl.OnClickOnThumbnail(aPageIdx: integer);
begin
  if Assigned(FViewControl) then
    FViewControl.GotoPage(aPageIdx);
end;

constructor TPdfThumbnailsControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FScrollbar := TScrollBar.Create(Self);
  FScrollbar.Parent := Self;
  FScrollbar.Align := alBottom;
  FScrollbar.Kind:= sbHorizontal;
  FPanel := TPdfThumbnailsPanel.Create(Self);
  FPanel.Parent := Self;
  FPanel.Align := alClient;
  FPanel.Scrollbar := FScrollbar;
  FPanel.OnClickOnThumbnail := OnClickOnThumbnail;
  FScrollbar.OnChange := Self.OnChangeScrollbar;
end;

destructor TPdfThumbnailsControl.Destroy;
begin
  inherited Destroy;
end;

{ TPdfThumbsControl }
(*
procedure TPdfThumbsControl.SetDocument(AValue: TPdfDocument);
var
  i : integer;
  curPanel : TPdfPageThumbnailPanel;
begin

  FScrollBox.Visible:= false;
  try
    for i := 0 to FPanels.Count - 1 do
      TPdfPageThumbnailPanel(FPanels.Items[i]).Free;
    FPanels.Clear;

    FDocument:=AValue;
    for i := FDocument.PageCount - 1 downto 0 do
    begin
      curPanel := TPdfPageThumbnailPanel.Create(FScrollBox);
      curPanel.Parent := FScrollBox;
      curPanel.Width:= FScrollBox.HorzScrollBar.ClientSizeWithoutBar;
      curPanel.Height:= FScrollBox.HorzScrollBar.ClientSizeWithoutBar;
      curPanel.Align:= alLeft;
      curPanel.Page := FDocument.Pages[i];
      FPanels.Add(curPanel);
    end;
  finally
    FScrollBox.Visible:= true;
  end;

end;


constructor TPdfThumbsControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FPanels := TList.Create;
  Self.BorderStyle := bsNone;
  Self.BevelInner := bvNone;
  Self.BevelOuter := bvNone;

  FScrollBox := TScrollBox.Create(Self);
  FScrollBox.Parent := Self;
  FScrollBox.Align := alClient;
  FScrollBox.VertScrollBar.Visible := false;
end;

destructor TPdfThumbsControl.Destroy;
begin
  FPanels.Free;
  inherited Destroy;
end;
*)

end.
