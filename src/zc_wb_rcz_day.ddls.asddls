@EndUserText.label: 'Wyniki rozliczenia czasu pracy - dzień'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_WB_RCZ_DAY_QUERY'
@Metadata.allowExtensions: true
// Jeden wiersz = pracownik + okres FPPER + dzień (DATCZ) z tabeli /QUERC/RCZ_CZAS0.
// Kolumny = suma CZILO (minuty) dla grup rodzajów czasu RODCZ, w formacie hh:mm.
// Dane liczy klasa ZCL_WB_RCZ_DAY_QUERY, wygląd ekranu: rozszerzenie metadanych ZC_WB_RCZ_DAY.
define custom entity ZC_WB_RCZ_DAY
{
      @EndUserText.label: 'Numer osobowy'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
  key Pernr : pernr_d;
      @EndUserText.label: 'Okres rozliczenia (FPPER)'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
  key Fpper : fpper;
      @EndUserText.label: 'Data'
  key Datcz : /querc/rcz_e_datcz;

      @EndUserText.label: 'Plan'
      PlanTime : abap.char( 10 );
      @EndUserText.label: 'Czas przepracowany'
      WorkedTime : abap.char( 10 );
      @EndUserText.label: 'Niedobór czasu'
      Shortage : abap.char( 10 );
      @EndUserText.label: 'Czas pomijany'
      SkippedTime : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe BD'
      OvtDailyBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 50% zapł.'
      OvtDaily50 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe do odbioru'
      OvtDailyComp : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 100% zapł.'
      OvtDaily100 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł. BD'
      OvtAvgPaidBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł.'
      OvtAvgPaid : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. do odbioru'
      OvtAvgComp : abap.char( 10 );
      @EndUserText.label: 'Godziny ponadwymiarowe'
      ExtraHours : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 50%'
      Extra50 : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 100%'
      Extra100 : abap.char( 10 );
      @EndUserText.label: 'Dyżury'
      OnCall : abap.char( 10 );
      @EndUserText.label: 'Godziny II'
      SecondShift : abap.char( 10 );
      @EndUserText.label: 'Godziny nocne'
      NightHours : abap.char( 10 );
      @EndUserText.label: 'Godziny niedziela i święto'
      SundayHoliday : abap.char( 10 );
      @EndUserText.label: 'Dni do oddania (DW, DS/DN)'
      DaysToGive : abap.char( 10 );
      @EndUserText.label: 'Dni odebrane (DW, DS/DN)'
      DaysTaken : abap.char( 10 );
      @EndUserText.label: 'Godziny nieobecności'
      Absence : abap.char( 10 );
      @EndUserText.label: 'Godz. nieobecności płatne (stawka godz.)'
      AbsencePaid : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do odpracowania'
      PrivExitWork : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do potrącenia'
      PrivExitDeduct : abap.char( 10 );
      @EndUserText.label: 'Godziny odpracowania'
      MakeUpHours : abap.char( 10 );
      @EndUserText.label: 'Saldo wyjść prywatnych (koniec okresu)'
      PrivExitBalance : abap.char( 10 );
}
