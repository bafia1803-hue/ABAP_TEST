sap.ui.define([
    "sap/ui/core/Control"
], function (Control) {
    "use strict";

    // Oś czasu jednego dnia: nagłówek z datą, skala 0-24 h, wiersz = rodzaj czasu, pasek = przedział godzin.
    // Zmiana dnia: przyciski, klawisze strzałek, przeciągnięcie (mysz / palec), przewinięcie w poziomie.
    // Kontrolka sama nie pobiera danych - wywołuje zdarzenie "navigate", a dane dostaje przez showDay().
    //
    // Dane dnia (showDay):
    // { title, subtitle, weekend: "" | "sat" | "sun",
    //   rows: [{ id, title, text, focused, color,
    //            bars: [{ start, end, continues, carried, label, tooltip,
    //                     details: { title, time, duration, note } }] }] }   start / end w minutach 0-1440
    // continues = przedział kończy się następnego dnia, carried = dokończenie przedziału z poprzedniego dnia.
    // Kliknięcie w pasek otwiera okienko ze szczegółami (details), kliknięcie obok je zamyka.

    var DURATION = 360;
    var MINUTES_PER_DAY = 1440;
    var SWIPE_THRESHOLD = 70;
    var WHEEL_THRESHOLD = 60;
    var WHEEL_LOCK_MS = 450;
    var DRAG_RESISTANCE = 0.35;
    var NARROW_WIDTH = 640;

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

    // Dwie klatki: przeglądarka zdąży narysować stan początkowy, zanim zacznie się przejście
    function nextFrame(callback) {
        window.requestAnimationFrame(function () {
            window.requestAnimationFrame(callback);
        });
    }

    function reducedMotion() {
        return !!(window.matchMedia && window.matchMedia("(prefers-reduced-motion: reduce)").matches);
    }

    function percent(minutes) {
        return (Math.max(0, Math.min(MINUTES_PER_DAY, minutes)) / MINUTES_PER_DAY * 100) + "%";
    }

    function chevron(direction) {
        var path = direction < 0 ? "M15 5l-7 7 7 7" : "M9 5l7 7-7 7";
        return "<svg viewBox=\"0 0 24 24\" aria-hidden=\"true\"><path d=\"" + path + "\" /></svg>";
    }

    var DayTimeline = Control.extend("zwb.rcz.ext.control.DayTimeline", {
        metadata: {
            properties: {
                prevText: { type: "string", defaultValue: "" },
                nextText: { type: "string", defaultValue: "" },
                emptyText: { type: "string", defaultValue: "" },
                hintText: { type: "string", defaultValue: "" }
            },
            events: {
                navigate: {
                    parameters: {
                        // -1 = poprzedni dzień, 1 = następny dzień
                        direction: { type: "int" }
                    }
                }
            }
        },

        renderer: {
            apiVersion: 2,
            render: function (rm, control) {
                rm.openStart("div", control);
                rm.class("zwbTl");
                rm.attr("tabindex", "0");
                rm.attr("role", "region");
                rm.openEnd();
                rm.close("div");
            }
        },

        exit: function () {
            this._closePopover();
        },

        init: function () {
            this._day = null;
            this._details = new WeakMap();
            this._popover = null;
            this._suppressClick = false;
            this._loading = false;
            this._drag = null;
            this._wheel = { sum: 0, lockedUntil: 0 };
        },

        // ------------------------------------------------------------------ API
        showDay: function (day, direction) {
            this._day = day;
            if (this._refs) {
                this._renderDay(day, direction || 0, false);
            }
        },

        setLoading: function (loading) {
            this._loading = !!loading;
            var root = this.getDomRef();
            if (root) {
                root.classList.toggle("is-loading", this._loading);
            }
        },

        // ------------------------------------------------------------------ szkielet
        onAfterRendering: function () {
            this._build();
            if (this._day) {
                this._renderDay(this._day, 0, true);
            }
            this.setLoading(this._loading);
        },

        _build: function () {
            var root = this.getDomRef();
            root.innerHTML = "";

            var head = create("div", "zwbTl-head");
            var prev = create("button", "zwbTl-nav zwbTl-prev");
            prev.innerHTML = chevron(-1);
            prev.title = this.getPrevText();
            prev.setAttribute("aria-label", this.getPrevText());
            prev.dataset.direction = "-1";
            var next = create("button", "zwbTl-nav zwbTl-next");
            next.innerHTML = chevron(1);
            next.title = this.getNextText();
            next.setAttribute("aria-label", this.getNextText());
            next.dataset.direction = "1";
            var titleBox = create("div", "zwbTl-titleBox");
            var titles = create("div", "zwbTl-titles");
            var subtitle = create("div", "zwbTl-subtitle");
            titleBox.appendChild(titles);
            titleBox.appendChild(subtitle);
            head.appendChild(prev);
            head.appendChild(titleBox);
            head.appendChild(next);

            var progress = create("div", "zwbTl-progress");

            var body = create("div", "zwbTl-body");
            var scale = create("div", "zwbTl-scale");
            scale.appendChild(create("div", "zwbTl-scaleLabel", this.getHintText()));
            var hours = create("div", "zwbTl-hours");
            for (var hour = 0; hour <= 24; hour++) {
                var tick = create("span", "zwbTl-hour" + (hour % 2 ? " is-odd" : ""), String(hour));
                tick.style.left = (hour / 24 * 100) + "%";
                hours.appendChild(tick);
            }
            scale.appendChild(hours);
            var rows = create("div", "zwbTl-rows");
            var empty = create("div", "zwbTl-empty", this.getEmptyText());
            body.appendChild(scale);
            body.appendChild(rows);
            body.appendChild(empty);

            root.appendChild(head);
            root.appendChild(progress);
            root.appendChild(body);

            this._refs = { root: root, titles: titles, subtitle: subtitle, body: body, rows: rows };
            this._bindEvents(root);
            this._updateWidthClass();
        },

        _bindEvents: function (root) {
            // Element główny może zostać ten sam po ponownym renderowaniu - zdarzenia tylko raz
            if (root.__zwbTlBound) {
                return;
            }
            root.__zwbTlBound = true;
            var that = this;

            root.addEventListener("click", function (event) {
                that._onClick(event);
            });
            document.addEventListener("click", function (event) {
                if (that._popover && !root.contains(event.target) && !event.target.closest(".zwbTl-pop")) {
                    that._closePopover();
                }
            });
            // Przewinięcie strony przesuwa pasek - okienko się zamyka
            document.addEventListener("scroll", function () {
                that._closePopover();
            }, true);
            document.addEventListener("keydown", function (event) {
                if (event.key === "Escape") {
                    that._closePopover();
                }
            });
            root.addEventListener("keydown", function (event) {
                if (event.key === "Escape") {
                    that._closePopover();
                    return;
                }
                if (event.key === "ArrowLeft" || event.key === "ArrowRight") {
                    event.preventDefault();
                    that._navigate(event.key === "ArrowLeft" ? -1 : 1);
                }
            });
            root.addEventListener("wheel", function (event) {
                that._onWheel(event);
            }, { passive: false });
            root.addEventListener("pointerdown", function (event) {
                that._onPointerDown(event);
            });
            root.addEventListener("pointermove", function (event) {
                that._onPointerMove(event);
            });
            root.addEventListener("pointerup", function (event) {
                that._onPointerUp(event);
            });
            root.addEventListener("pointercancel", function (event) {
                that._onPointerUp(event);
            });
            window.addEventListener("resize", function () {
                that._closePopover();
                that._updateWidthClass();
            });
        },

        _updateWidthClass: function () {
            if (!this._refs) {
                return;
            }
            this._refs.root.classList.toggle("is-narrow", this._refs.root.clientWidth < NARROW_WIDTH);
            Array.prototype.forEach.call(this._refs.rows.querySelectorAll(".zwbTl-bars"), this._hideTightLabels);
        },

        _navigate: function (direction) {
            this._closePopover();
            this.fireNavigate({ direction: direction });
        },

        _onClick: function (event) {
            // Kliknięcie kończące przeciąganie nie otwiera okienka
            if (this._suppressClick) {
                this._suppressClick = false;
                return;
            }
            var button = event.target.closest(".zwbTl-nav");
            if (button) {
                this._navigate(Number(button.dataset.direction));
                return;
            }
            var bar = event.target.closest(".zwbTl-bar");
            if (bar) {
                this._togglePopover(bar);
            } else if (!event.target.closest(".zwbTl-pop")) {
                this._closePopover();
            }
        },

        // ------------------------------------------------------------------ okienko szczegółów paska
        _togglePopover: function (bar) {
            if (this._popover && this._popover.bar === bar) {
                this._closePopover();
                return;
            }
            this._closePopover();
            var details = this._details.get(bar);
            if (!details) {
                return;
            }

            var pop = create("div", "zwbTl-pop");
            pop.setAttribute("role", "dialog");
            pop.style.setProperty("--zwb-color", getComputedStyle(bar).getPropertyValue("--zwb-color"));
            pop.appendChild(create("div", "zwbTl-popTitle", details.title));
            pop.appendChild(create("div", "zwbTl-popTime", details.time));
            if (details.duration) {
                pop.appendChild(create("div", "zwbTl-popLine", details.duration));
            }
            if (details.note) {
                pop.appendChild(create("div", "zwbTl-popNote", details.note));
            }
            // Okienko leży nad całą stroną (nie jest przycinane przez ramkę wykresu)
            document.body.appendChild(pop);

            // Nad paskiem, a gdy brak miejsca - pod nim; zawsze w granicach okna przeglądarki
            var barRect = bar.getBoundingClientRect();
            var margin = 8;
            var center = barRect.left + barRect.width / 2;
            var left = Math.max(margin, Math.min(window.innerWidth - pop.offsetWidth - margin, center - pop.offsetWidth / 2));
            var top = barRect.top - pop.offsetHeight - 12;
            if (top < margin) {
                top = barRect.bottom + 12;
                pop.classList.add("is-below");
            }
            pop.style.left = left + "px";
            pop.style.top = top + "px";
            pop.style.setProperty("--zwb-arrow-x", Math.max(12, Math.min(pop.offsetWidth - 12, center - left)) + "px");

            bar.classList.add("is-selected");
            this._popover = { element: pop, bar: bar };
            nextFrame(function () {
                pop.classList.add("is-open");
            });
        },

        _closePopover: function () {
            var popover = this._popover;
            if (!popover) {
                return;
            }
            this._popover = null;
            popover.bar.classList.remove("is-selected");
            popover.element.classList.remove("is-open");
            setTimeout(function () {
                popover.element.remove();
            }, 200);
        },

        // ------------------------------------------------------------------ gesty
        _onWheel: function (event) {
            if (Math.abs(event.deltaX) <= Math.abs(event.deltaY)) {
                return;
            }
            event.preventDefault();
            var now = Date.now();
            if (now < this._wheel.lockedUntil) {
                return;
            }
            this._wheel.sum += event.deltaX;
            if (Math.abs(this._wheel.sum) >= WHEEL_THRESHOLD) {
                var direction = this._wheel.sum > 0 ? 1 : -1;
                this._wheel = { sum: 0, lockedUntil: now + WHEEL_LOCK_MS };
                this._navigate(direction);
            }
        },

        _onPointerDown: function (event) {
            if (event.button !== 0 || event.target.closest(".zwbTl-nav")) {
                return;
            }
            this._drag = { id: event.pointerId, startX: event.clientX, dx: 0, active: false };
        },

        _onPointerMove: function (event) {
            var drag = this._drag;
            if (!drag || drag.id !== event.pointerId) {
                return;
            }
            drag.dx = event.clientX - drag.startX;
            if (!drag.active && Math.abs(drag.dx) > 6) {
                drag.active = true;
                this._refs.root.classList.add("is-dragging");
                this._refs.root.setPointerCapture(event.pointerId);
            }
            if (drag.active) {
                this._refs.root.style.setProperty("--zwb-drag", (drag.dx * DRAG_RESISTANCE) + "px");
            }
        },

        _onPointerUp: function (event) {
            var drag = this._drag;
            if (!drag || drag.id !== event.pointerId) {
                return;
            }
            this._drag = null;
            var root = this._refs.root;
            root.classList.remove("is-dragging");
            root.style.setProperty("--zwb-drag", "0px");
            if (drag.active) {
                this._suppressClick = true;
            }
            if (drag.active && Math.abs(drag.dx) >= SWIPE_THRESHOLD) {
                // Przeciągnięcie w lewo = następny dzień (jak przewracanie kartki)
                this._navigate(drag.dx < 0 ? 1 : -1);
            }
        },

        // ------------------------------------------------------------------ rysowanie dnia
        _renderDay: function (day, direction, instant) {
            var animate = !instant && !reducedMotion();
            var refs = this._refs;

            this._closePopover();
            refs.root.classList.toggle("has-focus", day.rows.some(function (row) {
                return row.focused;
            }));
            refs.subtitle.textContent = day.subtitle || "";
            this._swapTitle(day, direction, animate);
            this._updateRows(day.rows, direction, animate);
            refs.root.classList.toggle("is-empty", !day.rows.length);
        },

        _swapTitle: function (day, direction, animate) {
            var titles = this._refs.titles;
            var fresh = create("div", "zwbTl-title" + (day.weekend ? " is-" + day.weekend : ""), day.title);
            var old = titles.querySelector(".zwbTl-title:not(.is-leaving)");
            titles.appendChild(fresh);
            this._slide(old, fresh, direction, animate);
        },

        // Stary element wyjeżdża, nowy wjeżdża z przeciwnej strony (kierunek 0 = tylko przenikanie)
        _slide: function (oldElement, newElement, direction, animate) {
            if (!animate) {
                if (oldElement) {
                    oldElement.remove();
                }
                return;
            }
            var enterClass = direction > 0 ? "from-right" : direction < 0 ? "from-left" : "from-fade";
            var leaveClass = direction > 0 ? "to-left" : direction < 0 ? "to-right" : "to-fade";
            newElement.classList.add(enterClass);
            nextFrame(function () {
                newElement.classList.remove(enterClass);
            });
            if (oldElement) {
                oldElement.classList.add("is-leaving", leaveClass);
                setTimeout(function () {
                    oldElement.remove();
                }, DURATION);
            }
        },

        _updateRows: function (rows, direction, animate) {
            var container = this._refs.rows;
            var current = {};
            Array.prototype.forEach.call(container.querySelectorAll(".zwbTl-row:not(.is-leaving)"), function (element) {
                current[element.dataset.id] = element;
            });

            // Położenie przed zmianą (animacja przesunięcia wierszy, które zostają)
            var firstTop = {};
            var startHeight = container.offsetHeight;
            if (animate) {
                Object.keys(current).forEach(function (id) {
                    firstTop[id] = current[id].getBoundingClientRect().top;
                });
            }

            // Znikające wiersze: wypadają z układu (pozycja absolutna) i gasną w miejscu
            var newIds = {};
            rows.forEach(function (row) {
                newIds[row.id] = true;
            });
            Object.keys(current).forEach(function (id) {
                if (!newIds[id]) {
                    this._removeRow(current[id], direction, animate);
                }
            }, this);

            // Wiersze w nowej kolejności: istniejące aktualizowane, nowe tworzone
            var entering = [];
            rows.forEach(function (row, index) {
                var element = current[row.id];
                if (element) {
                    this._fillRow(element, row, direction, animate);
                } else {
                    element = this._createRow(row);
                    entering.push(element);
                }
                var atIndex = container.children[index];
                if (atIndex !== element) {
                    container.insertBefore(element, atIndex || null);
                }
            }, this);

            // Pomiar tekstów dopiero teraz, gdy wszystkie wiersze są na stronie
            Array.prototype.forEach.call(container.querySelectorAll(".zwbTl-bars:not(.is-leaving)"),
                this._hideTightLabels);

            if (!animate) {
                return;
            }

            // Wiersze, które zostały, płynnie przesuwają się na nowe miejsce
            Object.keys(firstTop).forEach(function (id) {
                var element = current[id];
                if (!newIds[id]) {
                    return;
                }
                var delta = firstTop[id] - element.getBoundingClientRect().top;
                if (Math.abs(delta) < 1) {
                    return;
                }
                element.style.transition = "none";
                element.style.transform = "translateY(" + delta + "px)";
                nextFrame(function () {
                    element.style.transition = "";
                    element.style.transform = "";
                });
            });

            // Nowe wiersze rozwijają się
            entering.forEach(function (element) {
                element.classList.add("is-entering");
            });
            nextFrame(function () {
                entering.forEach(function (element) {
                    element.classList.remove("is-entering");
                });
            });

            // Wysokość listy zmienia się płynnie
            var endHeight = container.offsetHeight;
            if (startHeight !== endHeight) {
                container.style.height = startHeight + "px";
                nextFrame(function () {
                    container.style.height = endHeight + "px";
                    setTimeout(function () {
                        container.style.height = "";
                    }, DURATION);
                });
            }
        },

        _createRow: function (row) {
            var element = create("div", "zwbTl-row");
            element.dataset.id = row.id;
            var label = create("div", "zwbTl-label");
            label.appendChild(create("div", "zwbTl-name"));
            label.appendChild(create("div", "zwbTl-meta"));
            element.appendChild(label);
            element.appendChild(create("div", "zwbTl-track"));
            this._fillRow(element, row, 0, false);
            return element;
        },

        _fillRow: function (element, row, direction, animate) {
            element.classList.toggle("is-focused", !!row.focused);
            element.style.setProperty("--zwb-color", row.color);
            element.querySelector(".zwbTl-name").textContent = row.title;
            element.querySelector(".zwbTl-name").title = row.title;
            element.querySelector(".zwbTl-meta").textContent = row.text;

            var track = element.querySelector(".zwbTl-track");
            var old = track.querySelector(".zwbTl-bars:not(.is-leaving)");
            var bars = this._createBars(row);
            track.appendChild(bars);
            this._slide(old, bars, direction, animate);
        },

        // Godziny, które nie mieszczą się na pasku, zostają tylko w podpowiedzi
        _hideTightLabels: function (bars) {
            Array.prototype.forEach.call(bars.querySelectorAll(".zwbTl-barText"), function (text) {
                text.classList.toggle("is-hidden", text.scrollWidth > text.clientWidth + 1);
            });
        },

        _createBars: function (row) {
            var bars = create("div", "zwbTl-bars");
            row.bars.forEach(function (bar) {
                var element = create("div", "zwbTl-bar"
                    + (bar.continues ? " is-continued" : "")
                    + (bar.carried ? " is-carried" : ""));
                element.style.left = percent(bar.start);
                element.style.width = "calc(" + percent(bar.end) + " - " + percent(bar.start) + ")";
                element.title = bar.tooltip;
                element.appendChild(create("span", "zwbTl-barText", bar.label));
                if (bar.details) {
                    this._details.set(element, bar.details);
                }
                bars.appendChild(element);
            }, this);
            return bars;
        },

        _removeRow: function (element, direction, animate) {
            if (!animate) {
                element.remove();
                return;
            }
            element.style.top = element.offsetTop + "px";
            element.classList.add("is-leaving", direction > 0 ? "to-left" : direction < 0 ? "to-right" : "to-fade");
            setTimeout(function () {
                element.remove();
            }, DURATION);
        }
    });

    return DayTimeline;
});
