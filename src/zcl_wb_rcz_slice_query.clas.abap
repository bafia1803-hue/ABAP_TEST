"! Dane osi czasu jednego dnia (custom entity ZC_WB_RCZ_SLICE).
"! Wiersz = niepusty rodzaj czasu dnia (suma CZILO z /QUERC/RCZ_CZAS0 różna od 0)
"! i jeden jego wycinek godzinowy z /QUERC/RCZ_WYCIN (GODZOD - GODZDO).
"! Wycinki są łączone z rodzajem czasu po PERNR, FPPER, dacie i wskaźniku WSKCZ.
"! Rodzaj czasu bez wycinków ma jeden wiersz z SLICENO = 0 (bez godzin).
"! Nazwy rodzajów czasu z /QUERC/RCZ_RCZAS, ważne na dzień dzisiejszy.
CLASS zcl_wb_rcz_slice_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

    TYPES tt_slices TYPE STANDARD TABLE OF zc_wb_rcz_slice WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_time_record,
        pernr TYPE pernr_d,
        fpper TYPE fpper,
        datcz TYPE /querc/rcz_e_datcz,
        rodcz TYPE /querc/rcz_e_rodcz,
        wskcz TYPE /querc/rcz_e_wskcz,
        czilo TYPE /querc/rcz_e_czilo,
      END OF ty_time_record.
    TYPES tt_time_records TYPE STANDARD TABLE OF ty_time_record WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_cut,
        pernr  TYPE pernr_d,
        fpper  TYPE fpper,
        datwyc TYPE /querc/rcz_e_datwyc,
        wskcz  TYPE /querc/rcz_e_wskcz,
        godzod TYPE /querc/rcz_e_godzod,
        godzdo TYPE /querc/rcz_e_godzdo,
      END OF ty_cut.
    TYPES tt_cuts TYPE STANDARD TABLE OF ty_cut WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_time_type_name,
        rodcz  TYPE /querc/rcz_e_rodcz,
        rcname TYPE /querc/rcz_e_rcname,
      END OF ty_time_type_name.
    TYPES tt_time_type_names TYPE SORTED TABLE OF ty_time_type_name WITH UNIQUE KEY rodcz.

    "! Wiersze osi czasu z rekordów czasu, wycinków i nazw rodzajów czasu
    CLASS-METHODS build_slices
      IMPORTING
        it_records       TYPE tt_time_records
        it_cuts          TYPE tt_cuts
        it_names         TYPE tt_time_type_names
      RETURNING
        VALUE(rt_slices) TYPE tt_slices.

    "! Godzina jako minuty od północy, np. 08:30:00 -> 510, 24:00:00 -> 1440
    CLASS-METHODS time_to_minutes
      IMPORTING
        iv_time           TYPE t
      RETURNING
        VALUE(rv_minutes) TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES tt_wskcz TYPE SORTED TABLE OF /querc/rcz_e_wskcz WITH UNIQUE KEY table_line.
    TYPES:
      " Rodzaj czasu w jednym dniu: suma minut i wskaźniki łączące z wycinkami
      BEGIN OF ty_time_type_day,
        pernr   TYPE pernr_d,
        fpper   TYPE fpper,
        datcz   TYPE /querc/rcz_e_datcz,
        rodcz   TYPE /querc/rcz_e_rodcz,
        minutes TYPE i,
        wskcz   TYPE tt_wskcz,
      END OF ty_time_type_day.
    TYPES tt_time_type_days TYPE STANDARD TABLE OF ty_time_type_day WITH EMPTY KEY.
    TYPES:
      " Przedział czasu w minutach od północy dnia (koniec może przekraczać 1440)
      BEGIN OF ty_interval,
        begin TYPE i,
        end   TYPE i,
      END OF ty_interval.
    TYPES tt_intervals TYPE STANDARD TABLE OF ty_interval WITH EMPTY KEY.

    CONSTANTS c_minutes_per_day TYPE i VALUE 1440.

    CLASS-METHODS group_by_time_type
      IMPORTING
        it_records     TYPE tt_time_records
      RETURNING
        VALUE(rt_days) TYPE tt_time_type_days.

    "! Łączy przedziały stykające się lub nakładające, np. 22:00-22:30 + 22:30-02:00 = 22:00-02:00
    CLASS-METHODS merge_intervals
      IMPORTING
        it_intervals       TYPE tt_intervals
      RETURNING
        VALUE(rt_intervals) TYPE tt_intervals.

    CLASS-METHODS intervals_of_time_type
      IMPORTING
        is_time_type        TYPE ty_time_type_day
        it_cuts             TYPE tt_cuts
      RETURNING
        VALUE(rt_intervals) TYPE tt_intervals.

    CLASS-METHODS add_slices_of_time_type
      IMPORTING
        is_time_type TYPE ty_time_type_day
        it_cuts      TYPE tt_cuts
        it_names     TYPE tt_time_type_names
      CHANGING
        ct_slices    TYPE tt_slices.

    CLASS-METHODS read_records
      IMPORTING
        it_filter         TYPE if_rap_query_filter=>tt_name_range_pairs
      EXPORTING
        et_records        TYPE tt_time_records
        et_cuts           TYPE tt_cuts
        et_names          TYPE tt_time_type_names.

    CLASS-METHODS sort_slices
      IMPORTING
        it_sort   TYPE if_rap_query_request=>tt_sort_elements
      CHANGING
        ct_slices TYPE tt_slices.

    CLASS-METHODS get_page
      IMPORTING
        it_slices      TYPE tt_slices
        iv_offset      TYPE int8
        iv_page_size   TYPE int8
      RETURNING
        VALUE(rt_page) TYPE tt_slices.

