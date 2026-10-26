CLASS ltcl_rcz_day DEFINITION FINAL FOR TESTING
  DURATION SHORT
  RISK LEVEL HARMLESS.

  PRIVATE SECTION.
    METHODS format_hours_and_minutes FOR TESTING.
    METHODS format_negative FOR TESTING.
    METHODS format_over_99_hours FOR TESTING.
    METHODS sums_time_types_per_day FOR TESTING.
    METHODS unknown_time_type_is_ignored FOR TESTING.
    METHODS all_days_of_period FOR TESTING.
    METHODS day_of_week FOR TESTING.
    METHODS message_counts FOR TESTING.

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

  METHOD all_days_of_period.

    " Wrzesień 2026: dane tylko 1.09, a wierszy ma być 30
    DATA(lt_days) = zcl_wb_rcz_day_query=>build_days( VALUE #(
      ( pernr = '00000011' fpper = '202609' datcz = '20260901' rodcz = '107' czilo = 480 ) ) ).

    zcl_wb_rcz_day_query=>add_missing_days(
      EXPORTING
        iv_pernr = '00000011'
        iv_fpper = '202609'
        it_datcz = VALUE #( )
      CHANGING
        ct_days  = lt_days ).

    cl_abap_unit_assert=>assert_equals( act = lines( lt_days ) exp = 30 ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_days[ datcz = '20260901' ]-plantime ) exp = `08:00` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( lt_days[ datcz = '20260905' ]-plantime ) exp = `` ).
    cl_abap_unit_assert=>assert_true( xsdbool( line_exists( lt_days[ datcz = '20260930' ] ) ) ).

  ENDMETHOD.


  METHOD day_of_week.

    DATA(ls_day) = VALUE zc_wb_rcz_day( datcz = '20260905' ).
    zcl_wb_rcz_day_query=>set_day_of_week( CHANGING cs_day = ls_day ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-dayofweek ) exp = `sobota` ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-weekendtype ) exp = `SAT` ).

    ls_day = VALUE zc_wb_rcz_day( datcz = '20260906' ).
    zcl_wb_rcz_day_query=>set_day_of_week( CHANGING cs_day = ls_day ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-weekendtype ) exp = `SUN` ).

    ls_day = VALUE zc_wb_rcz_day( datcz = '20260901' ).
    zcl_wb_rcz_day_query=>set_day_of_week( CHANGING cs_day = ls_day ).
    cl_abap_unit_assert=>assert_equals( act = CONV string( ls_day-dayofweek ) exp = `wtorek` ).
    cl_abap_unit_assert=>assert_initial( ls_day-weekendtype ).

  ENDMETHOD.

  METHOD message_counts.

    DATA(lt_days) = VALUE zcl_wb_rcz_day_query=>tt_days(
      ( pernr = '00000011' fpper = '202609' datcz = '20260902' )
      ( pernr = '00000011' fpper = '202609' datcz = '20260903' ) ).

    zcl_wb_rcz_day_query=>apply_message_counts(
      EXPORTING
        it_counts = VALUE #( ( dakom = '20260902' tykom = 'E' msg_count = 2 )
                             ( dakom = '20260902' tykom = 'W' msg_count = 3 )
                             ( dakom = '20260903' tykom = 'W' msg_count = 1 ) )
      CHANGING
        ct_days   = lt_days ).

    cl_abap_unit_assert=>assert_equals( act = lt_days[ datcz = '20260902' ]-errorcount exp = 2 ).
    cl_abap_unit_assert=>assert_equals( act = lt_days[ datcz = '20260902' ]-warningcount exp = 3 ).
    cl_abap_unit_assert=>assert_equals( act = lt_days[ datcz = '20260903' ]-errorcount exp = 0 ).
    cl_abap_unit_assert=>assert_equals( act = lt_days[ datcz = '20260903' ]-warningcount exp = 1 ).

  ENDMETHOD.

ENDCLASS.
