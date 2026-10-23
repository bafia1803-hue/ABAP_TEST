"! Maskowanie pól numerycznych (NUMC, np. PERNR): losowy, unikalny zamiennik
"! tej samej długości, różny od wszystkich zebranych prawdziwych wartości.
CLASS zcl_wb_numc_masker DEFINITION
  PUBLIC
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES zif_wb_field_masker.

    "! @parameter iv_length | Liczba cyfr pola
    "! @parameter iv_seed | Ziarno losowania (stałe ziarno = powtarzalny wynik, np. w testach)
    METHODS constructor
      IMPORTING
        iv_length TYPE i
        iv_seed   TYPE i.

  PROTECTED SECTION.
  PRIVATE SECTION.

    CONSTANTS c_max_attempts TYPE i VALUE 1000.
    CONSTANTS c_max_int TYPE i VALUE 2147483647.

    DATA mo_random TYPE REF TO cl_abap_random_int.
    DATA mt_reserved TYPE HASHED TABLE OF string WITH UNIQUE KEY table_line.
    DATA mt_mapping TYPE zif_wb_field_masker=>tt_mapping.

    CLASS-METHODS max_value
      IMPORTING
        iv_length     TYPE i
      RETURNING
        VALUE(rv_max) TYPE i.

    METHODS new_substitute
      IMPORTING
        iv_template          TYPE simple
      RETURNING
        VALUE(rv_substitute) TYPE string
      EXCEPTIONS
        masking_failed.

ENDCLASS.



CLASS zcl_wb_numc_masker IMPLEMENTATION.


  METHOD constructor.

    TRY.
        mo_random = cl_abap_random_int=>create(
          seed = iv_seed
          min  = 1
          max  = max_value( iv_length ) ).
      CATCH cx_abap_random.
        " Brak generatora zgłosi MASK wyjątkiem MASKING_FAILED
        CLEAR mo_random.
    ENDTRY.

  ENDMETHOD.


  METHOD max_value.

    " Np. 8 cyfr -> 99999999; dla 10 i więcej cyfr ograniczenie typu I
    IF iv_length >= 10.
      rv_max = c_max_int.
    ELSE.
      rv_max = 10 ** iv_length - 1.
    ENDIF.

  ENDMETHOD.


  METHOD zif_wb_field_masker~collect.

    DATA lv_value TYPE string.

    IF iv_value IS INITIAL.
      RETURN.
    ENDIF.

    lv_value = iv_value.
    INSERT lv_value INTO TABLE mt_reserved.

  ENDMETHOD.


  METHOD zif_wb_field_masker~mask.

    DATA ls_mapping TYPE zif_wb_field_masker=>ty_mapping.

    " Pusta wartość nie identyfikuje osoby - zostaje bez zmian
    IF cv_value IS INITIAL.
      RETURN.
    ENDIF.

    ls_mapping-original = cv_value.
    READ TABLE mt_mapping INTO ls_mapping WITH TABLE KEY original = ls_mapping-original.
    IF sy-subrc <> 0.
      new_substitute(
        EXPORTING
          iv_template    = cv_value
        RECEIVING
          rv_substitute  = ls_mapping-masked
        EXCEPTIONS
          masking_failed = 1
          OTHERS         = 2 ).
      IF sy-subrc <> 0.
        MESSAGE e003(zwb_it2001) RAISING masking_failed.
      ENDIF.
      INSERT ls_mapping INTO TABLE mt_mapping.
    ENDIF.

    cv_value = ls_mapping-masked.

  ENDMETHOD.


  METHOD zif_wb_field_masker~get_mapping.
    rt_mapping = mt_mapping.
  ENDMETHOD.


  METHOD new_substitute.

    DATA lr_candidate TYPE REF TO data.
    FIELD-SYMBOLS <lv_candidate> TYPE simple.

    IF mo_random IS NOT BOUND.
      MESSAGE e003(zwb_it2001) RAISING masking_failed.
    ENDIF.

    " Kandydat ma ten sam typ co pole, więc ma też ten sam zapis (np. zera wiodące)
    CREATE DATA lr_candidate LIKE iv_template.
    ASSIGN lr_candidate->* TO <lv_candidate>.

    DO c_max_attempts TIMES.
      <lv_candidate> = mo_random->get_next( ).
      rv_substitute = <lv_candidate>.
      INSERT rv_substitute INTO TABLE mt_reserved.
      IF sy-subrc = 0.
        RETURN.
      ENDIF.
    ENDDO.

    CLEAR rv_substitute.
    MESSAGE e003(zwb_it2001) RAISING masking_failed.

  ENDMETHOD.
ENDCLASS.
