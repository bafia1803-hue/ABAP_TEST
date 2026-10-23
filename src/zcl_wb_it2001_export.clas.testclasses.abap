CLASS ltcl_export DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS clip_to_period FOR TESTING.
    METHODS clip_removes_outside FOR TESTING.
    METHODS map_is_unique FOR TESTING RAISING zcx_wb_it2001_export.
    METHODS apply_replaces_pernr FOR TESTING RAISING zcx_wb_it2001_export.
    METHODS begda_after_endda FOR TESTING.

ENDCLASS.


CLASS ltcl_export IMPLEMENTATION.

  METHOD clip_to_period.

    DATA lt_data TYPE zcl_wb_it2001_export=>tt_p2001.
    DATA ls_data LIKE LINE OF lt_data.

    ls_data-pernr = '00000001'.
    ls_data-begda = '20250101'.
    ls_data-endda = '20251231'.
    APPEND ls_data TO lt_data.

    ls_data-pernr = '00000002'.
    ls_data-begda = '20250310'.
    ls_data-endda = '20250312'.
    APPEND ls_data TO lt_data.

    zcl_wb_it2001_export=>clip_dates(
      EXPORTING
        iv_begda = '20250301'
        iv_endda = '20250331'
      CHANGING
        ct_data  = lt_data ).

    READ TABLE lt_data INTO ls_data INDEX 1.
    cl_abap_unit_assert=>assert_equals( act = ls_data-begda exp = '20250301' ).
    cl_abap_unit_assert=>assert_equals( act = ls_data-endda exp = '20250331' ).

    READ TABLE lt_data INTO ls_data INDEX 2.
    cl_abap_unit_assert=>assert_equals( act = ls_data-begda exp = '20250310' ).
    cl_abap_unit_assert=>assert_equals( act = ls_data-endda exp = '20250312' ).

  ENDMETHOD.


  METHOD clip_removes_outside.

    DATA lt_data TYPE zcl_wb_it2001_export=>tt_p2001.
    DATA ls_data LIKE LINE OF lt_data.

    ls_data-pernr = '00000001'.
    ls_data-begda = '20250101'.
    ls_data-endda = '20250115'.
    APPEND ls_data TO lt_data.

    zcl_wb_it2001_export=>clip_dates(
      EXPORTING
        iv_begda = '20250301'
        iv_endda = '20250331'
      CHANGING
        ct_data  = lt_data ).

    cl_abap_unit_assert=>assert_initial( lt_data ).

  ENDMETHOD.


  METHOD map_is_unique.

    DATA lt_pernr TYPE zcl_wb_it2001_export=>tt_pernr.
    DATA lt_map TYPE zcl_wb_it2001_export=>tt_pernr_map.
    DATA ls_map LIKE LINE OF lt_map.
    DATA lt_anon TYPE HASHED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    DATA lv_pernr TYPE pernr_d.

    DO 200 TIMES.
      lv_pernr = sy-index.
      INSERT lv_pernr INTO TABLE lt_pernr.
    ENDDO.

    lt_map = zcl_wb_it2001_export=>build_pernr_map(
      it_pernr = lt_pernr
      iv_seed  = 42 ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_map ) exp = 200 ).

    LOOP AT lt_map INTO ls_map.
      INSERT ls_map-pernr_anon INTO TABLE lt_anon.
      cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'Zastępczy PERNR powtarza się' ).

      READ TABLE lt_pernr TRANSPORTING NO FIELDS WITH TABLE KEY table_line = ls_map-pernr_anon.
      cl_abap_unit_assert=>assert_subrc( exp = 4 msg = 'Zastępczy PERNR równy prawdziwemu' ).

      cl_abap_unit_assert=>assert_not_initial( ls_map-pernr_anon ).
    ENDLOOP.

  ENDMETHOD.


  METHOD apply_replaces_pernr.

    DATA lt_pernr TYPE zcl_wb_it2001_export=>tt_pernr.
    DATA lt_map TYPE zcl_wb_it2001_export=>tt_pernr_map.
    DATA ls_map LIKE LINE OF lt_map.
    DATA lt_data TYPE zcl_wb_it2001_export=>tt_p2001.
    DATA ls_data LIKE LINE OF lt_data.

    INSERT '00001234' INTO TABLE lt_pernr.
    lt_map = zcl_wb_it2001_export=>build_pernr_map(
      it_pernr = lt_pernr
      iv_seed  = 7 ).
    READ TABLE lt_map INTO ls_map INDEX 1.

    ls_data-pernr = '00001234'.
    APPEND ls_data TO lt_data.
    ls_data-pernr = '00009999'.
    APPEND ls_data TO lt_data.

    zcl_wb_it2001_export=>apply_pernr_map(
      EXPORTING
        it_map  = lt_map
      CHANGING
        ct_data = lt_data ).

    READ TABLE lt_data TRANSPORTING NO FIELDS WITH KEY pernr = ls_map-pernr_anon.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    READ TABLE lt_data TRANSPORTING NO FIELDS WITH KEY pernr = '00001234'.
    cl_abap_unit_assert=>assert_subrc( exp = 4 ).

    " Numer bez mapowania jest czyszczony, a nie zostawiany
    READ TABLE lt_data TRANSPORTING NO FIELDS WITH KEY pernr = '00009999'.
    cl_abap_unit_assert=>assert_subrc( exp = 4 ).

  ENDMETHOD.


  METHOD begda_after_endda.

    DATA lt_range TYPE zcl_wb_it2001_export=>tt_pernr_range.
    DATA lo_export TYPE REF TO zcl_wb_it2001_export.

    TRY.
        CREATE OBJECT lo_export
          EXPORTING
            it_pernr = lt_range
            iv_begda = '20250201'
            iv_endda = '20250101'.
        cl_abap_unit_assert=>fail( 'Oczekiwano wyjątku' ).
      CATCH zcx_wb_it2001_export ##NO_HANDLER.
    ENDTRY.

  ENDMETHOD.

ENDCLASS.
