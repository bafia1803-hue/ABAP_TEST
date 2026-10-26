*&---------------------------------------------------------------------*
*& Report ZWB_DDIC_DUMP
*&---------------------------------------------------------------------*
*& Opis techniczny obiektów słownika DDIC (domeny, elementy danych,
*& tabele i struktury, typy tabel) oraz infotypów HR w jednym pliku
*& Markdown, do przekazania modelowi AI jako kontekst systemu.
*& Obiekty wybierane są po nazwie (domyślnie Z*, Y*, CI_*) i/lub po
*& pakietach, opcjonalnie razem z całą hierarchią podpakietów.
*&---------------------------------------------------------------------*
REPORT zwb_ddic_dump MESSAGE-ID zwb_ddic.

TABLES sscrfields.

TYPES tt_objn_range TYPE RANGE OF sobj_name.
TYPES tt_devc_range TYPE RANGE OF devclass.
TYPES tt_infty_range TYPE RANGE OF infty.

TYPES:
  BEGIN OF ty_options,
    objn        TYPE tt_objn_range,
    devc        TYPE tt_devc_range,
    subpackages TYPE abap_bool,
    doma        TYPE abap_bool,
    dtel        TYPE abap_bool,
    tabl        TYPE abap_bool,
    ttyp        TYPE abap_bool,
    infotypes   TYPE abap_bool,
    infty       TYPE tt_infty_range,
    infty_cust  TYPE abap_bool,
  END OF ty_options.

DATA gv_obj_name TYPE sobj_name.
DATA gv_devclass TYPE devclass.
DATA gv_infty TYPE infty.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
SELECT-OPTIONS s_objn FOR gv_obj_name.
SELECT-OPTIONS s_devc FOR gv_devclass.
PARAMETERS p_subp AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b01.

SELECTION-SCREEN BEGIN OF BLOCK b02 WITH FRAME TITLE TEXT-b02.
PARAMETERS p_doma AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_dtel AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_tabl AS CHECKBOX DEFAULT 'X'.
PARAMETERS p_ttyp AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b02.

SELECTION-SCREEN BEGIN OF BLOCK b03 WITH FRAME TITLE TEXT-b03.
PARAMETERS p_inft AS CHECKBOX DEFAULT 'X'.
SELECT-OPTIONS s_infty FOR gv_infty.
PARAMETERS p_icust AS CHECKBOX DEFAULT 'X'.
SELECTION-SCREEN END OF BLOCK b03.


*----------------------------------------------------------------------*
* Odczyt słownika i budowa dokumentu Markdown
*----------------------------------------------------------------------*
CLASS lcl_ddic_dump DEFINITION FINAL.

  PUBLIC SECTION.

    METHODS constructor
      IMPORTING
        is_options TYPE ty_options.

    METHODS run
      RETURNING
        VALUE(rv_markdown) TYPE string.

    METHODS get_object_count
      RETURNING
        VALUE(rv_count) TYPE i.

  PRIVATE SECTION.

    TYPES tt_devclass TYPE STANDARD TABLE OF devclass WITH DEFAULT KEY.
    TYPES tt_domname TYPE STANDARD TABLE OF domname WITH DEFAULT KEY.
    TYPES tt_rollname TYPE STANDARD TABLE OF rollname WITH DEFAULT KEY.
    TYPES tt_tabname TYPE STANDARD TABLE OF tabname WITH DEFAULT KEY.
    TYPES tt_typename TYPE STANDARD TABLE OF ttypename WITH DEFAULT KEY.
    TYPES tt_langu_range TYPE RANGE OF spras.
    TYPES tt_langu TYPE STANDARD TABLE OF spras WITH DEFAULT KEY.

    TYPES:
      BEGIN OF ty_object,
        object   TYPE trobjtype,
        obj_name TYPE sobj_name,
        devclass TYPE devclass,
      END OF ty_object.
    TYPES tt_object TYPE SORTED TABLE OF ty_object WITH UNIQUE KEY object obj_name.

    " Teksty wszystkich rodzajów w jednej tabeli, wybór języka w GET_TEXT
    TYPES:
      BEGIN OF ty_text,
        kind  TYPE c LENGTH 4,
        name  TYPE sobj_name,
        sub   TYPE fieldname,
        langu TYPE spras,
        text  TYPE string,
      END OF ty_text.
    TYPES tt_text TYPE HASHED TABLE OF ty_text WITH UNIQUE KEY kind name sub langu.

    TYPES:
      BEGIN OF ty_doma,
        domname   TYPE dd01l-domname,
        datatype  TYPE dd01l-datatype,
        leng      TYPE dd01l-leng,
        outputlen TYPE dd01l-outputlen,
        decimals  TYPE dd01l-decimals,
        lowercase TYPE dd01l-lowercase,
        signflag  TYPE dd01l-signflag,
        convexit  TYPE dd01l-convexit,
        entitytab TYPE dd01l-entitytab,
      END OF ty_doma.
    TYPES tt_doma TYPE SORTED TABLE OF ty_doma WITH UNIQUE KEY domname.

    TYPES:
      BEGIN OF ty_fixval,
        domname    TYPE dd07l-domname,
        valpos     TYPE dd07l-valpos,
        domvalue_l TYPE dd07l-domvalue_l,
        domvalue_h TYPE dd07l-domvalue_h,
      END OF ty_fixval.
    TYPES tt_fixval TYPE SORTED TABLE OF ty_fixval WITH NON-UNIQUE KEY domname valpos.

    TYPES:
      BEGIN OF ty_dtel,
        rollname TYPE dd04l-rollname,
        domname  TYPE dd04l-domname,
        datatype TYPE dd04l-datatype,
        leng     TYPE dd04l-leng,
        decimals TYPE dd04l-decimals,
        refkind  TYPE dd04l-refkind,
        shlpname TYPE dd04l-shlpname,
        memoryid TYPE dd04l-memoryid,
      END OF ty_dtel.
    TYPES tt_dtel TYPE SORTED TABLE OF ty_dtel WITH UNIQUE KEY rollname.

    TYPES:
      BEGIN OF ty_tabl,
        tabname  TYPE dd02l-tabname,
        tabclass TYPE dd02l-tabclass,
        sqltab   TYPE dd02l-sqltab,
        contflag TYPE dd02l-contflag,
        clidep   TYPE dd02l-clidep,
      END OF ty_tabl.
    TYPES tt_tabl TYPE SORTED TABLE OF ty_tabl WITH UNIQUE KEY tabname.

    TYPES:
      BEGIN OF ty_field,
        tabname    TYPE dd03l-tabname,
        position   TYPE dd03l-position,
        fieldname  TYPE dd03l-fieldname,
        keyflag    TYPE dd03l-keyflag,
        rollname   TYPE dd03l-rollname,
        checktable TYPE dd03l-checktable,
        precfield  TYPE dd03l-precfield,
        reftable   TYPE dd03l-reftable,
        reffield   TYPE dd03l-reffield,
        datatype   TYPE dd03l-datatype,
        leng       TYPE dd03l-leng,
        decimals   TYPE dd03l-decimals,
        domname    TYPE dd03l-domname,
        comptype   TYPE dd03l-comptype,
      END OF ty_field.
    TYPES tt_field TYPE SORTED TABLE OF ty_field WITH NON-UNIQUE KEY tabname position.

    TYPES:
      BEGIN OF ty_ttyp,
        typename   TYPE dd40l-typename,
        rowtype    TYPE dd40l-rowtype,
        rowkind    TYPE dd40l-rowkind,
        datatype   TYPE dd40l-datatype,
        leng       TYPE dd40l-leng,
        decimals   TYPE dd40l-decimals,
        accessmode TYPE dd40l-accessmode,
        keydef     TYPE dd40l-keydef,
        keykind    TYPE dd40l-keykind,
        keyfields  TYPE string,
      END OF ty_ttyp.
    TYPES tt_ttyp TYPE SORTED TABLE OF ty_ttyp WITH UNIQUE KEY typename.

    TYPES:
      BEGIN OF ty_infty,
        infty   TYPE t582a-infty,
        zeitb   TYPE t582a-zeitb,
        dbtab   TYPE t777d-dbtab,
        ci_name TYPE tabname,
        appends TYPE string,
      END OF ty_infty.
    TYPES tt_infty TYPE SORTED TABLE OF ty_infty WITH UNIQUE KEY infty.

    DATA ms_options TYPE ty_options.
    DATA mt_langu TYPE tt_langu.
    DATA mr_langu TYPE tt_langu_range.
    DATA mt_devclass TYPE tt_devclass.
    DATA mt_object TYPE tt_object.
    DATA mt_text TYPE tt_text.
    DATA mt_doma TYPE tt_doma.
    DATA mt_fixval TYPE tt_fixval.
    DATA mt_dtel TYPE tt_dtel.
    DATA mt_tabl TYPE tt_tabl.
    DATA mt_field TYPE tt_field.
    DATA mt_ttyp TYPE tt_ttyp.
    DATA mt_infty TYPE tt_infty.
    DATA mt_lines TYPE string_table.

    METHODS add_language
      IMPORTING
        iv_langu TYPE spras.

    METHODS collect_packages.
    METHODS collect_objects.
    METHODS collect_infotypes.
    METHODS load_domains.
    METHODS load_data_elements.
    METHODS load_tables.
    METHODS load_table_types.
    METHODS load_dtel_texts.

    METHODS render_header.
    METHODS render_domains.
    METHODS render_data_elements.
    METHODS render_tables.
    METHODS render_table_types.
    METHODS render_infotypes.

    METHODS render_fields
      IMPORTING
        iv_tabname TYPE tabname.

    METHODS add
      IMPORTING
        iv_line TYPE string.

    METHODS add_text
      IMPORTING
        iv_kind  TYPE clike
        iv_name  TYPE clike
        iv_sub   TYPE clike OPTIONAL
        iv_langu TYPE spras
        iv_text  TYPE clike.

    METHODS get_text
      IMPORTING
        iv_kind        TYPE clike
        iv_name        TYPE clike
        iv_sub         TYPE clike OPTIONAL
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS get_package
      IMPORTING
        iv_object          TYPE trobjtype
        iv_name            TYPE clike
      RETURNING
        VALUE(rv_devclass) TYPE devclass.

    METHODS md
      IMPORTING
        iv_text        TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS num
      IMPORTING
        iv_value       TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS yes_no
      IMPORTING
        iv_flag        TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS range_text
      IMPORTING
        it_range       TYPE STANDARD TABLE
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS tabclass_text
      IMPORTING
        iv_tabclass    TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS contflag_text
      IMPORTING
        iv_contflag    TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS rowkind_text
      IMPORTING
        iv_rowkind     TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS accessmode_text
      IMPORTING
        iv_accessmode  TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS key_text
      IMPORTING
        is_ttyp        TYPE ty_ttyp
      RETURNING
        VALUE(rv_text) TYPE string.

    METHODS zeitb_text
      IMPORTING
        iv_zeitb       TYPE clike
      RETURNING
        VALUE(rv_text) TYPE string.

