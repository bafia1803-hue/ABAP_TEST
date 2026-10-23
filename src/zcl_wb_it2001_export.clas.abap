"! <p class="shorttext synchronized">Eksport IT2001 do JSON z anonimizacją numerów osobowych</p>
"! Odczytuje rekordy infotypu 2001 (PA2001), które nachodzą na podany okres,
"! przycina ich daty do tego okresu, zastępuje PERNR losowymi, unikalnymi
"! numerami zastępczymi, serializuje wynik do JSON i zapisuje plik na PC.
CLASS zcl_wb_it2001_export DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES tt_pernr_range TYPE RANGE OF pernr_d.
    TYPES tt_p2001 TYPE STANDARD TABLE OF p2001 WITH DEFAULT KEY.
    TYPES tt_pernr TYPE SORTED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    TYPES:
      BEGIN OF ty_pernr_map,
        pernr_real TYPE pernr_d,
        pernr_anon TYPE pernr_d,
      END OF ty_pernr_map.
    TYPES tt_pernr_map TYPE SORTED TABLE OF ty_pernr_map WITH UNIQUE KEY pernr_real.

    "! @parameter it_pernr | Zakres numerów osobowych (pusty = wszyscy)
    "! @parameter iv_begda | Początek okresu
    "! @parameter iv_endda | Koniec okresu
    "! @raising zcx_wb_it2001_export | Data początkowa jest późniejsza niż końcowa
    METHODS constructor
      IMPORTING
        it_pernr TYPE tt_pernr_range
        iv_begda TYPE begda
        iv_endda TYPE endda
      RAISING
        zcx_wb_it2001_export.

    "! Odczyt, przycięcie dat i anonimizacja
    "! @raising zcx_wb_it2001_export | Brak danych lub błąd losowania
    METHODS execute
      RAISING
        zcx_wb_it2001_export.

    "! Dane po anonimizacji (PERNR zastąpiony)
    METHODS get_data
      RETURNING
        VALUE(rt_data) TYPE tt_p2001.

    "! Mapowanie: prawdziwy PERNR -> PERNR zastępczy
    METHODS get_pernr_map
      RETURNING
        VALUE(rt_map) TYPE tt_pernr_map.

    "! Serializacja danych po anonimizacji do JSON (UTF-8)
    METHODS serialize_json
      RETURNING
        VALUE(rv_json) TYPE xstring.

    "! Okno wyboru pliku i zapis JSON na komputerze użytkownika
    "! @parameter iv_default_name | Proponowana nazwa pliku
    "! @parameter rv_fullpath | Ścieżka zapisanego pliku; pusta, gdy użytkownik anulował
    "! @raising zcx_wb_it2001_export | Tryb tła lub błąd zapisu
    METHODS download
      IMPORTING
        iv_default_name    TYPE string OPTIONAL
      RETURNING
        VALUE(rv_fullpath) TYPE string
      RAISING
        zcx_wb_it2001_export.

    "! Usuwa wiersze spoza okresu i przycina BEGDA/ENDDA do okresu
    CLASS-METHODS clip_dates
      IMPORTING
        iv_begda TYPE begda
        iv_endda TYPE endda
      CHANGING
        ct_data  TYPE tt_p2001.

    "! Losuje unikalne numery zastępcze (różne od siebie i od numerów prawdziwych)
    "! @raising zcx_wb_it2001_export | Nie udało się wylosować unikalnego numeru
    CLASS-METHODS build_pernr_map
      IMPORTING
        it_pernr      TYPE tt_pernr
        iv_seed       TYPE i
      RETURNING
        VALUE(rt_map) TYPE tt_pernr_map
      RAISING
        zcx_wb_it2001_export.

    "! Podmienia PERNR w danych wg mapowania
    CLASS-METHODS apply_pernr_map
      IMPORTING
        it_map  TYPE tt_pernr_map
      CHANGING
        ct_data TYPE tt_p2001.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS c_max_attempts TYPE i VALUE 1000.
    CONSTANTS c_max_pernr TYPE i VALUE 99999999.

    DATA mt_pernr TYPE tt_pernr_range.
    DATA mv_begda TYPE begda.
    DATA mv_endda TYPE endda.
    DATA mt_data TYPE tt_p2001.
    DATA mt_map TYPE tt_pernr_map.

    METHODS read_data
      RETURNING
        VALUE(rt_data) TYPE tt_p2001.

