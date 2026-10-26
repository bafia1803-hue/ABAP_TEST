"! Dane aplikacji Fiori 'Wyniki rozliczenia czasu pracy' (custom entity ZC_WB_RCZ_DAY).
"! Czyta /QUERC/RCZ_CZAS0 dla wybranego PERNR i FPPER, sumuje minuty CZILO
"! dla grup rodzajów czasu (RODCZ) - każda grupa to jedna kolumna -
"! i zwraca je w formacie hh:mm, jeden wiersz na dzień (DATCZ). Suma 0 = pusta komórka.
"! Dni okresu FPPER bez rekordów też są zwracane (puste wiersze), z dniem tygodnia.
"! Grupy rodzajów czasu są w CLASS_CONSTRUCTOR.
CLASS zcl_wb_rcz_day_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

    TYPES tt_days TYPE STANDARD TABLE OF zc_wb_rcz_day WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_time_record,
        pernr TYPE pernr_d,
        fpper TYPE fpper,
        datcz TYPE /querc/rcz_e_datcz,
        rodcz TYPE /querc/rcz_e_rodcz,
        czilo TYPE /querc/rcz_e_czilo,
      END OF ty_time_record.
    TYPES tt_time_records TYPE STANDARD TABLE OF ty_time_record WITH EMPTY KEY.
    TYPES tt_datcz_range TYPE RANGE OF /querc/rcz_e_datcz.
    TYPES:
      " Liczba komunikatów jednego typu (E / W) w jednym dniu
      BEGIN OF ty_message_count,
        dakom TYPE /querc/rcz_e_dakom,
        tykom TYPE /querc/rcz_e_tykom,
        msg_count TYPE i,
      END OF ty_message_count.
    TYPES tt_message_counts TYPE STANDARD TABLE OF ty_message_count WITH EMPTY KEY.

    CLASS-METHODS class_constructor.

    "! Jeden wiersz na dzień, kolumny = sumy minut grup rodzajów czasu w formacie hh:mm (0 = puste)
    "! @parameter it_records | Rekordy z /QUERC/RCZ_CZAS0
    CLASS-METHODS build_days
      IMPORTING
        it_records     TYPE tt_time_records
      RETURNING
        VALUE(rt_days) TYPE tt_days.

    "! Minuty jako hh:mm, np. 90 -> 01:30, -75 -> -01:15, 6000 -> 100:00
    CLASS-METHODS format_minutes
      IMPORTING
        iv_minutes     TYPE i
      RETURNING
        VALUE(rv_text) TYPE string.

    "! Dodaje puste wiersze dla dni okresu FPPER (miesiąc RRRRMM) bez rekordów czasu
    "! @parameter it_datcz | Ograniczenie dni (puste = cały miesiąc)
    CLASS-METHODS add_missing_days
      IMPORTING
        iv_pernr TYPE pernr_d
        iv_fpper TYPE fpper
        it_datcz TYPE tt_datcz_range
      CHANGING
        ct_days  TYPE tt_days.

    "! Liczby błędów (E) i ostrzeżeń (W) z /QUERC/RCZ_KOMP w wierszach dni
    CLASS-METHODS apply_message_counts
      IMPORTING
        it_counts TYPE tt_message_counts
      CHANGING
        ct_days   TYPE tt_days.

    "! Dzień tygodnia (nazwa) i znacznik weekendu (SAT / SUN) dla daty wiersza
    CLASS-METHODS set_day_of_week
      CHANGING
        cs_day TYPE zc_wb_rcz_day.

    "! Kolumna aplikacji (pole ZC_WB_RCZ_DAY, np. WORKEDTIME), do której należy rodzaj czasu;
    "! pusta, gdy rodzaj czasu nie należy do żadnej kolumny
    CLASS-METHODS get_column
      IMPORTING
        iv_rodcz         TYPE /querc/rcz_e_rodcz
      RETURNING
        VALUE(rv_column) TYPE fieldname.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES tt_rodcz_range TYPE RANGE OF /querc/rcz_e_rodcz.
    TYPES:
      " Kolumna aplikacji (nazwa pola w ZC_WB_RCZ_DAY) i jej rodzaje czasu
      BEGIN OF ty_column,
        name  TYPE fieldname,
        rodcz TYPE tt_rodcz_range,
      END OF ty_column.
    TYPES tt_columns TYPE STANDARD TABLE OF ty_column WITH KEY name.
    TYPES:
      " Suma minut jednej kolumny w jednym dniu (COLLECT sumuje MINUTES)
      BEGIN OF ty_day_total,
        pernr   TYPE pernr_d,
        fpper   TYPE fpper,
        datcz   TYPE /querc/rcz_e_datcz,
        column  TYPE fieldname,
        minutes TYPE i,
      END OF ty_day_total.
    TYPES tt_day_totals TYPE STANDARD TABLE OF ty_day_total WITH DEFAULT KEY.

    CLASS-DATA gt_columns TYPE tt_columns.

    CLASS-METHODS add_time_type
      IMPORTING
        iv_column TYPE fieldname
        iv_rodcz  TYPE /querc/rcz_e_rodcz.

    CLASS-METHODS sum_minutes
      IMPORTING
        it_records       TYPE tt_time_records
      RETURNING
        VALUE(rt_totals) TYPE tt_day_totals.

    CLASS-METHODS single_value
      IMPORTING
        it_filter       TYPE if_rap_query_filter=>tt_name_range_pairs
        iv_name         TYPE string
      RETURNING
        VALUE(rv_value) TYPE string.

    CLASS-METHODS is_month_period
      IMPORTING
        iv_fpper         TYPE fpper
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    CLASS-METHODS last_day_of_month
      IMPORTING
        iv_first_day       TYPE d
      RETURNING
        VALUE(rv_last_day) TYPE d.

    CLASS-METHODS read_message_counts
      IMPORTING
        iv_pernr         TYPE pernr_d
        iv_fpper         TYPE fpper
        it_datcz         TYPE tt_datcz_range
      RETURNING
        VALUE(rt_counts) TYPE tt_message_counts.

    CLASS-METHODS read_records
      IMPORTING
        it_filter         TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING
        VALUE(rt_records) TYPE tt_time_records.

    CLASS-METHODS sort_days
      IMPORTING
        it_sort TYPE if_rap_query_request=>tt_sort_elements
      CHANGING
        ct_days TYPE tt_days.

    CLASS-METHODS get_page
      IMPORTING
        it_days        TYPE tt_days
        iv_offset      TYPE int8
        iv_page_size   TYPE int8
      RETURNING
        VALUE(rt_page) TYPE tt_days.

