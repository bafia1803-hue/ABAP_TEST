"! Dane jednego pracownika (jeden PERNR) wczytane z pliku JSON
"! utworzonego przez ZCL_WB_HR_DATA_EXPORT.
"! Obiekt wie, z jakiego okresu ma dane (MV_BEGDA - MV_ENDDA):
"! poza tym okresem brak rekordu nie oznacza, że rekordu nie ma w systemie.
"! Obiekty tworzą metody FROM_FILE i FROM_JSON (jeden obiekt na PERNR).
"! Błędy są zgłaszane klasycznymi wyjątkami z komunikatem z klasy ZWB_IT2001.
CLASS zcl_wb_empl DEFINITION
  PUBLIC
  FINAL
  CREATE PRIVATE.

  PUBLIC SECTION.

    TYPES tt_employees TYPE STANDARD TABLE OF REF TO zcl_wb_empl WITH DEFAULT KEY.

    TYPES tt_p0000 TYPE STANDARD TABLE OF p0000 WITH DEFAULT KEY.
    TYPES tt_p0001 TYPE STANDARD TABLE OF p0001 WITH DEFAULT KEY.
    TYPES tt_p0007 TYPE STANDARD TABLE OF p0007 WITH DEFAULT KEY.
    TYPES tt_p0008 TYPE STANDARD TABLE OF p0008 WITH DEFAULT KEY.
    TYPES tt_p0030 TYPE STANDARD TABLE OF p0030 WITH DEFAULT KEY.
    TYPES tt_p0515 TYPE STANDARD TABLE OF p0515 WITH DEFAULT KEY.
    TYPES tt_p2001 TYPE STANDARD TABLE OF p2001 WITH DEFAULT KEY.
    TYPES tt_p2002 TYPE STANDARD TABLE OF p2002 WITH DEFAULT KEY.
    TYPES tt_p2004 TYPE STANDARD TABLE OF p2004 WITH DEFAULT KEY.
    TYPES tt_p2006 TYPE STANDARD TABLE OF p2006 WITH DEFAULT KEY.
    TYPES tt_p2007 TYPE STANDARD TABLE OF p2007 WITH DEFAULT KEY.
    TYPES tt_teven TYPE STANDARD TABLE OF teven WITH DEFAULT KEY.

    "! Numer osobowy (w pliku z eksportu: numer zastępczy)
    DATA mv_pernr TYPE pernr_d READ-ONLY.
    "! Początek okresu, z którego są dane
    DATA mv_begda TYPE begda READ-ONLY.
    "! Koniec okresu, z którego są dane
    DATA mv_endda TYPE endda READ-ONLY.

    DATA mt_pa0000 TYPE tt_p0000 READ-ONLY.
    DATA mt_pa0001 TYPE tt_p0001 READ-ONLY.
    DATA mt_pa0007 TYPE tt_p0007 READ-ONLY.
    DATA mt_pa0008 TYPE tt_p0008 READ-ONLY.
    DATA mt_pa0030 TYPE tt_p0030 READ-ONLY.
    DATA mt_pa0515 TYPE tt_p0515 READ-ONLY.
    DATA mt_pa2001 TYPE tt_p2001 READ-ONLY.
    DATA mt_pa2002 TYPE tt_p2002 READ-ONLY.
    DATA mt_pa2004 TYPE tt_p2004 READ-ONLY.
    DATA mt_pa2006 TYPE tt_p2006 READ-ONLY.
    DATA mt_pa2007 TYPE tt_p2007 READ-ONLY.
    DATA mt_teven TYPE tt_teven READ-ONLY.

    CLASS-METHODS class_constructor.

    "! Wczytuje plik JSON z komputera użytkownika i tworzy obiekty pracowników
    "! @parameter iv_fullpath | Ścieżka pliku; pusta = okno wyboru pliku
    "! @parameter rt_employees | Pracownicy posortowani po PERNR; pusto, gdy anulowano
    CLASS-METHODS from_file
      IMPORTING
        iv_fullpath         TYPE string OPTIONAL
      RETURNING
        VALUE(rt_employees) TYPE tt_employees
      EXCEPTIONS
        no_gui
        dialog_failed
        upload_failed
        invalid_file.

    "! Tworzy obiekty pracowników z zawartości pliku JSON
    "! @parameter iv_json | Zawartość pliku (UTF-8)
    "! @parameter rt_employees | Pracownicy posortowani po PERNR
    CLASS-METHODS from_json
      IMPORTING
        iv_json             TYPE xstring
      RETURNING
        VALUE(rt_employees) TYPE tt_employees
      EXCEPTIONS
        invalid_file.

    "! Czy dane obejmują ten dzień
    METHODS covers_date
      IMPORTING
        iv_date          TYPE d
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

    "! Czy dane obejmują cały podany okres
    METHODS covers_period
      IMPORTING
        iv_begda         TYPE begda
        iv_endda         TYPE endda
      RETURNING
        VALUE(rv_result) TYPE abap_bool.

  PROTECTED SECTION.
  PRIVATE SECTION.

    TYPES:
      " Tabela z pliku i atrybut, do którego trafiają jej wiersze
      BEGIN OF ty_source,
        tabname   TYPE tabname,
        attribute TYPE string,
      END OF ty_source.
    TYPES tt_sources TYPE STANDARD TABLE OF ty_source WITH DEFAULT KEY.
    TYPES:
      BEGIN OF ty_employee,
        pernr    TYPE pernr_d,
        employee TYPE REF TO zcl_wb_empl,
      END OF ty_employee.
    TYPES tt_employee_index TYPE SORTED TABLE OF ty_employee WITH UNIQUE KEY pernr.

    CONSTANTS c_pernr TYPE fieldname VALUE 'PERNR'.

    CLASS-DATA gt_sources TYPE tt_sources.

    CLASS-METHODS add_source
      IMPORTING
        iv_tabname TYPE tabname.

    CLASS-METHODS split_by_pernr
      IMPORTING
        io_all              TYPE REF TO zcl_wb_empl
      RETURNING
        VALUE(rt_employees) TYPE tt_employees.

    METHODS constructor
      IMPORTING
        iv_pernr TYPE pernr_d
        iv_begda TYPE begda
        iv_endda TYPE endda.

