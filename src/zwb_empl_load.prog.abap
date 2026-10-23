*&---------------------------------------------------------------------*
*& Report ZWB_EMPL_LOAD
*&---------------------------------------------------------------------*
*& Wczytanie pliku JSON z ZWB_IT2001_EXPORT do obiektów ZCL_WB_EMPL
*& i podgląd: okres danych oraz liczba rekordów każdej tabeli na pracownika.
*&---------------------------------------------------------------------*
REPORT zwb_empl_load.

TYPES:
  BEGIN OF ty_summary,
    pernr  TYPE pernr_d,
    begda  TYPE begda,
    endda  TYPE endda,
    pa0000 TYPE i,
    pa0001 TYPE i,
    pa0007 TYPE i,
    pa0008 TYPE i,
    pa0030 TYPE i,
    pa0515 TYPE i,
    pa2001 TYPE i,
    pa2002 TYPE i,
    pa2004 TYPE i,
    pa2006 TYPE i,
    pa2007 TYPE i,
    teven  TYPE i,
  END OF ty_summary.
TYPES tt_summary TYPE STANDARD TABLE OF ty_summary WITH DEFAULT KEY.


START-OF-SELECTION.
  PERFORM main.


*&---------------------------------------------------------------------*
*& Form main
*&---------------------------------------------------------------------*
FORM main.

  DATA lt_employees TYPE zcl_wb_empl=>tt_employees.
  DATA lo_employee TYPE REF TO zcl_wb_empl.
  DATA lt_summary TYPE tt_summary.
  DATA ls_summary TYPE ty_summary.

  zcl_wb_empl=>from_file(
    RECEIVING
      rt_employees  = lt_employees
    EXCEPTIONS
      no_gui        = 1
      dialog_failed = 2
      upload_failed = 3
      invalid_file  = 4
      OTHERS        = 5 ).
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lt_employees IS INITIAL.
    MESSAGE s002(zwb_it2001) DISPLAY LIKE 'W'.
    RETURN.
  ENDIF.

  LOOP AT lt_employees INTO lo_employee.
    CLEAR ls_summary.
    ls_summary-pernr = lo_employee->mv_pernr.
    ls_summary-begda = lo_employee->mv_begda.
    ls_summary-endda = lo_employee->mv_endda.
    ls_summary-pa0000 = lines( lo_employee->mt_pa0000 ).
    ls_summary-pa0001 = lines( lo_employee->mt_pa0001 ).
    ls_summary-pa0007 = lines( lo_employee->mt_pa0007 ).
    ls_summary-pa0008 = lines( lo_employee->mt_pa0008 ).
    ls_summary-pa0030 = lines( lo_employee->mt_pa0030 ).
    ls_summary-pa0515 = lines( lo_employee->mt_pa0515 ).
    ls_summary-pa2001 = lines( lo_employee->mt_pa2001 ).
    ls_summary-pa2002 = lines( lo_employee->mt_pa2002 ).
    ls_summary-pa2004 = lines( lo_employee->mt_pa2004 ).
    ls_summary-pa2006 = lines( lo_employee->mt_pa2006 ).
    ls_summary-pa2007 = lines( lo_employee->mt_pa2007 ).
    ls_summary-teven = lines( lo_employee->mt_teven ).
    APPEND ls_summary TO lt_summary.
  ENDLOOP.

  cl_demo_output=>display( lt_summary ).

ENDFORM.