ENDCLASS.



CLASS zcl_wb_rcz_day_query IMPLEMENTATION.


  METHOD class_constructor.

    " Kolumna aplikacji <- rodzaj czasu (RODCZ). Jeden RODCZ = jedna linia.
    " Nowa kolumna: pole w ZC_WB_RCZ_DAY + pozycja w rozszerzeniu metadanych + linie tutaj.

    " Plan
    add_time_type( iv_column = 'PLANTIME' iv_rodcz = '107' ).

    " Czas przepracowany
    add_time_type( iv_column = 'WORKEDTIME' iv_rodcz = '105' ).
    add_time_type( iv_column = 'WORKEDTIME' iv_rodcz = '290' ).

    " Niedobór czasu
    add_time_type( iv_column = 'SHORTAGE' iv_rodcz = '300' ).

    " Czas pomijany
    add_time_type( iv_column = 'SKIPPEDTIME' iv_rodcz = '310' ).

    " Nadgodz. dobowe BD
    add_time_type( iv_column = 'OVTDAILYBD' iv_rodcz = '108' ).
    add_time_type( iv_column = 'OVTDAILYBD' iv_rodcz = '109' ).

    " Nadgodz. dobowe 50% zapł.
    add_time_type( iv_column = 'OVTDAILY50' iv_rodcz = '110' ).
    add_time_type( iv_column = 'OVTDAILY50' iv_rodcz = '111' ).

    " Nadgodz. dobowe do odbioru
    add_time_type( iv_column = 'OVTDAILYCOMP' iv_rodcz = '120' ).
    add_time_type( iv_column = 'OVTDAILYCOMP' iv_rodcz = '121' ).

    " Nadgodz. dobowe 100% zapł.
    add_time_type( iv_column = 'OVTDAILY100' iv_rodcz = '115' ).
    add_time_type( iv_column = 'OVTDAILY100' iv_rodcz = '116' ).

    " Nadgodz. średniotyg. zapł. BD
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '137' ).
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '138' ).
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '142' ).
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '143' ).
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '147' ).
    add_time_type( iv_column = 'OVTAVGPAIDBD' iv_rodcz = '148' ).

    " Nadgodz. średniotyg. zapł.
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '135' ).
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '136' ).
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '140' ).
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '141' ).
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '145' ).
    add_time_type( iv_column = 'OVTAVGPAID' iv_rodcz = '146' ).

    " Nadgodz. średniotyg. do odbioru
    add_time_type( iv_column = 'OVTAVGCOMP' iv_rodcz = '150' ).
    add_time_type( iv_column = 'OVTAVGCOMP' iv_rodcz = '151' ).

    " Godziny ponadwymiarowe
    add_time_type( iv_column = 'EXTRAHOURS' iv_rodcz = '255' ).

    " Godz. ponadwymiarowe 50%
    add_time_type( iv_column = 'EXTRA50' iv_rodcz = '256' ).

    " Godz. ponadwymiarowe 100%
    add_time_type( iv_column = 'EXTRA100' iv_rodcz = '257' ).

    " Dyżury
    add_time_type( iv_column = 'ONCALL' iv_rodcz = '240' ).
    add_time_type( iv_column = 'ONCALL' iv_rodcz = '242' ).
    add_time_type( iv_column = 'ONCALL' iv_rodcz = '243' ).
    add_time_type( iv_column = 'ONCALL' iv_rodcz = '244' ).

    " Godziny II
    add_time_type( iv_column = 'SECONDSHIFT' iv_rodcz = '295' ).

    " Godziny nocne
    add_time_type( iv_column = 'NIGHTHOURS' iv_rodcz = '235' ).

    " Godziny niedziela i święto
    add_time_type( iv_column = 'SUNDAYHOLIDAY' iv_rodcz = '250' ).

    " Dni do oddania (DW, DS/DN)
    add_time_type( iv_column = 'DAYSTOGIVE' iv_rodcz = '200' ).
    add_time_type( iv_column = 'DAYSTOGIVE' iv_rodcz = '215' ).

    " Dni odebrane (DW, DS/DN)
    add_time_type( iv_column = 'DAYSTAKEN' iv_rodcz = '205' ).
    add_time_type( iv_column = 'DAYSTAKEN' iv_rodcz = '220' ).

    " Godziny nieobecności
    add_time_type( iv_column = 'ABSENCE' iv_rodcz = '230' ).

    " Godz. nieobecności płatne (stawka godz.)
    add_time_type( iv_column = 'ABSENCEPAID' iv_rodcz = '232' ).

    " Wyjścia prywatne do odpracowania
    add_time_type( iv_column = 'PRIVEXITWORK' iv_rodcz = '260' ).

    " Wyjścia prywatne do potrącenia
    add_time_type( iv_column = 'PRIVEXITDEDUCT' iv_rodcz = '261' ).

    " Godziny odpracowania
    add_time_type( iv_column = 'MAKEUPHOURS' iv_rodcz = '265' ).

    " Saldo wyjść prywatnych (koniec okresu)
    add_time_type( iv_column = 'PRIVEXITBALANCE' iv_rodcz = '940' ).

  ENDMETHOD.


  METHOD add_time_type.

    READ TABLE gt_columns ASSIGNING FIELD-SYMBOL(<ls_column>) WITH TABLE KEY name = iv_column.
    IF sy-subrc <> 0.
      INSERT VALUE #( name = iv_column ) INTO TABLE gt_columns ASSIGNING <ls_column>.
    ENDIF.

    INSERT VALUE #( sign = 'I' option = 'EQ' low = iv_rodcz ) INTO TABLE <ls_column>-rodcz.

  ENDMETHOD.


  METHOD if_rap_query_provider~select.

    " Stronicowanie i sortowanie trzeba odczytać zawsze, inaczej RAP zgłasza błąd
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lt_sort) = io_request->get_sort_elements( ).

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        " Filtr, którego nie da się zamienić na zakresy - brak wyników
        CLEAR lt_filter.
    ENDTRY.

    DATA(lt_days) = build_days( read_records( lt_filter ) ).
    " Wszystkie dni okresu, także bez rekordów czasu
    DATA(lv_pernr) = CONV pernr_d( single_value( it_filter = lt_filter iv_name = `PERNR` ) ).
    DATA(lv_fpper) = CONV fpper( single_value( it_filter = lt_filter iv_name = `FPPER` ) ).
    DATA(lt_datcz) = CORRESPONDING tt_datcz_range( VALUE #( lt_filter[ name = 'DATCZ' ]-range OPTIONAL ) ).
    add_missing_days(
      EXPORTING
        iv_pernr = lv_pernr
        iv_fpper = lv_fpper
        it_datcz = lt_datcz
      CHANGING
        ct_days  = lt_days ).
    " Liczby błędów i ostrzeżeń dnia (kolumna ikon w tabeli)
    apply_message_counts(
      EXPORTING
        it_counts = read_message_counts( iv_pernr = lv_pernr
                                         iv_fpper = lv_fpper
                                         it_datcz = lt_datcz )
      CHANGING
        ct_days   = lt_days ).
    sort_days(
      EXPORTING
        it_sort = lt_sort
      CHANGING
        ct_days = lt_days ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_days ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( get_page(
        it_days      = lt_days
        iv_offset    = lo_paging->get_offset( )
        iv_page_size = lo_paging->get_page_size( ) ) ).
    ENDIF.

  ENDMETHOD.


  METHOD read_records.

    DATA lt_pernr TYPE RANGE OF pernr_d.
    DATA lt_fpper TYPE RANGE OF fpper.
    DATA lt_datcz TYPE RANGE OF /querc/rcz_e_datcz.

    lt_pernr = CORRESPONDING #( VALUE #( it_filter[ name = 'PERNR' ]-range OPTIONAL ) ).
    lt_fpper = CORRESPONDING #( VALUE #( it_filter[ name = 'FPPER' ]-range OPTIONAL ) ).
    " Data jest w filtrze, gdy aplikacja otwiera szczegóły jednego dnia
    lt_datcz = CORRESPONDING #( VALUE #( it_filter[ name = 'DATCZ' ]-range OPTIONAL ) ).

    " Bez numeru osobowego i okresu nie czytamy nic (oba filtry są obowiązkowe)
    IF lt_pernr IS INITIAL OR lt_fpper IS INITIAL.
      RETURN.
    ENDIF.

    SELECT pernr, fpper, datcz, rodcz, czilo
      FROM /querc/rcz_czas0
      WHERE pernr IN @lt_pernr
        AND fpper IN @lt_fpper
        AND datcz IN @lt_datcz
      INTO CORRESPONDING FIELDS OF TABLE @rt_records.

  ENDMETHOD.


  METHOD build_days.

    DATA(lt_totals) = sum_minutes( it_records ).

    LOOP AT it_records INTO DATA(ls_record)
         GROUP BY ( pernr = ls_record-pernr fpper = ls_record-fpper datcz = ls_record-datcz )
         INTO DATA(ls_key).

      DATA(ls_day) = VALUE zc_wb_rcz_day( pernr = ls_key-pernr fpper = ls_key-fpper datcz = ls_key-datcz ).
      set_day_of_week( CHANGING cs_day = ls_day ).

      LOOP AT gt_columns INTO DATA(ls_column).
        ASSIGN COMPONENT ls_column-name OF STRUCTURE ls_day TO FIELD-SYMBOL(<lv_value>).
        IF sy-subrc <> 0.
          CONTINUE.
        ENDIF.
        DATA(lv_minutes) = VALUE #( lt_totals[ pernr  = ls_key-pernr
                                               fpper  = ls_key-fpper
                                               datcz  = ls_key-datcz
                                               column = ls_column-name ]-minutes OPTIONAL ).
        " Zero nic nie wnosi - komórka zostaje pusta
        IF lv_minutes <> 0.
          <lv_value> = format_minutes( lv_minutes ).
        ENDIF.
      ENDLOOP.

      INSERT ls_day INTO TABLE rt_days.
    ENDLOOP.

  ENDMETHOD.


  METHOD sum_minutes.

    LOOP AT it_records INTO DATA(ls_record).
      LOOP AT gt_columns INTO DATA(ls_column).
        IF ls_record-rodcz IN ls_column-rodcz.
          DATA(ls_total) = VALUE ty_day_total( pernr   = ls_record-pernr
                                               fpper   = ls_record-fpper
                                               datcz   = ls_record-datcz
                                               column  = ls_column-name
                                               minutes = ls_record-czilo ).
          COLLECT ls_total INTO rt_totals.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD single_value.

    " Wartość filtra, gdy jest dokładnie jedna (np. PERNR = 446)
    DATA(lt_range) = VALUE #( it_filter[ name = iv_name ]-range OPTIONAL ).
    IF lines( lt_range ) = 1 AND lt_range[ 1 ]-sign = 'I' AND lt_range[ 1 ]-option = 'EQ'.
      rv_value = lt_range[ 1 ]-low.
    ENDIF.

  ENDMETHOD.


  METHOD add_missing_days.

    IF iv_pernr IS INITIAL OR is_month_period( iv_fpper ) = abap_false.
      RETURN.
    ENDIF.

    DATA(lv_day) = CONV d( |{ iv_fpper }01| ).
    DATA(lv_last_day) = last_day_of_month( lv_day ).

    WHILE lv_day <= lv_last_day.
      IF lv_day IN it_datcz
          AND NOT line_exists( ct_days[ pernr = iv_pernr fpper = iv_fpper datcz = lv_day ] ).
        DATA(ls_day) = VALUE zc_wb_rcz_day( pernr = iv_pernr fpper = iv_fpper datcz = lv_day ).
        set_day_of_week( CHANGING cs_day = ls_day ).
        INSERT ls_day INTO TABLE ct_days.
      ENDIF.
      lv_day = lv_day + 1.
    ENDWHILE.

  ENDMETHOD.


  METHOD is_month_period.

    " FPPER w postaci RRRRMM, np. 202609
    rv_result = boolc( iv_fpper CO '0123456789'
                       AND strlen( iv_fpper ) = 6
                       AND iv_fpper+4(2) BETWEEN '01' AND '12' ).

  ENDMETHOD.


  METHOD last_day_of_month.

    " 28. dzień + 4 dni zawsze wypada w następnym miesiącu; jego 1. dzień - 1 = koniec miesiąca
    DATA(lv_next_month) = iv_first_day.
    lv_next_month+6(2) = '28'.
    lv_next_month = lv_next_month + 4.
    lv_next_month+6(2) = '01'.
    rv_last_day = lv_next_month - 1.

  ENDMETHOD.


  METHOD read_message_counts.

    DATA lt_dakom TYPE RANGE OF /querc/rcz_e_dakom.

    IF iv_pernr IS INITIAL.
      RETURN.
    ENDIF.

    " Dni okresu: cały miesiąc FPPER albo dni z filtra (np. jeden dzień)
    IF it_datcz IS NOT INITIAL.
      lt_dakom = CORRESPONDING #( it_datcz ).
    ELSEIF is_month_period( iv_fpper ) = abap_true.
      DATA(lv_first_day) = CONV d( |{ iv_fpper }01| ).
      lt_dakom = VALUE #( ( sign = 'I' option = 'BT' low = lv_first_day high = last_day_of_month( lv_first_day ) ) ).
    ELSE.
      RETURN.
    ENDIF.

    SELECT dakom, tykom, COUNT( * ) AS msg_count
      FROM /querc/rcz_komp
      WHERE pernr = @iv_pernr
        AND dakom IN @lt_dakom
        AND tykom IN ( 'E', 'W' )
      GROUP BY dakom, tykom
      INTO CORRESPONDING FIELDS OF TABLE @rt_counts.

  ENDMETHOD.


  METHOD apply_message_counts.

    LOOP AT ct_days ASSIGNING FIELD-SYMBOL(<ls_day>).
      LOOP AT it_counts INTO DATA(ls_count) WHERE dakom = <ls_day>-datcz.
        CASE ls_count-tykom.
          WHEN 'E'.
            <ls_day>-errorcount = <ls_day>-errorcount + ls_count-msg_count.
          WHEN 'W'.
            <ls_day>-warningcount = <ls_day>-warningcount + ls_count-msg_count.
        ENDCASE.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD set_day_of_week.

    " 1 stycznia 1900 był poniedziałkiem
    CONSTANTS lc_monday TYPE d VALUE '19000101'.
    DATA(lv_index) = ( cs_day-datcz - lc_monday ) MOD 7.

    cs_day-dayofweek = SWITCH #( lv_index
                                 WHEN 0 THEN 'poniedziałek'
                                 WHEN 1 THEN 'wtorek'
                                 WHEN 2 THEN 'środa'
                                 WHEN 3 THEN 'czwartek'
                                 WHEN 4 THEN 'piątek'
                                 WHEN 5 THEN 'sobota'
                                 WHEN 6 THEN 'niedziela' ).
    cs_day-weekendtype = SWITCH #( lv_index
                                   WHEN 5 THEN 'SAT'
                                   WHEN 6 THEN 'SUN' ).

  ENDMETHOD.


  METHOD get_column.

    LOOP AT gt_columns INTO DATA(ls_column).
      IF iv_rodcz IN ls_column-rodcz.
        rv_column = ls_column-name.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD format_minutes.

    DATA(lv_minutes) = abs( iv_minutes ).
    DATA(lv_sign) = COND string( WHEN iv_minutes < 0 THEN `-` ).

    rv_text = |{ lv_sign }{ lv_minutes DIV 60 WIDTH = 2 ALIGN = RIGHT PAD = `0` }:|
           && |{ lv_minutes MOD 60 WIDTH = 2 ALIGN = RIGHT PAD = `0` }|.

  ENDMETHOD.


  METHOD sort_days.

    " Domyślnie po dacie; nazwy elementów CDS (np. Datcz) = nazwy pól wielkimi literami
    IF it_sort IS INITIAL.
      SORT ct_days BY datcz.
      RETURN.
    ENDIF.

    DATA(lt_order) = VALUE abap_sortorder_tab(
      FOR ls_sort IN it_sort
      ( name = to_upper( ls_sort-element_name ) descending = ls_sort-descending ) ).
    SORT ct_days BY (lt_order).

  ENDMETHOD.


  METHOD get_page.

    IF iv_page_size = if_rap_query_paging=>page_size_unlimited.
      rt_page = it_days.
      RETURN.
    ENDIF.

    DATA(lv_from) = iv_offset + 1.
    DATA(lv_to) = iv_offset + iv_page_size.
    LOOP AT it_days INTO DATA(ls_day) FROM lv_from TO lv_to.
      INSERT ls_day INTO TABLE rt_page.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
