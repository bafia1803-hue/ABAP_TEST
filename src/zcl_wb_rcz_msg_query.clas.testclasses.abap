CLASS ltcl_rcz_msg DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS errors_first FOR TESTING.
    METHODS times_and_period FOR TESTING.

ENDCLASS.


CLASS ltcl_rcz_msg IMPLEMENTATION.

  METHOD errors_first.

    DATA(lt_messages) = zcl_wb_rcz_msg_query=>build_messages( VALUE #(
      ( pernr = '00000011' seqnr = '00001' dakom = '20260902' tykom = 'W' tekom = 'Ostrzeżenie' )
      ( pernr = '00000011' seqnr = '00002' dakom = '20260905' tykom = 'I' tekom = 'Informacja' )
      ( pernr = '00000011' seqnr = '00003' dakom = '20260910' tykom = 'E' tekom = 'Błąd' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = lt_messages[ 1 ]-tykom exp = 'E' ).
    cl_abap_unit_assert=>assert_equals( act = lt_messages[ 2 ]-tykom exp = 'W' ).
    cl_abap_unit_assert=>assert_equals( act = lt_messages[ 3 ]-severityrank exp = 3 ).

  ENDMETHOD.


  METHOD times_and_period.

    DATA(lt_messages) = zcl_wb_rcz_msg_query=>build_messages( VALUE #(
      ( pernr = '00000011' seqnr = '00001' dakom = '20260902' tykom = 'E' begti = '220000' endti = '020000' )
      ( pernr = '00000011' seqnr = '00002' dakom = '20260903' tykom = 'E' ) ) ).

    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_messages[ 1 ]-begintime ) exp = `22:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_messages[ 1 ]-endtime ) exp = `02:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_messages[ 1 ]-period ) exp = `202609` ).
    cl_abap_unit_assert=>assert_initial( lt_messages[ 2 ]-begintime ).

  ENDMETHOD.

ENDCLASS.
