CLASS ltcl_hr_data_export DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS config_has_all_sources FOR TESTING.
    METHODS config_masks_pernr FOR TESTING.
    METHODS clip_to_period FOR TESTING.
    METHODS clip_removes_outside FOR TESTING.
    METHODS clip_single_date_field FOR TESTING.
    METHODS wrong_period FOR TESTING.

ENDCLASS.


CLASS ltcl_hr_data_export IMPLEMENTATION.

  METHOD config_has_all_sources.

    DATA lt_config TYPE zcl_wb_hr_data_export=>tt_sources.
    DATA lt_expected TYPE STANDARD TABLE OF tabname WITH DEFAULT KEY.
    DATA lv_tabname TYPE tabname.

    APPEND 'PA0000' TO lt_expected.
    APPEND 'PA0001' TO lt_expected.
    APPEND 'PA0007' TO lt_expected.
    APPEND 'PA0008' TO lt_expected.
    APPEND 'PA0030' TO lt_expected.
    APPEND 'PA0515' TO lt_expected.
    APPEND 'PA2001' TO lt_expected.
    APPEND 'PA2002' TO lt_expected.
    APPEND 'PA2004' TO lt_expected.
    APPEND 'PA2006' TO lt_expected.
    APPEND 'PA2007' TO lt_expected.
    APPEND 'TEVEN' TO lt_expected.

    lt_config = zcl_wb_hr_data_export=>get_config( ).

    LOOP AT lt_expected INTO lv_tabname.
      READ TABLE lt_config TRANSPORTING NO FIELDS WITH TABLE KEY tabname = lv_tabname.
      cl_abap_unit_assert=>assert_subrc( exp = 0 msg = lv_tabname ).
    ENDLOOP.

  ENDMETHOD.


  METHOD config_masks_pernr.

    DATA lt_config TYPE zcl_wb_hr_data_export=>tt_sources.
    DATA ls_source LIKE LINE OF lt_config.
    DATA lv_field TYPE fieldname.

    lt_config = zcl_wb_hr_data_export=>get_config( ).

    LOOP AT lt_config INTO ls_source.
      lv_field = 'PERNR'.
      cl_abap_unit_assert=>assert_true( act = boolc( lv_field IN ls_source-masked_fields )
                                        msg = ls_source-tabname ).
      cl_abap_unit_assert=>assert_true( act = boolc( lv_field IN ls_source-fields )
                                        msg = ls_source-tabname ).
      lv_field = 'MANDT'.
      cl_abap_unit_assert=>assert_false( act = boolc( lv_field IN ls_source-fields )
                                         msg = ls_source-tabname ).
    ENDLOOP.

  ENDMETHOD.


  METHOD clip_to_period.

    DATA lt_data TYPE STANDARD TABLE OF p2001 WITH DEFAULT KEY.
    DATA ls_data LIKE LINE OF lt_data.
    DATA lv_exp TYPE d.

    ls_data-pernr = '00000001'.
    ls_data-begda = '20250101'.
    ls_data-endda = '20251231'.
    APPEND ls_data TO lt_data.

    ls_data-pernr = '00000002'.
    ls_data-begda = '20250310'.
    ls_data-endda = '20250312'.
    APPEND ls_data TO lt_data.

    zcl_wb_hr_data_export=>clip_dates(
      EXPORTING
        iv_begda      = '20250301'
        iv_endda      = '20250331'
        iv_from_field = 'BEGDA'
        iv_to_field   = 'ENDDA'
      CHANGING
        ct_data       = lt_data ).

    READ TABLE lt_data INTO ls_data INDEX 1.
    lv_exp = '20250301'.
    cl_abap_unit_assert=>assert_equals( act = ls_data-begda exp = lv_exp ).
    lv_exp = '20250331'.
    cl_abap_unit_assert=>assert_equals( act = ls_data-endda exp = lv_exp ).

    READ TABLE lt_data INTO ls_data INDEX 2.
    lv_exp = '20250310'.
    cl_abap_unit_assert=>assert_equals( act = ls_data-begda exp = lv_exp ).
    lv_exp = '20250312'.
    cl_abap_unit_assert=>assert_equals( act = ls_data-endda exp = lv_exp ).

  ENDMETHOD.


  METHOD clip_removes_outside.

    DATA lt_data TYPE STANDARD TABLE OF p2001 WITH DEFAULT KEY.
    DATA ls_data LIKE LINE OF lt_data.

    ls_data-pernr = '00000001'.
    ls_data-begda = '20250101'.
    ls_data-endda = '20250115'.
    APPEND ls_data TO lt_data.

    zcl_wb_hr_data_export=>clip_dates(
      EXPORTING
        iv_begda      = '20250301'
        iv_endda      = '20250331'
        iv_from_field = 'BEGDA'
        iv_to_field   = 'ENDDA'
      CHANGING
        ct_data       = lt_data ).

    cl_abap_unit_assert=>assert_initial( lt_data ).

  ENDMETHOD.


  METHOD clip_single_date_field.

    TYPES:
      BEGIN OF ty_event,
        pernr TYPE pernr_d,
        ldate TYPE d,
      END OF ty_event.
    DATA lt_data TYPE STANDARD TABLE OF ty_event WITH DEFAULT KEY.
    DATA ls_data LIKE LINE OF lt_data.
    DATA lv_lines TYPE i.

    ls_data-pernr = '00000001'.
    ls_data-ldate = '20250315'.
    APPEND ls_data TO lt_data.
    ls_data-ldate = '20250415'.
    APPEND ls_data TO lt_data.

    zcl_wb_hr_data_export=>clip_dates(
      EXPORTING
        iv_begda      = '20250301'
        iv_endda      = '20250331'
        iv_from_field = 'LDATE'
        iv_to_field   = 'LDATE'
      CHANGING
        ct_data       = lt_data ).

    lv_lines = lines( lt_data ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 1 ).

  ENDMETHOD.


  METHOD wrong_period.

    DATA lt_range TYPE zcl_wb_hr_data_export=>tt_pernr_range.
    DATA lo_export TYPE REF TO zcl_wb_hr_data_export.

    CREATE OBJECT lo_export
      EXPORTING
        it_pernr = lt_range
        iv_begda = '20250201'
        iv_endda = '20250101'.

    lo_export->execute(
      EXCEPTIONS
        wrong_period   = 1
        no_data        = 2
        read_failed    = 3
        masking_failed = 4
        OTHERS         = 5 ).
    cl_abap_unit_assert=>assert_subrc( exp = 1 ).

  ENDMETHOD.

ENDCLASS.