ENDCLASS.



CLASS zcl_wb_rcz_slice_query IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    " Stronicowanie i sortowanie trzeba odczytać zawsze, inaczej RAP zgłasza błąd
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lt_sort) = io_request->get_sort_elements( ).

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    read_records(
      EXPORTING
        it_filter  = lt_filter
      IMPORTING
        et_records = DATA(lt_records)
        et_cuts    = DATA(lt_cuts)
        et_names   = DATA(lt_names) ).

    DATA(lt_slices) = build_slices(
      it_records = lt_records
      it_cuts    = lt_cuts
      it_names   = lt_names ).
    sort_slices(
      EXPORTING
        it_sort   = lt_sort
      CHANGING
        ct_slices = lt_slices ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_slices ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( get_page(
        it_slices    = lt_slices
        iv_offset    = lo_paging->get_offset( )
        iv_page_size = lo_paging->get_page_size( ) ) ).
    ENDIF.

  ENDMETHOD.


  METHOD read_records.

    DATA lt_pernr TYPE RANGE OF pernr_d.
    DATA lt_fpper TYPE RANGE OF fpper.
    DATA lt_datcz TYPE RANGE OF /querc/rcz_e_datcz.

    CLEAR: et_records, et_cuts, et_names.

    lt_pernr = CORRESPONDING #( VALUE #( it_filter[ name = 'PERNR' ]-range OPTIONAL ) ).
    lt_fpper = CORRESPONDING #( VALUE #( it_filter[ name = 'FPPER' ]-range OPTIONAL ) ).
    lt_datcz = CORRESPONDING #( VALUE #( it_filter[ name = 'DATCZ' ]-range OPTIONAL ) ).

    " Oś czasu dotyczy jednego dnia jednego pracownika - bez tych filtrów nic nie czytamy
    IF lt_pernr IS INITIAL OR lt_fpper IS INITIAL OR lt_datcz IS INITIAL.
      RETURN.
    ENDIF.

    SELECT pernr, fpper, datcz, rodcz, wskcz, czilo
      FROM /querc/rcz_czas0
      WHERE pernr IN @lt_pernr
        AND fpper IN @lt_fpper
        AND datcz IN @lt_datcz
      INTO CORRESPONDING FIELDS OF TABLE @et_records.

    IF et_records IS INITIAL.
      RETURN.
    ENDIF.

    SELECT pernr, fpper, datwyc, wskcz, godzod, godzdo
      FROM /querc/rcz_wycin
      WHERE pernr  IN @lt_pernr
        AND fpper  IN @lt_fpper
        AND datwyc IN @lt_datcz
      INTO CORRESPONDING FIELDS OF TABLE @et_cuts.

    " Nazwy rodzajów czasu ważne dzisiaj
    SELECT rodcz, rcname
      FROM /querc/rcz_rczas
      WHERE datod <= @sy-datum
        AND datdo >= @sy-datum
      ORDER BY rodcz, datod DESCENDING
      INTO TABLE @DATA(lt_names).

    LOOP AT lt_names INTO DATA(ls_name).
      " Przy kilku wpisach ważnych dziś bierzemy najnowszy (pierwszy po sortowaniu)
      INSERT VALUE #( rodcz = ls_name-rodcz rcname = ls_name-rcname ) INTO TABLE et_names.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_slices.

    LOOP AT group_by_time_type( it_records ) INTO DATA(ls_time_type).
      " Pusty rodzaj czasu (suma 0) nie trafia na oś czasu
      IF ls_time_type-minutes = 0.
        CONTINUE.
      ENDIF.
      add_slices_of_time_type(
        EXPORTING
          is_time_type = ls_time_type
          it_cuts      = it_cuts
          it_names     = it_names
        CHANGING
          ct_slices    = rt_slices ).
    ENDLOOP.

  ENDMETHOD.


  METHOD group_by_time_type.

    LOOP AT it_records INTO DATA(ls_record)
         GROUP BY ( pernr = ls_record-pernr
                    fpper = ls_record-fpper
                    datcz = ls_record-datcz
                    rodcz = ls_record-rodcz )
         INTO DATA(ls_key).

      DATA(ls_day) = VALUE ty_time_type_day( pernr = ls_key-pernr
                                             fpper = ls_key-fpper
                                             datcz = ls_key-datcz
                                             rodcz = ls_key-rodcz ).
      LOOP AT GROUP ls_key INTO DATA(ls_member).
        ls_day-minutes = ls_day-minutes + ls_member-czilo.
        IF ls_member-wskcz IS NOT INITIAL.
          INSERT ls_member-wskcz INTO TABLE ls_day-wskcz.
        ENDIF.
      ENDLOOP.

      INSERT ls_day INTO TABLE rt_days.
    ENDLOOP.

  ENDMETHOD.


  METHOD add_slices_of_time_type.

    DATA(ls_slice) = VALUE zc_wb_rcz_slice(
      pernr      = is_time_type-pernr
      fpper      = is_time_type-fpper
      datcz      = is_time_type-datcz
      rodcz      = is_time_type-rodcz
      rodczname  = VALUE #( it_names[ rodcz = is_time_type-rodcz ]-rcname OPTIONAL )
      columnname = zcl_wb_rcz_day_query=>get_column( is_time_type-rodcz )
      totaltime  = zcl_wb_rcz_day_query=>format_minutes( is_time_type-minutes ) ).

    " Ciągłe wycinki (np. 22:00-22:30 i 22:30-02:00) są pokazywane jako jeden pasek
    DATA(lt_intervals) = merge_intervals( intervals_of_time_type( is_time_type = is_time_type
                                                                  it_cuts      = it_cuts ) ).

    LOOP AT lt_intervals INTO DATA(ls_interval).
      ls_slice-sliceno = sy-tabix.
      ls_slice-beginmin = ls_interval-begin.
      ls_slice-endmin = ls_interval-end.
      ls_slice-begintime = zcl_wb_rcz_day_query=>format_minutes( ls_interval-begin ).
      ls_slice-endtime = zcl_wb_rcz_day_query=>format_minutes( ls_interval-end MOD c_minutes_per_day ).
      INSERT ls_slice INTO TABLE ct_slices.
    ENDLOOP.

    " Rodzaj czasu bez wycinków - jeden wiersz bez godzin, żeby był widoczny na osi
    IF lt_intervals IS INITIAL.
      INSERT ls_slice INTO TABLE ct_slices.
    ENDIF.

  ENDMETHOD.


  METHOD intervals_of_time_type.

    LOOP AT it_cuts INTO DATA(ls_cut)
         WHERE pernr  = is_time_type-pernr
           AND fpper  = is_time_type-fpper
           AND datwyc = is_time_type-datcz.
      IF NOT line_exists( is_time_type-wskcz[ table_line = ls_cut-wskcz ] ).
        CONTINUE.
      ENDIF.

      DATA(ls_interval) = VALUE ty_interval( begin = time_to_minutes( ls_cut-godzod )
                                             end   = time_to_minutes( ls_cut-godzdo ) ).
      " Wycinek przechodzący przez północ kończy się następnego dnia
      IF ls_interval-end <= ls_interval-begin.
        ls_interval-end = ls_interval-end + c_minutes_per_day.
      ENDIF.
      INSERT ls_interval INTO TABLE rt_intervals.
    ENDLOOP.

  ENDMETHOD.


  METHOD merge_intervals.

    DATA(lt_sorted) = it_intervals.
    SORT lt_sorted BY begin end.

    FIELD-SYMBOLS <ls_previous> TYPE ty_interval.

    LOOP AT lt_sorted INTO DATA(ls_interval).
      UNASSIGN <ls_previous>.
      ASSIGN rt_intervals[ lines( rt_intervals ) ] TO <ls_previous>.
      IF <ls_previous> IS ASSIGNED AND ls_interval-begin <= <ls_previous>-end.
        " Styka się albo nakłada na poprzedni - wydłużamy poprzedni
        <ls_previous>-end = nmax( val1 = <ls_previous>-end
                                  val2 = ls_interval-end ).
      ELSE.
        INSERT ls_interval INTO TABLE rt_intervals.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD time_to_minutes.

    " TIMS ma postać HHMMSS; 240000 (koniec dnia) daje 1440
    rv_minutes = CONV i( iv_time(2) ) * 60 + CONV i( iv_time+2(2) ).

  ENDMETHOD.


  METHOD sort_slices.

    IF it_sort IS INITIAL.
      SORT ct_slices BY pernr fpper datcz rodcz sliceno.
      RETURN.
    ENDIF.

    DATA(lt_order) = VALUE abap_sortorder_tab(
      FOR ls_sort IN it_sort
      ( name = to_upper( ls_sort-element_name ) descending = ls_sort-descending ) ).
    SORT ct_slices BY (lt_order).

  ENDMETHOD.


  METHOD get_page.

    IF iv_page_size = if_rap_query_paging=>page_size_unlimited.
      rt_page = it_slices.
      RETURN.
    ENDIF.

    DATA(lv_from) = iv_offset + 1.
    DATA(lv_to) = iv_offset + iv_page_size.
    LOOP AT it_slices INTO DATA(ls_slice) FROM lv_from TO lv_to.
      INSERT ls_slice INTO TABLE rt_page.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