ENDCLASS.



CLASS zcl_wb_empl IMPLEMENTATION.


  METHOD class_constructor.

    " Tabele z pliku eksportu; atrybut MT_<tabela> musi istnieć w tej klasie
    add_source( 'PA0000' ).
    add_source( 'PA0001' ).
    add_source( 'PA0007' ).
    add_source( 'PA0008' ).
    add_source( 'PA0030' ).
    add_source( 'PA0515' ).
    add_source( 'PA2001' ).
    add_source( 'PA2002' ).
    add_source( 'PA2004' ).
    add_source( 'PA2006' ).
    add_source( 'PA2007' ).
    add_source( 'TEVEN' ).

  ENDMETHOD.


  METHOD add_source.

    DATA ls_source TYPE ty_source.

    ls_source-tabname = iv_tabname.
    CONCATENATE 'MT_' iv_tabname INTO ls_source-attribute.
    APPEND ls_source TO gt_sources.

  ENDMETHOD.


  METHOD constructor.

    mv_pernr = iv_pernr.
    mv_begda = iv_begda.
    mv_endda = iv_endda.

  ENDMETHOD.


  METHOD from_file.

    DATA lt_files TYPE filetable.
    DATA ls_file LIKE LINE OF lt_files.
    DATA lv_rc TYPE i.
    DATA lv_action TYPE i.
    DATA lv_fullpath TYPE string.
    DATA lt_solix TYPE solix_tab.
    DATA lv_size TYPE i.
    DATA lv_json TYPE xstring.

    IF sy-batch = abap_true.
      MESSAGE e006(zwb_it2001) RAISING no_gui.
    ENDIF.

    lv_fullpath = iv_fullpath.
    IF lv_fullpath IS INITIAL.
      cl_gui_frontend_services=>file_open_dialog(
        EXPORTING
          default_extension = 'json'
          file_filter       = 'JSON (*.json)|*.json|'
          multiselection    = abap_false
        CHANGING
          file_table        = lt_files
          rc                = lv_rc
          user_action       = lv_action
        EXCEPTIONS
          OTHERS            = 1 ).
      IF sy-subrc <> 0.
        MESSAGE e004(zwb_it2001) RAISING dialog_failed.
      ENDIF.
      IF lv_action <> cl_gui_frontend_services=>action_ok.
        RETURN.
      ENDIF.
      READ TABLE lt_files INTO ls_file INDEX 1.
      IF sy-subrc <> 0.
        RETURN.
      ENDIF.
      lv_fullpath = ls_file-filename.
    ENDIF.

    cl_gui_frontend_services=>gui_upload(
      EXPORTING
        filename   = lv_fullpath
        filetype   = 'BIN'
      IMPORTING
        filelength = lv_size
      CHANGING
        data_tab   = lt_solix
      EXCEPTIONS
        OTHERS     = 1 ).
    IF sy-subrc <> 0.
      MESSAGE e012(zwb_it2001) WITH lv_fullpath RAISING upload_failed.
    ENDIF.

    lv_json = cl_bcs_convert=>solix_to_xstring(
      it_solix = lt_solix
      iv_size  = lv_size ).

    from_json(
      EXPORTING
        iv_json      = lv_json
      RECEIVING
        rt_employees = rt_employees
      EXCEPTIONS
        invalid_file = 1
        OTHERS       = 2 ).
    IF sy-subrc <> 0.
      MESSAGE ID sy-msgid TYPE 'E' NUMBER sy-msgno
        WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
        RAISING invalid_file.
    ENDIF.

  ENDMETHOD.


  METHOD from_json.

    DATA lo_all TYPE REF TO zcl_wb_empl.
    DATA lv_no_pernr TYPE pernr_d.
    DATA lv_no_date TYPE d.
    DATA ls_period TYPE zcl_wb_hr_data_export=>ty_period.
    DATA lt_bindings TYPE abap_trans_resbind_tab.
    DATA ls_binding LIKE LINE OF lt_bindings.
    DATA ls_source TYPE ty_source.
    DATA lo_reader TYPE REF TO if_sxml_reader.
    DATA lx_error TYPE REF TO cx_root.
    DATA lv_text TYPE string.
    DATA lv_msgv1 TYPE symsgv.
    FIELD-SYMBOLS <lt_rows> TYPE STANDARD TABLE.

    " Pomocniczy obiekt na wszystkie wiersze z pliku; potem podział na pracowników
    CREATE OBJECT lo_all
      EXPORTING
        iv_pernr = lv_no_pernr
        iv_begda = lv_no_date
        iv_endda = lv_no_date.

    ls_binding-name = zcl_wb_hr_data_export=>c_period.
    GET REFERENCE OF ls_period INTO ls_binding-value.
    APPEND ls_binding TO lt_bindings.

    LOOP AT gt_sources INTO ls_source.
      ASSIGN lo_all->(ls_source-attribute) TO <lt_rows>.
      ls_binding-name = ls_source-tabname.
      GET REFERENCE OF <lt_rows> INTO ls_binding-value.
      APPEND ls_binding TO lt_bindings.
    ENDLOOP.

    TRY.
        lo_reader = cl_sxml_string_reader=>create( iv_json ).
        CALL TRANSFORMATION id
          SOURCE XML lo_reader
          RESULT (lt_bindings).
      CATCH cx_transformation_error cx_sxml_error INTO lx_error.
        lv_text = lx_error->get_text( ).
        lv_msgv1 = lv_text.
        MESSAGE e011(zwb_it2001) WITH lv_msgv1 RAISING invalid_file.
    ENDTRY.

    " Bez okresu obiekt nie wiedziałby, z jakiego czasu ma dane
    IF ls_period-begda IS INITIAL OR ls_period-endda IS INITIAL.
      MESSAGE e013(zwb_it2001) RAISING invalid_file.
    ENDIF.

    lo_all->mv_begda = ls_period-begda.
    lo_all->mv_endda = ls_period-endda.
    rt_employees = split_by_pernr( lo_all ).

  ENDMETHOD.


  METHOD split_by_pernr.

    DATA lt_index TYPE tt_employee_index.
    DATA ls_index TYPE ty_employee.
    DATA ls_source TYPE ty_source.
    FIELD-SYMBOLS <lt_all_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <lt_employee_rows> TYPE STANDARD TABLE.
    FIELD-SYMBOLS <ls_row> TYPE any.
    FIELD-SYMBOLS <lv_pernr> TYPE any.

    LOOP AT gt_sources INTO ls_source.
      ASSIGN io_all->(ls_source-attribute) TO <lt_all_rows>.

      LOOP AT <lt_all_rows> ASSIGNING <ls_row>.
        ASSIGN COMPONENT c_pernr OF STRUCTURE <ls_row> TO <lv_pernr>.

        READ TABLE lt_index INTO ls_index WITH TABLE KEY pernr = <lv_pernr>.
        IF sy-subrc <> 0.
          ls_index-pernr = <lv_pernr>.
          CREATE OBJECT ls_index-employee
            EXPORTING
              iv_pernr = ls_index-pernr
              iv_begda = io_all->mv_begda
              iv_endda = io_all->mv_endda.
          INSERT ls_index INTO TABLE lt_index.
        ENDIF.

        ASSIGN ls_index-employee->(ls_source-attribute) TO <lt_employee_rows>.
        APPEND <ls_row> TO <lt_employee_rows>.
      ENDLOOP.
    ENDLOOP.

    LOOP AT lt_index INTO ls_index.
      APPEND ls_index-employee TO rt_employees.
    ENDLOOP.

  ENDMETHOD.


  METHOD covers_date.
    rv_result = boolc( iv_date BETWEEN mv_begda AND mv_endda ).
  ENDMETHOD.


  METHOD covers_period.
    rv_result = boolc( iv_begda >= mv_begda AND iv_endda <= mv_endda AND iv_begda <= iv_endda ).
  ENDMETHOD.
ENDCLASS.
