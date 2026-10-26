@EndUserText.label: 'Oś czasu dnia - wycinki rodzajów czasu'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_WB_RCZ_SLICE_QUERY'
// Wiersz = niepusty rodzaj czasu dnia i jeden jego wycinek godzinowy (GODZOD - GODZDO).
// SliceNo = 0: rodzaj czasu bez wycinków. Dane liczy klasa ZCL_WB_RCZ_SLICE_QUERY,
// wyświetla strona osi czasu aplikacji ZWB_RCZ (filtr: Pernr, Fpper, Datcz).
define custom entity ZC_WB_RCZ_SLICE
{
      @EndUserText.label: 'Numer osobowy'
  key Pernr      : pernr_d;
      @EndUserText.label: 'Okres rozliczenia (FPPER)'
  key Fpper      : fpper;
      @EndUserText.label: 'Data'
  key Datcz      : /querc/rcz_e_datcz;
      @EndUserText.label: 'Rodzaj czasu'
  key Rodcz      : /querc/rcz_e_rodcz;
      @EndUserText.label: 'Nr wycinka'
  key SliceNo    : abap.int4;
      @EndUserText.label: 'Nazwa rodzaju czasu'
      RodczName  : /querc/rcz_e_rcname;
      @EndUserText.label: 'Kolumna w tabeli dni'
      ColumnName : abap.char( 30 );
      @EndUserText.label: 'Suma rodzaju czasu w dniu'
      TotalTime  : abap.char( 10 );
      @EndUserText.label: 'Początek (minuty od północy)'
      BeginMin   : abap.int4;
      @EndUserText.label: 'Koniec (minuty od północy)'
      EndMin     : abap.int4;
      @EndUserText.label: 'Godzina od'
      BeginTime  : abap.char( 10 );
      @EndUserText.label: 'Godzina do'
      EndTime    : abap.char( 10 );
}