ENDCLASS.


CLASS lcl_ddic_dump IMPLEMENTATION.

  METHOD constructor.

    ms_options = is_options.

    " Teksty w języku logowania, a gdy ich brak po angielsku lub niemiecku
    add_language( sy-langu ).
    add_language( 'E' ).
    add_language( 'D' ).

  ENDMETHOD.


  METHOD add_language.

    DATA ls_langu LIKE LINE OF mr_langu.

    READ TABLE mt_langu TRANSPORTING NO FIELDS WITH KEY table_line = iv_langu.
    IF sy-subrc = 0.
      RETURN.
    ENDIF.

    APPEND iv_langu TO mt_langu.
    ls_langu-sign = 'I'.
    ls_langu-option = 'EQ'.
    ls_langu-low = iv_langu.
    APPEND ls_langu TO mr_langu.

  ENDMETHOD.


  METHOD run.

    collect_packages( ).
    collect_objects( ).
    collect_infotypes( ).

    load_domains( ).
    load_data_elements( ).
    load_tables( ).
    load_table_types( ).
    load_dtel_texts( ).

    CLEAR mt_lines.
    render_header( ).
    render_domains( ).
    render_data_elements( ).
    render_tables( ).
    render_table_types( ).
    render_infotypes( ).

    CONCATENATE LINES OF mt_lines INTO rv_markdown
      SEPARATED BY cl_abap_char_utilities=>newline.

  ENDMETHOD.


  METHOD get_object_count.

    rv_count = lines( mt_doma ) + lines( mt_dtel ) + lines( mt_tabl )
             + lines( mt_ttyp ) + lines( mt_infty ).

  ENDMETHOD.


  METHOD collect_packages.

    DATA lt_level TYPE tt_devclass.
    DATA lt_children TYPE tt_devclass.
    DATA lv_devclass TYPE devclass.

    CLEAR mt_devclass.
    IF ms_options-devc IS INITIAL.
      RETURN.
    ENDIF.

    SELECT devclass FROM tdevc INTO TABLE lt_level
      WHERE devclass IN ms_options-devc.

    " Schodzenie poziomami w dół hierarchii TDEVC-PARENTCL
    WHILE lt_level IS NOT INITIAL.
      APPEND LINES OF lt_level TO mt_devclass.
      IF ms_options-subpackages = abap_false.
        EXIT.
      ENDIF.

      SELECT devclass FROM tdevc INTO TABLE lt_children
        FOR ALL ENTRIES IN lt_level
        WHERE parentcl = lt_level-table_line.

      " Pakiety już odwiedzone pomijamy, żeby uniknąć pętli
      CLEAR lt_level.
      LOOP AT lt_children INTO lv_devclass.
        READ TABLE mt_devclass TRANSPORTING NO FIELDS WITH KEY table_line = lv_devclass.
        IF sy-subrc <> 0.
          APPEND lv_devclass TO lt_level.
        ENDIF.
      ENDLOOP.
      SORT lt_level.
      DELETE ADJACENT DUPLICATES FROM lt_level.
    ENDWHILE.

    SORT mt_devclass.
    DELETE ADJACENT DUPLICATES FROM mt_devclass.

  ENDMETHOD.


  METHOD collect_objects.

    DATA lt_type TYPE RANGE OF trobjtype.
    DATA ls_type LIKE LINE OF lt_type.
    DATA lt_tadir TYPE STANDARD TABLE OF ty_object.
    DATA ls_tadir TYPE ty_object.

    CLEAR mt_object.

    ls_type-sign = 'I'.
    ls_type-option = 'EQ'.
    IF ms_options-doma = abap_true.
      ls_type-low = 'DOMA'.
      APPEND ls_type TO lt_type.
    ENDIF.
    IF ms_options-dtel = abap_true.
      ls_type-low = 'DTEL'.
      APPEND ls_type TO lt_type.
    ENDIF.
    IF ms_options-tabl = abap_true.
      ls_type-low = 'TABL'.
      APPEND ls_type TO lt_type.
    ENDIF.
    IF ms_options-ttyp = abap_true.
      ls_type-low = 'TTYP'.
      APPEND ls_type TO lt_type.
    ENDIF.
    IF lt_type IS INITIAL.
      RETURN.
    ENDIF.

    " Obiekty wg nazwy i obiekty z pakietów sumują się
    IF ms_options-objn IS NOT INITIAL.
      SELECT object obj_name devclass FROM tadir
        INTO CORRESPONDING FIELDS OF TABLE lt_tadir
        WHERE pgmid = 'R3TR'
          AND object IN lt_type
          AND obj_name IN ms_options-objn
          AND delflag = space
          AND genflag = space.
      LOOP AT lt_tadir INTO ls_tadir.
        INSERT ls_tadir INTO TABLE mt_object.
      ENDLOOP.
    ENDIF.

    IF mt_devclass IS NOT INITIAL.
      SELECT object obj_name devclass FROM tadir
        INTO CORRESPONDING FIELDS OF TABLE lt_tadir
        FOR ALL ENTRIES IN mt_devclass
        WHERE pgmid = 'R3TR'
          AND object IN lt_type
          AND devclass = mt_devclass-table_line
          AND delflag = space
          AND genflag = space.
      LOOP AT lt_tadir INTO ls_tadir.
        INSERT ls_tadir INTO TABLE mt_object.
      ENDLOOP.
    ENDIF.

  ENDMETHOD.


  METHOD collect_infotypes.

    TYPES:
      BEGIN OF ty_t582a,
        infty TYPE t582a-infty,
        zeitb TYPE t582a-zeitb,
      END OF ty_t582a.
    TYPES:
      BEGIN OF ty_t777d,
        infty TYPE t777d-infty,
        dbtab TYPE t777d-dbtab,
      END OF ty_t777d.
    TYPES:
      BEGIN OF ty_t582s,
        sprsl TYPE t582s-sprsl,
        infty TYPE t582s-infty,
        itext TYPE t582s-itext,
      END OF ty_t582s.
    TYPES:
      BEGIN OF ty_append,
        tabname TYPE dd02l-tabname,
        sqltab  TYPE dd02l-sqltab,
      END OF ty_append.

    DATA lt_t582a TYPE STANDARD TABLE OF ty_t582a.
    DATA ls_t582a TYPE ty_t582a.
    DATA lt_t777d TYPE SORTED TABLE OF ty_t777d WITH UNIQUE KEY infty.
    DATA ls_t777d TYPE ty_t777d.
    DATA lt_t582s TYPE STANDARD TABLE OF ty_t582s.
    DATA ls_t582s TYPE ty_t582s.
    DATA lt_append TYPE STANDARD TABLE OF ty_append.
    DATA ls_append TYPE ty_append.
    DATA lt_ci TYPE SORTED TABLE OF tabname WITH UNIQUE KEY table_line.
    DATA ls_infty TYPE ty_infty.
    DATA lv_ci_name TYPE tabname.
    DATA lv_ps_name TYPE tabname.
    DATA lv_p_name TYPE tabname.

    CLEAR mt_infty.
    IF ms_options-infotypes = abap_false.
      RETURN.
    ENDIF.

    SELECT infty zeitb FROM t582a
      INTO CORRESPONDING FIELDS OF TABLE lt_t582a
      WHERE infty IN ms_options-infty.
    IF lt_t582a IS INITIAL.
      RETURN.
    ENDIF.

    SELECT infty dbtab FROM t777d
      INTO CORRESPONDING FIELDS OF TABLE lt_t777d
      FOR ALL ENTRIES IN lt_t582a
      WHERE infty = lt_t582a-infty.

    " Rozszerzenia klienta: include CI_Pnnnn i struktury append
    SELECT tabname FROM dd02l INTO TABLE lt_ci
      WHERE tabname LIKE 'CI_P%'
        AND as4local = 'A'
        AND as4vers = '0000'.

    SELECT tabname sqltab FROM dd02l
      INTO CORRESPONDING FIELDS OF TABLE lt_append
      WHERE tabclass = 'APPEND'
        AND as4local = 'A'
        AND as4vers = '0000'.
    SORT lt_append BY sqltab tabname.

    LOOP AT lt_t582a INTO ls_t582a.
      READ TABLE lt_t777d INTO ls_t777d WITH TABLE KEY infty = ls_t582a-infty.
      IF sy-subrc <> 0 OR ls_t777d-dbtab IS INITIAL.
        CONTINUE.
      ENDIF.

      CLEAR ls_infty.
      ls_infty-infty = ls_t582a-infty.
      ls_infty-zeitb = ls_t582a-zeitb.
      ls_infty-dbtab = ls_t777d-dbtab.

      CONCATENATE 'CI_P' ls_infty-infty INTO lv_ci_name.
      READ TABLE lt_ci TRANSPORTING NO FIELDS WITH TABLE KEY table_line = lv_ci_name.
      IF sy-subrc = 0.
        ls_infty-ci_name = lv_ci_name.
      ENDIF.

      CONCATENATE 'PS' ls_infty-infty INTO lv_ps_name.
      CONCATENATE 'P' ls_infty-infty INTO lv_p_name.
      LOOP AT lt_append INTO ls_append
        WHERE sqltab = ls_infty-dbtab OR sqltab = lv_ps_name OR sqltab = lv_p_name.
        IF ls_infty-appends IS INITIAL.
          ls_infty-appends = ls_append-tabname.
        ELSE.
          ls_infty-appends = |{ ls_infty-appends }, { ls_append-tabname }|.
        ENDIF.
      ENDLOOP.

      " Infotypy standardowe bez zmian klienta można pominąć
      IF ms_options-infty_cust = abap_true
        AND ls_infty-infty < '9000'
        AND ls_infty-ci_name IS INITIAL
        AND ls_infty-appends IS INITIAL.
        CONTINUE.
      ENDIF.

      INSERT ls_infty INTO TABLE mt_infty.
    ENDLOOP.

    IF mt_infty IS INITIAL.
      RETURN.
    ENDIF.

    SELECT sprsl infty itext FROM t582s
      INTO CORRESPONDING FIELDS OF TABLE lt_t582s
      FOR ALL ENTRIES IN mt_infty
      WHERE sprsl IN mr_langu
        AND infty = mt_infty-infty.
    LOOP AT lt_t582s INTO ls_t582s.
      add_text( iv_kind  = 'INFT'
                iv_name  = ls_t582s-infty
                iv_langu = ls_t582s-sprsl
                iv_text  = ls_t582s-itext ).
    ENDLOOP.

  ENDMETHOD.


  METHOD load_domains.

    TYPES:
      BEGIN OF ty_dd01t,
        domname    TYPE dd01t-domname,
        ddlanguage TYPE dd01t-ddlanguage,
        ddtext     TYPE dd01t-ddtext,
      END OF ty_dd01t.
    TYPES:
      BEGIN OF ty_dd07t,
        domname    TYPE dd07t-domname,
        ddlanguage TYPE dd07t-ddlanguage,
        valpos     TYPE dd07t-valpos,
        ddtext     TYPE dd07t-ddtext,
      END OF ty_dd07t.

    DATA lt_name TYPE tt_domname.
    DATA ls_object TYPE ty_object.
    DATA lt_dd01t TYPE STANDARD TABLE OF ty_dd01t.
    DATA ls_dd01t TYPE ty_dd01t.
    DATA lt_dd07t TYPE STANDARD TABLE OF ty_dd07t.
    DATA ls_dd07t TYPE ty_dd07t.

    CLEAR: mt_doma, mt_fixval.

    LOOP AT mt_object INTO ls_object WHERE object = 'DOMA'.
      APPEND ls_object-obj_name TO lt_name.
    ENDLOOP.
    IF lt_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT domname datatype leng outputlen decimals lowercase signflag convexit entitytab
      FROM dd01l INTO CORRESPONDING FIELDS OF TABLE mt_doma
      FOR ALL ENTRIES IN lt_name
      WHERE domname = lt_name-table_line
        AND as4local = 'A'
        AND as4vers = '0000'.

    SELECT domname valpos domvalue_l domvalue_h
      FROM dd07l INTO CORRESPONDING FIELDS OF TABLE mt_fixval
      FOR ALL ENTRIES IN lt_name
      WHERE domname = lt_name-table_line
        AND as4local = 'A'
        AND as4vers = '0000'.

    SELECT domname ddlanguage ddtext
      FROM dd01t INTO CORRESPONDING FIELDS OF TABLE lt_dd01t
      FOR ALL ENTRIES IN lt_name
      WHERE domname = lt_name-table_line
        AND ddlanguage IN mr_langu
        AND as4local = 'A'.
    LOOP AT lt_dd01t INTO ls_dd01t.
      add_text( iv_kind  = 'DOMA'
                iv_name  = ls_dd01t-domname
                iv_langu = ls_dd01t-ddlanguage
                iv_text  = ls_dd01t-ddtext ).
    ENDLOOP.

    SELECT domname ddlanguage valpos ddtext
      FROM dd07t INTO CORRESPONDING FIELDS OF TABLE lt_dd07t
      FOR ALL ENTRIES IN lt_name
      WHERE domname = lt_name-table_line
        AND ddlanguage IN mr_langu
        AND as4local = 'A'.
    LOOP AT lt_dd07t INTO ls_dd07t.
      add_text( iv_kind  = 'DOVA'
                iv_name  = ls_dd07t-domname
                iv_sub   = ls_dd07t-valpos
                iv_langu = ls_dd07t-ddlanguage
                iv_text  = ls_dd07t-ddtext ).
    ENDLOOP.

  ENDMETHOD.


  METHOD load_data_elements.

    DATA lt_name TYPE tt_rollname.
    DATA ls_object TYPE ty_object.

    CLEAR mt_dtel.

    LOOP AT mt_object INTO ls_object WHERE object = 'DTEL'.
      APPEND ls_object-obj_name TO lt_name.
    ENDLOOP.
    IF lt_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT rollname domname datatype leng decimals refkind shlpname memoryid
      FROM dd04l INTO CORRESPONDING FIELDS OF TABLE mt_dtel
      FOR ALL ENTRIES IN lt_name
      WHERE rollname = lt_name-table_line
        AND as4local = 'A'
        AND as4vers = '0000'.

  ENDMETHOD.


  METHOD load_tables.

    TYPES:
      BEGIN OF ty_dd02t,
        tabname    TYPE dd02t-tabname,
        ddlanguage TYPE dd02t-ddlanguage,
        ddtext     TYPE dd02t-ddtext,
      END OF ty_dd02t.
    TYPES:
      BEGIN OF ty_dd03t,
        tabname    TYPE dd03t-tabname,
        ddlanguage TYPE dd03t-ddlanguage,
        fieldname  TYPE dd03t-fieldname,
        ddtext     TYPE dd03t-ddtext,
      END OF ty_dd03t.

    DATA lt_name TYPE tt_tabname.
    DATA lt_field_tab TYPE tt_tabname.
    DATA ls_object TYPE ty_object.
    DATA ls_infty TYPE ty_infty.
    DATA lt_dd02t TYPE STANDARD TABLE OF ty_dd02t.
    DATA ls_dd02t TYPE ty_dd02t.
    DATA lt_dd03t TYPE STANDARD TABLE OF ty_dd03t.
    DATA ls_dd03t TYPE ty_dd03t.

    CLEAR: mt_tabl, mt_field.

    LOOP AT mt_object INTO ls_object WHERE object = 'TABL'.
      APPEND ls_object-obj_name TO lt_name.
    ENDLOOP.

    IF lt_name IS NOT INITIAL.
      SELECT tabname tabclass sqltab contflag clidep
        FROM dd02l INTO CORRESPONDING FIELDS OF TABLE mt_tabl
        FOR ALL ENTRIES IN lt_name
        WHERE tabname = lt_name-table_line
          AND as4local = 'A'
          AND as4vers = '0000'.

      SELECT tabname ddlanguage ddtext
        FROM dd02t INTO CORRESPONDING FIELDS OF TABLE lt_dd02t
        FOR ALL ENTRIES IN lt_name
        WHERE tabname = lt_name-table_line
          AND ddlanguage IN mr_langu
          AND as4local = 'A'.
      LOOP AT lt_dd02t INTO ls_dd02t.
        add_text( iv_kind  = 'TABL'
                  iv_name  = ls_dd02t-tabname
                  iv_langu = ls_dd02t-ddlanguage
                  iv_text  = ls_dd02t-ddtext ).
      ENDLOOP.
    ENDIF.

    " Pola potrzebne są też dla tabel bazy danych infotypów
    lt_field_tab = lt_name.
    LOOP AT mt_infty INTO ls_infty.
      APPEND ls_infty-dbtab TO lt_field_tab.
    ENDLOOP.
    SORT lt_field_tab.
    DELETE ADJACENT DUPLICATES FROM lt_field_tab.
    IF lt_field_tab IS INITIAL.
      RETURN.
    ENDIF.

    SELECT tabname position fieldname keyflag rollname checktable precfield
           reftable reffield datatype leng decimals domname comptype
      FROM dd03l INTO CORRESPONDING FIELDS OF TABLE mt_field
      FOR ALL ENTRIES IN lt_field_tab
      WHERE tabname = lt_field_tab-table_line
        AND as4local = 'A'
        AND as4vers = '0000'.

    " Opisy pól bez elementu danych (typ wbudowany)
    SELECT tabname ddlanguage fieldname ddtext
      FROM dd03t INTO CORRESPONDING FIELDS OF TABLE lt_dd03t
      FOR ALL ENTRIES IN lt_field_tab
      WHERE tabname = lt_field_tab-table_line
        AND ddlanguage IN mr_langu
        AND as4local = 'A'.
    LOOP AT lt_dd03t INTO ls_dd03t.
      add_text( iv_kind  = 'FILD'
                iv_name  = ls_dd03t-tabname
                iv_sub   = ls_dd03t-fieldname
                iv_langu = ls_dd03t-ddlanguage
                iv_text  = ls_dd03t-ddtext ).
    ENDLOOP.

  ENDMETHOD.


  METHOD load_table_types.

    TYPES:
      BEGIN OF ty_dd40t,
        typename   TYPE dd40t-typename,
        ddlanguage TYPE dd40t-ddlanguage,
        ddtext     TYPE dd40t-ddtext,
      END OF ty_dd40t.

    DATA lt_name TYPE tt_typename.
    DATA ls_object TYPE ty_object.
    DATA lt_dd40t TYPE STANDARD TABLE OF ty_dd40t.
    DATA ls_dd40t TYPE ty_dd40t.
    DATA lt_dd42v TYPE STANDARD TABLE OF dd42v.
    DATA ls_dd42v TYPE dd42v.
    FIELD-SYMBOLS <ls_ttyp> TYPE ty_ttyp.
    FIELD-SYMBOLS <lv_seckey> TYPE any.

    CLEAR mt_ttyp.

    LOOP AT mt_object INTO ls_object WHERE object = 'TTYP'.
      APPEND ls_object-obj_name TO lt_name.
    ENDLOOP.
    IF lt_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT typename rowtype rowkind datatype leng decimals accessmode keydef keykind
      FROM dd40l INTO CORRESPONDING FIELDS OF TABLE mt_ttyp
      FOR ALL ENTRIES IN lt_name
      WHERE typename = lt_name-table_line
        AND as4local = 'A'.

    SELECT typename ddlanguage ddtext
      FROM dd40t INTO CORRESPONDING FIELDS OF TABLE lt_dd40t
      FOR ALL ENTRIES IN lt_name
      WHERE typename = lt_name-table_line
        AND ddlanguage IN mr_langu
        AND as4local = 'A'.
    LOOP AT lt_dd40t INTO ls_dd40t.
      add_text( iv_kind  = 'TTYP'
                iv_name  = ls_dd40t-typename
                iv_langu = ls_dd40t-ddlanguage
                iv_text  = ls_dd40t-ddtext ).
    ENDLOOP.

    " Pola klucza tylko dla klucza zdefiniowanego przez użytkownika
    LOOP AT mt_ttyp ASSIGNING <ls_ttyp> WHERE keydef = 'K'.
      CLEAR lt_dd42v.
      CALL FUNCTION 'DDIF_TTYP_GET'
        EXPORTING
          name          = <ls_ttyp>-typename
          state         = 'A'
        TABLES
          dd42v         = lt_dd42v
        EXCEPTIONS
          illegal_input = 1
          OTHERS        = 2.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.

      SORT lt_dd42v BY keyfdpos.
      LOOP AT lt_dd42v INTO ls_dd42v.
        " Klucze drugorzędne pomijamy, interesuje nas klucz podstawowy
        ASSIGN COMPONENT 'SECKEYNAME' OF STRUCTURE ls_dd42v TO <lv_seckey>.
        IF sy-subrc = 0 AND <lv_seckey> IS NOT INITIAL.
          CONTINUE.
        ENDIF.
        IF <ls_ttyp>-keyfields IS INITIAL.
          <ls_ttyp>-keyfields = ls_dd42v-keyfield.
        ELSE.
          <ls_ttyp>-keyfields = |{ <ls_ttyp>-keyfields }, { ls_dd42v-keyfield }|.
        ENDIF.
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD load_dtel_texts.

    TYPES:
      BEGIN OF ty_dd04t,
        rollname   TYPE dd04t-rollname,
        ddlanguage TYPE dd04t-ddlanguage,
        ddtext     TYPE dd04t-ddtext,
        scrtext_m  TYPE dd04t-scrtext_m,
      END OF ty_dd04t.

    DATA lt_name TYPE tt_rollname.
    DATA ls_dtel TYPE ty_dtel.
    DATA ls_field TYPE ty_field.
    DATA lt_dd04t TYPE STANDARD TABLE OF ty_dd04t.
    DATA ls_dd04t TYPE ty_dd04t.

    " Elementy danych wybrane do opisu oraz użyte w polach tabel
    LOOP AT mt_dtel INTO ls_dtel.
      APPEND ls_dtel-rollname TO lt_name.
    ENDLOOP.
    LOOP AT mt_field INTO ls_field WHERE comptype = 'E'.
      APPEND ls_field-rollname TO lt_name.
    ENDLOOP.
    SORT lt_name.
    DELETE ADJACENT DUPLICATES FROM lt_name.
    IF lt_name IS INITIAL.
      RETURN.
    ENDIF.

    SELECT rollname ddlanguage ddtext scrtext_m
      FROM dd04t INTO CORRESPONDING FIELDS OF TABLE lt_dd04t
      FOR ALL ENTRIES IN lt_name
      WHERE rollname = lt_name-table_line
        AND ddlanguage IN mr_langu
        AND as4local = 'A'.
    LOOP AT lt_dd04t INTO ls_dd04t.
      add_text( iv_kind  = 'DTEL'
                iv_name  = ls_dd04t-rollname
                iv_langu = ls_dd04t-ddlanguage
                iv_text  = ls_dd04t-ddtext ).
      add_text( iv_kind  = 'DTLM'
                iv_name  = ls_dd04t-rollname
                iv_langu = ls_dd04t-ddlanguage
                iv_text  = ls_dd04t-scrtext_m ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_header.

    DATA lv_timestamp TYPE string.
    DATA lv_langu TYPE spras.
    DATA lv_langu_iso TYPE laiso.
    DATA lv_languages TYPE string.
    DATA lv_devclass TYPE devclass.
    DATA lv_packages TYPE string.

    lv_timestamp = |{ sy-datum DATE = ISO } { sy-uzeit TIME = ISO }|.

    LOOP AT mt_langu INTO lv_langu.
      CALL FUNCTION 'CONVERSION_EXIT_ISOLA_OUTPUT'
        EXPORTING
          input  = lv_langu
        IMPORTING
          output = lv_langu_iso.
      IF lv_languages IS INITIAL.
        lv_languages = lv_langu_iso.
      ELSE.
        lv_languages = |{ lv_languages }, { lv_langu_iso }|.
      ENDIF.
    ENDLOOP.

    LOOP AT mt_devclass INTO lv_devclass.
      IF lv_packages IS INITIAL.
        lv_packages = lv_devclass.
      ELSE.
        lv_packages = |{ lv_packages }, { lv_devclass }|.
      ENDIF.
    ENDLOOP.

    add( |# Słownik danych ABAP (DDIC) – system { sy-sysid }, klient { sy-mandt }| ).
    add( `` ).
    add( |- Wygenerowano: { lv_timestamp }, wydanie SAP_BASIS { sy-saprl }| ).
    add( |- Język opisów: { lv_languages } (pierwszy dostępny w tej kolejności)| ).
    IF ms_options-objn IS NOT INITIAL.
      add( |- Nazwy obiektów: { range_text( ms_options-objn ) }| ).
    ENDIF.
    IF ms_options-devc IS NOT INITIAL.
      IF ms_options-subpackages = abap_true.
        add( |- Pakiety (z podpakietami): { lv_packages }| ).
      ELSE.
        add( |- Pakiety: { lv_packages }| ).
      ENDIF.
    ENDIF.
    IF ms_options-infotypes = abap_true.
      IF ms_options-infty IS NOT INITIAL.
        add( |- Infotypy: { range_text( ms_options-infty ) }| ).
      ENDIF.
      IF ms_options-infty_cust = abap_true.
        add( `- Infotypy tylko z rozszerzeniami klienta (9xxx, include CI_Pnnnn lub append)` ).
      ENDIF.
    ENDIF.
    add( `` ).
    add( `Jak czytać: kolumna Typ to typ danych słownika ABAP (CHAR – tekst, NUMC – tekst cyfrowy, `
      && `DATS – data RRRRMMDD, TIMS – czas GGMMSS, CURR – kwota z polem waluty, QUAN – ilość z polem `
      && `jednostki, DEC – liczba spakowana, INT1/INT2/INT4 – liczby całkowite, CUKY – waluta, UNIT – jednostka). `
      && `Dł. = długość, Dz. = miejsca dziesiętne. Wiersze .INCLUDE / .APPEND oznaczają dołączoną strukturę, `
      && `której pola występują bezpośrednio pod nimi.` ).

  ENDMETHOD.


  METHOD render_domains.

    DATA ls_doma TYPE ty_doma.
    DATA ls_fixval TYPE ty_fixval.
    DATA lv_value TYPE string.

    IF mt_doma IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( |## Domeny ({ lines( mt_doma ) })| ).
    add( `` ).
    add( `| Domena | Pakiet | Typ | Dł. | Dz. | Dł. wyj. | Małe litery | Ze znakiem | Konwersja | Tabela wartości | Opis |` ).
    add( `|---|---|---|---|---|---|---|---|---|---|---|` ).
    LOOP AT mt_doma INTO ls_doma.
      add( |\| { ls_doma-domname } \| { get_package( iv_object = 'DOMA' iv_name = ls_doma-domname ) } |
        && |\| { ls_doma-datatype } \| { num( ls_doma-leng ) } \| { num( ls_doma-decimals ) } |
        && |\| { num( ls_doma-outputlen ) } \| { yes_no( ls_doma-lowercase ) } \| { yes_no( ls_doma-signflag ) } |
        && |\| { ls_doma-convexit } \| { ls_doma-entitytab } |
        && |\| { md( get_text( iv_kind = 'DOMA' iv_name = ls_doma-domname ) ) } \|| ).
    ENDLOOP.

    IF mt_fixval IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( `### Wartości stałe domen` ).
    LOOP AT mt_doma INTO ls_doma.
      READ TABLE mt_fixval TRANSPORTING NO FIELDS WITH KEY domname = ls_doma-domname.
      IF sy-subrc <> 0.
        CONTINUE.
      ENDIF.
      add( `` ).
      add( |**{ ls_doma-domname }** – { md( get_text( iv_kind = 'DOMA' iv_name = ls_doma-domname ) ) }| ).
      LOOP AT mt_fixval INTO ls_fixval WHERE domname = ls_doma-domname.
        IF ls_fixval-domvalue_h IS INITIAL.
          lv_value = |`{ ls_fixval-domvalue_l }`|.
        ELSE.
          lv_value = |`{ ls_fixval-domvalue_l }`..`{ ls_fixval-domvalue_h }`|.
        ENDIF.
        add( |- { lv_value } – { md( get_text( iv_kind = 'DOVA' iv_name = ls_fixval-domname iv_sub = ls_fixval-valpos ) ) }| ).
      ENDLOOP.
    ENDLOOP.

  ENDMETHOD.


  METHOD render_data_elements.

    DATA ls_dtel TYPE ty_dtel.
    DATA lv_type_ref TYPE string.

    IF mt_dtel IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( |## Elementy danych ({ lines( mt_dtel ) })| ).
    add( `` ).
    add( `| Element danych | Pakiet | Domena / typ ref. | Typ | Dł. | Dz. | Opis | Etykieta | Pomoc wyszuk. | ID param. |` ).
    add( `|---|---|---|---|---|---|---|---|---|---|` ).
    LOOP AT mt_dtel INTO ls_dtel.
      IF ls_dtel-refkind = 'R'.
        lv_type_ref = |REF TO { ls_dtel-domname }|.
      ELSE.
        lv_type_ref = ls_dtel-domname.
      ENDIF.
      add( |\| { ls_dtel-rollname } \| { get_package( iv_object = 'DTEL' iv_name = ls_dtel-rollname ) } |
        && |\| { lv_type_ref } \| { ls_dtel-datatype } \| { num( ls_dtel-leng ) } \| { num( ls_dtel-decimals ) } |
        && |\| { md( get_text( iv_kind = 'DTEL' iv_name = ls_dtel-rollname ) ) } |
        && |\| { md( get_text( iv_kind = 'DTLM' iv_name = ls_dtel-rollname ) ) } |
        && |\| { ls_dtel-shlpname } \| { ls_dtel-memoryid } \|| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_tables.

    DATA ls_tabl TYPE ty_tabl.
    DATA lv_info TYPE string.

    IF mt_tabl IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( |## Tabele i struktury ({ lines( mt_tabl ) })| ).
    LOOP AT mt_tabl INTO ls_tabl.
      add( `` ).
      add( |### { ls_tabl-tabname } – { md( get_text( iv_kind = 'TABL' iv_name = ls_tabl-tabname ) ) }| ).
      add( `` ).
      lv_info = |- Rodzaj: { tabclass_text( ls_tabl-tabclass ) }, |
             && |pakiet { get_package( iv_object = 'TABL' iv_name = ls_tabl-tabname ) }|.
      IF ls_tabl-tabclass = 'TRANSP' OR ls_tabl-tabclass = 'POOL' OR ls_tabl-tabclass = 'CLUSTER'.
        lv_info = |{ lv_info }, klasa dostawy { contflag_text( ls_tabl-contflag ) }, |
               && |zależna od klienta: { yes_no( ls_tabl-clidep ) }|.
      ENDIF.
      add( lv_info ).
      IF ls_tabl-tabclass = 'APPEND' AND ls_tabl-sqltab IS NOT INITIAL.
        add( |- Rozszerza tabelę/strukturę: { ls_tabl-sqltab }| ).
      ENDIF.
      render_fields( ls_tabl-tabname ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_table_types.

    DATA ls_ttyp TYPE ty_ttyp.
    DATA lv_row TYPE string.

    IF mt_ttyp IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( |## Typy tabel ({ lines( mt_ttyp ) })| ).
    add( `` ).
    add( `| Typ tabeli | Pakiet | Typ wiersza | Rodzaj wiersza | Dostęp | Klucz | Opis |` ).
    add( `|---|---|---|---|---|---|---|` ).
    LOOP AT mt_ttyp INTO ls_ttyp.
      IF ls_ttyp-rowtype IS NOT INITIAL.
        lv_row = ls_ttyp-rowtype.
      ELSE.
        lv_row = |{ ls_ttyp-datatype } { num( ls_ttyp-leng ) }|.
        IF ls_ttyp-decimals IS NOT INITIAL.
          lv_row = |{ lv_row },{ num( ls_ttyp-decimals ) }|.
        ENDIF.
      ENDIF.
      add( |\| { ls_ttyp-typename } \| { get_package( iv_object = 'TTYP' iv_name = ls_ttyp-typename ) } |
        && |\| { lv_row } \| { rowkind_text( ls_ttyp-rowkind ) } \| { accessmode_text( ls_ttyp-accessmode ) } |
        && |\| { key_text( ls_ttyp ) } \| { md( get_text( iv_kind = 'TTYP' iv_name = ls_ttyp-typename ) ) } \|| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_infotypes.

    DATA ls_infty TYPE ty_infty.

    IF mt_infty IS INITIAL.
      RETURN.
    ENDIF.

    add( `` ).
    add( |## Infotypy HR ({ lines( mt_infty ) })| ).
    LOOP AT mt_infty INTO ls_infty.
      add( `` ).
      add( |### Infotyp { ls_infty-infty } – { md( get_text( iv_kind = 'INFT' iv_name = ls_infty-infty ) ) }| ).
      add( `` ).
      add( |- Tabela bazy danych: { ls_infty-dbtab }| ).
      add( |- Ograniczenie czasowe: { zeitb_text( ls_infty-zeitb ) }| ).
      IF ls_infty-ci_name IS NOT INITIAL.
        add( |- Include klienta: { ls_infty-ci_name }| ).
      ELSE.
        add( `- Include klienta: brak` ).
      ENDIF.
      IF ls_infty-appends IS NOT INITIAL.
        add( |- Struktury append: { ls_infty-appends }| ).
      ENDIF.
      render_fields( ls_infty-dbtab ).
    ENDLOOP.

  ENDMETHOD.


  METHOD render_fields.

    DATA ls_field TYPE ty_field.
    DATA lv_type_ref TYPE string.
    DATA lv_ref TYPE string.
    DATA lv_text TYPE string.

    READ TABLE mt_field TRANSPORTING NO FIELDS WITH KEY tabname = iv_tabname.
    IF sy-subrc <> 0.
      add( `` ).
      add( `Brak aktywnych pól.` ).
      RETURN.
    ENDIF.

    add( `` ).
    add( `| Pole | Klucz | Element danych / typ | Typ | Dł. | Dz. | Domena | Tab. kontrolna | Pole ref. | Opis |` ).
    add( `|---|---|---|---|---|---|---|---|---|---|` ).
    LOOP AT mt_field INTO ls_field WHERE tabname = iv_tabname.
      CLEAR: lv_type_ref, lv_ref, lv_text.

      " Wiersz dołączenia struktury (.INCLUDE, .APPEND, .INCLU--AP ...)
      IF ls_field-fieldname(1) = '.'.
        IF ls_field-precfield IS NOT INITIAL.
          lv_type_ref = ls_field-precfield.
        ELSE.
          lv_type_ref = ls_field-rollname.
        ENDIF.
        add( |\| **{ ls_field-fieldname }** \| \| **{ lv_type_ref }** \| \| \| \| \| \| \| \|| ).
        CONTINUE.
      ENDIF.

      CASE ls_field-comptype.
        WHEN 'E'.
          lv_type_ref = ls_field-rollname.
          lv_text = get_text( iv_kind = 'DTEL' iv_name = ls_field-rollname ).
        WHEN 'S'.
          lv_type_ref = |struktura { ls_field-rollname }|.
        WHEN 'L'.
          lv_type_ref = |typ tabeli { ls_field-rollname }|.
        WHEN 'R'.
          lv_type_ref = |REF TO { ls_field-rollname }|.
      ENDCASE.
      IF lv_text IS INITIAL.
        lv_text = get_text( iv_kind = 'FILD' iv_name = ls_field-tabname iv_sub = ls_field-fieldname ).
      ENDIF.
      IF ls_field-reffield IS NOT INITIAL.
        lv_ref = |{ ls_field-reftable }-{ ls_field-reffield }|.
      ENDIF.

      add( |\| { ls_field-fieldname } \| { ls_field-keyflag } \| { lv_type_ref } \| { ls_field-datatype } |
        && |\| { num( ls_field-leng ) } \| { num( ls_field-decimals ) } \| { ls_field-domname } |
        && |\| { ls_field-checktable } \| { lv_ref } \| { md( lv_text ) } \|| ).
    ENDLOOP.

  ENDMETHOD.


  METHOD add.

    APPEND iv_line TO mt_lines.

  ENDMETHOD.


  METHOD add_text.

    DATA ls_text TYPE ty_text.

    IF iv_text IS INITIAL.
      RETURN.
    ENDIF.

    ls_text-kind = iv_kind.
    ls_text-name = iv_name.
    ls_text-sub = iv_sub.
    ls_text-langu = iv_langu.
    ls_text-text = iv_text.
    INSERT ls_text INTO TABLE mt_text.

  ENDMETHOD.


  METHOD get_text.

    DATA ls_text TYPE ty_text.
    DATA lv_langu TYPE spras.
    DATA lv_name TYPE sobj_name.
    DATA lv_sub TYPE fieldname.

    lv_name = iv_name.
    lv_sub = iv_sub.
    LOOP AT mt_langu INTO lv_langu.
      READ TABLE mt_text INTO ls_text
        WITH TABLE KEY kind = iv_kind name = lv_name sub = lv_sub langu = lv_langu.
      IF sy-subrc = 0.
        rv_text = ls_text-text.
        RETURN.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD get_package.

    DATA ls_object TYPE ty_object.
    DATA lv_name TYPE sobj_name.

    lv_name = iv_name.
    READ TABLE mt_object INTO ls_object
      WITH TABLE KEY object = iv_object obj_name = lv_name.
    IF sy-subrc = 0.
      rv_devclass = ls_object-devclass.
    ENDIF.

  ENDMETHOD.


  METHOD md.

    rv_text = iv_text.
    REPLACE ALL OCCURRENCES OF '|' IN rv_text WITH '\|'.

  ENDMETHOD.


  METHOD num.

    rv_text = iv_value.
    SHIFT rv_text LEFT DELETING LEADING '0'.
    IF rv_text IS INITIAL.
      rv_text = '0'.
    ENDIF.

  ENDMETHOD.


  METHOD yes_no.

    IF iv_flag IS INITIAL.
      rv_text = 'nie'.
    ELSE.
      rv_text = 'tak'.
    ENDIF.

  ENDMETHOD.


  METHOD range_text.

    DATA lv_entry TYPE string.
    FIELD-SYMBOLS <ls_line> TYPE any.
    FIELD-SYMBOLS <lv_sign> TYPE clike.
    FIELD-SYMBOLS <lv_low> TYPE clike.
    FIELD-SYMBOLS <lv_high> TYPE clike.

    LOOP AT it_range ASSIGNING <ls_line>.
      ASSIGN COMPONENT 'SIGN' OF STRUCTURE <ls_line> TO <lv_sign>.
      ASSIGN COMPONENT 'LOW' OF STRUCTURE <ls_line> TO <lv_low>.
      ASSIGN COMPONENT 'HIGH' OF STRUCTURE <ls_line> TO <lv_high>.
      IF <lv_high> IS INITIAL.
        lv_entry = <lv_low>.
      ELSE.
        lv_entry = |{ <lv_low> }–{ <lv_high> }|.
      ENDIF.
      IF <lv_sign> = 'E'.
        lv_entry = |bez { lv_entry }|.
      ENDIF.
      IF rv_text IS INITIAL.
        rv_text = lv_entry.
      ELSE.
        rv_text = |{ rv_text }, { lv_entry }|.
      ENDIF.
    ENDLOOP.

  ENDMETHOD.


  METHOD tabclass_text.

    CASE iv_tabclass.
      WHEN 'TRANSP'.
        rv_text = 'TRANSP (tabela bazy danych)'.
      WHEN 'INTTAB'.
        rv_text = 'INTTAB (struktura)'.
      WHEN 'APPEND'.
        rv_text = 'APPEND (struktura append)'.
      WHEN 'POOL'.
        rv_text = 'POOL (tabela pulowa)'.
      WHEN 'CLUSTER'.
        rv_text = 'CLUSTER (tabela klastrowa)'.
      WHEN 'VIEW'.
        rv_text = 'VIEW (widok)'.
      WHEN OTHERS.
        rv_text = iv_tabclass.
    ENDCASE.

  ENDMETHOD.


  METHOD contflag_text.

    CASE iv_contflag.
      WHEN 'A'.
        rv_text = 'A (dane aplikacyjne)'.
      WHEN 'C'.
        rv_text = 'C (customizing)'.
      WHEN 'G'.
        rv_text = 'G (customizing chroniony)'.
      WHEN 'L'.
        rv_text = 'L (dane tymczasowe)'.
      WHEN 'E' OR 'S' OR 'W'.
        rv_text = |{ iv_contflag } (dane systemowe)|.
      WHEN OTHERS.
        rv_text = iv_contflag.
    ENDCASE.

  ENDMETHOD.


  METHOD rowkind_text.

    CASE iv_rowkind.
      WHEN 'E'.
        rv_text = 'element danych'.
      WHEN 'S'.
        rv_text = 'struktura/tabela'.
      WHEN 'L'.
        rv_text = 'typ tabeli'.
      WHEN 'R'.
        rv_text = 'referencja'.
      WHEN OTHERS.
        rv_text = 'typ wbudowany'.
    ENDCASE.

  ENDMETHOD.


  METHOD accessmode_text.

    CASE iv_accessmode.
      WHEN 'T'.
        rv_text = 'STANDARD'.
      WHEN 'S'.
        rv_text = 'SORTED'.
      WHEN 'H'.
        rv_text = 'HASHED'.
      WHEN 'I'.
        rv_text = 'INDEX'.
      WHEN 'A'.
        rv_text = 'ANY'.
      WHEN OTHERS.
        rv_text = iv_accessmode.
    ENDCASE.

  ENDMETHOD.


  METHOD key_text.

    DATA lv_kind TYPE string.

    CASE is_ttyp-keykind.
      WHEN 'U'.
        lv_kind = 'UNIQUE'.
      WHEN 'N'.
        lv_kind = 'NON-UNIQUE'.
    ENDCASE.

    CASE is_ttyp-keydef.
      WHEN 'D'.
        rv_text = 'DEFAULT KEY'.
      WHEN 'T'.
        rv_text = 'TABLE_LINE'.
      WHEN 'K'.
        rv_text = is_ttyp-keyfields.
      WHEN OTHERS.
        rv_text = 'brak'.
    ENDCASE.

    IF lv_kind IS NOT INITIAL.
      rv_text = |{ lv_kind } { rv_text }|.
    ENDIF.

  ENDMETHOD.


  METHOD zeitb_text.

    CASE iv_zeitb.
      WHEN '1'.
        rv_text = '1 (rekord musi istnieć bez przerw, jeden naraz)'.
      WHEN '2'.
        rv_text = '2 (najwyżej jeden rekord naraz, przerwy dozwolone)'.
      WHEN '3'.
        rv_text = '3 (dowolna liczba rekordów naraz)'.
      WHEN 'A'.
        rv_text = 'A (dokładnie jeden rekord przez cały czas)'.
      WHEN 'B'.
        rv_text = 'B (najwyżej jeden rekord przez cały czas)'.
      WHEN 'T'.
        rv_text = 'T (zależne od podtypu)'.
      WHEN OTHERS.
        rv_text = iv_zeitb.
    ENDCASE.

  ENDMETHOD.

ENDCLASS.


INITIALIZATION.
  " Domyślnie obiekty w przestrzeni nazw klienta
  s_objn-sign = 'I'.
  s_objn-option = 'CP'.
  s_objn-low = 'Z*'.
  APPEND s_objn.
  s_objn-low = 'Y*'.
  APPEND s_objn.
  s_objn-low = 'CI_*'.
  APPEND s_objn.
  CLEAR s_objn.


AT SELECTION-SCREEN.
  IF sscrfields-ucomm = 'ONLI'.
    IF p_doma = abap_false AND p_dtel = abap_false AND p_tabl = abap_false
      AND p_ttyp = abap_false AND p_inft = abap_false.
      MESSAGE e002.
    ENDIF.
    IF s_objn[] IS INITIAL AND s_devc[] IS INITIAL
      AND ( p_doma = abap_true OR p_dtel = abap_true OR p_tabl = abap_true OR p_ttyp = abap_true ).
      MESSAGE e001.
    ENDIF.
  ENDIF.


START-OF-SELECTION.
  PERFORM main.


*&---------------------------------------------------------------------*
*& Form main
*&---------------------------------------------------------------------*
FORM main.

  DATA ls_options TYPE ty_options.
  DATA lo_dump TYPE REF TO lcl_ddic_dump.
  DATA lv_markdown TYPE string.
  DATA lv_count TYPE i.
  DATA lv_fullpath TYPE string.

  ls_options-objn = s_objn[].
  ls_options-devc = s_devc[].
  ls_options-subpackages = p_subp.
  ls_options-doma = p_doma.
  ls_options-dtel = p_dtel.
  ls_options-tabl = p_tabl.
  ls_options-ttyp = p_ttyp.
  ls_options-infotypes = p_inft.
  ls_options-infty = s_infty[].
  ls_options-infty_cust = p_icust.

  CREATE OBJECT lo_dump
    EXPORTING
      is_options = ls_options.

  lv_markdown = lo_dump->run( ).
  lv_count = lo_dump->get_object_count( ).
  IF lv_count = 0.
    MESSAGE s003 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  PERFORM download USING lv_markdown CHANGING lv_fullpath.
  IF lv_fullpath IS NOT INITIAL.
    MESSAGE s007 WITH lv_fullpath lv_count.
  ENDIF.

ENDFORM.


*&---------------------------------------------------------------------*
*& Form download
*&---------------------------------------------------------------------*
FORM download USING iv_markdown TYPE string
              CHANGING cv_fullpath TYPE string.

  DATA lv_content TYPE xstring.
  DATA lv_default_name TYPE string.
  DATA lv_filename TYPE string.
  DATA lv_path TYPE string.
  DATA lv_action TYPE i.
  DATA lt_solix TYPE solix_tab.
  DATA lv_size TYPE i.

  CLEAR cv_fullpath.

  IF sy-batch = abap_true.
    MESSAGE s006 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lv_default_name = |DDIC_{ sy-sysid }_{ sy-datum }.md|.

  cl_gui_frontend_services=>file_save_dialog(
    EXPORTING
      default_extension = 'md'
      default_file_name = lv_default_name
      file_filter       = 'Markdown (*.md)|*.md|'
    CHANGING
      filename          = lv_filename
      path              = lv_path
      fullpath          = cv_fullpath
      user_action       = lv_action
    EXCEPTIONS
      OTHERS            = 1 ).
  IF sy-subrc <> 0.
    CLEAR cv_fullpath.
    MESSAGE s004 DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_action <> cl_gui_frontend_services=>action_ok OR cv_fullpath IS INITIAL.
    CLEAR cv_fullpath.
    MESSAGE s008 DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  lv_content = cl_abap_codepage=>convert_to( source = iv_markdown codepage = `UTF-8` ).
  lt_solix = cl_bcs_convert=>xstring_to_solix( iv_xstring = lv_content ).
  lv_size = xstrlen( lv_content ).

  cl_gui_frontend_services=>gui_download(
    EXPORTING
      bin_filesize = lv_size
      filename     = cv_fullpath
      filetype     = 'BIN'
    CHANGING
      data_tab     = lt_solix
    EXCEPTIONS
      OTHERS       = 1 ).
  IF sy-subrc <> 0.
    MESSAGE s005 WITH cv_fullpath DISPLAY LIKE 'E'.
    CLEAR cv_fullpath.
  ENDIF.

ENDFORM.
