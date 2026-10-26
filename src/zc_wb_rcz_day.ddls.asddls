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
// Dane liczy klasa ZCL_WB_RCZ_DAY_QUERY; adnotacje @UI opisują wygląd ekranu Fiori
// (aplikacja BSP ZWB_RCZ). Strona szczegółów dnia ma sekcje = grupy pól (fieldGroup).
define custom entity ZC_WB_RCZ_DAY
{
      // Sekcje strony szczegółów dnia (po kliknięciu wiersza)
      @UI.facet: [
                  { id: 'Work',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'Work',
                    label: 'Czas pracy',
                    position: 10 },
                  { id: 'OvtDay',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'OvtDay',
                    label: 'Nadgodziny dobowe',
                    position: 20 },
                  { id: 'OvtAvg',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'OvtAvg',
                    label: 'Nadgodziny średniotygodniowe',
                    position: 30 },
                  { id: 'Extra',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'Extra',
                    label: 'Godziny ponadwymiarowe',
                    position: 40 },
                  { id: 'Bonus',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'Bonus',
                    label: 'Dodatki',
                    position: 50 },
                  { id: 'Absence',
                    purpose: #STANDARD,
                    type: #FIELDGROUP_REFERENCE,
                    targetQualifier: 'Absence',
                    label: 'Nieobecności i wyjścia',
                    position: 60 } ]
      @EndUserText.label: 'Numer osobowy'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
      @UI.selectionField: [{ position: 10 }]
  key Pernr : pernr_d;
      @EndUserText.label: 'Okres rozliczenia (FPPER)'
      @Consumption.filter: { mandatory: true, selectionType: #SINGLE, multipleSelections: false }
      @UI.selectionField: [{ position: 20 }]
  key Fpper : fpper;
      // Data i dzień tygodnia są w tabeli kolumnami własnymi aplikacji (kolor weekendu)
      @EndUserText.label: 'Data'
  key Datcz : /querc/rcz_e_datcz;

      @EndUserText.label: 'Dzień tygodnia'
      DayOfWeek : abap.char( 15 );
      // SAT = sobota, SUN = niedziela, puste = dzień roboczy
      @UI.hidden: true
      WeekendType : abap.char( 3 );

      // Komunikaty dnia z /QUERC/RCZ_KOMP (kolumna ikon w tabeli)
      @EndUserText.label: 'Błędy'
      @UI.hidden: true
      ErrorCount : abap.int4;
      @EndUserText.label: 'Ostrzeżenia'
      @UI.hidden: true
      WarningCount : abap.int4;

      @EndUserText.label: 'Plan'
      @UI: { lineItem: [{ position: 20, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Work', position: 10 }] }
      PlanTime : abap.char( 10 );
      @EndUserText.label: 'Czas przepracowany'
      @UI: { lineItem: [{ position: 30, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Work', position: 20 }] }
      WorkedTime : abap.char( 10 );
      @EndUserText.label: 'Niedobór czasu'
      @UI: { lineItem: [{ position: 40, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Work', position: 30 }] }
      Shortage : abap.char( 10 );
      @EndUserText.label: 'Czas pomijany'
      @UI: { lineItem: [{ position: 50, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Work', position: 40 }] }
      SkippedTime : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe BD'
      @UI: { lineItem: [{ position: 60, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtDay', position: 10 }] }
      OvtDailyBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 50% zapł.'
      @UI: { lineItem: [{ position: 70, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtDay', position: 20 }] }
      OvtDaily50 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe do odbioru'
      @UI: { lineItem: [{ position: 80, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtDay', position: 30 }] }
      OvtDailyComp : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. dobowe 100% zapł.'
      @UI: { lineItem: [{ position: 90, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtDay', position: 40 }] }
      OvtDaily100 : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł. BD'
      @UI: { lineItem: [{ position: 100, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtAvg', position: 10 }] }
      OvtAvgPaidBd : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. zapł.'
      @UI: { lineItem: [{ position: 110, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtAvg', position: 20 }] }
      OvtAvgPaid : abap.char( 10 );
      @EndUserText.label: 'Nadgodz. średniotyg. do odbioru'
      @UI: { lineItem: [{ position: 120, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'OvtAvg', position: 30 }] }
      OvtAvgComp : abap.char( 10 );
      @EndUserText.label: 'Godziny ponadwymiarowe'
      @UI: { lineItem: [{ position: 130, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Extra', position: 10 }] }
      ExtraHours : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 50%'
      @UI: { lineItem: [{ position: 140, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Extra', position: 20 }] }
      Extra50 : abap.char( 10 );
      @EndUserText.label: 'Godz. ponadwymiarowe 100%'
      @UI: { lineItem: [{ position: 150, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Extra', position: 30 }] }
      Extra100 : abap.char( 10 );
      @EndUserText.label: 'Dyżury'
      @UI: { lineItem: [{ position: 160, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Bonus', position: 10 }] }
      OnCall : abap.char( 10 );
      @EndUserText.label: 'Godziny II'
      @UI: { lineItem: [{ position: 170, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Bonus', position: 20 }] }
      SecondShift : abap.char( 10 );
      @EndUserText.label: 'Godziny nocne'
      @UI: { lineItem: [{ position: 180, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Bonus', position: 30 }] }
      NightHours : abap.char( 10 );
      @EndUserText.label: 'Godziny niedziela i święto'
      @UI: { lineItem: [{ position: 190, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Bonus', position: 40 }] }
      SundayHoliday : abap.char( 10 );
      @EndUserText.label: 'Dni do oddania (DW, DS/DN)'
      @UI: { lineItem: [{ position: 200, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 10 }] }
      DaysToGive : abap.char( 10 );
      @EndUserText.label: 'Dni odebrane (DW, DS/DN)'
      @UI: { lineItem: [{ position: 210, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 20 }] }
      DaysTaken : abap.char( 10 );
      @EndUserText.label: 'Godziny nieobecności'
      @UI: { lineItem: [{ position: 220, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 30 }] }
      Absence : abap.char( 10 );
      @EndUserText.label: 'Godz. nieobecności płatne (stawka godz.)'
      @UI: { lineItem: [{ position: 230, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 40 }] }
      AbsencePaid : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do odpracowania'
      @UI: { lineItem: [{ position: 240, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 50 }] }
      PrivExitWork : abap.char( 10 );
      @EndUserText.label: 'Wyjścia prywatne do potrącenia'
      @UI: { lineItem: [{ position: 250, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 60 }] }
      PrivExitDeduct : abap.char( 10 );
      @EndUserText.label: 'Godziny odpracowania'
      @UI: { lineItem: [{ position: 260, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 70 }] }
      MakeUpHours : abap.char( 10 );
      @EndUserText.label: 'Saldo wyjść prywatnych (koniec okresu)'
      @UI: { lineItem: [{ position: 270, importance: #HIGH }],
             fieldGroup: [{ qualifier: 'Absence', position: 80 }] }
      PrivExitBalance : abap.char( 10 );
}
