sap.ui.define([
    "sap/ui/core/Control",
    "zwb/rcz/ext/MessageList"
], function (Control, MessageList) {
    "use strict";

    // Ekran wszystkich komunikatów: nagłówek, filtr typu (Wszystkie / Błędy / Ostrzeżenia / Pozostałe)
    // i lista pogrupowana wg typu (błędy na górze).
    // Dane: setData({ title, subtitle, messages, loading })

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

    return Control.extend("zwb.rcz.ext.control.MessageBoard", {
        metadata: {
            properties: {
                allText: { type: "string", defaultValue: "" },
                errorsText: { type: "string", defaultValue: "" },
                warningsText: { type: "string", defaultValue: "" },
                infosText: { type: "string", defaultValue: "" },
                emptyText: { type: "string", defaultValue: "" }
            }
        },

        renderer: {
            apiVersion: 2,
            render: function (rm, control) {
                rm.openStart("div", control);
                rm.class("zwbRczBoard");
                rm.openEnd();
                rm.close("div");
            }
        },

        init: function () {
            this._data = { title: "", subtitle: "", messages: [], loading: true };
            this._filter = "all";
        },

        setData: function (data) {
            this._data = data;
            this._draw();
        },

        onAfterRendering: function () {
            this._draw();
        },

        _getText: function (key) {
            return {
                msgErrors: this.getErrorsText(),
                msgWarnings: this.getWarningsText(),
                msgInfos: this.getInfosText(),
                msgNone: this.getEmptyText()
            }[key] || key;
        },

        _draw: function () {
            var root = this.getDomRef();
            if (!root) {
                return;
            }
            var data = this._data;
            var counts = MessageList.count(data.messages);
            root.innerHTML = "";
            root.classList.toggle("is-loading", !!data.loading);

            var head = create("div", "zwbRczBoardHead");
            head.appendChild(create("div", "zwbRczBoardTitle", data.title));
            head.appendChild(create("div", "zwbRczBoardSub", data.subtitle));
            root.appendChild(head);
            root.appendChild(create("div", "zwbRczBoardProgress"));

            // Filtr typu komunikatu z liczbami
            var filters = create("div", "zwbRczBoardFilters");
            [
                ["all", this.getAllText(), data.messages.length],
                ["error", this.getErrorsText(), counts.error],
                ["warning", this.getWarningsText(), counts.warning],
                ["info", this.getInfosText(), counts.info]
            ].forEach(function (entry) {
                if (entry[0] !== "all" && !entry[2]) {
                    return;
                }
                var button = create("button", "zwbRczFilter is-" + entry[0] + (this._filter === entry[0] ? " is-active" : ""));
                button.type = "button";
                if (entry[0] !== "all") {
                    button.appendChild(MessageList.icon(entry[0]));
                }
                button.appendChild(create("span", "zwbRczFilterText", entry[1]));
                button.appendChild(create("span", "zwbRczFilterCount", String(entry[2])));
                button.addEventListener("click", function () {
                    this._filter = entry[0];
                    this._draw();
                }.bind(this));
                filters.appendChild(button);
            }, this);
            root.appendChild(filters);

            var list = create("div", "zwbRczBoardList");
            var filter = this._filter;
            var visible = data.messages.filter(function (message) {
                var key = message.Tykom === "E" ? "error" : message.Tykom === "W" ? "warning" : "info";
                return filter === "all" || filter === key;
            });
            if (!data.loading) {
                MessageList.render(list, visible, { getText: this._getText.bind(this), showDate: true });
            }
            root.appendChild(list);
        }
    });
});
