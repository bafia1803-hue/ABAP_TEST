*&---------------------------------------------------------------------*
*& Report ZWB_IT2001_EXPORT
*&---------------------------------------------------------------------*
*& Eksport infotypu 2001 do pliku JSON z zastępczymi numerami osobowymi.
*& Wiersze nachodzące na okres są przycinane do dat z ekranu selekcji.
*&---------------------------------------------------------------------*
REPORT zwb_it2001_export.

TYPES:
  BEGIN OF ty_output,
    prawdziwy_pernr       TYPE pernr_d,
    pernr_po_serializacji TYPE pernr_d,
  END OF ty_output.
TYPES tt_output TYPE STANDARD TABLE OF ty_output WITH DEFAULT KEY.

DATA gv_pernr TYPE pernr_d.

SELECTION-SCREEN BEGIN OF BLOCK b01 WITH FRAME TITLE TEXT-b01.
SELECT-OPTIONS s_pernr FOR gv_pernr.
PARAMETERS p_begda TYPE begda OBLIGATORY.
PARAMETERS p_endda TYPE endda OBLIGATORY.
SELECTION-SCREEN END OF BLOCK b01.


INITIALIZATION.
  " Domyślnie bieżący rok
  CONCATENATE sy-datum(4) '0101' INTO p_begda.
  CONCATENATE sy-datum(4) '1231' INTO p_endda.


AT SELECTION-SCREEN.
  IF p_begda > p_endda.
    MESSAGE e001(zwb_it2001).
  ENDIF.


START-OF-SELECTION.
  PERFORM main.


*&---------------------------------------------------------------------*
*& Form main
*&---------------------------------------------------------------------*
FORM main.

  DATA lo_export TYPE REF TO zcl_wb_it2001_export.
  DATA lt_map TYPE zcl_wb_it2001_export=>tt_pernr_map.
  DATA ls_map LIKE LINE OF lt_map.
  DATA lt_output TYPE tt_output.
  DATA ls_output TYPE ty_output.
  DATA lv_fullpath TYPE string.

  CREATE OBJECT lo_export
    EXPORTING
      it_pernr = s_pernr[]
      iv_begda = p_begda
      iv_endda = p_endda.

  lo_export->execute(
    EXCEPTIONS
      wrong_period  = 1
      no_data       = 2
      random_failed = 3
      OTHERS        = 4 ).
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  lo_export->download(
    RECEIVING
      rv_fullpath     = lv_fullpath
    EXCEPTIONS
      no_gui          = 1
      dialog_failed   = 2
      download_failed = 3
      OTHERS          = 4 ).
  IF sy-subrc <> 0.
    MESSAGE ID sy-msgid TYPE 'S' NUMBER sy-msgno
      WITH sy-msgv1 sy-msgv2 sy-msgv3 sy-msgv4
      DISPLAY LIKE 'E'.
    RETURN.
  ENDIF.

  IF lv_fullpath IS INITIAL.
    MESSAGE s008(zwb_it2001) DISPLAY LIKE 'W'.
  ELSE.
    MESSAGE s007(zwb_it2001) WITH lv_fullpath.
  ENDIF.

  lt_map = lo_export->get_pernr_map( ).
  LOOP AT lt_map INTO ls_map.
    ls_output-prawdziwy_pernr = ls_map-pernr_real.
    ls_output-pernr_po_serializacji = ls_map-pernr_anon.
    APPEND ls_output TO lt_output.
  ENDLOOP.

  cl_demo_output=>display( lt_output ).

ENDFORM.
