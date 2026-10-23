"! Eksport danych HR (infotypy PAxxxx i tabela TEVEN) do jednego pliku JSON
"! z maskowaniem wybranych pól (na razie PERNR).
"! Konfiguracja tabel, odczytywanych pól i pól maskowanych jest w CLASS_CONSTRUCTOR.
"! Rekordy okresowe (BEGDA/ENDDA) nachodzące na okres mają daty przycięte do okresu.
"! Błędy są zgłaszane klasycznymi wyjątkami z komunikatem z klasy ZWB_IT2001
"! (pola SY-MSGID, SY-MSGNO, SY-MSGV1..4 są ustawione po wyjątku).
CLASS zcl_wb_hr_data_export DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    TYPES tt_pernr_range TYPE RANGE OF pernr_d.
    TYPES tt_field_range TYPE RANGE OF fieldname.
    TYPES:
      " Jedna eksportowana tabela:
      " TABNAME         - tabela bazy danych, np. PA2001
      " DATE_FROM_FIELD - pole daty początku (BEGDA) albo jedynej daty rekordu (np. LDATE)
      " DATE_TO_FIELD   - pole daty końca (ENDDA) albo to samo pole co DATE_FROM_FIELD
      " FIELDS          - pola odczytywane i zapisywane do JSON
      " MASKED_FIELDS   - pola, których wartość jest zamieniana na zastępczą
      BEGIN OF ty_source,
        tabname         TYPE tabname,
        date_from_field TYPE fieldname,
        date_to_field   TYPE fieldname,
        fields          TYPE tt_field_range,
        masked_fields   TYPE tt_field_range,
      END OF ty_source.
    TYPES tt_sources TYPE STANDARD TABLE OF ty_source WITH KEY tabname.
    TYPES:
      " Okres, którego dotyczą dane w pliku (element PERIOD w JSON)
      BEGIN OF ty_period,
        begda TYPE begda,
        endda TYPE endda,
      END OF ty_period.

    "! Nazwa elementu JSON z okresem danych
    CONSTANTS c_period TYPE string VALUE 'PERIOD'.

    CLASS-METHODS class_constructor.

    "! Konfiguracja eksportowanych tabel
    CLASS-METHODS get_config
      RETURNING
        VALUE(rt_config) TYPE tt_sources.

    "! Usuwa wiersze spoza okresu i przycina daty do okresu (tabela dowolnego typu)
    "! @parameter iv_from_field | Pole daty początku
    "! @parameter iv_to_field | Pole daty końca (może być tym samym polem)
    CLASS-METHODS clip_dates
      IMPORTING
        iv_begda      TYPE begda
        iv_endda      TYPE endda
        iv_from_field TYPE fieldname
        iv_to_field   TYPE fieldname
      CHANGING
        ct_data       TYPE STANDARD TABLE.

    "! @parameter it_pernr | Zakres numerów osobowych (pusty = wszyscy)
    "! @parameter iv_begda | Początek okresu
    "! @parameter iv_endda | Koniec okresu
    METHODS constructor
      IMPORTING
        it_pernr TYPE tt_pernr_range
        iv_begda TYPE begda
        iv_endda TYPE endda.

    "! Odczyt wszystkich tabel z konfiguracji, przycięcie dat i maskowanie
    METHODS execute
      EXCEPTIONS
        wrong_period
        no_data
        read_failed
        masking_failed.

    "! Pary prawdziwa wartość -> zamiennik dla maskowanego pola
    "! @parameter iv_fieldname | Nazwa pola, np. PERNR
    METHODS get_mapping
      IMPORTING
        iv_fieldname      TYPE fieldname
      RETURNING
        VALUE(rt_mapping) TYPE zif_wb_field_masker=>tt_mapping.

    "! Okres i wszystkie tabele w jednym JSON (UTF-8):
    "! {"PERIOD":{"BEGDA":...,"ENDDA":...},"PA0000":[...],...,"TEVEN":[...]}
    METHODS serialize_json
      RETURNING
        VALUE(rv_json) TYPE xstring.

    "! Okno wyboru pliku i zapis JSON na komputerze użytkownika
    "! @parameter iv_default_name | Proponowana nazwa pliku
    "! @parameter rv_fullpath | Ścieżka zapisanego pliku; pusta, gdy użytkownik anulował
    METHODS download
      IMPORTING
        iv_default_name    TYPE string OPTIONAL
      RETURNING
        VALUE(rv_fullpath) TYPE string
      EXCEPTIONS
        no_gui
        dialog_failed
        download_failed.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      BEGIN OF ty_result,
        tabname TYPE tabname,
        data    TYPE REF TO data,
      END OF ty_result.
    TYPES tt_results TYPE STANDARD TABLE OF ty_result WITH KEY tabname.
    TYPES:
      BEGIN OF ty_masker,
        fieldname TYPE fieldname,
        masker    TYPE REF TO zif_wb_field_masker,
      END OF ty_masker.
    TYPES tt_maskers TYPE HASHED TABLE OF ty_masker WITH UNIQUE KEY fieldname.
    TYPES tt_fieldnames TYPE STANDARD TABLE OF fieldname WITH DEFAULT KEY.

    CONSTANTS c_pernr TYPE fieldname VALUE 'PERNR'.

    CLASS-DATA gt_config TYPE tt_sources.

    DATA mt_pernr TYPE tt_pernr_range.
    DATA mv_begda TYPE begda.
    DATA mv_endda TYPE endda.
    DATA mv_seed TYPE i.
    DATA mt_results TYPE tt_results.
    DATA mt_maskers TYPE tt_maskers.

    CLASS-METHODS add_infotype
      IMPORTING
        iv_tabname TYPE tabname.

    CLASS-METHODS add_source
      IMPORTING
        iv_tabname         TYPE tabname
        iv_date_from_field TYPE fieldname
        iv_date_to_field   TYPE fieldname.

    CLASS-METHODS all_fields
      RETURNING
        VALUE(rt_fields) TYPE tt_field_range.

    CLASS-METHODS field
      IMPORTING
        iv_fieldname     TYPE fieldname
      RETURNING
        VALUE(rt_fields) TYPE tt_field_range.

    CLASS-METHODS selected_fields
      IMPORTING
        is_source        TYPE ty_source
      RETURNING
        VALUE(rt_fields) TYPE ddfields.

    CLASS-METHODS create_table
      IMPORTING
        iv_tabname     TYPE tabname
        it_fields      TYPE ddfields
      RETURNING
        VALUE(rr_data) TYPE REF TO data.

    CLASS-METHODS masked_components
      IMPORTING
        is_source      TYPE ty_source
        it_data        TYPE STANDARD TABLE
      RETURNING
        VALUE(rt_names) TYPE tt_fieldnames.

    METHODS read_source
      IMPORTING
        is_source      TYPE ty_source
      RETURNING
        VALUE(rr_data) TYPE REF TO data
      EXCEPTIONS
        read_failed.

    METHODS collect_values
      IMPORTING
        is_source TYPE ty_source
        it_data   TYPE STANDARD TABLE
      EXCEPTIONS
        masking_failed.

    METHODS mask_values
      IMPORTING
        is_source TYPE ty_source
      CHANGING
        ct_data   TYPE STANDARD TABLE
      EXCEPTIONS
        masking_failed.

    METHODS get_masker
      IMPORTING
        iv_fieldname     TYPE fieldname
        iv_value         TYPE simple
      RETURNING
        VALUE(ro_masker) TYPE REF TO zif_wb_field_masker
      EXCEPTIONS
        masking_failed.

    METHODS create_masker
      IMPORTING
        iv_fieldname     TYPE fieldname
        iv_value         TYPE simple
      RETURNING
        VALUE(ro_masker) TYPE REF TO zif_wb_field_masker
      EXCEPTIONS
        masking_failed.

    METHODS get_source
      IMPORTING
        iv_tabname       TYPE tabname
      RETURNING
        VALUE(rs_source) TYPE ty_source.

