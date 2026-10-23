CLASS ltcl_empl DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS splits_by_pernr FOR TESTING.
    METHODS keeps_period FOR TESTING.
    METHODS missing_period_is_invalid FOR TESTING.
    METHODS broken_json_is_invalid FOR TESTING.

    METHODS load
      IMPORTING
        iv_json             TYPE string
      RETURNING
        VALUE(rt_employees) TYPE zcl_wb_empl=>tt_employees.

    METHODS sample_json
      RETURNING
        VALUE(rv_json) TYPE string.

ENDCLASS.


CLASS ltcl_empl IMPLEMENTATION.

  METHOD sample_json.

    CONCATENATE
      '{"PERIOD":{"BEGDA":"2025-03-01","ENDDA":"2025-03-31"},'
      '"PA2001":['
      '{"PERNR":"00000011","SUBTY":"0100","BEGDA":"2025-03-03","ENDDA":"2025-03-04"},'
      '{"PERNR":"00000022","SUBTY":"0100","BEGDA":"2025-03-10","ENDDA":"2025-03-10"},'
      '{"PERNR":"00000011","SUBTY":"0200","BEGDA":"2025-03-20","ENDDA":"2025-03-21"}'
      '],'
      '"TEVEN":[{"PERNR":"00000011","LDATE":"2025-03-05"}]}'
      INTO rv_json.

  ENDMETHOD.


  METHOD load.

    DATA lv_json TYPE xstring.

    lv_json = cl_abap_codepage=>convert_to( iv_json ).

    zcl_wb_empl=>from_json(
      EXPORTING
        iv_json      = lv_json
      RECEIVING
        rt_employees = rt_employees
      EXCEPTIONS
        invalid_file = 1
        OTHERS       = 2 ).

  ENDMETHOD.


  METHOD splits_by_pernr.

    DATA lt_employees TYPE zcl_wb_empl=>tt_employees.
    DATA lo_employee TYPE REF TO zcl_wb_empl.
    DATA lv_lines TYPE i.
    DATA lv_exp_pernr TYPE pernr_d.

    lt_employees = load( sample_json( ) ).
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    lv_lines = lines( lt_employees ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 2 ).

    READ TABLE lt_employees INTO lo_employee INDEX 1.
    lv_exp_pernr = '00000011'.
    cl_abap_unit_assert=>assert_equals( act = lo_employee->mv_pernr exp = lv_exp_pernr ).
    lv_lines = lines( lo_employee->mt_pa2001 ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 2 ).
    lv_lines = lines( lo_employee->mt_teven ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 1 ).

    READ TABLE lt_employees INTO lo_employee INDEX 2.
    lv_exp_pernr = '00000022'.
    cl_abap_unit_assert=>assert_equals( act = lo_employee->mv_pernr exp = lv_exp_pernr ).
    lv_lines = lines( lo_employee->mt_pa2001 ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 1 ).
    cl_abap_unit_assert=>assert_initial( lo_employee->mt_teven ).

  ENDMETHOD.


  METHOD keeps_period.

    DATA lt_employees TYPE zcl_wb_empl=>tt_employees.
    DATA lo_employee TYPE REF TO zcl_wb_empl.
    DATA lv_exp TYPE d.

    lt_employees = load( sample_json( ) ).
    READ TABLE lt_employees INTO lo_employee INDEX 1.
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    lv_exp = '20250301'.
    cl_abap_unit_assert=>assert_equals( act = lo_employee->mv_begda exp = lv_exp ).
    lv_exp = '20250331'.
    cl_abap_unit_assert=>assert_equals( act = lo_employee->mv_endda exp = lv_exp ).

    cl_abap_unit_assert=>assert_true( lo_employee->covers_date( '20250315' ) ).
    cl_abap_unit_assert=>assert_false( lo_employee->covers_date( '20250401' ) ).
    cl_abap_unit_assert=>assert_true( lo_employee->covers_period( iv_begda = '20250301' iv_endda = '20250310' ) ).
    cl_abap_unit_assert=>assert_false( lo_employee->covers_period( iv_begda = '20250225' iv_endda = '20250310' ) ).

  ENDMETHOD.


  METHOD missing_period_is_invalid.

    load( '{"PA2001":[{"PERNR":"00000011","BEGDA":"2025-03-03","ENDDA":"2025-03-04"}]}' ).
    cl_abap_unit_assert=>assert_subrc( exp = 1 ).

  ENDMETHOD.


  METHOD broken_json_is_invalid.

    load( '{"PERIOD":' ).
    cl_abap_unit_assert=>assert_subrc( exp = 1 ).

  ENDMETHOD.

ENDCLASS.
