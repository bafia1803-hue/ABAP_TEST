"! Maskowanie wartości jednego pola (np. PERNR) we wszystkich eksportowanych tabelach.
"! Każdy typ danych może mieć własną implementację (np. liczby NUMC, tekst).
"! Kolejność użycia: najpierw COLLECT dla wszystkich prawdziwych wartości,
"! potem MASK, dzięki czemu zamiennik nigdy nie jest równy żadnej prawdziwej wartości.
INTERFACE zif_wb_field_masker
  PUBLIC.

  TYPES:
    BEGIN OF ty_mapping,
      original TYPE string,
      masked   TYPE string,
    END OF ty_mapping.
  TYPES tt_mapping TYPE SORTED TABLE OF ty_mapping WITH UNIQUE KEY original.

  "! Zapamiętuje prawdziwą wartość, której zamiennik nie może powtórzyć
  "! @parameter iv_value | Prawdziwa wartość pola
  METHODS collect
    IMPORTING
      iv_value TYPE simple.

  "! Zamienia wartość na zastępczą; ta sama wartość zawsze daje ten sam zamiennik
  "! @parameter cv_value | Wartość pola (zmieniana w miejscu)
  "! @exception masking_failed | Nie udało się wyznaczyć zamiennika
  METHODS mask
    CHANGING
      cv_value TYPE simple
    EXCEPTIONS
      masking_failed.

  "! Pary: prawdziwa wartość -> zamiennik
  METHODS get_mapping
    RETURNING
      VALUE(rt_mapping) TYPE tt_mapping.

ENDINTERFACE.
