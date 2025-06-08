unit PdfiumLaz;

{$mode objfpc}{$H+}

interface

uses
  Graphics,
  PdfiumCore;

procedure DrawPageToBitmap(aPage: TPdfPage; aBitmap: TBitmap; aX, aY, aWidth, aHeight: Integer; aRotate: TPdfPageRotation; const aOptions: TPdfPageRenderOptions; aPageBackground: TColor);

procedure DrawPageToCanvas(aPage: TPdfPage; aCanvas: TCanvas; aX, aY, aWidth, aHeight: Integer; aRotate: TPdfPageRotation; const aOptions: TPdfPageRenderOptions; aPageBackground: TColor);

// https://forum.lazarus.freepascal.org/index.php/topic,50167.msg365785.html#msg365785
procedure DarkenBitmap(aBitmap : TBitmap; ALevel: Byte);

implementation

uses
  IntfGraphics, LCLType(*, GraphUtil*);

type
  TBitmapPixel = record
    B, G, R{$IFDEF UNIX}, A {$ENDIF}: UInt8;
  end;

type
  PBitmapLine = ^TBitmapLine;
  TBitmapLine = array [UInt16] of TBitmapPixel;

procedure DrawPageToBitmap(aPage: TPdfPage; aBitmap: TBitmap; aX, aY, aWidth, aHeight: Integer; aRotate: TPdfPageRotation; const aOptions: TPdfPageRenderOptions; aPageBackground: TColor);
var
  tmpLazImage : TLazIntfImage;
  ImgHandle,ImgMaskHandle: HBitmap;
  PdfBmp: TPdfBitmap;
  w, h : integer;
begin
  tmpLazImage := TLazIntfImage.Create(0, 0);
  try
    if (aRotate = prNormal) or (aRotate = pr180) then
    begin
      w := aWidth;
      h := aHeight;
    end
    else
    begin
      w := aHeight;
      h := aWidth;
    end;
    tmpLazImage.DataDescription.Init_BPP32_B8G8R8A8_BIO_TTB(w, h);
    tmpLazImage.CreateData;
    PdfBmp := TPdfBitmap.Create(w, h, bfBGRx, tmpLazImage.PixelData, w * 4);
    try
      PdfBmp.FillRect(0, 0, w, h, ColorToRGB(aPageBackground));
      aPage.DrawToPdfBitmap(PdfBmp, 0, 0, w, h, aRotate, aOptions);
      aPage.DrawFormToPdfBitmap(PdfBmp, 0, 0, w, h, aRotate, aOptions);

      tmpLazImage.CreateBitmaps(ImgHandle,ImgMaskHandle,false);
      aBitmap.Handle:=ImgHandle;
      aBitmap.MaskHandle:=ImgMaskHandle;
    finally
      PdfBmp.Free;
    end;
  finally
    tmpLazImage.Free;
  end;
end;

procedure DrawPageToCanvas(aPage: TPdfPage; aCanvas: TCanvas; aX, aY, aWidth, aHeight: Integer; aRotate: TPdfPageRotation; const aOptions: TPdfPageRenderOptions; aPageBackground: TColor);
var
  tmpBitmap : TBitmap;
begin
  tmpBitmap := TBitmap.Create;
  try
    DrawPageToBitmap(aPage, tmpBitmap, aX, aY, aWidth, aHeight, aRotate, aOptions, aPageBackground);
    aCanvas.Draw(aX, aY, tmpBitmap);
  finally
    tmpBitmap.Free;
  end;
end;

// https://forum.lazarus.freepascal.org/index.php/topic,50167.msg365785.html#msg365785
procedure DarkenBitmap(aBitmap: TBitmap; ALevel: Byte);
var
  Line: PBitmapLine;
  LineIndex, PixelIndex: Integer;
begin
  ALevel := 255 - ALevel;
  aBitmap.BeginUpdate();

  for LineIndex := 0 to aBitmap.Height - 1 do
  begin
    Line := aBitmap.ScanLine[LineIndex];

    for PixelIndex := 0 to aBitmap.Width - 1 do
      with Line^[PixelIndex] do
      begin
        B := B * ALevel shr 8;
        G := G * ALevel shr 8;
        R := R * ALevel shr 8;
      end;
  end;

  aBitmap.EndUpdate();
end;


end.