ENDCLASS.



CLASS zcl_wb_it2001_export IMPLEMENTATION.


  METHOD constructor.

    IF iv_begda > iv_endda.
      RAISE EXCEPTION TYPE zcx_wb_it2001_export
        EXPORTING
          textid = zcx_wb_it2001_export=>begda_after_endda.
    ENDIF.

    mt_pernr = it_pernr.
    mv_begda = iv_begda.
    mv_endda = iv_endda.

  ENDMETHOD.


  METHOD execute.

    DATA lt_pernr TYPE tt_pernr.
    DATA lv_timestamp TYPE timestampl.
    DATA lv_seed TYPE i.
    FIELD-SYMBOLS <ls_data> LIKE LINE OF mt_data.

    CLEAR: mt_data, mt_map.

    mt_data = read_data( ).
    IF mt_data IS INITIAL.
      RAISE EXCEPTION TYPE zcx_wb_it2001_export
        EXPORTING
          textid = zcx_wb_it2001_export=>no_data.
    ENDIF.

    clip_dates(
      EXPORTING
        iv_begda = mv_begda
        iv_endda = mv_endda
      CHANGING
        ct_data  = mt_data ).

    LOOP AT mt_data ASSIGNING <ls_data>.
      INSERT <ls_data>-pernr INTO TABLE lt_pernr.
    ENDLOOP.

    " Ziarno z czasu (ułamek sekundy), więc każde uruchomienie daje inne numery
    GET TIME STAMP FIELD lv_timestamp.
    lv_seed = frac( lv_timestamp ) * 10000000.

    mt_map = build_pernr_map(
      it_pernr = lt_pernr
      iv_seed  = lv_seed ).

    apply_pernr_map(
      EXPORTING
        it_map  = mt_map
      CHANGING
        ct_data = mt_data ).

  ENDMETHOD.


  METHOD get_data.
    rt_data = mt_data.
  ENDMETHOD.


  METHOD get_pernr_map.
    rt_map = mt_map.
  ENDMETHOD.


  METHOD read_data.

    " Wiersze nachodzące na okres: BEGDA <= koniec okresu i ENDDA >= początek okresu
    SELECT * FROM pa2001
      INTO CORRESPONDING FIELDS OF TABLE rt_data
      WHERE pernr IN mt_pernr
        AND begda <= mv_endda
        AND endda >= mv_begda
      ORDER BY PRIMARY KEY.

  ENDMETHOD.


  METHOD clip_dates.

    FIELD-SYMBOLS <ls_data> LIKE LINE OF ct_data.

    DELETE ct_data WHERE begda > iv_endda OR endda < iv_begda.

    LOOP AT ct_data ASSIGNING <ls_data>.
      IF <ls_data>-begda < iv_begda.
        <ls_data>-begda = iv_begda.
      ENDIF.
      IF <ls_data>-endda > iv_endda.
        <ls_data>-endda = iv_endda.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD build_pernr_map.

    DATA lo_random TYPE REF TO cl_abap_random_int.
    DATA lt_used TYPE HASHED TABLE OF pernr_d WITH UNIQUE KEY table_line.
    DATA lv_real TYPE pernr_d.
    DATA lv_anon TYPE pernr_d.
    DATA lv_attempt TYPE i.
    DATA ls_map TYPE ty_pernr_map.
    DATA lx_random TYPE REF TO cx_abap_random.

    TRY.
        lo_random = cl_abap_random_int=>create(
          seed = iv_seed
          min  = 1
          max  = c_max_pernr ).
      CATCH cx_abap_random INTO lx_random.
        RAISE EXCEPTION TYPE zcx_wb_it2001_export
          EXPORTING
            textid   = zcx_wb_it2001_export=>random_failed
            previous = lx_random.
    ENDTRY.

    " Numery prawdziwe są od razu "zajęte", żeby żaden zastępczy nie trafił na istniejącą osobę z eksportu
    INSERT LINES OF it_pernr INTO TABLE lt_used.

    LOOP AT it_pernr INTO lv_real.
      lv_attempt = 0.
      DO.
        lv_attempt = lv_attempt + 1.
        IF lv_attempt > c_max_attempts.
          RAISE EXCEPTION TYPE zcx_wb_it2001_export
            EXPORTING
              textid = zcx_wb_it2001_export=>random_failed.
        ENDIF.

        lv_anon = lo_random->get_next( ).
        INSERT lv_anon INTO TABLE lt_used.
        IF sy-subrc = 0.
          ls_map-pernr_real = lv_real.
          ls_map-pernr_anon = lv_anon.
          INSERT ls_map INTO TABLE rt_map.
          EXIT.
        ENDIF.
      ENDDO.
    ENDLOOP.

  ENDMETHOD.


  METHOD apply_pernr_map.

    DATA ls_map TYPE ty_pernr_map.
    FIELD-SYMBOLS <ls_data> LIKE LINE OF ct_data.

    LOOP AT ct_data ASSIGNING <ls_data>.
      READ TABLE it_map INTO ls_map WITH TABLE KEY pernr_real = <ls_data>-pernr.
      IF sy-subrc = 0.
        <ls_data>-pernr = ls_map-pernr_anon.
      ELSE.
        " Bez mapowania nie wolno zostawić prawdziwego numeru
        CLEAR <ls_data>-pernr.
      ENDIF.
    ENDLOOP.

    " Sortowanie po nowym numerze, żeby kolejność nie zdradzała prawdziwych numerów
    SORT ct_data BY pernr subty begda endda seqnr.

  ENDMETHOD.


  METHOD serialize_json.

    DATA lo_writer TYPE REF TO cl_sxml_string_writer.

    lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).
    CALL TRANSFORMATION id
      SOURCE it2001 = mt_data
      RESULT XML lo_writer.
    rv_json = lo_writer->get_output( ).

  ENDMETHOD.


  METHOD download.

    DATA lv_json TYPE xstring.
    DATA lv_default_name TYPE string.
    DATA lv_filename TYPE string.
    DATA lv_path TYPE string.
    DATA lv_fullpath TYPE string.
    DATA lv_action TYPE i.
    DATA lt_solix TYPE solix_tab.
    DATA lv_msgv1 TYPE symsgv.

    IF sy-batch = abap_true.
      RAISE EXCEPTION TYPE zcx_wb_it2001_export
        EXPORTING
          textid = zcx_wb_it2001_export=>no_gui.
    ENDIF.

    lv_json = serialize_json( ).

    IF iv_default_name IS INITIAL.
      lv_default_name = |IT2001_{ mv_begda }_{ mv_endda }.json|.
    ELSE.
      lv_default_name = iv_default_name.
    ENDIF.

    cl_gui_frontend_services=>file_save_dialog(
      EXPORTING
        default_extension = 'json'
        default_file_name = lv_default_name
        file_filter       = 'JSON (*.json)|*.json|'
      CHANGING
        filename          = lv_filename
        path              = lv_path
        fullpath          = lv_fullpath
        user_action       = lv_action
      EXCEPTIONS
        OTHERS            = 1 ).
    IF sy-subrc <> 0.
      RAISE EXCEPTION TYPE zcx_wb_it2001_export
        EXPORTING
          textid = zcx_wb_it2001_export=>file_dialog_failed.
    ENDIF.

    IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_fullpath IS INITIAL.
      RETURN.
    ENDIF.

    lt_solix = cl_bcs_convert=>xstring_to_solix( iv_xstring = lv_json ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = xstrlen( lv_json )
        filename     = lv_fullpath
        filetype     = 'BIN'
      CHANGING
        data_tab     = lt_solix
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc <> 0.
      lv_msgv1 = lv_fullpath.
      RAISE EXCEPTION TYPE zcx_wb_it2001_export
        EXPORTING
          textid = zcx_wb_it2001_export=>download_failed
          msgv1  = lv_msgv1.
    ENDIF.

    rv_fullpath = lv_fullpath.

  ENDMETHOD.
ENDCLASS.
