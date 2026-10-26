sap.ui.define([], function () {
    "use strict";

    // Zaznaczanie prostokątnego obszaru komórek tabeli dni przeciągnięciem myszą (jak w arkuszu).
    // Zaznaczenie zaczyna się dopiero, gdy kursor przejdzie na inną komórkę - zwykłe kliknięcie
    // i dwuklik działają jak dotąd.
    //
    // options: {
    //   columnInfo(innerColumn) -> { field, label, isTime },
    //   onSelect({ rows: [obiekty wierszy], columns: [{ field, label, isTime }] }),
    //   onClear()
    // }

    function RangeSelection(table, options) {
        this._table = table;
        this._options = options;
        this._anchor = null;
        this._range = null;
        this._dragging = false;
        this._justDragged = false;
        this._onMove = this._mouseMove.bind(this);
        this._onUp = this._mouseUp.bind(this);

        table.attachEvent("rowsUpdated", this._highlight, this);
        table.addEventDelegate({ onAfterRendering: this._bindDom }, this);
        document.addEventListener("keydown", function (event) {
            if (event.key === "Escape" && this._range) {
                this.clear();
            }
        }.bind(this));
        this._bindDom();
    }

    // Czy ostatnie kliknięcie kończyło przeciąganie (wtedy nie otwieramy osi czasu)
    RangeSelection.prototype.wasDragging = function () {
        return this._justDragged;
    };

    RangeSelection.prototype.clear = function () {
        var hadRange = !!this._range;
        this._range = null;
        this._highlight();
        if (hadRange) {
            this._options.onClear();
        }
    };

    RangeSelection.prototype._bindDom = function () {
        var dom = this._table.getDomRef();
        if (!dom || dom.__zwbRangeBound) {
            this._highlight();
            return;
        }
        dom.__zwbRangeBound = true;
        dom.addEventListener("mousedown", this._mouseDown.bind(this));
        this._highlight();
    };

    RangeSelection.prototype._visibleColumns = function () {
        return this._table.getColumns().filter(function (column) {
            return column.getVisible();
        });
    };

    // Komórka pod elementem strony -> { row: indeks wiersza w danych, column: indeks widocznej kolumny }
    RangeSelection.prototype._cellAt = function (element) {
        var cell = element && element.closest && element.closest("td[data-sap-ui-colid]");
        var tableRow = cell && cell.closest("tr[data-sap-ui-rowindex]");
        if (!cell || !tableRow || !this._table.getDomRef().contains(cell)) {
            return null;
        }
        var row = this._table.getRows()[Number(tableRow.getAttribute("data-sap-ui-rowindex"))];
        var context = row && row.getBindingContext();
        var columnIndex = this._visibleColumns().map(function (column) {
            return column.getId();
        }).indexOf(cell.getAttribute("data-sap-ui-colid"));
        if (!context || columnIndex < 0) {
            return null;
        }
        return { row: context.getIndex(), column: columnIndex };
    };

    RangeSelection.prototype._mouseDown = function (event) {
        if (event.button !== 0) {
            return;
        }
        var cell = this._cellAt(event.target);
        if (!cell) {
            return;
        }
        // Bez zaznaczania tekstu kursorem
        event.preventDefault();
        this._anchor = cell;
        this._dragging = false;
        document.addEventListener("mousemove", this._onMove);
        document.addEventListener("mouseup", this._onUp);
    };

    RangeSelection.prototype._mouseMove = function (event) {
        var cell = this._cellAt(document.elementFromPoint(event.clientX, event.clientY));
        if (!cell) {
            return;
        }
        if (!this._dragging && cell.row === this._anchor.row && cell.column === this._anchor.column) {
            return;
        }
        this._dragging = true;
        this._range = {
            top: Math.min(this._anchor.row, cell.row),
            bottom: Math.max(this._anchor.row, cell.row),
            left: Math.min(this._anchor.column, cell.column),
            right: Math.max(this._anchor.column, cell.column)
        };
        this._highlight();
    };

    RangeSelection.prototype._mouseUp = function () {
        document.removeEventListener("mousemove", this._onMove);
        document.removeEventListener("mouseup", this._onUp);
        if (!this._dragging) {
            return;
        }
        this._dragging = false;
        this._justDragged = true;
        setTimeout(function () {
            this._justDragged = false;
        }.bind(this), 600);
        this._options.onSelect(this._collect());
    };

    // Dane zaznaczenia: wiersze (obiekty dni) i kolumny
    RangeSelection.prototype._collect = function () {
        var range = this._range;
        var binding = this._table.getBinding("rows");
        var contexts = binding.getAllCurrentContexts
            ? binding.getAllCurrentContexts() : binding.getContexts(0, binding.getLength());
        var rows = contexts.filter(function (context) {
            return context && context.getIndex() >= range.top && context.getIndex() <= range.bottom;
        }).map(function (context) {
            return context.getObject() || {};
        });
        var columns = this._visibleColumns().slice(range.left, range.right + 1).map(this._options.columnInfo);
        return { rows: rows, columns: columns };
    };

    // Podświetlenie widocznych komórek z zakresu (po przewinięciu tabeli rysowane od nowa)
    RangeSelection.prototype._highlight = function () {
        var dom = this._table.getDomRef();
        if (!dom) {
            return;
        }
        Array.prototype.forEach.call(dom.querySelectorAll(".zwbRczSel"), function (cell) {
            cell.classList.remove("zwbRczSel");
            cell.style.boxShadow = "";
        });
        var range = this._range;
        if (!range) {
            return;
        }
        var columns = this._visibleColumns();
        this._table.getRows().forEach(function (row, rowIndex) {
            var context = row.getBindingContext();
            var index = context ? context.getIndex() : -1;
            if (index < range.top || index > range.bottom) {
                return;
            }
            for (var columnIndex = range.left; columnIndex <= range.right; columnIndex++) {
                var cell = dom.querySelector("tr[data-sap-ui-rowindex=\"" + rowIndex + "\"] td[data-sap-ui-colid=\""
                    + columns[columnIndex].getId() + "\"]");
                if (!cell) {
                    continue;
                }
                cell.classList.add("zwbRczSel");
                // Ramka wokół całego obszaru
                var edges = [];
                if (index === range.top) {
                    edges.push("inset 0 2px 0 var(--sapSelectedColor, #0064d9)");
                }
                if (index === range.bottom) {
                    edges.push("inset 0 -2px 0 var(--sapSelectedColor, #0064d9)");
                }
                if (columnIndex === range.left) {
                    edges.push("inset 2px 0 0 var(--sapSelectedColor, #0064d9)");
                }
                if (columnIndex === range.right) {
                    edges.push("inset -2px 0 0 var(--sapSelectedColor, #0064d9)");
                }
                cell.style.boxShadow = edges.join(", ");
            }
        });
    };

    return RangeSelection;
});
