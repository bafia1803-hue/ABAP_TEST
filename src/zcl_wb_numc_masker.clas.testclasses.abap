CLASS ltcl_numc_masker DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    DATA mo_cut TYPE REF TO zif_wb_field_masker.

    METHODS setup.
    METHODS substitutes_are_unique FOR TESTING.
    METHODS same_value_same_substitute FOR TESTING.
    METHODS initial_value_unchanged FOR TESTING.

ENDCLASS.


CLASS ltcl_numc_masker IMPLEMENTATION.

  METHOD setup.
    CREATE OBJECT mo_cut TYPE zcl_wb_numc_masker
      EXPORTING
        iv_length = 8
        iv_seed   = 42.
  ENDMETHOD.


  METHOD substitutes_are_unique.

    DATA lt_real TYPE HASHED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    DATA lt_masked TYPE HASHED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    DATA lv_pernr TYPE pernr_d.

    DO 200 TIMES.
      lv_pernr = sy-index.
      INSERT lv_pernr INTO TABLE lt_real.
      mo_cut->collect( lv_pernr ).
    ENDDO.

    LOOP AT lt_real INTO lv_pernr.
      mo_cut->mask(
        CHANGING
          cv_value       = lv_pernr
        EXCEPTIONS
          masking_failed = 1
          OTHERS         = 2 ).
      cl_abap_unit_assert=>assert_subrc( exp = 0 ).

      INSERT lv_pernr INTO TABLE lt_masked.
      cl_abap_unit_assert=>assert_subrc( exp = 0 msg = 'Zamiennik powtarza się' ).

      READ TABLE lt_real TRANSPORTING NO FIELDS WITH TABLE KEY table_line = lv_pernr.
      cl_abap_unit_assert=>assert_subrc( exp = 4 msg = 'Zamiennik równy prawdziwej wartości' ).
    ENDLOOP.

  ENDMETHOD.


  METHOD same_value_same_substitute.

    DATA lv_first TYPE pernr_d.
    DATA lv_second TYPE pernr_d.
    DATA lt_mapping TYPE zif_wb_field_masker=>tt_mapping.
    DATA lv_lines TYPE i.

    lv_first = '00001234'.
    lv_second = '00001234'.
    mo_cut->collect( lv_first ).

    mo_cut->mask( CHANGING cv_value = lv_first EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    mo_cut->mask( CHANGING cv_value = lv_second EXCEPTIONS OTHERS = 1 ).
    cl_abap_unit_assert=>assert_subrc( exp = 0 ).

    cl_abap_unit_assert=>assert_equals( act = lv_second exp = lv_first ).

    lt_mapping = mo_cut->get_mapping( ).
    lv_lines = lines( lt_mapping ).
    cl_abap_unit_assert=>assert_equals( act = lv_lines exp = 1 ).

  ENDMETHOD.


  METHOD initial_value_unchanged.

    DATA lv_pernr TYPE pernr_d.

    mo_cut->mask( CHANGING cv_value = lv_pernr EXCEPTIONS OTHERS = 1 ).

    cl_abap_unit_assert=>assert_subrc( exp = 0 ).
    cl_abap_unit_assert=>assert_initial( lv_pernr ).

  ENDMETHOD.

ENDCLASS.
