sap.ui.define([
    "sap/ui/core/mvc/ControllerExtension",
    "sap/ui/core/Element",
    "sap/m/MessageToast",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator"
], function (ControllerExtension, Element, MessageToast, Filter, FilterOperator) {
    "use strict";

    // Rozszerzenie strony listy dni (manifest.json -> sap.ui5/extends).
    // 1. Przyciski "Ukryj puste kolumny" / "Pokaż wszystkie kolumny".
    //    Kolumna jest pusta, gdy w KAŻDYM dniu wybranego okresu ma 00:00.
    // 2. Przejście do osi czasu dnia: strzałka / kliknięcie wiersza - oś czasu bez wyróżnienia,
    //    dwuklik w komórkę - oś czasu z wyróżnionymi rodzajami czasu z tej kolumny.

    var TABLE_ID = "fe::table::TimeResultDay::LineItem";
    var ENTITY_SET = "/TimeResultDay";
    var DAY_ROUTE = "TimeResultDayObjectPage";
    var KEY_FIELDS = ["Pernr", "Fpper", "Datcz"];
    // Kolumny, które nie są godzinami (nie ukrywamy ich i nie wyróżniamy po dwukliku)
    var NON_TIME_COLUMNS = KEY_FIELDS.concat(["DateCell", "WeekdayCell", "DayOfWeek", "WeekendType"]);
    var EMPTY_VALUES = ["", "00:00"];
    // Czas na drugie kliknięcie: dopiero po nim wiadomo, czy to dwuklik
    var DOUBLE_CLICK_MS = 400;

    // Jedyna strona listy w aplikacji - potrzebne w routing.onBeforeNavigation
    var current;

    function log(message, details) {
        // eslint-disable-next-line no-console
        console.info("[ZWB_RCZ] " + message, details === undefined ? "" : details);
    }

    // Kolumna tabeli -> nazwa pola, np. "DataField::PlanTime" -> "PlanTime"
    function getFieldName(column) {
        var key = column.getPropertyKey ? column.getPropertyKey() : column.getDataProperty();
        return String(key || "").split("::").pop();
    }

    function isTimeColumn(fieldName) {
        return !!fieldName && NON_TIME_COLUMNS.indexOf(fieldName) < 0;
    }

    // "/TimeResultDay(Pernr='00000446',Fpper='202610',Datcz=2026-10-02)" -> to, co w nawiasie
    function getContextKey(context) {
        var match = /\((.*)\)$/.exec(context.getPath());
        return match ? match[1] : "";
    }

    function isEmptyEveryDay(days, fieldName) {
        return days.every(function (day) {
            return EMPTY_VALUES.indexOf(String(day[fieldName] || "").trim()) >= 0;
        });
    }

    function findFirst(className, idSuffix) {
        var found = Element.registry.filter(function (element) {
            return element.isA(className);
        });
        var withId = found.filter(function (element) {
            return !idSuffix || element.getId().slice(-idSuffix.length) === idSuffix;
        });
        return withId[0] || found[0];
    }

    return ControllerExtension.extend("zwb.rcz.ext.ListReportExt", {

        override: {
            onInit: function () {
                current = this;
                this._hiddenColumns = [];
                this._lastCell = null;
                this._pendingNavigation = null;
                this._cellEventsAttached = false;
            },

            onAfterRendering: function () {
                // Błąd w obsłudze dwukliku nie może zablokować strony
                try {
                    this._attachCellEvents();
                } catch (error) {
                    // eslint-disable-next-line no-console
                    console.error("[ZWB_RCZ] Obsługa dwukliku", error);
                }
            },

            routing: {
                // Nawigację do dnia robimy sami (z opóźnieniem na ewentualny dwuklik)
                onBeforeNavigation: function (navigationParameters) {
                    current._delayNavigation(navigationParameters && navigationParameters.bindingContext);
                    return true;
                }
            }
        },

        // ------------------------------------------------------------------ przyciski
        hideEmptyColumns: function () {
            var that = this;
            var table = this._getTable();
            this._attachCellEvents();
            var contexts = this._getRowContexts(table);

            if (!contexts.length) {
                MessageToast.show(this._getText("noData"));
                return;
            }

            // Zaczynamy zawsze od pełnego zestawu kolumn (np. po zmianie okresu)
            this._restoreColumns(table);

            var columns = table.getColumns().filter(function (column) {
                return isTimeColumn(getFieldName(column));
            });
            var fieldNames = columns.map(getFieldName);
            log("Sprawdzam kolumny", fieldNames);

            this._readAllDays(table.getModel(), contexts[0].getObject(), fieldNames)
                .then(function (days) {
                    log("Dni w okresie", days.length);
                    var allColumns = table.getColumns();
                    var emptyColumns = columns.filter(function (column) {
                        return isEmptyEveryDay(days, getFieldName(column));
                    });
                    if (!emptyColumns.length) {
                        MessageToast.show(that._getText("nothingToHide"));
                        return;
                    }
                    emptyColumns.forEach(function (column) {
                        that._hiddenColumns.push({ column: column, index: allColumns.indexOf(column) });
                        table.removeColumn(column);
                    });
                    log("Ukryte kolumny", emptyColumns.map(getFieldName));
                    MessageToast.show(that._getText("columnsHidden", [emptyColumns.length]));
                })
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error("[ZWB_RCZ] Ukrywanie kolumn", error);
                    MessageToast.show(that._getText("error"));
                });
        },

        showAllColumns: function () {
            var table = this._getTable();
            if (table) {
                this._restoreColumns(table);
            }
            MessageToast.show(this._getText("columnsShown"));
        },

        // ------------------------------------------------------------------ tabela i dane
        // Tabela listy szukana w rejestrze kontrolek (ExtensionAPI.byId nie zwraca
        // wewnętrznej tabeli - zgłasza wyjątek)
        _getTable: function () {
            return findFirst("sap.ui.mdc.Table", TABLE_ID);
        },

        _getText: function (key, args) {
            return this.base.getView().getModel("i18n").getResourceBundle().getText(key, args);
        },

        _getRowContexts: function (table) {
            var binding = table && table.getRowBinding && table.getRowBinding();
            if (!binding) {
                return [];
            }
            return binding.getAllCurrentContexts ? binding.getAllCurrentContexts() : binding.getCurrentContexts();
        },

        // Wszystkie dni okresu z wartościami wszystkich kolumn (osobne zapytanie,
        // bo tabela pobiera tylko pola widocznych kolumn)
        _readAllDays: function (model, firstRow, fieldNames) {
            var list = model.bindList(ENTITY_SET, undefined, undefined, [
                new Filter("Pernr", FilterOperator.EQ, firstRow.Pernr),
                new Filter("Fpper", FilterOperator.EQ, firstRow.Fpper)
            ], {
                $select: KEY_FIELDS.concat(fieldNames).join(",")
            });
            return list.requestContexts(0, 1000).then(function (contexts) {
                return contexts.map(function (context) {
                    return context.getObject();
                });
            });
        },

        _restoreColumns: function (table) {
            this._hiddenColumns
                .sort(function (a, b) {
                    return a.index - b.index;
                })
                .forEach(function (hidden) {
                    table.insertColumn(hidden.column, hidden.index);
                });
            this._hiddenColumns = [];
        },

        // ------------------------------------------------------------------ kliknięcia i nawigacja
        _attachCellEvents: function () {
            var that = this;
            var table = this._getTable();
            if (this._cellEventsAttached || !table) {
                return;
            }
            this._cellEventsAttached = true;

            table.initialized().then(function () {
                var innerTable = table.getAggregation("_content") || findFirst("sap.ui.table.Table", "");
                if (!innerTable || !innerTable.attachCellClick) {
                    log("Brak tabeli Grid - dwuklik nie będzie działał");
                    that._cellEventsAttached = false;
                    return;
                }
                innerTable.attachCellClick(that._onCellClick, that);
                innerTable.attachBrowserEvent("dblclick", that._onDoubleClick, that);
                log("Obsługa dwukliku włączona");
            }).catch(function (error) {
                that._cellEventsAttached = false;
                // eslint-disable-next-line no-console
                console.error("[ZWB_RCZ] Obsługa dwukliku", error);
            });
        },

        _onCellClick: function (event) {
            this._lastCell = {
                columnId: event.getParameter("columnId"),
                context: event.getParameter("rowBindingContext")
            };
        },

        _onDoubleClick: function () {
            if (!this._lastCell || !this._lastCell.context) {
                return;
            }
            clearTimeout(this._pendingNavigation);
            this._pendingNavigation = null;

            var mdcColumn = Element.registry.get(String(this._lastCell.columnId).replace(/-innerColumn$/, ""));
            var fieldName = mdcColumn && mdcColumn.isA("sap.ui.mdc.table.Column") ? getFieldName(mdcColumn) : "";
            log("Dwuklik w kolumnę", fieldName);
            this._navigateToDay(this._lastCell.context, isTimeColumn(fieldName) ? fieldName : "");
        },

        _delayNavigation: function (context) {
            var that = this;
            clearTimeout(this._pendingNavigation);
            if (!context) {
                return;
            }
            this._pendingNavigation = setTimeout(function () {
                that._pendingNavigation = null;
                that._navigateToDay(context, "");
            }, DOUBLE_CLICK_MS);
        },

        _navigateToDay: function (context, focusField) {
            var parameters = { key: getContextKey(context) };
            if (focusField) {
                parameters["?query"] = { focus: focusField };
            }
            this.base.getAppComponent().getRouter().navTo(DAY_ROUTE, parameters);
        }
    });
});