ENDCLASS.



CLASS zcl_wb_hr_data_export IMPLEMENTATION.


  METHOD class_constructor.

    " Infotypy: rekordy okresowe BEGDA-ENDDA, wszystkie pola, maskowany PERNR.
    " Żeby ograniczyć pola, zmień zakres FIELDS w ADD_SOURCE (np. dodaj E EQ 'NAZWA_POLA').
    add_infotype( 'PA0000' ).
    add_infotype( 'PA0001' ).
    add_infotype( 'PA0007' ).
    add_infotype( 'PA0008' ).
    add_infotype( 'PA0030' ).
    add_infotype( 'PA0515' ).
    add_infotype( 'PA2001' ).
    add_infotype( 'PA2002' ).
    add_infotype( 'PA2004' ).
    add_infotype( 'PA2006' ).
    add_infotype( 'PA2007' ).

    " Zdarzenia czasu: jedna data rekordu (dzień logiczny)
    add_source(
      iv_tabname         = 'TEVEN'
      iv_date_from_field = 'LDATE'
      iv_date_to_field   = 'LDATE' ).

  ENDMETHOD.


  METHOD add_infotype.

    add_source(
      iv_tabname         = iv_tabname
      iv_date_from_field = 'BEGDA'
      iv_date_to_field   = 'ENDDA' ).

  ENDMETHOD.


  METHOD add_source.

    DATA ls_source TYPE ty_source.

    ls_source-tabname = iv_tabname.
    ls_source-date_from_field = iv_date_from_field.
    ls_source-date_to_field = iv_date_to_field.
    ls_source-fields = all_fields( ).
    ls_source-masked_fields = field( c_pernr ).
    APPEND ls_source TO gt_config.

  ENDMETHOD.


  METHOD all_fields.

    DATA ls_field LIKE LINE OF rt_fields.

    ls_field-sign = 'I'.
    ls_field-option = 'CP'.
    ls_field-low = '*'.
    APPEND ls_field TO rt_fields.

    " Mandant nie jest daną biznesową
    ls_field-sign = 'E'.
    ls_field-option = 'EQ'.
    ls_field-low = 'MANDT'.
    APPEND ls_field TO rt_fields.

  ENDMETHOD.


  METHOD field.

    DATA ls_field LIKE LINE OF rt_fields.

    ls_field-sign = 'I'.
    ls_field-option = 'EQ'.
    ls_field-low = iv_fieldname.
    APPEND ls_field TO rt_fields.

  ENDMETHOD.


  METHOD get_config.
    rt_config = gt_config.
  ENDMETHOD.


  METHOD get_source.
    READ TABLE gt_config INTO rs_source WITH TABLE KEY tabname = iv_tabname.
  ENDMETHOD.


  METHOD constructor.

    DATA lv_timestamp TYPE timestampl.

    mt_pernr = it_pernr.
    mv_begda = iv_begda.
    mv_endda = iv_endda.

    " Ziarno z czasu (ułamek sekundy), więc każde uruchomienie daje inne zamienniki
    GET TIME STAMP FIELD lv_timestamp.
    mv_seed = frac( lv_timestamp ) * 10000000.

  ENDMETHOD.


  METHOD execute.

    DATA ls_source TYPE ty_source.
    DATA ls_result TYPE ty_result.
    DATA lv_failed TYPE abap_bool.
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.

    CLEAR: mt_results, mt_maskers.

    IF mv_begda > mv_endda.
      MESSAGE e001(zwb_it2001) RAISING wrong_period.
    ENDIF.

    LOOP AT gt_config INTO ls_source.
      read_source(
        EXPORTING
          is_source   = ls_source
        RECEIVING
          rr_data     = ls_result-data
        EXCEPTIONS
          read_failed = 1
          OTHERS      = 2 ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
          RAISING read_failed.
      ENDIF.

      ASSIGN ls_result-data->* TO <lt_data>.
      clip_dates(
        EXPORTING
          iv_begda      = mv_begda
          iv_endda      = mv_endda
          iv_from_field = ls_source-date_from_field
          iv_to_field   = ls_source-date_to_field
        CHANGING
          ct_data       = <lt_data> ).

      IF <lt_data> IS NOT INITIAL.
        ls_result-tabname = ls_source-tabname.
        APPEND ls_result TO mt_results.
      ENDIF.
    ENDLOOP.

    IF mt_results IS INITIAL.
      MESSAGE e002(zwb_it2001) RAISING no_data.
    ENDIF.

    " Najpierw wszystkie prawdziwe wartości ze wszystkich tabel, potem maskowanie,
    " dzięki czemu ta sama osoba ma ten sam zamiennik w każdej tabeli
    LOOP AT mt_results INTO ls_result.
      ASSIGN ls_result-data->* TO <lt_data>.
      collect_values(
        EXPORTING
          is_source      = get_source( ls_result-tabname )
          it_data        = <lt_data>
        EXCEPTIONS
          masking_failed = 1
          OTHERS         = 2 ).
      IF sy-subrc <> 0.
        MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
          WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
          RAISING masking_failed.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_results INTO ls_result.
      ASSIGN ls_result-data->* TO <lt_data>.
      mask_values(
        EXPORTING
          is_source      = get_source( ls_result-tabname )
        CHANGING
          ct_data        = <lt_data>
        EXCEPTIONS
          masking_failed = 1
          OTHERS         = 2 ).
      IF sy-subrc <> 0.
        lv_failed = abap_true.
        EXIT.
      ENDIF.
    ENDLOOP.

    " Częściowo zamaskowane dane nie mogą trafić do pliku
    IF lv_failed = abap_true.
      CLEAR mt_results.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        RAISING masking_failed.
    ENDIF.

  ENDMETHOD.


  METHOD read_source.

    DATA lt_fields TYPE ddfields.
    DATA ls_field LIKE LINE OF lt_fields.
    DATA lt_select TYPE string_table.
    DATA lv_where TYPE string.
    " Zmienne używane w dynamicznym WHERE (muszą być widoczne w tej metodzie)
    DATA lt_pernr TYPE tt_pernr_range ##NEEDED.
    DATA lv_begda TYPE begda ##NEEDED.
    DATA lv_endda TYPE endda ##NEEDED.
    FIELD-SYMBOLS <lt_data> TYPE STANDARD TABLE.

    lt_fields = selected_fields( is_source ).
    IF lt_fields IS INITIAL.
      MESSAGE e010(zwb_it2001) WITH is_source-tabname RAISING read_failed.
    ENDIF.

    rr_data = create_table(
      iv_tabname = is_source-tabname
      it_fields  = lt_fields ).
    IF rr_data IS NOT BOUND.
      MESSAGE e010(zwb_it2001) WITH is_source-tabname RAISING read_failed.
    ENDIF.
    ASSIGN rr_data->* TO <lt_data>.

    LOOP AT lt_fields INTO ls_field.
      APPEND ls_field-fieldname TO lt_select.
    ENDLOOP.

    lt_pernr = mt_pernr.
    lv_begda = mv_begda.
    lv_endda = mv_endda.
    " Rekord nachodzi na okres: początek rekordu <= koniec okresu i koniec rekordu >= początek okresu
    lv_where = |{ c_pernr } IN LT_PERNR|
            && | AND { is_source-date_from_field } <= LV_ENDDA|
            && | AND { is_source-date_to_field } >= LV_BEGDA|.

    TRY.
        SELECT (lt_select) FROM (is_source-tabname)
          INTO CORRESPONDING FIELDS OF TABLE <lt_data>
          WHERE (lv_where).
      CATCH cx_sy_dynamic_osql_error.
        MESSAGE e010(zwb_it2001) WITH is_source-tabname RAISING read_failed.
    ENDTRY.

  ENDMETHOD.


  METHOD selected_fields.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.

    cl_abap_typedescr=>describe_by_name(
      EXPORTING
        p_name         = is_source-tabname
      RECEIVING
        p_descr_ref    = lo_type
      EXCEPTIONS
        type_not_found = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      RETURN.
    ENDIF.

    lo_struct ?= lo_type.
    lo_struct->get_ddic_field_list(
      RECEIVING
        p_field_list = rt_fields
      EXCEPTIONS
        not_found    = 1
        no_ddic_type = 2
        OTHERS       = 3 ).
    IF sy-subrc <> 0.
      CLEAR rt_fields.
      RETURN.
    ENDIF.

    DELETE rt_fields WHERE fieldname NOT IN is_source-fields.
    " Znaczniki dołączonych struktur (.INCLUDE, .APPEND) to nie są pola
    DELETE rt_fields WHERE fieldname CP '.*'.

  ENDMETHOD.


  METHOD create_table.

    DATA ls_field LIKE LINE OF it_fields.
    DATA lt_components TYPE cl_abap_structdescr=>component_table.
    DATA ls_component LIKE LINE OF lt_components.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lo_table TYPE REF TO cl_abap_tabledescr.
    DATA lv_name TYPE string.

    LOOP AT it_fields INTO ls_field.
      CONCATENATE iv_tabname '-' ls_field-fieldname INTO lv_name.
      ls_component-name = ls_field-fieldname.
      ls_component-type ?= cl_abap_typedescr=>describe_by_name( lv_name ).
      APPEND ls_component TO lt_components.
    ENDLOOP.

    TRY.
        lo_struct = cl_abap_structdescr=>create( lt_components ).
        lo_table = cl_abap_tabledescr=>create( lo_struct ).
      CATCH cx_sy_struct_creation cx_sy_table_creation.
        RETURN.
    ENDTRY.

    CREATE DATA rr_data TYPE HANDLE lo_table.

  ENDMETHOD.


  METHOD clip_dates.

    DATA lv_tabix TYPE i.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_from> TYPE any.
    FIELD-SYMBOLS <lv_to> TYPE any.

    LOOP AT ct_data ASSIGNING <ls_row>.
      lv_tabix = sy-tabix.

      ASSIGN COMPONENT iv_from_field OF STRUCTURE <ls_row> TO <lv_from>.
      IF sy-subrc <> 0.
        " Pole daty nie jest eksportowane - nie ma czego przycinać
        RETURN.
      ENDIF.
      ASSIGN COMPONENT iv_to_field OF STRUCTURE <ls_row> TO <lv_to>.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.

      IF <lv_from> > iv_endda OR <lv_to> < iv_begda.
        DELETE ct_data INDEX lv_tabix.
        CONTINUE.
      ENDIF.

      IF <lv_from> < iv_begda.
        <lv_from> = iv_begda.
      ENDIF.
      IF <lv_to> > iv_endda.
        <lv_to> = iv_endda.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD masked_components.

    DATA lr_row TYPE REF TO data.
    DATA lo_struct TYPE REF TO cl_abap_structdescr.
    DATA lt_components TYPE cl_abap_structdescr=>component_table.
    DATA ls_component LIKE LINE OF lt_components.
    DATA lv_fieldname TYPE fieldname.

    CREATE DATA lr_row LIKE LINE OF it_data.
    lo_struct ?= cl_abap_typedescr=>describe_by_data_ref( lr_row ).
    lt_components = lo_struct->get_components( ).

    LOOP AT lt_components INTO ls_component.
      lv_fieldname = ls_component-name.
      IF lv_fieldname IN is_source-masked_fields.
        APPEND lv_fieldname TO rt_names.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD collect_values.

    DATA lt_names TYPE tt_fieldnames.
    DATA lv_name TYPE fieldname.
    DATA lo_masker TYPE REF TO zif_wb_field_masker.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE simple.

    lt_names = masked_components(
      is_source = is_source
      it_data   = it_data ).

    LOOP AT it_data ASSIGNING <ls_row>.
      LOOP AT lt_names INTO lv_name.
        ASSIGN COMPONENT lv_name OF STRUCTURE <ls_row> TO <lv_value>.

        get_masker(
          EXPORTING
            iv_fieldname   = lv_name
            iv_value       = <lv_value>
          RECEIVING
            ro_masker      = lo_masker
          EXCEPTIONS
            masking_failed = 1
            OTHERS         = 2 ).
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            RAISING masking_failed.
        ENDIF.

        lo_masker->collect( <lv_value> ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD mask_values.

    DATA lt_names TYPE tt_fieldnames.
    DATA lv_name TYPE fieldname.
    DATA lo_masker TYPE REF TO zif_wb_field_masker.
    DATA lt_sort TYPE abap_sortorder_tab.
    DATA ls_sort LIKE LINE OF lt_sort.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_value> TYPE simple.

    lt_names = masked_components(
      is_source = is_source
      it_data   = ct_data ).

    LOOP AT ct_data ASSIGNING <ls_row>.
      LOOP AT lt_names INTO lv_name.
        ASSIGN COMPONENT lv_name OF STRUCTURE <ls_row> TO <lv_value>.

        get_masker(
          EXPORTING
            iv_fieldname   = lv_name
            iv_value       = <lv_value>
          RECEIVING
            ro_masker      = lo_masker
          EXCEPTIONS
            masking_failed = 1
            OTHERS         = 2 ).
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            RAISING masking_failed.
        ENDIF.

        lo_masker->mask(
          CHANGING
            cv_value       = <lv_value>
          EXCEPTIONS
            masking_failed = 1
            OTHERS         = 2 ).
        IF sy-subrc <> 0.
          MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
            WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
            RAISING masking_failed.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

    " Sortowanie po zamiennikach, żeby kolejność wierszy nie zdradzała prawdziwych wartości
    IF lt_names IS NOT INITIAL.
      LOOP AT lt_names INTO lv_name.
        ls_sort-name = lv_name.
        APPEND ls_sort TO lt_sort.
      ENDLOOP.
      SORT ct_data BY (lt_sort).
    ENDIF.

  ENDMETHOD.


  METHOD get_masker.

    DATA ls_masker TYPE ty_masker.

    " Jeden obiekt na pole: ten sam PERNR ma ten sam zamiennik we wszystkich tabelach
    READ TABLE mt_maskers INTO ls_masker WITH TABLE KEY fieldname = iv_fieldname.
    IF sy-subrc = 0.
      ro_masker = ls_masker-masker.
      RETURN.
    ENDIF.

    create_masker(
      EXPORTING
        iv_fieldname   = iv_fieldname
        iv_value       = iv_value
      RECEIVING
        ro_masker      = ro_masker
      EXCEPTIONS
        masking_failed = 1
        OTHERS         = 2 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        RAISING masking_failed.
    ENDIF.

    ls_masker-fieldname = iv_fieldname.
    ls_masker-masker = ro_masker.
    INSERT ls_masker INTO TABLE mt_maskers.

  ENDMETHOD.


  METHOD create_masker.

    DATA lo_type TYPE REF TO cl_abap_typedescr.
    DATA lv_length TYPE i.
    DATA lv_seed TYPE i.

    lo_type = cl_abap_typedescr=>describe_by_data( iv_value ).
    " Różne ziarno dla każdego pola
    lv_seed = mv_seed + lines( mt_maskers ).

    " Sposób maskowania zależy od typu danych pola.
    " Nowy typ (np. tekst) = nowa klasa z interfejsem ZIF_WB_FIELD_MASKER i nowa gałąź WHEN.
    CASE lo_type->type_kind.
      WHEN cl_abap_typedescr=>typekind_num.
        DESCRIBE FIELD iv_value LENGTH lv_length IN CHARACTER MODE.
        CREATE OBJECT ro_masker TYPE zcl_wb_numc_masker
          EXPORTING
            iv_length = lv_length
            iv_seed   = lv_seed.

      WHEN OTHERS.
        MESSAGE e009(zwb_it2001) WITH iv_fieldname lo_type->type_kind RAISING masking_failed.
    ENDCASE.

  ENDMETHOD.


  METHOD get_mapping.

    DATA ls_masker TYPE ty_masker.

    READ TABLE mt_maskers INTO ls_masker WITH TABLE KEY fieldname = iv_fieldname.
    IF sy-subrc = 0.
      rt_mapping = ls_masker-masker->get_mapping( ).
    ENDIF.

  ENDMETHOD.


  METHOD serialize_json.

    DATA lo_writer TYPE REF TO cl_sxml_string_writer.
    DATA lt_source TYPE abap_trans_srcbind_tab.
    DATA ls_source LIKE LINE OF lt_source.
    DATA ls_result TYPE ty_result.
    DATA ls_period TYPE ty_period.

    " Okres zapisany w pliku, żeby odbiorca wiedział, z jakiego czasu są dane
    ls_period-begda = mv_begda.
    ls_period-endda = mv_endda.
    ls_source-name = c_period.
    GET REFERENCE OF ls_period INTO ls_source-value.
    APPEND ls_source TO lt_source.

    " Każda tabela jako osobna tablica w jednym obiekcie JSON
    LOOP AT mt_results INTO ls_result.
      ls_source-name = ls_result-tabname.
      ls_source-value = ls_result-data.
      APPEND ls_source TO lt_source.
    ENDLOOP.

    lo_writer = cl_sxml_string_writer=>create( type = if_sxml=>co_xt_json ).
    CALL TRANSFORMATION id
      SOURCE (lt_source)
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
    DATA lv_size TYPE i.

    IF sy-batch = abap_true.
      MESSAGE e006(zwb_it2001) RAISING no_gui.
    ENDIF.

    lv_json = serialize_json( ).

    IF iv_default_name IS INITIAL.
      CONCATENATE 'HR_EXPORT_' mv_begda '_' mv_endda '.json' INTO lv_default_name.
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
      MESSAGE e004(zwb_it2001) RAISING dialog_failed.
    ENDIF.

    IF lv_action <> cl_gui_frontend_services=>action_ok OR lv_fullpath IS INITIAL.
      RETURN.
    ENDIF.

    lt_solix = cl_bcs_convert=>xstring_to_solix( iv_xstring = lv_json ).
    lv_size = xstrlen( lv_json ).

    cl_gui_frontend_services=>gui_download(
      EXPORTING
        bin_filesize = lv_size
        filename     = lv_fullpath
        filetype     = 'BIN'
      CHANGING
        data_tab     = lt_solix
      EXCEPTIONS
        OTHERS       = 1 ).
    IF sy-subrc <> 0.
      MESSAGE e005(zwb_it2001) WITH lv_fullpath RAISING download_failed.
    ENDIF.

    rv_fullpath = lv_fullpath.

  ENDMETHOD.
ENDCLASS.
