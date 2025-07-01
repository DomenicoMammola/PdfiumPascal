unit PdfiumPascalEvents;

{$IFDEF FPC}
  {$MODE DELPHI}
{$ENDIF}

interface

type
  TPdfPageViewControlEventsSubscription =  class abstract
  public
    procedure ChangePage(const aPageIndex : integer); virtual; abstract;
  end;

  TPdfPageViewControlEventsSubscriptionClass = class of TPdfPageViewControlEventsSubscription;

implementation

end.
