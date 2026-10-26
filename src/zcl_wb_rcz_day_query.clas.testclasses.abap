CLASS ltcl_rcz_day DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS format_hours_and_minutes FOR TESTING.
    METHODS format_negative FOR TESTING.
    METHODS format_over_99_hours FOR TESTING.
    METHODS sums_time_types_per_day FOR TESTING.
    METHODS unknown_time_type_is_ignored FOR TESTING.

ENDCLASS.


CLASS ltcl_rcz_day IMPLEMENTATION.

  METHOD format_hours_and_minutes.
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( 0 )   exp = `00:00` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( 5 )   exp = `00:05` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( 90 )  exp = `01:30` ).
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( 480 ) exp = `08:00` ).
  ENDMETHOD.


  METHOD format_negative.
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( -75 ) exp = `-01:15` ).
  ENDMETHOD.


  METHOD format_over_99_hours.
    cl_abap_unit_assert=>assert_equals( act = zcl_wb_rcz_day_query=>format_minutes( 6000 ) exp = `100:00` ).
  ENDMETHOD.


  METHOD sums_time_types_per_day.

    " 105 i 290 to ta sama kolumna (czas przepracowany), 107 to plan
    DATA(lt_records) = VALUE zcl_wb_rcz_day_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261001' rodcz = '107' czilo = 480 )
      ( pernr = '00000011' fpper = '202610' datcz = '20261001' rodcz = '105' czilo = 300 )
      ( pernr = '00000011' fpper = '202610' datcz = '20261001' rodcz = '290' czilo = 150 )
      ( pernr = '00000011' fpper = '202610' datcz = '20261002' rodcz = '107' czilo = 450 ) ).

    DATA(lt_days) = zcl_wb_rcz_day_query=>build_days( lt_records ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 2 ).

    DATA(ls_day) = lt_days[ datcz = '20261001' ].
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-plantime )   exp = `08:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-workedtime ) exp = `07:30` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-shortage )   exp = `` ).

    ls_day = lt_days[ datcz = '20261002' ].
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-plantime )   exp = `07:30` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-workedtime ) exp = `` ).

  ENDMETHOD.


  METHOD unknown_time_type_is_ignored.

    " 305 (czas przerwy) jest zakomentowany w konfiguracji - dzień jest, ale wszystkie kolumny puste
    DATA(lt_records) = VALUE zcl_wb_rcz_day_query=>tt_time_records(
      ( pernr = '00000011' fpper = '202610' datcz = '20261003' rodcz = '305' czilo = 30 ) ).

    DATA(lt_days) = zcl_wb_rcz_day_query=>build_days( lt_records ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 1 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_days[ 1 ]-plantime ) exp = `` ).

  ENDMETHOD.

ENDCLASS.
