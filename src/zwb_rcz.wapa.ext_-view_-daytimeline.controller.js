sap.ui.define([
    "sap/fe/core/PageController",
    "sap/ui/model/Filter",
    "sap/ui/model/FilterOperator",
    "sap/ui/core/routing/History",
    "sap/ui/core/format/DateFormat"
], function (PageController, Filter, FilterOperator, History, DateFormat) {
    "use strict";

    // Strona osi czasu dnia (manifest.json -> cel TimeResultDayObjectPage).
    // Adres: TimeResultDay(Pernr='...',Fpper='...',Datcz=RRRR-MM-DD)?focus=<pole kolumny>
    // Dane: encja TimeSlice (ZC_WB_RCZ_SLICE) - wiersz = rodzaj czasu i jeden jego przedział godzin.
    // Zmiana dnia odbywa się w miejscu (bez zmiany adresu); dni sąsiednie są wczytywane z wyprzedzeniem.
    // Przedziały poprzedniego dnia trwające po północy są pokazywane jako jego dokończenie (od 00:00).

    var DAY_ROUTE = "TimeResultDayObjectPage";
    var LIST_ROUTE = "TimeResultDayList";
    var SLICE_SET = "/TimeSlice";
    var MINUTES_PER_DAY = 1440;
    // Kolory rodzajów czasu (stałe dla danego RODCZ, niezależnie od dnia)
    var PALETTE = ["#0070f2", "#00a2a6", "#7858ff", "#e76500", "#cc00dc",
                   "#049f55", "#da0f48", "#1c7a96", "#a93e00", "#5d36ff"];

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

    function toDate(isoDay) {
        var parts = isoDay.split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function toIsoDay(date) {
        var month = String(date.getMonth() + 1).padStart(2, "0");
        var day = String(date.getDate()).padStart(2, "0");
        return date.getFullYear() + "-" + month + "-" + day;
    }

    function addDays(isoDay, days) {
        var date = toDate(isoDay);
        date.setDate(date.getDate() + days);
        return toIsoDay(date);
    }

    // "2026-09-05" -> "202609"
    function toMonthPeriod(isoDay) {
        return isoDay.slice(0, 4) + isoDay.slice(5, 7);
    }

    function colorOf(rodcz) {
        var hash = 0;
        String(rodcz).split("").forEach(function (character) {
            hash = (hash * 31 + character.charCodeAt(0)) % 9973;
        });
        return PALETTE[hash % PALETTE.length];
    }

    // Minuty jako czas trwania, np. 240 -> "4:00"
    function formatDuration(minutes) {
        return Math.floor(minutes / 60) + ":" + String(minutes % 60).padStart(2, "0");
    }

    function sameColumn(slice, focus) {
        return !!focus && String(slice.ColumnName || "").trim().toUpperCase() === focus.toUpperCase();
    }

    return PageController.extend("zwb.rcz.ext.view.DayTimeline", {

        onInit: function () {
            if (PageController.prototype.onInit) {
                PageController.prototype.onInit.apply(this, arguments);
            }
            this._cache = {};
            this._current = null;

            var router = this.getAppComponent().getRouter();
            router.getRoute(DAY_ROUTE).attachPatternMatched(this._onDayMatched, this);

            // Widok powstaje przy pierwszym wejściu - wtedy zdarzenie trasy już minęło
            var hash = router.getHashChanger ? router.getHashChanger().getHash() : "";
            var routeInfo = router.getRouteInfoByHash ? router.getRouteInfoByHash(hash) : null;
            if (routeInfo && routeInfo.name === DAY_ROUTE) {
                this._openDay(routeInfo.arguments);
            }
        },

        onNavBack: function () {
            if (History.getInstance().getPreviousHash() !== undefined) {
                window.history.go(-1);
            } else {
                this.getAppComponent().getRouter().navTo(LIST_ROUTE, {}, true);
            }
        },

        // Kontrolka: przewinięcie / strzałka -> poprzedni (-1) lub następny (1) dzień
        onNavigateDay: function (event) {
            if (!this._current) {
                return;
            }
            var direction = event.getParameter("direction");
            this._showDay(this._shiftKey(this._current.key, direction), this._current.focus, direction);
        },

        _onDayMatched: function (event) {
            this._openDay(event.getParameter("arguments"));
        },

        // Wejście na stronę z tabeli dni
        _openDay: function (routeArguments) {
            var key = parseKey(routeArguments && routeArguments.key);
            var query = (routeArguments && routeArguments["?query"]) || {};
            if (!key.Pernr || !key.Fpper || !key.Datcz) {
                return;
            }
            // Świeże dane przy każdym wejściu
            this._cache = {};
            this._showDay(key, query.focus || "", 0);
        },

        _shiftKey: function (key, days) {
            var datcz = addDays(key.Datcz, days);
            // Okres FPPER = miesiąc dnia, jeśli tak było dla bieżącego dnia
            var fpper = key.Fpper === toMonthPeriod(key.Datcz) ? toMonthPeriod(datcz) : key.Fpper;
            return { Pernr: key.Pernr, Fpper: fpper, Datcz: datcz };
        },

        _showDay: function (key, focus, direction) {
            var timeline = this.byId("dayTimeline");
            var request = {};
            this._current = { key: key, focus: focus, request: request };

            var previous = this._cache[this._shiftKey(key, -1).Datcz];
            var loaded = this._cache[key.Datcz] && this._cache[key.Datcz].done && previous && previous.done;
            if (!loaded) {
                timeline.setLoading(true);
            }

            // Dzień i poprzedni dzień (przedziały nocne przechodzące przez północ)
            var previousKey = this._shiftKey(key, -1);
            Promise.all([
                this._readDay(key),
                this._readDay(previousKey).catch(function () {
                    return [];
                })
            ])
                .then(function (results) {
                    // Wynik starszego żądania (szybkie przewijanie) jest pomijany
                    if (this._current.request !== request) {
                        return;
                    }
                    timeline.setLoading(false);
                    timeline.showDay(this._buildDay(key, results[0], focus, previousKey, results[1]), direction);
                    this._prefetch(key);
                }.bind(this))
                .catch(function (error) {
                    // eslint-disable-next-line no-console
                    console.error("[ZWB_RCZ] Oś czasu", error);
                    if (this._current.request === request) {
                        timeline.setLoading(false);
                    }
                }.bind(this));
        },

        // Dni obok wczytywane w tle - przewijanie jest wtedy natychmiastowe
        _prefetch: function (key) {
            this._readDay(this._shiftKey(key, -1));
            this._readDay(this._shiftKey(key, 1));
        },

        // Wycinki dnia (z pamięci, jeśli już były wczytane)
        _readDay: function (key) {
            var cached = this._cache[key.Datcz];
            if (cached) {
                return cached.promise;
            }
            var entry = { done: false };
            var list = this.getAppComponent().getModel().bindList(SLICE_SET, undefined, undefined, [
                new Filter("Pernr", FilterOperator.EQ, key.Pernr),
                new Filter("Fpper", FilterOperator.EQ, key.Fpper),
                new Filter("Datcz", FilterOperator.EQ, key.Datcz)
            ]);
            entry.promise = list.requestContexts(0, 5000)
                .then(function (contexts) {
                    entry.done = true;
                    return contexts.map(function (context) {
                        return context.getObject();
                    });
                })
                .catch(function (error) {
                    // Nieudane wczytanie nie zostaje w pamięci - kolejna próba pyta serwer ponownie
                    delete this._cache[key.Datcz];
                    throw error;
                }.bind(this));
            this._cache[key.Datcz] = entry;
            return entry.promise;
        },

        // Wycinki -> dane kontrolki: jeden wiersz na rodzaj czasu, wyróżnione na górze
        _buildDay: function (key, slices, focus, previousKey, previousSlices) {
            var rowsById = {};
            var rows = [];
            var nextDayText = this._getText("timelineToNext");
            var fromPreviousText = this._getText("timelineFromPrev", [this._formatShortDay(previousKey.Datcz)]);

            var getRow = function (slice, text) {
                var row = rowsById[slice.Rodcz];
                if (!row) {
                    row = {
                        id: slice.Rodcz,
                        title: slice.RodczName || slice.Rodcz,
                        text: text,
                        focused: sameColumn(slice, focus),
                        color: colorOf(slice.Rodcz),
                        bars: []
                    };
                    rowsById[slice.Rodcz] = row;
                    rows.push(row);
                }
                return row;
            };

            slices.forEach(function (slice) {
                var row = getRow(slice, this._getText("timelineRowText", [slice.Rodcz, slice.TotalTime]));
                if (slice.SliceNo > 0) {
                    var period = slice.BeginTime + " – " + slice.EndTime;
                    var continues = slice.EndMin > MINUTES_PER_DAY;
                    row.bars.push({
                        start: slice.BeginMin,
                        end: Math.min(slice.EndMin, MINUTES_PER_DAY),
                        continues: continues,
                        label: period,
                        tooltip: row.title + ": " + period,
                        details: {
                            title: row.title,
                            time: period,
                            duration: this._getText("timelineDuration", [formatDuration(slice.EndMin - slice.BeginMin)]),
                            note: continues ? nextDayText : ""
                        }
                    });
                }
            }, this);

            rows.forEach(function (row) {
                if (!row.bars.length) {
                    row.text = row.text + " · " + this._getText("timelineNoSlices");
                }
            }, this);

            // Dokończenie nocnych przedziałów z poprzedniego dnia (od 00:00)
            previousSlices.forEach(function (slice) {
                if (!(slice.SliceNo > 0 && slice.EndMin > MINUTES_PER_DAY)) {
                    return;
                }
                var row = getRow(slice, this._getText("timelineCarryRowText", [slice.Rodcz]));
                var period = slice.BeginTime + " – " + slice.EndTime;
                row.bars.push({
                    start: 0,
                    end: Math.min(slice.EndMin - MINUTES_PER_DAY, MINUTES_PER_DAY),
                    carried: true,
                    label: period,
                    tooltip: fromPreviousText + ": " + period,
                    details: {
                        title: row.title,
                        time: period,
                        duration: this._getText("timelineDuration", [formatDuration(slice.EndMin - slice.BeginMin)]),
                        note: fromPreviousText
                    }
                });
            }, this);

            rows.sort(function (a, b) {
                if (a.focused !== b.focused) {
                    return a.focused ? -1 : 1;
                }
                return a.id < b.id ? -1 : 1;
            });

            var date = toDate(key.Datcz);
            var weekday = date.getDay();
            return {
                title: DateFormat.getDateInstance({ pattern: "EEEE, d MMMM yyyy" }).format(date),
                subtitle: this._getText("timelineSubtitle", [key.Pernr.replace(/^0+/, "")]),
                weekend: weekday === 6 ? "sat" : weekday === 0 ? "sun" : "",
                rows: rows
            };
        },

        _formatShortDay: function (isoDay) {
            return DateFormat.getDateInstance({ pattern: "d MMMM" }).format(toDate(isoDay));
        },

        _getText: function (key, args) {
            return this.getAppComponent().getModel("i18n").getResourceBundle().getText(key, args);
        }
    });
});
