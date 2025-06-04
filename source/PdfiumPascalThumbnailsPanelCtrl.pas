unit PdfiumPascalThumbnailsPanelCtrl;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

uses
  Classes,  Controls, ExtCtrls, Forms, Graphics, StdCtrls,
  LMessages,
  Contnrs,
  PdfiumCore, PdfiumPascalViewPageCtrl;

type
  { TPdfThumbnailsPanelMouseMoveData }

  TPdfThumbnailsPanelMouseMoveData = record
    MouseOnPage : boolean;
    IdxCurrentPage : integer;
    MouseOnSeparator : boolean;
    IdxSeparator : integer;

    procedure Clear;
  end;

  TPdfThumbnailsPanelDarkenProcedure = procedure (aBitmap : TBitmap; ALevel: Byte);
  TPdfThumbnailsPanelClickOnThumbnailEvent = procedure (aPageIdx : integer) of object;

  TPdfThumbnailsPanelOptions = (tpoMovePages);
  TPdfThumbnailsPanelOptionsSet = set of TPdfThumbnailsPanelOptions;

  TPdfThumbnailsPanel = class(TCustomControl)
  strict private
    const TEXT_HEIGHT : integer = 10;
    const DROP_AREA_SIZE : integer = 6;
  strict private
    FCurrentPageIdx : integer;
    FDocument : TPdfDocument;
    FScrollbar : TScrollBar;
    FPages : TObjectList;
    FTextColor : TColor;
    FMarginWidth : integer;
    FMouseMoveData : TPdfThumbnailsPanelMouseMoveData;
    FOnClickOnThumbnail : TPdfThumbnailsPanelClickOnThumbnailEvent;
    FOptions : TPdfThumbnailsPanelOptionsSet;
    FMovingPage : boolean;

    procedure Rebuild;
    procedure SetDocument(aValue : TPdfDocument);
    procedure PaintPage(const aPage : TPdfPage; const aPageIndex : integer; const aDrawingRect : TRect);
    procedure CalculateGeometryOfPage(const aDrawingRect : TRect; const aPage : TPdfPage; out aPageWidth, aPageHeight, aViewportX, aViewportY : integer);
    procedure UpdateMouseMoveData(X, Y: integer);
    function GetSquareSize : integer;
    {$ifdef fpc}
    procedure CMMouseWheel(var Message: TLMMouseEvent); message LM_MOUSEWHEEL;
    {$else}
    procedure WMMouseWheel(var Message: TWMMouseWheel); message WM_MOUSEWHEEL;
    {$endif}
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
    property Options : TPdfThumbnailsPanelOptionsSet read FOptions write FOptions;

    property OnClickOnThumbnail : TPdfThumbnailsPanelClickOnThumbnailEvent read FOnClickOnThumbnail write FOnClickOnThumbnail;
  end;

  TPdfThumbnailsControlOrientation = (tcHorizontal, tcVertical);

  { TPdfThumbnailsControl }

  TPdfThumbnailsControl = class(TCustomPanel)
  strict private
    FDocument : TPdfDocument;
    FScrollbar : TScrollBar;
    FPanel : TPdfThumbnailsPanel;
    FViewControl : TPdfPageViewControl;
    FOrientation : TPdfThumbnailsControlOrientation;

    function GetOptions: TPdfThumbnailsPanelOptionsSet;
    function GetTextColor: TColor;
    procedure SetOptions(AValue: TPdfThumbnailsPanelOptionsSet);
    procedure SetOrientation(AValue: TPdfThumbnailsControlOrientation);
    procedure SetTextColor(AValue: TColor);
    procedure SetDocument(AValue: TPdfDocument);
    procedure OnChangeScrollbar(aSender: TObject);
    procedure OnClickOnThumbnail(aPageIdx : integer);
  public
    constructor Create(TheOwner: TComponent); override;
    destructor Destroy; override;
    property TextColor : TColor read GetTextColor write SetTextColor;
    property Document : TPdfDocument read FDocument write SetDocument;
    property ViewControl : TPdfPageViewControl read FViewControl write FViewControl;
    property Orientation : TPdfThumbnailsControlOrientation read FOrientation write SetOrientation;
    property Options : TPdfThumbnailsPanelOptionsSet read GetOptions write SetOptions;
  end;

