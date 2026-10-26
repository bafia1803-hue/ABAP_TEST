sap.ui.define([
    "sap/fe/core/PageController",
    "sap/ui/model/json/JSONModel",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/ui/core/routing/History",
    "sap/ui/core/format/DateFormat"
], function (PageController, JSONModel, Filter, FilterOperator, History, DateFormat) {
    "use strict";

    // Strona osi czasu dnia (manifest.json -> cel TimeResultDayObjectPage).
    // Adres: TimeResultDay(Pernr='...',Fpper='...',Datcz=RRRR-MM-DD)?focus=<pole kolumny>
    // Dane: encja TimeSlice (ZC_WB_RCZ_SLICE) - wiersz = rodzaj czasu i jeden jego wycinek.

    var DAY_ROUTE = "TimeResultDayObjectPage";
    var LIST_ROUTE = "TimeResultDayList";
    var SLICE_SET = "/TimeSlice";
    var FOCUS_TYPE = "Type01";
    var NORMAL_TYPE = "Type06";

    // "Pernr='00000446',Fpper='202610',Datcz=2026-10-02" -> { Pernr: "00000446", ... }
    function parseKey(key) {
        var result = {};
        var pattern = /(\w+)=(?:'([^']*)'|([^,]*))/g;
        var match = pattern.exec(key || "");
        while (match) {
            result[match[1]] = match[2] !== undefined ? match[2] : match[3];
            match = pattern.exec(key);
        }
        return result;
    }

    // "2026-10-02" + minuty od północy -> Date (minuty > 1440 = następny dzień)
    function toDate(isoDay, minutes) {
        var parts = isoDay.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]), 0, minutes || 0);
    }

    // Date -> "RRRR-MM-DD" (czas lokalny)
    function toIsoDay(date) {
        var month = String(date.getMonth() + 1).padStart(2, "0");
        var day = String(date.getDate()).padStart(2, "0");
        return date.getFullYear() + "-" + month + "-" + day;
    }

    // "2026-09-05" -> "202609"
    function toMonthPeriod(isoDay) {
        return isoDay.slice(0, 4) + isoDay.slice(5, 7);
    }

    function sameColumn(slice, focus) {
        return !!focus && String(slice.ColumnName || "").trim().toUpperCase() === focus.toUpperCase();
    }

    return PageController.extend("zwb.rcz.ext.view.DayTimeline", {

        onInit: function () {
            if (PageController.prototype.onInit) {
                PageController.prototype.onInit.apply(this, arguments);
            }
            this.getView().setModel(new JSONModel({ busy: false, rows: [], title: "" }), "timeline");

            var router = this.getAppComponent().getRouter();
            router.getRoute(DAY_ROUTE).attachPatternMatched(this._onDayMatched, this);

            // Widok powstaje przy pierwszym wejściu - wtedy zdarzenie trasy już minęło
            var hash = router.getHashChanger ? router.getHashChanger().getHash() : "";
            var routeInfo = router.getRouteInfoByHash ? router.getRouteInfoByHash(hash) : null;
            if (routeInfo && routeInfo.name === DAY_ROUTE) {
                this._showDay(routeInfo.arguments);
            }
        },

        onNavBack: function () {
            if (History.getInstance().getPreviousHash() !== undefined) {
                window.history.go(-1);
            } else {
                this.getAppComponent().getRouter().navTo(LIST_ROUTE, {}, true);
            }
        },

        // Strzałki / "Dzisiaj" w kalendarzu: inny dzień -> wczytanie tylko jego osi czasu
        // (bez zmiany adresu strony, więc nie przeładowuje się cała strona)
        onStartDateChange: function (event) {
            var current = this._current;
            if (!current) {
                return;
            }
            var newDay = toIsoDay(event.getSource().getStartDate());
            if (newDay === current.key.Datcz) {
                // Przewinięcie w obrębie tego samego dnia (np. na wąskim ekranie)
                return;
            }

            // Okres FPPER = miesiąc dnia, jeśli tak było dla bieżącego dnia
            var fpper = current.key.Fpper === toMonthPeriod(current.key.Datcz)
                ? toMonthPeriod(newDay)
                : current.key.Fpper;
            this._loadDay({ Pernr: current.key.Pernr, Fpper: fpper, Datcz: newDay }, current.focus);
        },

        _onDayMatched: function (event) {
            this._showDay(event.getParameter("arguments"));
        },

        _showDay: function (routeArguments) {
            var key = parseKey(routeArguments && routeArguments.key);
            var query = (routeArguments && routeArguments["?query"]) || {};

            if (!key.Pernr || !key.Fpper || !key.Datcz) {
                this.getView().getModel("timeline").setData({ busy: false, rows: [], title: "" });
                return;
            }
            this._loadDay(key, query.focus || "");
        },

        // Wczytuje oś czasu dnia; dotychczasowe wiersze zostają widoczne do czasu wczytania nowych
        _loadDay: function (key, focus) {
            var timeline = this.getView().getModel("timeline");
            var request = {};
            this._current = { key: key, focus: focus, request: request };

            timeline.setProperty("/busy", true);
            timeline.setProperty("/title", this._getText("timelineTitle", [this._formatDay(key.Datcz), key.Pernr]));

            this._readSlices(key)
                .then(function (slices) {
                    // Wynik starszego żądania (szybkie klikanie strzałek) jest pomijany
                    if (this._current.request === request) {
                        this._fillTimeline(key.Datcz, slices, focus);
                    }
                }.bind(this))
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error("[ZWB_RCZ] Oś czasu", error);
                    timeline.setProperty("/rows", []);
                })
                .finally(function () {
                    if (this._current.request === request) {
                        timeline.setProperty("/busy", false);
                    }
                }.bind(this));
        },

        _readSlices: function (key) {
            var model = this.getAppComponent().getModel();
            var list = model.bindList(SLICE_SET, undefined, undefined, [
                new Filter("Pernr", FilterOperator.EQ, key.Pernr),
                new Filter("Fpper", FilterOperator.EQ, key.Fpper),
                new Filter("Datcz", FilterOperator.EQ, key.Datcz)
            ]);
            return list.requestContexts(0, 5000).then(function (contexts) {
                return contexts.map(function (context) {
                    return context.getObject();
                });
            });
        },

        // Wycinki -> wiersze kalendarza (jeden wiersz na rodzaj czasu)
        _fillTimeline: function (isoDay, slices, focus) {
            var rowsByTimeType = {};
            var rows = [];
            var firstMinute = null;

            slices.forEach(function (slice) {
                var row = rowsByTimeType[slice.Rodcz];
                if (!row) {
                    var focused = sameColumn(slice, focus);
                    row = {
                        rodcz: slice.Rodcz,
                        title: slice.RodczName || slice.Rodcz,
                        text: this._getText("timelineRowText", [slice.Rodcz, slice.TotalTime]),
                        focused: focused,
                        appointments: []
                    };
                    rowsByTimeType[slice.Rodcz] = row;
                    rows.push(row);
                }
                if (slice.SliceNo > 0) {
                    var period = slice.BeginTime + " - " + slice.EndTime;
                    row.appointments.push({
                        start: toDate(isoDay, slice.BeginMin),
                        end: toDate(isoDay, slice.EndMin),
                        title: period,
                        text: row.title,
                        tooltip: row.title + ": " + period,
                        type: row.focused ? FOCUS_TYPE : NORMAL_TYPE
                    });
                    firstMinute = firstMinute === null ? slice.BeginMin : Math.min(firstMinute, slice.BeginMin);
                }
            }, this);

            rows.forEach(function (row) {
                if (!row.appointments.length) {
                    row.text = row.text + " - " + this._getText("timelineNoSlices");
                }
            }, this);

            // Wyróżnione rodzaje czasu na górze, reszta wg kodu rodzaju czasu
            rows.sort(function (a, b) {
                if (a.focused !== b.focused) {
                    return a.focused ? -1 : 1;
                }
                return a.rodcz < b.rodcz ? -1 : 1;
            });

            var timeline = this.getView().getModel("timeline");
            // Oś zaczyna się godzinę przed pierwszym wycinkiem (albo o północy)
            var startHour = firstMinute === null ? 0 : Math.max(0, Math.floor(firstMinute / 60) - 1);
            timeline.setProperty("/startDate", toDate(isoDay, startHour * 60));
            timeline.setProperty("/rows", rows);
        },

        _formatDay: function (isoDay) {
            return DateFormat.getDateInstance({ style: "long" }).format(toDate(isoDay, 0));
        },

        _getText: function (key, args) {
            return this.getAppComponent().getModel("i18n").getResourceBundle().getText(key, args);
        }
    });
});
