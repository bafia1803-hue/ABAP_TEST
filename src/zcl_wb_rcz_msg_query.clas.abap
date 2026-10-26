"! Komunikaty rozliczenia czasu pracy (custom entity ZC_WB_RCZ_MSG) z /QUERC/RCZ_KOMP.
"! Filtr: PERNR (wymagany) oraz DAKOM (np. jeden dzień) albo PERIOD (miesiąc RRRRMM daty komunikatu).
"! Kolejność: błędy (E), ostrzeżenia (W), pozostałe; w obrębie typu wg daty, godziny i numeru.
CLASS zcl_wb_rcz_msg_query DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_rap_query_provider.

    TYPES tt_messages TYPE STANDARD TABLE OF zc_wb_rcz_msg WITH EMPTY KEY.
    TYPES:
      BEGIN OF ty_record,
        pernr TYPE pernr_d,
        inper TYPE inpro,
        fpper TYPE /querc/rcz_fpper,
        nrwer TYPE /querc/rcz_e_nrwer,
        seqnr TYPE cdseq,
        dakom TYPE /querc/rcz_e_dakom,
        rokom TYPE /querc/rcz_e_rokom,
        tykom TYPE /querc/rcz_e_tykom,
        tekom TYPE /querc/rcz_e_trkom,
        msgid TYPE msgid,
        msgno TYPE msgno,
        begti TYPE /querc/rcz_e_godzod,
        endti TYPE /querc/rcz_e_godzdo,
      END OF ty_record.
    TYPES tt_records TYPE STANDARD TABLE OF ty_record WITH EMPTY KEY.

    "! Rekordy tabeli -> wiersze encji, posortowane wg wagi (błędy na górze)
    CLASS-METHODS build_messages
      IMPORTING
        it_records         TYPE tt_records
      RETURNING
        VALUE(rt_messages) TYPE tt_messages.

    "! E = 1 (błąd), W = 2 (ostrzeżenie), pozostałe = 3
    CLASS-METHODS severity_rank
      IMPORTING
        iv_tykom       TYPE /querc/rcz_e_tykom
      RETURNING
        VALUE(rv_rank) TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES tt_dakom_range TYPE RANGE OF /querc/rcz_e_dakom.

    CLASS-METHODS read_records
      IMPORTING
        it_filter         TYPE if_rap_query_filter=>tt_name_range_pairs
      RETURNING
        VALUE(rt_records) TYPE tt_records.

    CLASS-METHODS sort_messages
      IMPORTING
        it_sort     TYPE if_rap_query_request=>tt_sort_elements
      CHANGING
        ct_messages TYPE tt_messages.

    CLASS-METHODS get_page
      IMPORTING
        it_messages    TYPE tt_messages
        iv_offset      TYPE int8
        iv_page_size   TYPE int8
      RETURNING
        VALUE(rt_page) TYPE tt_messages.

    CLASS-METHODS format_time
      IMPORTING
        iv_time        TYPE t
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.