var
  GraphicsBackend_DarkenProcedure : TPdfThumbnailsPanelDarkenProcedure;

implementation

uses
  SysUtils, Math, LCLIntf, LCLType, Types;

type

  { TPageThumbData }

  TPageThumbData = class
  strict private
    FCachedBitmap : TBitmap;
    FDarkerCachedBitmap : TBitmap;
    FViewportX : integer;
    FViewportY : integer;
  public
    constructor Create;
    destructor Destroy; override;

    procedure RebuildCachedBitmap(aPage : TPdfPage; const aWidth, aHeight : integer);

    property CachedBitmap : TBitmap read FCachedBitmap;
    property DarkerCachedBitmap : TBitmap read FDarkerCachedBitmap;
    property viewportX : integer read FViewportX write FViewportX;
    property viewportY : integer read FViewportY write FViewportY;
  end;

{ TPageThumbData }

constructor TPageThumbData.Create;
begin
  FCachedBitmap := nil;
  FDarkerCachedBitmap := nil;
  FViewportX := 0;
  FViewportY := 0;
end;

destructor TPageThumbData.Destroy;
begin
  FreeAndNil(FCachedBitmap);
  FreeAndNil(FDarkerCachedBitmap);
  inherited Destroy;
end;

procedure TPageThumbData.RebuildCachedBitmap(aPage: TPdfPage; const aWidth, aHeight: integer);
begin
  FreeAndNil(FCachedBitmap);
  FCachedBitmap:= TBitmap.Create;
  FCachedBitmap.Width:= aWidth;
  FCachedBitmap.Height:= aHeight;
  FCachedBitmap.Canvas.Brush.Style:= bsSolid;
  FreeAndNil(FDarkerCachedBitmap);
  FDarkerCachedBitmap:= TBitmap.Create;
  FDarkerCachedBitmap.Width:= aWidth;
  FDarkerCachedBitmap.Height:= aHeight;
  FDarkerCachedBitmap.Canvas.Brush.Style:= bsSolid;


  if Assigned(GraphicsBackend_DrawPageToCanvas) then
  begin
    GraphicsBackend_DrawPageToCanvas(aPage, FCachedBitmap.Canvas, 0, 0, aWidth, aHeight, prNormal, [], clWhite);
    FDarkerCachedBitmap.Canvas.Draw(0, 0, FCachedBitmap);
    if Assigned(GraphicsBackend_DarkenProcedure) then
      GraphicsBackend_DarkenProcedure(FDarkerCachedBitmap, 30);
  end;
end;

{ TPdfThumbnailsPanelMouseMoveData }

procedure TPdfThumbnailsPanelMouseMoveData.Clear;
begin
  MouseOnPage := false;
  IdxCurrentPage := -1;
  MouseOnSeparator := false;
  IdxSeparator := -1;
end;

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
  sz : TSize;
  lp, tp : integer;
begin
  if (not Assigned(FScrollbar)) or (not Assigned(FDocument)) then
    exit;

  Canvas.Brush.Color:= Self.Color;
  nbp := IntToStr(aPageIndex + 1);

  if Assigned(aPage) then
  begin
    curData := FPages.Items[aPageIndex] as TPageThumbData;
    if not Assigned(curData.CachedBitmap) then
    begin
      CalculateGeometryOfPage(aDrawingRect, aPage, pw, ph, vx, vy);
      curData.RebuildCachedBitmap(aPage, pw, ph);
      curData.viewPortX:= vx;
      curData.viewPortY:= vy;
    end;

    if FMouseMoveData.MouseOnPage and (FMouseMoveData.IdxCurrentPage = aPageIndex) then
      Canvas.Draw(curData.viewportX + aDrawingRect.Left, curData.viewportY + aDrawingRect.Top, curData.CachedBitmap)
    else
      Canvas.Draw(curData.viewportX + aDrawingRect.Left, curData.viewportY + aDrawingRect.Top, curData.DarkerCachedBitmap); // curData.CachedBitmap);
    Canvas.Font.Color := Self.TextColor;
    Canvas.Font.Size := 10;
    sz := Canvas.TextExtent(nbp);
    Canvas.TextOut(aDrawingRect.Left + ((aDrawingRect.Width - sz.Width) div 2), aDrawingRect.Bottom - FMarginWidth , nbp);
  end;

  if FMovingPage and FMouseMoveData.MouseOnSeparator and (FMouseMoveData.IdxSeparator = aPageIndex) then
  begin
    Canvas.Brush.Color:= clGreen;
    Canvas.Pen.Color:= clGreen;
    lp := Max(0, aDrawingRect.Left - (DROP_AREA_SIZE div 2));
    Canvas.FillRect(lp, aDrawingRect.Top, lp + DROP_AREA_SIZE, aDrawingRect.Bottom);
  end;
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
  lpage, tpage, lsquare, tsquare, lastIdx, lastSeparator : integer;
  rectPrev, rectNext : TRect;
  pt : TPoint;
