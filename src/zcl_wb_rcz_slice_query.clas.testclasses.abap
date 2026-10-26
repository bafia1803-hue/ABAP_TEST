CLASS ltcl_rcz_slice DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS time_to_minutes FOR TESTING.
    METHODS slices_joined_by_wskcz FOR TESTING.
    METHODS empty_time_type_skipped FOR TESTING.
    METHODS time_type_without_slices FOR TESTING.
    METHODS slice_over_midnight FOR TESTING.

ENDCLASS.


CLASS ltcl_rcz_slice IMPLEMENTATION.

  METHOD time_to_minutes.
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_slice_query=>time_to_minutes( '000000' ) exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_slice_query=>time_to_minutes( '083000' ) exp = 510 ).
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_slice_query=>time_to_minutes( '240000' ) exp = 1440 ).
  ENDMETHOD.


  METHOD slices_joined_by_wskcz.

    " 105 ma wskaźnik W1 (dwa wycinki), 107 ma wskaźnik P1 (jeden wycinek)
    DATA(lt_records) = VALUE zcl_wb_rcz_slice_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '105' wskcz = 'W1' czilo = 240 )
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '107' wskcz = 'P1' czilo = 480 ) ).
    DATA(lt_cuts) = VALUE zcl_wb_rcz_slice_query=>tt_cuts(
      ( pernr = '00000011' fpper = '202610' datwyc = '20261002' wskcz = 'W1' godzod = '120000' godzdo = '140000' )
      ( pernr = '00000011' fpper = '202610' datwyc = '20261002' wskcz = 'W1' godzod = '080000' godzdo = '100000' )
      ( pernr = '00000011' fpper = '202610' datwyc = '20261002' wskcz = 'P1' godzod = '080000' godzdo = '160000' )
      ( pernr = '00000011' fpper = '202610' datwyc = '20261003' wskcz = 'W1' godzod = '080000' godzdo = '090000' ) ).
    DATA(lt_names) = VALUE zcl_wb_rcz_slice_query=>tt_time_type_names(
      ( rodcz = '105' rcname = 'Czas przepracowany' )
      ( rodcz = '107' rcname = 'Plan' ) ).

    DATA(lt_slices) = zcl_wb_rcz_slice_query=>build_slices(
      it_records = lt_records
      it_cuts    = lt_cuts
      it_names   = lt_names ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_slices ) exp = 3 ).

    DATA(ls_first) = lt_slices[ rodcz = '105' sliceno = 1 ].
    cl_abap_unit_assert=>assert_equals( act = ls_first-beginmin exp = 480 ).
    cl_abap_unit_assert=>assert_equals( act = ls_first-endmin exp = 600 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_first-begintime ) exp = `08:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_first-totaltime ) exp = `04:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_first-rodczname ) exp = `Czas przepracowany` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_first-columnname ) exp = `WORKEDTIME` ).

    cl_abap_unit_assert=>assert_equals( act = lt_slices[ rodcz = '105' sliceno = 2 ]-beginmin exp = 720 ).
    cl_abap_unit_assert=>assert_equals( act = lt_slices[ rodcz = '107' sliceno = 1 ]-endmin exp = 960 ).

  ENDMETHOD.


  METHOD empty_time_type_skipped.

    DATA(lt_records) = VALUE zcl_wb_rcz_slice_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '300' wskcz = 'X' czilo = 0 ) ).

    DATA(lt_slices) = zcl_wb_rcz_slice_query=>build_slices(
      it_records = lt_records
      it_cuts    = VALUE #( )
      it_names   = VALUE #( ) ).

    cl_abap_unit_assert=>assert_initial( lt_slices ).

  ENDMETHOD.


  METHOD time_type_without_slices.

    DATA(lt_records) = VALUE zcl_wb_rcz_slice_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '940' wskcz = 'S1' czilo = 30 ) ).

    DATA(lt_slices) = zcl_wb_rcz_slice_query=>build_slices(
      it_records = lt_records
      it_cuts    = VALUE #( )
      it_names   = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_slices ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = lt_slices[ 1 ]-sliceno exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_slices[ 1 ]-totaltime ) exp = `00:30` ).

  ENDMETHOD.


  METHOD slice_over_midnight.

    DATA(lt_records) = VALUE zcl_wb_rcz_slice_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '235' wskcz = 'N1' czilo = 240 ) ).
    DATA(lt_cuts) = VALUE zcl_wb_rcz_slice_query=>tt_cuts(
      ( pernr = '00000011' fpper = '202610' datwyc = '20261002' wskcz = 'N1' godzod = '220000' godzdo = '020000' ) ).

    DATA(lt_slices) = zcl_wb_rcz_slice_query=>build_slices(
      it_records = lt_records
      it_cuts    = lt_cuts
      it_names   = VALUE #( ) ).

    cl_abap_unit_assert=>assert_equals( act = lt_slices[ 1 ]-beginmin exp = 1320 ).
    cl_abap_unit_assert=>assert_equals( act = lt_slices[ 1 ]-endmin exp = 1560 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_slices[ 1 ]-endtime ) exp = `02:00` ).

  ENDMETHOD.

ENDCLASS.
