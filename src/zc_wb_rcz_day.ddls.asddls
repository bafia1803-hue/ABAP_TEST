@EndUserText.label: 'Wyniki rozliczenia czasu pracy - dzień'
@ObjectModel.query.implementedBy: 'ABAP:ZCL_WB_RCZ_DAY_QUERY'
@UI: { headerInfo: { typeName: 'Dzień',
                     typeNamePlural: 'Wyniki rozliczenia czasu pracy',
                     title: { type: #STANDARD, value: 'Datcz' },
                     description: { type: #STANDARD, value: 'Pernr' } },
       presentationVariant: [{ sortOrder: [{ by: 'Datcz', direction: #ASC }],
                               visualizations: [{ type: #AS_LINEITEM }] }] }
// Jeden wiersz = pracownik + okres FPPER + dzień (DATCZ) z tabeli /QUERC/RCZ_CZAS0.
// Kolumny = suma CZILO (minuty) dla grup rodzajów czasu RODCZ, w formacie hh:mm.
// Dane liczy klasa ZCL_WB_RCZ_DAY_QUERY; adnotacje @UI opisują wygląd ekranu Fiori.
define custom entity ZC_WB_RCZ_DAY
{
      // Strona szczegółów dnia (po kliknięciu wiersza)
      @UI.facet: [{ id: 'DayResults',
                    purpose: #STANDARD,
                    type: #IDENTIFICATION_REFERENCE,
                    label: 'Wyniki dnia',
                    position: 10 }]
      @EndUserText.label: 'Numer osobowy'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
      @UI.selectionField: [{ position: 10 }]
  key Pernr : pernr_d;
      @EndUserText.label: 'Okres rozliczenia (FPPER)'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
      @UI.selectionField: [{ position: 20 }]
  key Fpper : fpper;
      @EndUserText.label: 'Data'
      @UI: { lineItem: [{ position: 10, importance: #HIGH }],
             identification: [{ position: 10 }] }
  key Datcz : /querc/rcz_e_datcz;

      @EndUserText.label: 'Plan'
      @UI: { lineItem: [{ position: 20, importance: #HIGH }],
             identification: [{ position: 20 }] }
      PlanTime : abap.char( 10 );
      @EndUserText.label: 'Czas przepracowany'
      @UI: { lineItem: [{ position: 30, importance: #HIGH }],
             identification: [{ position: 30 }] }
      WorkedTime : abap.char( 10 );
      @EndUserText.label: 'Niedobór czasu'
      @UI: { lineItem: [{ position: 40, importance: #HIGH }],
             identification: [{ position: 40 }] }
      Shortage : abap.char( 10 );
      @EndUserText.label: 'Czas pomijany'
      @UI: { lineItem: [{ position: 50, importance: #HIGH }],
             identification: [{ position: 50 }] }
      SkippedTime : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe BD'
      @UI: { lineItem: [{ position: 60, importance: #HIGH }],
             identification: [{ position: 60 }] }
      OvtDailyBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 50% zapł.'
      @UI: { lineItem: [{ position: 70, importance: #HIGH }],
             identification: [{ position: 70 }] }
      OvtDaily50 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe do odbioru'
      @UI: { lineItem: [{ position: 80, importance: #HIGH }],
             identification: [{ position: 80 }] }
      OvtDailyComp : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 100% zapł.'
      @UI: { lineItem: [{ position: 90, importance: #HIGH }],
             identification: [{ position: 90 }] }
      OvtDaily100 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł. BD'
      @UI: { lineItem: [{ position: 100, importance: #HIGH }],
             identification: [{ position: 100 }] }
      OvtAvgPaidBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł.'
      @UI: { lineItem: [{ position: 110, importance: #HIGH }],
             identification: [{ position: 110 }] }
      OvtAvgPaid : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. do odbioru'
      @UI: { lineItem: [{ position: 120, importance: #HIGH }],
             identification: [{ position: 120 }] }
      OvtAvgComp : abap.char( 10 );
      @EndUserText.label: 'Godziny ponadwymiarowe'
      @UI: { lineItem: [{ position: 130, importance: #HIGH }],
             identification: [{ position: 130 }] }
      ExtraHours : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 50%'
      @UI: { lineItem: [{ position: 140, importance: #HIGH }],
             identification: [{ position: 140 }] }
      Extra50 : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 100%'
      @UI: { lineItem: [{ position: 150, importance: #HIGH }],
             identification: [{ position: 150 }] }
      Extra100 : abap.char( 10 );
      @EndUserText.label: 'Dyżury'
      @UI: { lineItem: [{ position: 160, importance: #HIGH }],
             identification: [{ position: 160 }] }
      OnCall : abap.char( 10 );
      @EndUserText.label: 'Godziny II'
      @UI: { lineItem: [{ position: 170, importance: #HIGH }],
             identification: [{ position: 170 }] }
      SecondShift : abap.char( 10 );
      @EndUserText.label: 'Godziny nocne'
      @UI: { lineItem: [{ position: 180, importance: #HIGH }],
             identification: [{ position: 180 }] }
      NightHours : abap.char( 10 );
      @EndUserText.label: 'Godziny niedziela i święto'
      @UI: { lineItem: [{ position: 190, importance: #HIGH }],
             identification: [{ position: 190 }] }
      SundayHoliday : abap.char( 10 );
      @EndUserText.label: 'Dni do oddania (DW, DS/DN)'
      @UI: { lineItem: [{ position: 200, importance: #HIGH }],
             identification: [{ position: 200 }] }
      DaysToGive : abap.char( 10 );
      @EndUserText.label: 'Dni odebrane (DW, DS/DN)'
      @UI: { lineItem: [{ position: 210, importance: #HIGH }],
             identification: [{ position: 210 }] }
      DaysTaken : abap.char( 10 );
      @EndUserText.label: 'Godziny nieobecności'
      @UI: { lineItem: [{ position: 220, importance: #HIGH }],
             identification: [{ position: 220 }] }
      Absence : abap.char( 10 );
      @EndUserText.label: 'Godz. nieobecności płatne (stawka godz.)'
      @UI: { lineItem: [{ position: 230, importance: #HIGH }],
             identification: [{ position: 230 }] }
      AbsencePaid : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do odpracowania'
      @UI: { lineItem: [{ position: 240, importance: #HIGH }],
             identification: [{ position: 240 }] }
      PrivExitWork : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do potrącenia'
      @UI: { lineItem: [{ position: 250, importance: #HIGH }],
             identification: [{ position: 250 }] }
      PrivExitDeduct : abap.char( 10 );
      @EndUserText.label: 'Godziny odpracowania'
      @UI: { lineItem: [{ position: 260, importance: #HIGH }],
             identification: [{ position: 260 }] }
      MakeUpHours : abap.char( 10 );
      @EndUserText.label: 'Saldo wyjść prywatnych (koniec okresu)'
      @UI: { lineItem: [{ position: 270, importance: #HIGH }],
             identification: [{ position: 270 }] }
      PrivExitBalance : abap.char( 10 );
}
