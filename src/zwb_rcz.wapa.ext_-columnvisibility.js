sap.ui.define([
    "sap/ui/core/Element",
    "sap/m/MessageToast",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/ui/mdc/p13n/StateUtil"
], function (Element, MessageToast, Filter, FilterOperator, StateUtil) {
    "use strict";

    // Przyciski nad tabelą (manifest.json -> controlConfiguration -> actions).
    // "Ukryj puste kolumny": kolumna jest pusta, gdy w KAŻDYM dniu wybranego okresu ma 00:00.
    // Wystarczy jeden dzień z wartością, żeby kolumna została.

    var TABLE_ID = "fe::table::TimeResultDay::LineItem";
    var ENTITY_SET = "/TimeResultDay";
    var EMPTY_VALUES = ["", "00:00"];
    var KEY_FIELDS = ["Pernr", "Fpper", "Datcz"];

    // Kolumny ukryte przez przycisk (do przywrócenia przyciskiem "Pokaż wszystkie kolumny")
    var hiddenColumnKeys = [];

    function getTable(extensionAPI) {
        var table = extensionAPI.byId(TABLE_ID);
        if (table) {
            return table;
        }
        // Zapasowo: jedyna tabela aplikacji
        return Element.registry.filter(function (element) {
            return element.isA("sap.ui.mdc.Table");
        })[0];
    }

    function getText(extensionAPI, key, args) {
        var bundle = extensionAPI.getModel("i18n").getResourceBundle();
        return bundle.getText(key, args);
    }

    // Klucz kolumny w tabeli (np. "DataField::PlanTime") -> nazwa pola ("PlanTime")
    function getColumnKey(column) {
        return column.getPropertyKey ? column.getPropertyKey() : column.getDataProperty();
    }

    function getFieldName(columnKey) {
        return columnKey.split("::").pop();
    }

    function getCurrentContexts(table) {
        var binding = table.getRowBinding && table.getRowBinding();
        if (!binding) {
            return [];
        }
        return binding.getAllCurrentContexts ? binding.getAllCurrentContexts() : binding.getCurrentContexts();
    }

    // Wszystkie dni okresu z wartościami wszystkich kolumn (osobne zapytanie,
    // bo tabela ładuje tylko pola widocznych kolumn)
    function readAllDays(model, firstRow, fieldNames) {
        var filters = [
            new Filter("Pernr", FilterOperator.EQ, firstRow.Pernr),
            new Filter("Fpper", FilterOperator.EQ, firstRow.Fpper)
        ];
        var list = model.bindList(ENTITY_SET, undefined, undefined, filters, {
            $select: KEY_FIELDS.concat(fieldNames).join(",")
        });
        return list.requestContexts(0, 1000).then(function (contexts) {
            return contexts.map(function (context) {
                return context.getObject();
            });
        });
    }

    function isEmptyEveryDay(days, fieldName) {
        return days.every(function (day) {
            return EMPTY_VALUES.indexOf((day[fieldName] || "").trim()) >= 0;
        });
    }

    function setColumnsVisible(table, columnKeys, visible) {
        var items = columnKeys.map(function (key) {
            return { name: key, visible: visible };
        });
        return StateUtil.applyExternalState(table, { items: items });
    }

    return {
        hideEmptyColumns: function () {
            var extensionAPI = this;
            var table = getTable(extensionAPI);
            var contexts = table ? getCurrentContexts(table) : [];

            if (!contexts.length) {
                MessageToast.show(getText(extensionAPI, "noData"));
                return;
            }

            var columnKeys = table.getColumns().map(getColumnKey).filter(function (key) {
                return KEY_FIELDS.indexOf(getFieldName(key)) < 0;
            });
            var fieldNames = columnKeys.map(getFieldName);

            readAllDays(table.getModel(), contexts[0].getObject(), fieldNames)
                .then(function (days) {
                    var emptyKeys = columnKeys.filter(function (key) {
                        return isEmptyEveryDay(days, getFieldName(key));
                    });
                    if (!emptyKeys.length) {
                        MessageToast.show(getText(extensionAPI, "nothingToHide"));
                        return undefined;
                    }
                    return setColumnsVisible(table, emptyKeys, false).then(function () {
                        hiddenColumnKeys = hiddenColumnKeys.concat(emptyKeys);
                        MessageToast.show(getText(extensionAPI, "columnsHidden", [emptyKeys.length]));
                    });
                })
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error(error);
                    MessageToast.show(getText(extensionAPI, "error"));
                });
        },

        showAllColumns: function () {
            var extensionAPI = this;
            var table = getTable(extensionAPI);
            if (!table || !hiddenColumnKeys.length) {
                MessageToast.show(getText(extensionAPI, "columnsShown"));
                return;
            }
            setColumnsVisible(table, hiddenColumnKeys, true)
                .then(function () {
                    hiddenColumnKeys = [];
                    MessageToast.show(getText(extensionAPI, "columnsShown"));
                })
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error(error);
                    MessageToast.show(getText(extensionAPI, "error"));
                });
        }
    };
});
