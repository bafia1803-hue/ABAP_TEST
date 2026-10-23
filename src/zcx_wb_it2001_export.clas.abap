"! <p class="shorttext synchronized">Wyjątek eksportu IT2001</p>
CLASS zcx_wb_it2001_export DEFINITION
  PUBLIC
  INHERITING FROM cx_static_check
  FINAL
  CREATE PUBLIC.

  PUBLIC SECTION.

    INTERFACES if_t100_message.

    CONSTANTS:
      BEGIN OF begda_after_endda,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '001',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF begda_after_endda.
    CONSTANTS:
      BEGIN OF no_data,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '002',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_data.
    CONSTANTS:
      BEGIN OF random_failed,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '003',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF random_failed.
    CONSTANTS:
      BEGIN OF file_dialog_failed,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '004',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF file_dialog_failed.
    CONSTANTS:
      BEGIN OF download_failed,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '005',
        attr1 TYPE scx_attrname VALUE 'MSGV1',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF download_failed.
    CONSTANTS:
      BEGIN OF no_gui,
        msgid TYPE symsgid VALUE 'ZWB_IT2001',
        msgno TYPE symsgno VALUE '006',
        attr1 TYPE scx_attrname VALUE '',
        attr2 TYPE scx_attrname VALUE '',
        attr3 TYPE scx_attrname VALUE '',
        attr4 TYPE scx_attrname VALUE '',
      END OF no_gui.

    DATA msgv1 TYPE symsgv READ-ONLY.

    METHODS constructor
      IMPORTING
        textid   LIKE if_t100_message=>t100key OPTIONAL
        previous LIKE previous OPTIONAL
        msgv1    TYPE symsgv OPTIONAL.

  PROTECTED SECTION.
  PRIVATE SECTION.
ENDCLASS.



CLASS zcx_wb_it2001_export IMPLEMENTATION.


  METHOD constructor ##ADT_SUPPRESS_GENERATION.

    super->constructor( previous = previous ).

    me->msgv1 = msgv1.

    CLEAR me->textid.
    IF textid IS INITIAL.
      if_t100_message~t100key = if_t100_message=>default_textid.
    ELSE.
      if_t100_message~t100key = textid.
    ENDIF.

  ENDMETHOD.
ENDCLASS.
