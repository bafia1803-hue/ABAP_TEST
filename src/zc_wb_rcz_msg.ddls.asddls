@EndUserText.label: 'Komunikaty rozliczenia czasu pracy'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_WB_RCZ_MSG_QUERY'
// Komunikaty z /QUERC/RCZ_KOMP. Filtr: Pernr (wymagany) oraz Dakom (dzień) albo Period (miesiąc RRRRMM).
// Sortowanie domyślne: błędy (E), ostrzeżenia (W), pozostałe; potem data i godzina.
define custom entity ZC_WB_RCZ_MSG
{
      @EndUserText.label: 'Numer osobowy'
  key Pernr        : pernr_d;
      @EndUserText.label: 'Okres-W'
  key Inper        : inpro;
      @EndUserText.label: 'Okres Dla'
  key Fpper        : /querc/rcz_fpper;
      @EndUserText.label: 'Numer wersji'
  key Nrwer        : /querc/rcz_e_nrwer;
      @EndUserText.label: 'Numer sekwencyjny'
  key Seqnr        : cdseq;
      @EndUserText.label: 'Data komunikatu'
      Dakom        : /querc/rcz_e_dakom;
      @EndUserText.label: 'Miesiąc komunikatu (RRRRMM)'
      Period       : abap.char( 6 );
      @EndUserText.label: 'Typ komunikatu'
      Tykom        : /querc/rcz_e_tykom;
      // 1 = błąd, 2 = ostrzeżenie, 3 = pozostałe
      @EndUserText.label: 'Waga'
      SeverityRank : abap.int4;
      @EndUserText.label: 'Rodzaj komunikatu'
      Rokom        : /querc/rcz_e_rokom;
      @EndUserText.label: 'Treść komunikatu'
      Tekom        : /querc/rcz_e_trkom;
      @EndUserText.label: 'Identyfikacja komunikatu'
      Msgid        : msgid;
      @EndUserText.label: 'Numer komunikatu'
      Msgno        : msgno;
      @EndUserText.label: 'Godzina od'
      BeginTime    : abap.char( 10 );
      @EndUserText.label: 'Godzina do'
      EndTime      : abap.char( 10 );
}
