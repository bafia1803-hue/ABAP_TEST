sap.ui.define([
    "zwb/rcz/ext/TimeValues"
], function (TimeValues) {
    "use strict";

    // Wiersz "Suma miesiąca" pod tabelą dni: zawsze widoczny (niezależnie od długości listy),
    // komórki wyrównane do kolumn tabeli - także po przewinięciu w poziomie i zmianie szerokości.
    //
    // options: { label, columnInfo(innerColumn) -> { field, isTime } }

    function MonthTotals(table, options) {
        this._table = table;
        this._options = options;
        this._element = null;
        this._frame = 0;
        this._observer = window.ResizeObserver ? new window.ResizeObserver(this.refresh.bind(this)) : null;

        table.attachEvent("rowsUpdated", this.refresh, this);
        table.attachEvent("columnResize", this._refreshLater, this);
        table.attachEvent("columnMove", this._refreshLater, this);
        // Tabela po ponownym narysowaniu traci dodany wiersz - dokładamy go znowu
        table.addEventDelegate({ onAfterRendering: this.refresh }, this);
        window.addEventListener("resize", this.refresh.bind(this));
        this.refresh();
    }

    MonthTotals.prototype._refreshLater = function () {
        setTimeout(this.refresh.bind(this), 0);
    };

    // Odświeżenie najwyżej raz na klatkę obrazu
    MonthTotals.prototype.refresh = function () {
        if (this._frame) {
            return;
        }
        this._frame = window.requestAnimationFrame(function () {
            this._frame = 0;
            this._render();
        }.bind(this));
    };

    MonthTotals.prototype._ensureElement = function (tableDom) {
        if (this._element && this._element.parentNode === tableDom) {
            return this._element;
        }
        this._element = document.createElement("div");
        this._element.className = "zwbRczTotals";
        tableDom.appendChild(this._element);

        // Przewijanie w poziomie przesuwa kolumny - sumy idą za nimi
        Array.prototype.forEach.call(tableDom.querySelectorAll(".sapUiTableHSb, .sapUiTableCtrlScr"), function (scroller) {
            scroller.addEventListener("scroll", this.refresh.bind(this), { passive: true });
        }, this);
        if (this._observer) {
            this._observer.observe(tableDom);
            var header = tableDom.querySelector(".sapUiTableColHdrCnt");
            if (header) {
                this._observer.observe(header);
            }
        }
        return this._element;
    };

    MonthTotals.prototype._sums = function () {
        var binding = this._table.getBinding("rows");
        var contexts = !binding ? [] : binding.getAllCurrentContexts
            ? binding.getAllCurrentContexts() : binding.getContexts(0, binding.getLength());
        var rows = contexts.filter(Boolean).map(function (context) {
            return context.getObject() || {};
        });
        return function (field) {
            return rows.reduce(function (sum, row) {
                return sum + TimeValues.toMinutes(row[field]);
            }, 0);
        };
    };

    MonthTotals.prototype._render = function () {
        var tableDom = this._table.getDomRef();
        if (!tableDom) {
            return;
        }
        var element = this._ensureElement(tableDom);
        var hasRows = !!this._table.getBinding("rows") && this._table.getBinding("rows").getLength() > 0;
        element.classList.toggle("is-empty", !hasRows);
        element.innerHTML = "";
        if (!hasRows) {
            return;
        }

        var sumOf = this._sums();
        var baseLeft = tableDom.getBoundingClientRect().left;
        var labelPlaced = false;

        this._table.getColumns().forEach(function (column) {
            var header = column.getVisible() && column.getDomRef();
            if (!header) {
                return;
            }
            var rect = header.getBoundingClientRect();
            var info = this._options.columnInfo(column);
            var cell = document.createElement("div");
            cell.className = "zwbRczTotalsCell";
            cell.style.left = (rect.left - baseLeft) + "px";
            cell.style.width = rect.width + "px";

            if (info.isTime) {
                cell.textContent = TimeValues.format(sumOf(info.field));
                cell.classList.add("is-value");
            } else if (!labelPlaced) {
                cell.textContent = this._options.label;
                cell.classList.add("is-label");
                labelPlaced = true;
            }
            element.appendChild(cell);
        }, this);
    };

    return MonthTotals;
});