begin
  lastIdx := FMouseMoveData.IdxCurrentPage;
  lastSeparator := FMouseMoveData.IdxSeparator;
  FMouseMoveData.Clear;

  if not PtInRect(ClientRect, Classes.Point(X, Y)) then
    exit;

  if (not Assigned(FDocument)) or (not Assigned(FScrollbar)) then
    exit;

  if FScrollbar.Kind = sbHorizontal then
    idx := (X div GetSquareSize) + FScrollbar.Position - 1
  else
    idx := (Y div GetSquareSize) + FScrollbar.Position - 1;

  if (idx >= FDocument.PageCount) then
    exit;

  curData := FPages.Items[idx] as TPageThumbData;
  if FScrollbar.Kind = sbHorizontal then
  begin
    lsquare := ClientRect.Left + ((idx - FScrollbar.Position + 1) * GetSquareSize);
    tsquare := ClientRect.Top;
    lpage := lsquare + curData.viewportX;
    tpage := tsquare + curData.viewportY;
    rectPrev := Rect(lsquare, tsquare, lsquare + DROP_AREA_SIZE, tsquare + GetSquareSize);
    rectNext := Rect(lsquare + GetSquareSize - DROP_AREA_SIZE, tsquare, lsquare + GetSquareSize, rectPrev.Bottom);
  end
  else
  begin
    lsquare := ClientRect.Left;
    tsquare := ClientRect.Top + ((idx - FScrollbar.Position + 1) * GetSquareSize);
    lpage := lsquare + curData.viewportX;
    tpage := tsquare + curData.viewportY;
    rectPrev := Rect(lsquare, tsquare, lsquare + GetSquareSize, tsquare + DROP_AREA_SIZE);
    rectNext := Rect(lsquare, tsquare + GetSquareSize - DROP_AREA_SIZE, rectPrev.Right, tsquare + GetSquareSize);
  end;
  pt := Classes.Point(X, Y);
  if PtInRect(Classes.Rect(lpage, tpage, lpage + curData.CachedBitmap.Width, tpage + curData.CachedBitmap.Height), pt) then
  begin
    FMouseMoveData.MouseOnPage := true;
    FMouseMoveData.IdxCurrentPage := idx;
  end
  else if PtInRect(rectPrev, pt) then
  begin
    FMouseMoveData.MouseOnSeparator := true;
    FMouseMoveData.IdxSeparator := idx;
  end
  else if PtInRect(rectNext, pt) then
  begin
    FMouseMoveData.MouseOnSeparator := true;
    FMouseMoveData.IdxSeparator := idx + 1;
  end;

  if (lastIdx <> FMouseMoveData.IdxCurrentPage) or (lastSeparator <> FMouseMoveData.IdxSeparator) then
    Invalidate;
end;

function TPdfThumbnailsPanel.GetSquareSize: integer;
begin
  if FScrollbar.Kind = sbHorizontal then
    Result := Self.Height
  else
    Result := Self.Width;
end;