CLASS zcl_wb_rcz_msg_query IMPLEMENTATION.


  METHOD if_rap_query_provider~select.

    " Stronicowanie i sortowanie trzeba odczytać zawsze, inaczej RAP zgłasza błąd
    DATA(lo_paging) = io_request->get_paging( ).
    DATA(lt_sort) = io_request->get_sort_elements( ).

    TRY.
        DATA(lt_filter) = io_request->get_filter( )->get_as_ranges( ).
      CATCH cx_rap_query_filter_no_range.
        CLEAR lt_filter.
    ENDTRY.

    DATA(lt_messages) = build_messages( read_records( lt_filter ) ).
    sort_messages(
      EXPORTING
        it_sort     = lt_sort
      CHANGING
        ct_messages = lt_messages ).

    IF io_request->is_total_numb_of_rec_requested( ).
      io_response->set_total_number_of_records( lines( lt_messages ) ).
    ENDIF.

    IF io_request->is_data_requested( ).
      io_response->set_data( get_page(
        it_messages  = lt_messages
        iv_offset    = lo_paging->get_offset( )
        iv_page_size = lo_paging->get_page_size( ) ) ).
    ENDIF.

  ENDMETHOD.


  METHOD read_records.

    DATA lt_pernr TYPE RANGE OF pernr_d.
    DATA lt_dakom TYPE tt_dakom_range.
    DATA lt_period TYPE RANGE OF fpper.

    lt_pernr = CORRESPONDING #( VALUE #( it_filter[ name = 'PERNR' ]-range OPTIONAL ) ).
    lt_dakom = CORRESPONDING #( VALUE #( it_filter[ name = 'DAKOM' ]-range OPTIONAL ) ).
    lt_period = CORRESPONDING #( VALUE #( it_filter[ name = 'PERIOD' ]-range OPTIONAL ) ).

    " Bez numeru osobowego nie czytamy nic
    IF lt_pernr IS INITIAL.
      RETURN.
    ENDIF.

    " Miesiąc RRRRMM -> zakres dat komunikatu od pierwszego do ostatniego dnia
    LOOP AT lt_period INTO DATA(ls_period) WHERE sign = 'I' AND option = 'EQ'.
      DATA(lv_first_day) = CONV d( |{ ls_period-low }01| ).
      DATA(lv_next_month) = lv_first_day.
      lv_next_month+6(2) = '28'.
      lv_next_month = lv_next_month + 4.
      lv_next_month+6(2) = '01'.
      INSERT VALUE #( sign = 'I' option = 'BT' low = lv_first_day high = lv_next_month - 1 ) INTO TABLE lt_dakom.
    ENDLOOP.

    SELECT pernr, inper, fpper, nrwer, seqnr, dakom, rokom, tykom, tekom, msgid, msgno, begti, endti
      FROM /querc/rcz_komp
      WHERE pernr IN @lt_pernr
        AND dakom IN @lt_dakom
      INTO CORRESPONDING FIELDS OF TABLE @rt_records.

  ENDMETHOD.


  METHOD build_messages.

    LOOP AT it_records INTO DATA(ls_record).
      DATA(ls_message) = CORRESPONDING zc_wb_rcz_msg( ls_record ).
      ls_message-period = ls_record-dakom(6).
      ls_message-severityrank = severity_rank( ls_record-tykom ).
      IF ls_record-begti IS NOT INITIAL OR ls_record-endti IS NOT INITIAL.
        ls_message-begintime = format_time( ls_record-begti ).
        ls_message-endtime = format_time( ls_record-endti ).
      ENDIF.
      INSERT ls_message INTO TABLE rt_messages.
    ENDLOOP.

    SORT rt_messages BY severityrank dakom begintime seqnr.

  ENDMETHOD.


  METHOD severity_rank.

    rv_rank = SWITCH #( iv_tykom
                        WHEN 'E' THEN 1
                        WHEN 'W' THEN 2
                        ELSE 3 ).

  ENDMETHOD.


  METHOD format_time.

    " HHMMSS -> hh:mm
    rv_text = |{ iv_time(2) }:{ iv_time+2(2) }|.

  ENDMETHOD.


  METHOD sort_messages.

    IF it_sort IS INITIAL.
      RETURN.
    ENDIF.

    DATA(lt_order) = VALUE abap_sortorder_tab(
      FOR ls_sort IN it_sort
      ( name = to_upper( ls_sort-element_name ) descending = ls_sort-descending ) ).
    SORT ct_messages BY (lt_order).

  ENDMETHOD.


  METHOD get_page.

    IF iv_page_size = if_rap_query_paging=>page_size_unlimited.
      rt_page = it_messages.
      RETURN.
    ENDIF.

    DATA(lv_from) = iv_offset + 1.
    DATA(lv_to) = iv_offset + iv_page_size.
    LOOP AT it_messages INTO DATA(ls_message) FROM lv_from TO lv_to.
      INSERT ls_message INTO TABLE rt_page.
    ENDLOOP.

  ENDMETHOD.
ENDCLASS.
