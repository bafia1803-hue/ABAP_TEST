sap.ui.define([
    "sap/ui/core/format/DateFormat",
    "zwb/rcz/ext/TimeValues"
], function (DateFormat, TimeValues) {
    "use strict";

    // Karta "Raport zaznaczenia" wysuwana z prawej strony: zakres dni, suma każdej zaznaczonej
    // kolumny (z paskiem proporcji i liczbą dni z wartością) oraz suma wszystkich.
    //
    // options: { getText(key, args), onClose() }

    function create(tag, className, text) {
        var element = document.createElement(tag);
        if (className) {
            element.className = className;
        }
        if (text !== undefined) {
            element.textContent = text;
        }
        return element;
    }

    function toDate(isoDay) {
        var parts = String(isoDay).split("-");
        return new Date(Number(parts[0]), Number(parts[1]) - 1, Number(parts[2]));
    }

    function SelectionReport(options) {
        this._options = options;
        this._card = null;
    }

    SelectionReport.prototype.isOpen = function () {
        return !!this._card;
    };

    SelectionReport.prototype.show = function (selection) {
        var text = this._options.getText;
        var timeColumns = selection.columns.filter(function (column) {
            return column.isTime;
        });
        var days = selection.rows.slice().sort(function (a, b) {
            return a.Datcz < b.Datcz ? -1 : 1;
        });

        var sums = timeColumns.map(function (column) {
            var minutes = 0;
            var daysWithValue = 0;
            days.forEach(function (day) {
                var value = TimeValues.toMinutes(day[column.field]);
                minutes += value;
                if (value) {
                    daysWithValue++;
                }
            });
            return { label: column.label, minutes: minutes, days: daysWithValue };
        });
        var total = sums.reduce(function (sum, item) {
            return sum + item.minutes;
        }, 0);
        var largest = sums.reduce(function (max, item) {
            return Math.max(max, Math.abs(item.minutes));
        }, 0);

        // ---- treść karty
        var card = create("aside", "zwbRczReport");
        card.setAttribute("role", "dialog");
        card.setAttribute("aria-label", text("reportTitle"));

        var head = create("div", "zwbRczReportHead");
        var titles = create("div", "zwbRczReportTitles");
        titles.appendChild(create("div", "zwbRczReportTitle", text("reportTitle")));
        var dateFormat = DateFormat.getDateInstance({ style: "medium" });
        var period = days.length
            ? dateFormat.format(toDate(days[0].Datcz))
                + (days.length > 1 ? " – " + dateFormat.format(toDate(days[days.length - 1].Datcz)) : "")
            : "";
        titles.appendChild(create("div", "zwbRczReportSub",
            text("reportPeriod", [period, days.length, timeColumns.length])));
        var close = create("button", "zwbRczReportClose");
        close.type = "button";
        close.title = text("reportClose");
        close.setAttribute("aria-label", text("reportClose"));
        close.innerHTML = "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"M6 6l12 12M18 6L6 18\" /></svg>";
        close.addEventListener("click", function () {
            this.hide();
            this._options.onClose();
        }.bind(this));
        head.appendChild(titles);
        head.appendChild(close);
        card.appendChild(head);

        var list = create("div", "zwbRczReportList");
        if (!sums.length) {
            list.appendChild(create("div", "zwbRczReportEmpty", text("reportNoTimeColumns")));
        }
        sums.forEach(function (item) {
            var entry = create("div", "zwbRczReportItem" + (item.minutes ? "" : " is-zero"));
            var line = create("div", "zwbRczReportLine");
            line.appendChild(create("span", "zwbRczReportLabel", item.label));
            line.appendChild(create("span", "zwbRczReportValue", TimeValues.format(item.minutes) || "00:00"));
            entry.appendChild(line);
            var meter = create("div", "zwbRczReportMeter");
            var fill = create("div", "zwbRczReportFill");
            fill.style.width = largest ? (Math.abs(item.minutes) / largest * 100) + "%" : "0";
            meter.appendChild(fill);
            entry.appendChild(meter);
            entry.appendChild(create("div", "zwbRczReportDays", text("reportDays", [item.days, days.length])));
            list.appendChild(entry);
        });
        card.appendChild(list);

        var foot = create("div", "zwbRczReportTotal");
        foot.appendChild(create("span", "zwbRczReportTotalLabel", text("reportTotal")));
        foot.appendChild(create("span", "zwbRczReportTotalValue", TimeValues.format(total) || "00:00"));
        card.appendChild(foot);

        // ---- podmiana karty (nowe zaznaczenie odświeża treść bez ponownego wysuwania)
        var wasOpen = !!this._card;
        if (this._card) {
            this._card.remove();
        }
        this._card = card;
        document.body.appendChild(card);
        if (wasOpen) {
            card.classList.add("is-open", "is-instant");
        } else {
            window.requestAnimationFrame(function () {
                window.requestAnimationFrame(function () {
                    card.classList.add("is-open");
                });
            });
        }
    };

    SelectionReport.prototype.hide = function () {
        var card = this._card;
        if (!card) {
            return;
        }
        this._card = null;
        card.classList.remove("is-open", "is-instant");
        setTimeout(function () {
            card.remove();
        }, 300);
    };

    return SelectionReport;
});