{$ifdef fpc}
procedure TPdfThumbnailsPanel.CMMouseWheel(var Message: TLMMouseEvent);
{$else}
procedure TPdfThumbnailsPanel.WMMouseWheel(var Message: TWMMouseWheel); //message WM_MOUSEWHEEL;
{$endif}
begin
  if Message.WheelDelta < 0 then
    FScrollbar.Position := min(FScrollbar.Max, FScrollbar.Position + 1)
  else
    FScrollbar.Position := max(FScrollbar.Min, FScrollbar.Position - 1);
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
      if FScrollbar.Kind = sbHorizontal then
      begin
        curDrawingRect.Left := 0 + (i-FScrollbar.Position) * squareSize;
        curDrawingRect.Right := curDrawingRect.Left + squareSize;
        curDrawingRect.Top := 0;
        curDrawingRect.Bottom := squareSize;
        if curDrawingRect.Left > Self.ClientRect.Width then
          exit;
      end
      else
      begin
        curDrawingRect.Top := (i-FScrollbar.Position) * squareSize;
        curDrawingRect.Right := squareSize;
        curDrawingRect.Left := 0;
        curDrawingRect.Bottom := curDrawingRect.Top + squareSize;
        if curDrawingRect.Top > Self.ClientRect.Height then
          exit;
      end;
      PaintPage(FDocument.Pages[i - 1], i - 1, curDrawingRect);
    end;

    if FScrollbar.Kind = sbHorizontal then
    begin
      curDrawingRect.Left := 0 + (FDocument.PageCount + 1 -FScrollbar.Position) * squareSize;
      curDrawingRect.Right := curDrawingRect.Left + squareSize;
      curDrawingRect.Top := 0;
      curDrawingRect.Bottom := squareSize;
      if curDrawingRect.Left > Self.ClientRect.Width then
        exit;
    end
    else
    begin
      curDrawingRect.Top := (FDocument.PageCount + 1 -FScrollbar.Position) * squareSize;
      curDrawingRect.Right := squareSize;
      curDrawingRect.Left := 0;
      curDrawingRect.Bottom := curDrawingRect.Top + squareSize;
      if curDrawingRect.Top > Self.ClientRect.Height then
        exit;
    end;
    PaintPage(nil, FDocument.PageCount, curDrawingRect);
  finally
    Canvas.Unlock;
  end;
end;

procedure TPdfThumbnailsPanel.MouseUp(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if FMovingPage then
  begin
    FMovingPage:= false;
    Cursor := crDefault;
    Invalidate;
  end;
  inherited MouseUp(Button, Shift, X, Y);
end;

procedure TPdfThumbnailsPanel.MouseDown(Button: TMouseButton; Shift: TShiftState; X, Y: integer);
begin
  if (Button = mbLeft) then
  begin
    UpdateMouseMoveData(X, Y);
    if FMouseMoveData.MouseOnPage and (tpoMovePages in FOptions) then
      FMovingPage := true;
  end;

  inherited MouseDown(Button, Shift, X, Y);
end;

procedure TPdfThumbnailsPanel.MouseMove(Shift: TShiftState; X, Y: integer);
begin
  UpdateMouseMoveData(X, Y);
  if FMovingPage then
    Self.Cursor:= crDrag
  else
    Cursor := crDefault;
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
  FTextColor := clWhite;
  FMarginWidth := 20;
  FOnClickOnThumbnail := nil;
  FOptions := [];
  FMovingPage:= false;
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

function TPdfThumbnailsControl.GetTextColor: TColor;
begin
  Result := FPanel.TextColor;
end;

function TPdfThumbnailsControl.GetOptions: TPdfThumbnailsPanelOptionsSet;
begin
  Result := FPanel.Options;
end;

procedure TPdfThumbnailsControl.SetOptions(AValue: TPdfThumbnailsPanelOptionsSet);
begin
  FPanel.Options := AValue;
end;

procedure TPdfThumbnailsControl.SetOrientation(AValue: TPdfThumbnailsControlOrientation);
begin
  if FOrientation=AValue then Exit;
  FOrientation:=AValue;
  if FOrientation = tcHorizontal then
  begin
    FScrollbar.Kind:= sbHorizontal;
    FScrollbar.Align := alBottom;
    FPanel.Align := alClient;
  end
  else
  begin
    FScrollbar.Kind:= sbVertical;
    FScrollbar.Align := alRight;
    FPanel.Align := alClient;
  end;
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

procedure TPdfThumbnailsControl.SetTextColor(AValue: TColor);
begin
  FPanel.TextColor:= AValue;
end;

constructor TPdfThumbnailsControl.Create(TheOwner: TComponent);
begin
  inherited Create(TheOwner);
  FOrientation:= tcHorizontal;
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

end.
